// Sinh test/fixtures/parser/corpus.jsonl — chạy lại khi cần MỞ RỘNG corpus
// (Tony: "sẽ tinh chỉnh hàng tháng"). Giá trị "expected" tính ĐỘC LẬP với
// parser thật (công thức đóng, không gọi lại `parseMessage`) cho mọi trường
// hợp có công thức đóng được — đây là thứ khiến corpus có giá trị phát hiện
// bug thật, không chỉ là ảnh chụp hành vi hiện tại.
//
// Chạy: dart run tool/generate_parser_corpus.dart
import 'dart:convert';
import 'dart:io';

const _fixedToday = (year: 2026, month: 8, day: 21); // Thứ Sáu

const _categories = {
  'an_uong': 'cà phê',
  'di_chuyen': 'xăng',
  'nha_cua': 'tiền điện',
  'gia_dinh': 'bỉm',
  'mua_sam': 'quần áo',
  'dien_tu': 'tai nghe',
  'suc_khoe': 'thuốc',
  'lam_dep': 'cắt tóc',
  'giao_duc': 'học phí',
  'giai_tri': 'xem phim',
  'phat_sinh': 'sửa chữa',
  'luong': 'lương',
};

DateTime get _today =>
    DateTime(_fixedToday.year, _fixedToday.month, _fixedToday.day);

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `1500000` → `"1.500.000"` — dùng để sinh ca test số có nhóm phân cách
/// nghìn (độc lập với `tokenizer.dart`, chỉ là format ngược lại).
String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// `thứ N` → ISO weekday `N-1` — cùng công thức với `date_parser.dart`,
/// viết lại độc lập ở đây để corpus không "tự kiểm chứng chính nó".
DateTime _resolveWeekday(int isoWeekday, {String? week}) {
  final todayIso = _today.weekday;
  final daysAgo = (todayIso - isoWeekday + 7) % 7;
  var result = _today.subtract(Duration(days: daysAgo));
  if (week == 'trước') result = result.subtract(const Duration(days: 7));
  if (week == 'sau') result = result.add(const Duration(days: 7));
  return result;
}

class Case {
  Case(this.input, this.expected);
  final String input;
  final List<Map<String, dynamic>> expected;
}

Map<String, dynamic> _exp({
  int? amountMinor,
  bool amountConfident = true,
  String? categoryKey,
  DateTime? date,
  bool dateExplicit = false,
}) => {
  'amountMinor': amountMinor,
  'amountConfident': amountConfident,
  'categoryKey': categoryKey,
  'dateIso': _iso(date ?? _today),
  'dateExplicit': dateExplicit,
};

void main() {
  final cases = <Case>[];

  // ── 1. Ma trận tổ hợp: 12 danh mục × 5 định dạng số × 3 biến thể ngày ──
  final formatFns = <({String Function(int n) render, int Function(int n) value})>[
    (render: (n) => '${n}k', value: (n) => n * 1000),
    (render: (n) => '$n nghìn', value: (n) => n * 1000),
    (render: (n) => '$n tr', value: (n) => n * 1000000),
    (render: (n) => '$n triệu', value: (n) => n * 1000000),
    (
      render: (n) => _groupThousands(n * 100000),
      value: (n) => n * 100000,
    ),
  ];
  const sampleNs = [15, 35, 50, 120, 200];

  final dateVariants = <String, ({String suffix, DateTime date, bool explicit})>{
    'none': (suffix: '', date: _today, explicit: false),
    'homqua': (
      suffix: ' hôm qua',
      date: _today.subtract(const Duration(days: 1)),
      explicit: true,
    ),
    'thu2': (
      suffix: ' thứ 2',
      date: _resolveWeekday(1),
      explicit: true,
    ),
  };

  // Hai vòng với offset lấy mẫu `n` khác nhau — nhân đôi độ phủ tổ hợp
  // danh_mục×định_dạng×ngày mà không cần liệt kê tay.
  for (final roundOffset in [0, 2]) {
    var ni = roundOffset;
    for (final categoryEntry in _categories.entries) {
      final n = sampleNs[ni % sampleNs.length];
      ni++;
      var fi = roundOffset;
      for (final format in formatFns) {
        final suffixText = format.render(n);
        final amount = format.value(n);
        final dateKey = dateVariants.keys.elementAt(fi % dateVariants.length);
        final dv = dateVariants[dateKey]!;
        fi++;
        cases.add(
          Case(
            '${categoryEntry.value} $suffixText${dv.suffix}',
            [
              _exp(
                amountMinor: amount,
                categoryKey: categoryEntry.key,
                date: dv.date,
                dateExplicit: dv.explicit,
              ),
            ],
          ),
        );
      }
    }
  }

  // ── 2. Định dạng số bổ sung (ngàn/củ/vnd/đ/nhóm phân cách phẩy) ──
  for (final n in [8, 20, 35, 99, 250, 999]) {
    cases.add(
      Case('mua đồ $n ngàn', [_exp(amountMinor: n * 1000)]),
    );
    cases.add(
      Case('mua xe $n củ', [_exp(amountMinor: n * 1000000)]),
    );
    cases.add(
      Case('mua đồ ${n}000 vnd', [_exp(amountMinor: n * 1000)]),
    );
    cases.add(
      Case('mua đồ ${n}000đ', [_exp(amountMinor: n * 1000)]),
    );
    cases.add(
      Case('mua đồ $n.000', [_exp(amountMinor: n * 1000)]),
    );
    cases.add(
      Case('mua đồ $n,000', [_exp(amountMinor: n * 1000)]),
    );
  }

  // ── 3. Luật "hệ số mồ côi" — 2tr5 / 1tr250 / "1 triệu N" — nhiều giá trị ──
  const digitWords = {
    1: 'một',
    2: 'hai',
    3: 'ba',
    4: 'bốn',
    5: 'năm',
    6: 'sáu',
    7: 'bảy',
    8: 'tám',
    9: 'chín',
  };
  for (final whole in [1, 2, 3, 5, 8]) {
    for (final frac in [1, 2, 5, 7, 9]) {
      cases.add(
        Case(
          'mua đồ ${whole}tr$frac',
          [_exp(amountMinor: whole * 1000000 + frac * 100000)],
        ),
      );
      cases.add(
        Case(
          'mua đồ $whole triệu $frac',
          [_exp(amountMinor: whole * 1000000 + frac * 100000)],
        ),
      );
      cases.add(
        Case(
          'mua đồ $whole triệu ${digitWords[frac]}',
          [_exp(amountMinor: whole * 1000000 + frac * 100000)],
        ),
      );
    }
    for (final frac3 in [120, 250, 500, 999]) {
      cases.add(
        Case(
          'mua đồ ${whole}tr$frac3',
          [_exp(amountMinor: whole * 1000000 + frac3 * 1000)],
        ),
      );
    }
    cases.add(
      Case('lương $whole triệu rưỡi', [
        _exp(amountMinor: whole * 1000000 + 500000, categoryKey: 'luong'),
      ]),
    );
    cases.add(
      Case('lương ${whole}tr rưỡi', [
        _exp(amountMinor: whole * 1000000 + 500000, categoryKey: 'luong'),
      ]),
    );
  }

  // ── 4. Số đếm viết chữ có biến thể (một/mốt, năm/lăm, bốn/tư, mười/mươi) ──
  final spelledTens = <String, int>{
    'mười': 10,
    'mười một': 11,
    'mười lăm': 15,
    'hai mươi': 20,
    'hai mươi mốt': 21,
    'hai mươi tư': 24,
    'hai mươi lăm': 25,
    'ba mươi': 30,
    'năm mươi': 50,
    'chín mươi chín': 99,
  };
  for (final entry in spelledTens.entries) {
    cases.add(
      Case(
        'mua đồ ${entry.key} nghìn',
        [_exp(amountMinor: entry.value * 1000)],
      ),
    );
  }

  // ── 5. Hàng trăm + "linh"/"lẻ", trộn số/chữ ("2 trăm 50 nghìn") ──
  final hundredsCases = <String, int>{
    'một trăm linh năm nghìn': 105000,
    'một trăm lẻ năm nghìn': 105000,
    'hai trăm nghìn': 200000,
    'hai trăm năm mươi nghìn': 250000,
    '2 trăm 50 nghìn': 250000,
    '1 triệu 2 trăm 50 nghìn': 1250000,
    '1 triệu hai trăm năm mươi nghìn': 1250000,
    '3 trăm nghìn': 300000,
    'năm trăm ba mươi nghìn': 530000,
  };
  for (final entry in hundredsCases.entries) {
    cases.add(Case('mua đồ ${entry.key}', [_exp(amountMinor: entry.value)]));
  }

  // ── 6. Ngày — mọi thứ trong tuần, có/không "tuần trước"/"tuần sau" ──
  for (var wd = 2; wd <= 7; wd++) {
    cases.add(
      Case('cà phê 35k thứ $wd', [
        _exp(
          amountMinor: 35000,
          categoryKey: 'an_uong',
          date: _resolveWeekday(wd - 1),
          dateExplicit: true,
        ),
      ]),
    );
  }
  cases.add(
    Case('cà phê 35k thứ 3 tuần trước', [
      _exp(
        amountMinor: 35000,
        categoryKey: 'an_uong',
        date: _resolveWeekday(2, week: 'trước'),
        dateExplicit: true,
      ),
    ]),
  );
  cases.add(
    Case('cà phê 35k thứ 5 tuần sau', [
      _exp(
        amountMinor: 35000,
        categoryKey: 'an_uong',
        date: _resolveWeekday(4, week: 'sau'),
        dateExplicit: true,
      ),
    ]),
  );
  cases.add(
    Case('cà phê 35k chủ nhật', [
      _exp(
        amountMinor: 35000,
        categoryKey: 'an_uong',
        date: _resolveWeekday(7),
        dateExplicit: true,
      ),
    ]),
  );
  cases.add(
    Case('cà phê 35k hôm kia', [
      _exp(
        amountMinor: 35000,
        categoryKey: 'an_uong',
        date: _today.subtract(const Duration(days: 2)),
        dateExplicit: true,
      ),
    ]),
  );
  cases.add(
    Case('cà phê 35k ngày mai', [
      _exp(
        amountMinor: 35000,
        categoryKey: 'an_uong',
        date: _today.add(const Duration(days: 1)),
        dateExplicit: true,
      ),
    ]),
  );
  for (final entry in {'12/3': (3, 12), '1/1': (1, 1), '25/12': (12, 25), '9/6/2025': (6, 9)}.entries) {
    final parts = entry.key.split('/');
    final year = parts.length == 3 ? int.parse(parts[2]) : 2026;
    cases.add(
      Case('cà phê 35k ${entry.key}', [
        _exp(
          amountMinor: 35000,
          categoryKey: 'an_uong',
          date: DateTime(year, entry.value.$1, entry.value.$2),
          dateExplicit: true,
        ),
      ]),
    );
  }
  for (final label in ['sáng nay', 'trưa nay', 'chiều nay', 'tối nay', 'khuya nay']) {
    cases.add(
      Case('cà phê 35k $label', [
        _exp(
          amountMinor: 35000,
          categoryKey: 'an_uong',
          date: _today,
          dateExplicit: true,
        ),
      ]),
    );
  }
  cases.add(
    Case('cà phê 35k tối qua', [
      _exp(
        amountMinor: 35000,
        categoryKey: 'an_uong',
        date: _today.subtract(const Duration(days: 1)),
        dateExplicit: true,
      ),
    ]),
  );

  // ── 7. segmenter — nhiều khoản trong một tin nhắn ──
  cases.add(
    Case('Café 30k, xem phim 100k', [
      _exp(amountMinor: 30000, categoryKey: 'an_uong'),
      _exp(amountMinor: 100000, categoryKey: 'giai_tri'),
    ]),
  );
  cases.add(
    Case('cà phê 35k và xăng 50k', [
      _exp(amountMinor: 35000, categoryKey: 'an_uong'),
      _exp(amountMinor: 50000, categoryKey: 'di_chuyen'),
    ]),
  );
  cases.add(
    Case('ăn sáng 30k; ăn trưa 50k; ăn tối 40k', [
      _exp(amountMinor: 30000, categoryKey: 'an_uong'),
      _exp(amountMinor: 50000, categoryKey: 'an_uong'),
      _exp(amountMinor: 40000, categoryKey: 'an_uong'),
    ]),
  );
  cases.add(
    Case('cắt tóc 100k, mua thuốc 35k, xem phim 90k hôm qua', [
      _exp(amountMinor: 100000, categoryKey: 'lam_dep'),
      _exp(amountMinor: 35000, categoryKey: 'suc_khoe'),
      _exp(
        amountMinor: 90000,
        categoryKey: 'giai_tri',
        date: _today.subtract(const Duration(days: 1)),
        dateExplicit: true,
      ),
    ]),
  );

  // ── 8. Không hiểu — không có số tiền ──
  // Cố tình chọn chữ KHÔNG trùng bất kỳ từ khoá danh mục thật nào (đã grep
  // `category_seed.dart` để xác nhận) — nếu không, `categoryKey` mong đợi
  // `null` sẽ sai một cách chính đáng (category_matcher chạy độc lập với
  // amount, tìm được từ khoá thì vẫn khớp dù không có số tiền).
  for (final text in ['gõ thử xem sao', 'chưa nghĩ ra gì cả', 'xin chào']) {
    cases.add(Case(text, [_exp(amountMinor: null, amountConfident: false)]));
  }
  // "hôm nay" vẫn là một cụm ngày tường minh hợp lệ dù không có số tiền —
  // category_matcher/date_parser chạy ĐỘC LẬP với amount_evaluator.
  cases.add(
    Case('hôm nay vui quá', [
      _exp(
        amountMinor: null,
        amountConfident: false,
        date: _today,
        dateExplicit: true,
      ),
    ]),
  );

  // ── 9. Teencode ──
  cases.add(
    Case('ăn trưa ngon lắm dc 35k', [
      _exp(amountMinor: 35000, categoryKey: 'an_uong'),
    ]),
  );
  cases.add(
    Case('ko nhớ mua gì hết 20k', [_exp(amountMinor: 20000)]),
  );

  // ── Ghi file ──
  final buffer = StringBuffer();
  for (final c in cases) {
    buffer.writeln(jsonEncode({'input': c.input, 'expected': c.expected}));
  }
  final outFile = File('test/fixtures/parser/corpus.jsonl');
  outFile.writeAsStringSync(buffer.toString());
  stderr.writeln('Đã ghi ${cases.length} ca vào ${outFile.path}');
}
