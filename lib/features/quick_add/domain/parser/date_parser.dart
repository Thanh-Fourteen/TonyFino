/// Đọc cụm ngày từ dãy [Token], neo vào [Clock] được inject — TUYỆT ĐỐI
/// không `DateTime.now()` (Luật #3). Chạy TRƯỚC `amount_evaluator` trên
/// cùng dãy token của một đoạn, để `"thứ Tư"` không bị `amount_evaluator`
/// hiểu nhầm chữ `"tư"` (biến thể số 4) là một phần của cụm số.
library;

import 'package:clock/clock.dart';

import 'parse_result.dart';
import 'tokenizer.dart';

const Map<String, int> _weekdayWords = {
  'hai': 2,
  'ba': 3,
  'tư': 4,
  'năm': 5,
  'sáu': 6,
  'bảy': 7,
};

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class DateMatch {
  const DateMatch({
    required this.date,
    required this.startIndex,
    required this.endIndex,
  });

  final ParsedDate date;
  final int startIndex;
  final int endIndex;
}

/// `thứ 2` = Thứ Hai = **Monday** — cách đánh số của tiếng Việt lệch một so
/// với ISO (`DateTime.weekday`: Monday=1..Sunday=7). `thứ N` → ISO weekday
/// `N-1`. Không có qualifier → occurrence GẦN NHẤT tính cả hôm nay (hợp lý
/// nhất cho một app ghi chi tiêu: nhắc tới "thứ Ba" gần như luôn là thứ Ba
/// vừa qua/hôm nay, không phải thứ Ba tuần sau).
DateTime _resolveWeekday(DateTime today, int isoWeekday, {String? week}) {
  final todayIso = today.weekday;
  final daysAgo = (todayIso - isoWeekday + 7) % 7;
  var result = today.subtract(Duration(days: daysAgo));
  if (week == 'trước') result = result.subtract(const Duration(days: 7));
  if (week == 'sau') result = result.add(const Duration(days: 7));
  return result;
}

/// `(qualifier, số token đã ăn)` — `"tuần trước"`/`"tuần sau"` ngay sau một
/// cụm thứ/chủ nhật, tuỳ chọn.
({String? week, int consumed}) _tryParseWeekQualifier(
  List<Token> tokens,
  int idx,
) {
  if (idx + 1 < tokens.length &&
      tokens[idx].type == TokenType.word &&
      tokens[idx].text == 'tuần' &&
      tokens[idx + 1].type == TokenType.word &&
      (tokens[idx + 1].text == 'trước' || tokens[idx + 1].text == 'sau')) {
    return (week: tokens[idx + 1].text, consumed: 2);
  }
  return (week: null, consumed: 0);
}

DateMatch? _tryParseDateAt(List<Token> tokens, int idx, DateTime today) {
  if (idx >= tokens.length) return null;
  final t0 = tokens[idx];

  // "<buổi> nay" / "<buổi> qua" — vd "sáng nay", "tối qua". Chỉ nhận dạng
  // dưới dạng cụm 2 token CÓ "nay"/"qua" đi kèm, KHÔNG bắt từ buổi đứng một
  // mình — "sáng" đứng riêng rất hay là một phần của từ khoá danh mục
  // ("ăn sáng"), bắt nhầm sẽ cắt mất tín hiệu phân loại.
  if (t0.type == TokenType.word && timeOfDayWords.containsKey(t0.text)) {
    if (idx + 1 < tokens.length && tokens[idx + 1].type == TokenType.word) {
      final w1 = tokens[idx + 1].text;
      if (w1 == 'nay' || w1 == 'qua') {
        final date = w1 == 'nay'
            ? today
            : today.subtract(const Duration(days: 1));
        return DateMatch(
          date: ParsedDate(
            date: date,
            explicit: true,
            timeOfDayLabel: timeOfDayWords[t0.text],
          ),
          startIndex: idx,
          endIndex: idx + 2,
        );
      }
    }
    return null;
  }

  // "hôm nay" / "hôm qua" / "hôm kia"
  if (t0.type == TokenType.word && t0.text == 'hôm') {
    if (idx + 1 < tokens.length && tokens[idx + 1].type == TokenType.word) {
      final w1 = tokens[idx + 1].text;
      final delta = switch (w1) {
        'nay' => 0,
        'qua' => -1,
        'kia' => -2,
        _ => null,
      };
      if (delta != null) {
        return DateMatch(
          date: ParsedDate(
            date: today.add(Duration(days: delta)),
            explicit: true,
          ),
          startIndex: idx,
          endIndex: idx + 2,
        );
      }
    }
    return null;
  }

  // "ngày mai"
  if (t0.type == TokenType.word &&
      t0.text == 'ngày' &&
      idx + 1 < tokens.length &&
      tokens[idx + 1].type == TokenType.word &&
      tokens[idx + 1].text == 'mai') {
    return DateMatch(
      date: ParsedDate(
        date: today.add(const Duration(days: 1)),
        explicit: true,
      ),
      startIndex: idx,
      endIndex: idx + 2,
    );
  }

  // "thứ 2".."thứ 7" (số) hoặc "thứ hai".."thứ bảy" (chữ), + tuỳ chọn
  // "tuần trước"/"tuần sau".
  if (t0.type == TokenType.word &&
      t0.text == 'thứ' &&
      idx + 1 < tokens.length) {
    final t1 = tokens[idx + 1];
    int? weekdayNumber;
    if (t1.type == TokenType.number && t1.value! >= 2 && t1.value! <= 7) {
      weekdayNumber = t1.value;
    } else if (t1.type == TokenType.word &&
        _weekdayWords.containsKey(t1.text)) {
      weekdayNumber = _weekdayWords[t1.text];
    }
    if (weekdayNumber != null) {
      final qualifier = _tryParseWeekQualifier(tokens, idx + 2);
      return DateMatch(
        date: ParsedDate(
          date: _resolveWeekday(today, weekdayNumber - 1, week: qualifier.week),
          explicit: true,
        ),
        startIndex: idx,
        endIndex: idx + 2 + qualifier.consumed,
      );
    }
  }

  // "chủ nhật" hoặc viết tắt "cn" — ISO weekday 7 (Chủ Nhật).
  final isSundayPhrase =
      (t0.type == TokenType.word &&
          t0.text == 'chủ' &&
          idx + 1 < tokens.length &&
          tokens[idx + 1].type == TokenType.word &&
          tokens[idx + 1].text == 'nhật') ||
      (t0.type == TokenType.word && t0.text == 'cn');
  if (isSundayPhrase) {
    final consumedHead = t0.text == 'cn' ? 1 : 2;
    final qualifier = _tryParseWeekQualifier(tokens, idx + consumedHead);
    return DateMatch(
      date: ParsedDate(
        date: _resolveWeekday(today, 7, week: qualifier.week),
        explicit: true,
      ),
      startIndex: idx,
      endIndex: idx + consumedHead + qualifier.consumed,
    );
  }

  // Ngày tường minh DD/MM[/YYYY] hoặc DD-MM[/YYYY] — Việt Nam LUÔN là
  // ngày/tháng, KHÔNG BAO GIỜ tháng/ngày kiểu Mỹ.
  if (t0.type == TokenType.number &&
      idx + 2 < tokens.length &&
      (tokens[idx + 1].type == TokenType.slash ||
          tokens[idx + 1].type == TokenType.dash) &&
      tokens[idx + 2].type == TokenType.number) {
    final day = t0.value!;
    final month = tokens[idx + 2].value!;
    if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
      var year = today.year;
      var consumed = 3;
      if (idx + 4 < tokens.length &&
          (tokens[idx + 3].type == TokenType.slash ||
              tokens[idx + 3].type == TokenType.dash) &&
          tokens[idx + 4].type == TokenType.number) {
        final rawYear = tokens[idx + 4].value!;
        year = rawYear < 100 ? 2000 + rawYear : rawYear;
        consumed = 5;
      }
      return DateMatch(
        date: ParsedDate(date: DateTime(year, month, day), explicit: true),
        startIndex: idx,
        endIndex: idx + consumed,
      );
    }
  }

  return null;
}

/// Tìm cụm ngày ĐẦU TIÊN trong dãy token. `null` nếu không có cụm ngày nào
/// — tầng gọi mặc định về hôm nay (`explicit: false`).
DateMatch? findDate(List<Token> tokens, {required Clock clock}) {
  final today = _dateOnly(clock.now());
  for (var i = 0; i < tokens.length; i++) {
    final match = _tryParseDateAt(tokens, i, today);
    if (match != null) return match;
  }
  return null;
}

/// Ngày mặc định khi không tìm thấy cụm ngày nào trong chuỗi.
ParsedDate defaultDate(Clock clock) =>
    ParsedDate(date: _dateOnly(clock.now()), explicit: false);
