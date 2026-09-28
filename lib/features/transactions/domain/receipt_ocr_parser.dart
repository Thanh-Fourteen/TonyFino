import '../../../core/text/ascii_fold.dart';

/// Kết quả trích xuất từ văn bản OCR thô của một hoá đơn — CHỈ gợi ý, không
/// bao giờ dùng thẳng để ghi giao dịch (Luật #7, xem `TransactionFormPrefill.
/// fromReceiptScan`). Mọi trường đều `null` được — call site tự quyết định
/// fallback (form vẫn mở, chỉ trống hơn, Tony tự gõ tay).
/// Một dòng hàng trên hoá đơn — CHỈ gợi ý, Tony duyệt/sửa trong bảng món.
class ReceiptItem {
  const ReceiptItem({required this.name, this.amountMinor});

  final String name;

  /// Thành tiền của dòng (độ lớn, dương). `null` = đọc được TÊN nhưng không
  /// đọc được tiền (ngón tay che, mực mờ) — vẫn đưa vào bảng với ô tiền
  /// trống để Tony điền, thay vì làm mất món.
  final int? amountMinor;

  @override
  String toString() => 'ReceiptItem($name, $amountMinor)';
}

class ReceiptOcrExtraction {
  const ReceiptOcrExtraction({
    this.merchantName,
    this.amountMinor,
    this.occurredAt,
    this.items = const [],
  });

  final String? merchantName;

  /// VND nguyên (currencyScale 0), luôn là ĐỘ LỚN (dương) — xem
  /// [_findTotalAmount] cho thứ tự ưu tiên nhãn.
  final int? amountMinor;

  /// Ngày (và giờ, nếu hoá đơn in giờ cùng dòng) in trên hoá đơn — xem
  /// [_findDate]. `null` = không thấy ngày nào đáng tin, form giữ "hôm nay".
  final DateTime? occurredAt;

  /// Các dòng hàng theo thứ tự trên hoá đơn — xem [_findItems].
  final List<ReceiptItem> items;
}

/// Nhãn "tổng tiền" và mức độ chắc chắn của nó.
///
/// Luật chọn (xem [_findTotalAmount]): nhãn TỔNG THỰC SỰ (mức ≥ 2) nào in
/// CUỐI CÙNG thì thắng; nhãn TẠM TÍNH (mức 1) chỉ dùng khi không có nhãn
/// tổng nào. Không để mức 3 thắng mức 2 bất kể thứ tự — hoá đơn nhà hàng thật
/// (ảnh Tony gửi 2026-09-28) in "Tổng cộng 1.428.000" (TRƯỚC VAT), rồi
/// "VAT 114.240", rồi "Tổng: 1.542.240" mới là số phải trả. Luật "mức 3 luôn
/// thắng" ban đầu đã chọn sai đúng hoá đơn đó.
///
/// Mức 3 chỉ khác mức 2 ở chỗ được MIỄN danh sách [_notTotalMarkers] —
/// "Tổng cộng (đã gồm VAT)" vẫn là tổng dù có chữ VAT.
///
/// So khớp trên bản KHÔNG DẤU (qua [foldToAscii], cùng cách `note_ascii`/
/// `category_matcher` đã dùng từ Phase 4/7) vì OCR hay làm mất/sai dấu ở
/// đúng những chữ quan trọng nhất. Một dòng chứa nhiều nhãn thì nhãn DÀI
/// NHẤT quyết định mức: "tổng tiền hàng" (tạm tính) chứa "tổng tiền" nhưng
/// không được coi là tổng.
const _totalLabelTiers = <String, int>{
  // Tầng 3 — chắc chắn là số CUỐI CÙNG phải trả.
  'tong thanh toan': 3,
  'tong tien thanh toan': 3,
  'can thanh toan': 3,
  'phai thanh toan': 3,
  'khach can tra': 3,
  'khach phai tra': 3,
  'tong cong': 3,
  'grand total': 3,
  'total amount': 3,
  'amount due': 3,
  // Tầng 2 — tổng, nhưng có thể còn phí/giảm giá phía sau.
  'tong tien': 2,
  'tong so tien': 2,
  // "Tổng số" — nhãn Emart dùng. Bắt được nhờ chụp hoá đơn THẬT của Tony
  // (Emart Sala Thủ Thiêm 23/08/2026); danh sách nhãn cũ nghĩ ra trong đầu
  // không có nó, nên hoá đơn rơi thẳng xuống nhánh dự phòng.
  'tong so': 2,
  'total': 2,
  // "Tổng:" trần — hoá đơn khẩu trang Hội An và nhà hàng buffet (ảnh thật)
  // in số cuối cùng dưới đúng một chữ này.
  'tong': 2,
  // Tầng 1 — tạm tính trước giảm giá/phí, hoặc nhãn chung chung ("Số tiền"
  // trên ảnh chụp chuyển khoản ngân hàng).
  'tong tien hang': 1,
  // "Thành tiền" vừa là tên CỘT tiền từng món vừa là nhãn tổng ở vài hoá
  // đơn — không đủ chắc để thắng một nhãn tổng thật.
  'thanh tien': 1,
  'tam tinh': 1,
  'subtotal': 1,
  'sub total': 1,
  'so tien': 1,
};

/// Dòng chứa những chữ này KHÔNG phải tổng phải trả dù có chữ "tổng": tiền
/// khách đưa (thường LỚN HƠN tổng — nhánh "số lớn nhất" từng nhặt đúng nó),
/// tiền thối, thuế, giảm giá, số lượng. Nhãn tầng 3 miễn trừ — "Tổng cộng
/// (đã gồm VAT)" vẫn là tổng.
const _notTotalMarkers = [
  'khach dua',
  'tien khach',
  'tien thua',
  'tien thoi',
  'tra lai',
  'change',
  'cash',
  'tien mat',
  'thue',
  'vat',
  'giam gia',
  'chiet khau',
  'khuyen mai',
  'discount',
  'so luong',
  // "Tổng SL: 3" (hoá đơn Hội An) — tổng SỐ LƯỢNG, không phải tiền.
  'sl',
  'hang muc',
  'diem',
];

/// Khớp số kiểu Việt Nam có dấu phân cách nghìn (`125.000`, `1,250,000`) HOẶC
/// một chuỗi 4–9 chữ số liền không phân cách (`125000`) — hoá đơn in cả hai
/// kiểu tuỳ máy in/phần mềm POS.
///
/// 🚨 Chặn trên 9 chữ số là CỐ Ý, không phải con số tuỳ tiện: mã vạch EAN-13
/// (13 chữ số), mã số thuế (10), mã hoá đơn, số điện thoại đều dài hơn thế.
/// Không chặn thì trên hoá đơn siêu thị thật — nơi mỗi dòng hàng in kèm mã
/// vạch — số "lớn nhất" LUÔN là một mã vạch. Hoá đơn Emart của Tony trả về
/// 8.936.136.116.143đ trước khi có chặn này.
///
/// Mất gì: một khoản ≥ 1 tỉ đồng in KHÔNG có dấu phân cách sẽ bị bỏ qua. Đổi
/// lại là không bao giờ đề nghị một mã vạch làm số tiền — đánh đổi đúng
/// chiều cho một app chi tiêu cá nhân.
///
/// `[.,] ?` — ML Kit thật hay chèn MỘT dấu cách sau dấu phân cách ("78,
/// 000"), bắt được trên máy ảo (fixture `emart_mlkit_straight.txt`). Chỉ
/// MỘT: hai cột số cạnh nhau trên hoá đơn cách nhau từ hai dấu cách trở lên
/// (sau `arrangeIntoRows`), không được nối thành một số.
///
/// Nhóm đầu `[1-9]`: số chia nhóm nghìn không bao giờ bắt đầu bằng 0 —
/// "0.346" trên hoá đơn WinMart THẬT là cân nặng (kg), từng bị đọc thành
/// 346 đồng.
final _numberPattern = RegExp(
  r'(?<![\d.,])[1-9]\d{0,2}(?:[.,] ?\d{3})+|(?<!\d)\d{4,9}(?!\d)',
);

/// Cụm "trông như số" đứng riêng (không dính chữ cái hai bên): chữ số, dấu
/// phân cách, và các chữ OCR hay đọc nhầm từ số trên giấy in nhiệt — O/o
/// thay 0, l/I thay 1 (chính hoá đơn Emart có mã "…519O5").
final _numberishToken = RegExp(r'(?<![A-Za-z])[\dOolI][\dOolI.,]*(?![A-Za-z])');

/// Sửa CẢ CỤM một lượt — không sửa từng ký tự theo hàng xóm, vì "2O.OOO" có
/// những chữ O mà hàng xóm cũng là O. Cụm phải có ít nhất một chữ số thật,
/// nên "lo" hay "I" đứng một mình không bị đụng; chữ cái hai bên chặn chữ
/// thật như "Tổng" hay "Lon".
String _fixDigitLookalikes(String line) =>
    line.replaceAllMapped(_numberishToken, (m) {
      final token = m[0]!;
      if (!RegExp(r'\d').hasMatch(token)) return token;
      return token
          .replaceAll(RegExp('[Oo]'), '0')
          .replaceAll(RegExp('[lI]'), '1');
    });

/// Trích merchant + tổng tiền + ngày từ văn bản OCR đã ghép theo hàng
/// (`ReceiptOcrService` → `arrangeIntoRows`). Hàm THUẦN DART — không
/// Flutter/DB/platform channel — cùng kỷ luật tách biệt engine (ML Kit, ở
/// `data/services/`) khỏi luật trích xuất (ở đây) như `category_matcher.dart`.
///
/// [now] đến từ `Clock` được inject — dùng để loại ngày ở tương lai/quá xa
/// (gần như chắc là đọc nhầm, hoặc là hạn sử dụng in trên dòng hàng).
ReceiptOcrExtraction extractReceiptInfo(
  String ocrText, {
  required DateTime now,
}) {
  final lines = ocrText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) return const ReceiptOcrExtraction();

  final items = _findItems(lines);
  return ReceiptOcrExtraction(
    merchantName: _findMerchant(
      lines.take(_itemHeaderIndex(lines) ?? lines.length).toList(),
    ),
    amountMinor: _findTotalAmount(
      lines,
      floor: switch (_largestItemAmount(items)) {
        final largest? => largest ~/ 100,
        null => null,
      },
    ),
    occurredAt: _findDate(lines, now),
    items: items,
  );
}

// ─────────────────────────── Tổng tiền ───────────────────────────

/// Ưu tiên số tiền trên dòng có NHÃN "tổng" — nhãn tổng in cuối cùng thắng,
/// tạm tính chỉ là dự phòng (luật và lý do ở [_totalLabelTiers]). Dòng
/// nhãn không có số (máy in đẩy số xuống dòng dưới, như dòng "414,000" lặp
/// lại trên hoá đơn Emart) thì lấy số ở hàng NGAY SAU nếu hàng đó chỉ có số.
///
/// Không dòng nào khớp nhãn → lùi về số LỚN NHẤT toàn hoá đơn (tổng luôn ≥
/// mọi dòng thành phần) — kém tin cậy hơn, chấp nhận được vì kết quả chỉ là
/// điền sẵn. Nhánh này CHỈ xét số có DẤU PHÂN CÁCH NGHÌN (trên hoá đơn siêu
/// thị, giá tiền luôn có dấu phân cách còn mã vạch thì không) và bỏ qua các
/// dòng [_notTotalMarkers] — "Tiền khách đưa 500,000" luôn lớn hơn tổng.
///
/// [floor]: nhãn tổng có số nhỏ hơn mức này là số bị cắt/che — hoá đơn nhà
/// hàng THẬT bị ngón tay che còn "Tong: 1.542. 2/", đọc ra 1.542đ cho một
/// bữa 1,5 triệu — bị bỏ qua, lùi về nhãn tổng đứng trước nó. Mức sàn là
/// 1/100 món đắt nhất, KHÔNG phải bằng món đắt nhất: voucher làm số phải trả
/// nhỏ hơn món đắt nhất là chuyện thật (WinMart THẬT: món 149.900, voucher
/// 400.000, phải trả 68.097) — sàn "bằng món đắt nhất" từng loại nhầm nó.
int? _findTotalAmount(List<String> rawLines, {int? floor}) {
  final lines = [for (final line in rawLines) _fixDigitLookalikes(line)];

  var bestLevel = 0;
  int? bestLabelAmount;
  int? largestAny;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final folded = foldToAscii(line);
    final tier = _labelTier(folded);
    final excluded = _notTotalMarkers.any((m) => _hasWord(folded, m));

    final amounts = _amountsIn(line);
    if (!excluded) {
      for (final a in amounts) {
        if (a.grouped && (largestAny == null || a.value > largestAny)) {
          largestAny = a.value;
        }
      }
    }

    if (tier == 0 || (excluded && tier < 3)) continue;

    var candidates = amounts;
    if (candidates.isEmpty &&
        i + 1 < lines.length &&
        _isAmountOnly(lines[i + 1])) {
      candidates = _amountsIn(lines[i + 1]);
    }
    if (candidates.isEmpty) continue;

    final value = candidates
        .map((a) => a.value)
        .reduce((a, b) => a > b ? a : b);
    if (floor != null && value < floor) continue;
    // Mức 3 và 2 ngang nhau khi CHỌN — dòng sau thắng (xem
    // [_totalLabelTiers]); `>=` để dòng sau cùng mức ghi đè dòng trước.
    final level = tier >= 2 ? 2 : 1;
    if (level >= bestLevel) {
      bestLevel = level;
      bestLabelAmount = value;
    }
  }

  return bestLabelAmount ?? largestAny;
}

/// Mức nhãn tổng của một hàng — 0 nếu không phải hàng tổng.
///
/// 🚨 Nhãn phải đứng ĐẦU hàng (cho phép tối đa MỘT chữ trước nó: "Tiền
/// **cần thanh toán**"). Món Lotte THẬT "010 KDR TOTAL GUM 100G" có chữ
/// TOTAL trong TÊN MÓN — không chặn vị trí thì nó thành "tổng 40.500" và bảng
/// món bị cắt cụt ở món thứ 10. Mọi dòng tổng trên các hoá đơn thật đã thu
/// đều bắt đầu bằng nhãn; tên món thì có số thứ tự/mã đứng trước.
int _labelTier(String folded) {
  String? longest;
  for (final label in _totalLabelTiers.keys) {
    final at = _wordIndex(folded, label);
    if (at < 0) continue;
    // Phần trước nhãn chỉ toàn số/dấu câu (số thứ tự, gạch trang trí)
    // không tính là chữ. Có chữ cái thì đếm mọi cụm, kể cả mã số: "010 KDR"
    // là HAI chữ → "TOTAL" sau nó là tên món, không phải nhãn.
    final prefix = folded.substring(0, at);
    final wordsBefore = RegExp(r'[a-z]').hasMatch(prefix)
        ? prefix
              .split(RegExp(r'\s+'))
              .where((w) => RegExp(r'[a-z0-9]').hasMatch(w))
              .length
        : 0;
    if (wordsBefore > 1) continue;
    if (longest == null || label.length > longest.length) longest = label;
  }
  return longest == null ? 0 : _totalLabelTiers[longest]!;
}

typedef _Amount = ({int value, bool grouped});

List<_Amount> _amountsIn(String line) => [
  for (final m in _numberPattern.allMatches(line))
    (
      value: int.parse(m.group(0)!.replaceAll(RegExp(r'[.,\s]'), '')),
      grouped: m.group(0)!.contains(RegExp(r'[.,]')),
    ),
];

/// Hàng chỉ gồm số tiền (và ký hiệu tiền tệ) — không một chữ cái nào khác.
bool _isAmountOnly(String line) {
  final stripped = foldToAscii(
    line,
  ).replaceAll(RegExp(r'vnd|d\b'), '').replaceAll(RegExp(r'[\d.,\s:₫\-]'), '');
  return stripped.isEmpty && _numberPattern.hasMatch(line);
}

// ─────────────────────────── Ngày ───────────────────────────

/// ` ?` quanh dấu phân cách: ML Kit thật đọc "23-08-2026" thành
/// "23-08- 2026" (fixture `emart_mlkit_straight.txt`) — không cho phép thì
/// hoá đơn Emart mất ngày.
final _dmyPattern = RegExp(
  r'(?<!\d)(\d{1,2}) ?[/\-.] ?(\d{1,2}) ?[/\-.] ?(\d{4}|\d{2})(?!\d)',
);
final _ymdPattern = RegExp(
  r'(?<!\d)(\d{4}) ?[/\-.] ?(\d{1,2}) ?[/\-.] ?(\d{1,2})(?!\d)',
);

/// "Ngày 23 tháng 08 năm 2026" — cách hoá đơn điện tử (HĐĐT) in ngày.
final _wordyPattern = RegExp(
  r'ngay\s*(\d{1,2})\s*thang\s*(\d{1,2})\s*nam\s*(\d{4})',
);
final _timePattern = RegExp(
  r'(?<!\d)([01]?\d|2[0-3])[:h]([0-5]\d)(?::[0-5]\d)?(?!\d)',
);
const _dateLabels = ['ngay', 'date', 'thoi gian', 'gio vao', 'gio ra'];

/// Ngày trên hoá đơn — ưu tiên dòng có nhãn ngày ("Ngày:", "Date",
/// "Thời gian"), không có thì lấy ngày hợp lệ ĐẦU TIÊN từ trên xuống (ngày
/// bán luôn in ở phần đầu, trước các dòng hàng).
///
/// Loại ngày ở ngày mai trở đi và ngày cũ hơn một năm: gần như chắc chắn là
/// hạn sử dụng in cạnh dòng hàng, hoặc OCR đọc sai số. Thà để form giữ
/// "hôm nay" còn hơn điền một ngày sai mà Tony không để ý.
///
/// Giờ chỉ lấy khi in CÙNG dòng với ngày (dòng "Hoạt động từ 07h30 - 22h30"
/// của Emart là giờ mở cửa, không phải giờ mua). Không có giờ → dùng giờ
/// hiện tại, cùng cách form vẫn làm với "hôm nay".
DateTime? _findDate(List<String> lines, DateTime now) {
  DateTime? firstValid;
  for (final line in lines) {
    final folded = foldToAscii(line);
    final date = _dateIn(folded, now);
    if (date == null) continue;
    if (_dateLabels.any((l) => _hasWord(folded, l))) return date;
    firstValid ??= date;
  }
  return firstValid;
}

DateTime? _dateIn(String folded, DateTime now) {
  final candidates = <(int, int, int)>[
    for (final m in _wordyPattern.allMatches(folded))
      (int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!)),
    for (final m in _ymdPattern.allMatches(folded))
      (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)),
    for (final m in _dmyPattern.allMatches(folded))
      (
        m[3]!.length == 2 ? 2000 + int.parse(m[3]!) : int.parse(m[3]!),
        int.parse(m[2]!),
        int.parse(m[1]!),
      ),
  ];

  for (final (year, month, day) in candidates) {
    if (month < 1 || month > 12 || day < 1) continue;
    final date = DateTime(year, month, day);
    // `DateTime` tự tràn 31/02 thành 03/03 — tràn nghĩa là ngày không có thật.
    if (date.month != month || date.day != day) continue;

    final today = DateTime(now.year, now.month, now.day);
    if (date.isAfter(today)) continue;
    if (date.isBefore(DateTime(now.year - 1, now.month, now.day))) continue;

    final time = _timePattern.firstMatch(folded);
    final withTime = time == null
        ? DateTime(year, month, day, now.hour, now.minute)
        : DateTime(year, month, day, int.parse(time[1]!), int.parse(time[2]!));
    // Hoá đơn hôm nay mà giờ in ra muộn hơn bây giờ (đồng hồ máy POS lệch):
    // không ghi một khoản ở tương lai.
    return withTime.isAfter(now) ? now : withTime;
  }
  return null;
}

// ─────────────────────────── Tên cửa hàng ───────────────────────────

/// Những dòng đầu hoá đơn KHÔNG phải tên cửa hàng: web, điện thoại, mã số
/// thuế, địa chỉ, tiêu đề chứng từ, giờ mở cửa, lời chào.
const _merchantNoise = [
  'www',
  'http',
  '.com',
  '.vn',
  'dien thoai',
  'dt:',
  'tel',
  'hotline',
  'mst',
  'ma so thue',
  'dia chi',
  'dc:',
  'hoa don',
  'phieu',
  'receipt',
  'invoice',
  'hoat dong',
  'gio mo cua',
  'wifi',
  'cam on',
  'chao mung',
  'welcome',
  'so:',
  'ban:',
  'thu ngan',
  'in luc',
  'tn:',
  'khach hang',
  'doanh so',
  'ngay ban',
  'nhan vien',
  'cashier',
];

/// Dấu hiệu dòng địa chỉ ("10 Mai Chí Thọ, P.An Khánh, TP.HCM") — xét
/// trên chữ KHÔNG dấu.
final _addressPattern = RegExp(
  r'(^|[\s,])(p\.|q\.|tp\.|tp |phuong|tphcm|ha noi|so nha)',
);

/// "Quận" xét trên chữ CÒN DẤU: bỏ dấu thì "Quận 1" và "QUÁN CƠM" cùng ra
/// "quan", và mọi tên quán ăn sẽ bị coi là địa chỉ.
final _districtPattern = RegExp(r'(^|[\s,])quận', caseSensitive: false);

/// Viền trang trí máy in hay in quanh tên quán ("*** QUÁN A ***").
///
/// 🚨 KHÔNG dùng `\W` để lọc: trong RegExp của Dart, chữ có dấu tiếng Việt
/// ("Ă", "ơ") cũng là `\W` — tên quán sẽ bị gọt mất chữ.
final _decoration = RegExp(r'^[\s*=\-_~#|.:]+|[\s*=\-_~#|.:]+$');

/// Dòng đầu tiên trong vài hàng trên cùng mà không phải nhiễu — tên quán
/// in to nhất, ở trên cùng. Không thấy thì `null`: một ô ghi chú trống tốt
/// hơn một ô ghi chú là số điện thoại.
String? _findMerchant(List<String> lines) {
  for (final line in lines.take(8)) {
    final cleaned = line.replaceAll(_decoration, '');
    final folded = foldToAscii(cleaned);
    final letters = RegExp(r'[a-z]').allMatches(folded).length;
    if (letters < 3) continue;
    if (_merchantNoise.any((n) => _hasWord(folded, n))) continue;
    // Hàng tiêu đề cột ("Tên món  S/L  Tổng") — hoá đơn nhà hàng THẬT bị
    // chụp mất phần đầu, dòng đầu tiên còn lại chính là nó.
    if (_itemHeaderWords.where((w) => _hasWord(folded, w)).length >= 2) {
      continue;
    }
    // Đa số cụm chữ lẫn chữ số: số điện thoại/mã đọc vỡ thành chữ
    // ("SO9.BsO.682/ oO79.7AB.TS" — hoá đơn shop THẬT).
    final words = cleaned.split(RegExp(r'\s+'));
    final digitWords = words.where((w) => RegExp(r'\d').hasMatch(w)).length;
    if (digitWords * 2 >= words.length) continue;
    if (_addressPattern.hasMatch(folded) ||
        _districtPattern.hasMatch(cleaned)) {
      continue;
    }
    // Dòng nhiều số hơn chữ (mã quầy, ngày giờ, mã hoá đơn).
    if (RegExp(r'\d').allMatches(folded).length > letters) continue;
    return cleaned;
  }
  return null;
}

/// [needle] xuất hiện như một TỪ (hoặc cụm từ) trong [folded] — không dính
/// vào chữ cái hai bên. "tel" không được khớp "hotel", "vat" không khớp
/// "private", "total" không khớp "subtotal", "cash" không khớp "cashier".
/// Chỉ xét biên ở phía nào [needle] kết thúc bằng chữ/số — "dt:"/".com" tự
/// mang dấu câu làm biên.
bool _hasWord(String folded, String needle) => _wordIndex(folded, needle) >= 0;

/// Vị trí đầu tiên [needle] xuất hiện như một từ trong [folded] (xem
/// [_hasWord]), `-1` nếu không có.
int _wordIndex(String folded, String needle) {
  var start = folded.indexOf(needle);
  while (start != -1) {
    final end = start + needle.length;
    final leftOk =
        !_isWordChar(needle[0]) ||
        start == 0 ||
        !_isWordChar(folded[start - 1]);
    final rightOk =
        !_isWordChar(needle[needle.length - 1]) ||
        end == folded.length ||
        !_isWordChar(folded[end]);
    if (leftOk && rightOk) return start;
    start = folded.indexOf(needle, start + 1);
  }
  return -1;
}

bool _isWordChar(String c) => RegExp(r'[a-z0-9]').hasMatch(c);

// ─────────────────────────── Dòng hàng ───────────────────────────

/// Chữ trên hàng TIÊU ĐỀ CỘT của bảng hàng ("Tên sản phẩm  Đơn giá  SL  Số
/// tiền", "Mặt hàng  SL  T.Tiền", "Tên món  S/L  Tổng"). Mọi hoá đơn thật
/// Tony gửi đều có một hàng như vậy ngay trên dòng hàng đầu tiên.
const _itemHeaderWords = [
  'ten san pham',
  'ten hang',
  'mat hang',
  'ten mon',
  'ma sp',
  'don gia',
  'dgia',
  'sl',
  's/l',
  'tien',
  't.tien',
];

/// Mã thuế/số thứ tự đầu tên món siêu thị: "01) VAT08 SNACK POCA" → "SNACK
/// POCA". OCR hay đọc "VAT08" thành "VATO8".
final _itemNamePrefix = RegExp(
  r'^\s*(\d{1,3}\s*[).]\s*)?(vat\s*[0-9o]{1,2}\s+)?',
  caseSensitive: false,
);

/// Tách dòng hàng trong vùng giữa hàng tiêu đề cột và nhãn tổng đầu tiên.
///
/// Luật rút từ văn bản ML Kit THẬT của 6 hoá đơn (fixture `real_*.txt`,
/// `emart_mlkit_straight.txt`):
/// - Hàng có TÊN + TIỀN ("Cải bó xôi  29.000") → một món.
/// - Hàng chỉ có TÊN, hàng sau chỉ có TIỀN (siêu thị: tên ở trên, mã vạch +
///   đơn giá + thành tiền ở dưới; shop quần áo: tên, rồi "500.000 1 50.000
///   450.000") → ghép thành một món. Thành tiền là số NGOÀI CÙNG BÊN PHẢI.
/// - Hàng chỉ có TÊN mà hàng sau lại là TÊN khác → món không đọc được tiền
///   (hoá đơn nhà hàng bị ngón tay che cột tiền) → đưa vào với tiền trống.
///   Chỉ khi tên có từ hai chữ trở lên — tiêu đề cột vỡ ("KiM" từ cột "KM"
///   của WinMart) không thành món rác.
/// - Tên quá ngắn ("TẾ" trong "KHẨU TRANG Y" / "TẾ 3 150.0") là phần nối
///   của tên đang chờ.
/// - Tiền không có tên nào đứng trước ("-3, 460" — dòng khuyến mãi của
///   WinMart) bị bỏ; thành tiền bằng 0 ("Người lớn  4  0") bị bỏ.
///
/// Chỉ nhận số CÓ dấu phân cách nghìn làm tiền — mã vạch và số lượng không
/// bao giờ có. Không cố đúng 100%: Tony sửa trong bảng món, và dòng tổng
/// tô đỏ khi các món chưa cộng khớp.
List<ReceiptItem> _findItems(List<String> rawLines) {
  final lines = [for (final l in rawLines) _fixDigitLookalikes(l)];

  var start = 0;
  var end = lines.length;
  var hasHeader = false;
  for (var i = 0; i < lines.length; i++) {
    if (_isItemHeader(lines[i])) {
      start = i + 1;
      hasHeader = true;
      continue;
    }
    if (_labelTier(foldToAscii(lines[i])) > 0) {
      end = i;
      break;
    }
  }
  if (start >= end) return const [];

  final items = <ReceiptItem>[];
  String? pending;

  void flushPendingWithoutAmount() {
    final name = pending;
    pending = null;
    if (name != null && name.trim().split(RegExp(r'\s+')).length >= 2) {
      items.add(ReceiptItem(name: name));
    }
  }

  for (final line in lines.sublist(start, end)) {
    final grouped = [
      for (final a in _amountsIn(line))
        if (a.grouped) a.value,
    ];
    final name = _itemNameOf(line);
    final hasOwnName = name != null && _letterCount(name) >= 3;
    final isZero = grouped.isEmpty && RegExp(r'(^|\s)0\s*$').hasMatch(line);

    if (isZero) {
      pending = null;
      continue;
    }
    // Không tìm thấy tiêu đề cột → vùng "dòng hàng" là CẢ phần đầu hoá đơn
    // (tên quán, địa chỉ, ngày giờ). Ghép tên chờ ở đây là biến "QUÁN CƠM
    // TẤM" thành một món; nên chỉ nhận hàng có TÊN + TIỀN ngay trên nó.
    if (!hasHeader) {
      if (grouped.isNotEmpty && hasOwnName) {
        items.add(ReceiptItem(name: name, amountMinor: grouped.last));
      }
      continue;
    }
    if (grouped.isNotEmpty) {
      final amount = grouped.last;
      if (hasOwnName) {
        flushPendingWithoutAmount();
        items.add(ReceiptItem(name: name, amountMinor: amount));
      } else if (pending != null) {
        final joined = name == null ? pending! : '${pending!} $name';
        pending = null;
        items.add(ReceiptItem(name: joined, amountMinor: amount));
      }
      continue;
    }
    if (name == null) continue;
    if (hasOwnName) {
      flushPendingWithoutAmount();
      pending = name;
    } else if (pending != null) {
      pending = '${pending!} $name';
    }
  }
  flushPendingWithoutAmount();
  return items;
}

/// Phần CHỮ của một hàng: bỏ mọi cụm không có chữ cái (mã vạch, số lượng,
/// đơn giá, thành tiền, dấu câu lẻ) và tiền tố "01) VAT08". `null` nếu
/// không còn chữ nào.
String? _itemNameOf(String line) {
  final words = [
    for (final word in line.split(RegExp(r'\s+')))
      // Phải có CHỮ CÁI thật — "182,£00" (giá đọc vỡ) không phải tên — và
      // không phải mã vạch đọc vỡ lẫn một chữ cái ("S852756304046").
      if (RegExp(r'\p{L}', unicode: true).hasMatch(word) &&
          RegExp(r'\d').allMatches(word).length < 6)
        word,
  ];
  // Số còn dính trong tên ("100g", "320ML") được giữ — là một phần tên món.
  final text = words.join(' ').replaceFirst(_itemNamePrefix, '').trim();
  return text.isEmpty ? null : text;
}

int _letterCount(String text) =>
    RegExp(r'[a-z]').allMatches(foldToAscii(text)).length;

int? _largestItemAmount(List<ReceiptItem> items) {
  int? largest;
  for (final item in items) {
    final amount = item.amountMinor;
    if (amount != null && (largest == null || amount > largest)) {
      largest = amount;
    }
  }
  return largest;
}

/// Chỉ số hàng tiêu đề cột ĐẦU TIÊN — tên quán luôn in phía trên nó. Không
/// giới hạn thì hoá đơn bị chụp mất phần đầu (nhà hàng, Hội An THẬT) lấy
/// tên MÓN đầu tiên làm tên quán.
int? _itemHeaderIndex(List<String> lines) {
  for (var i = 0; i < lines.length; i++) {
    if (_isItemHeader(lines[i])) return i;
  }
  return null;
}

bool _isItemHeader(String line) {
  final folded = foldToAscii(line);
  final hasAmount = _amountsIn(line).any((a) => a.grouped);
  final headerWords = _itemHeaderWords.where((w) => _hasWord(folded, w));
  // Tiêu đề cột thật có ≥ 2 chữ tiêu đề ("Tên món  S/L  Tổng" — có cả chữ
  // "Tổng" mà vẫn là tiêu đề), hoặc một chữ mà KHÔNG kèm nhãn tổng. "Tổng
  // SL:" của hoá đơn Hội An THẬT chỉ có "SL" + nhãn tổng — là dòng tổng số
  // lượng, không phải tiêu đề; coi nó là tiêu đề từng làm mất cả bảng món.
  return !hasAmount &&
      (headerWords.length >= 2 ||
          (headerWords.isNotEmpty && _labelTier(folded) == 0));
}
