import 'package:clock/clock.dart';

import 'amount_evaluator.dart';
import 'category_matcher.dart';
import 'date_parser.dart';
import 'normalizer.dart';
import 'parse_result.dart';
import 'savings_matcher.dart';
import 'segmenter.dart';
import 'tokenizer.dart';

export 'parse_result.dart';

/// Điểm vào công khai duy nhất của parser Phase 7 — chuỗi tiếng Việt thô →
/// danh sách [ParsedDraft] (có thể rỗng, có thể nhiều phần tử — xem
/// `segmenter.dart`). Dart thuần: không Flutter, không DB, không network.
///
/// **Không bao giờ ném lỗi** — mọi input (kể cả chuỗi rỗng, chuỗi rác, emoji
/// ngẫu nhiên) đều trả về danh sách hợp lệ, có thể rỗng, có thể chứa draft
/// với `amount == null` (Luật bố cục Phase 8: draft không hiểu được vẫn
/// phải hiện thành một THẺ sửa được, không phải một exception).
List<ParsedDraft> parseMessage(
  String rawMessage, {
  required Clock clock,
  List<CategoryKeywordEntry> categoryKeywords = const [],
  List<SavingsTargetEntry> savingsTargets = const [],
}) {
  final normalizedWhole = normalize(rawMessage);
  final segments = segmentMessage(normalizedWhole.diacritics);
  return segments
      .map(
        (segment) => _parseSegment(
          segment,
          clock: clock,
          categoryKeywords: categoryKeywords,
          savingsTargets: savingsTargets,
        ),
      )
      .toList(growable: false);
}

ParsedDraft _parseSegment(
  String rawSegment, {
  required Clock clock,
  required List<CategoryKeywordEntry> categoryKeywords,
  required List<SavingsTargetEntry> savingsTargets,
}) {
  final normalized = normalize(rawSegment);
  final tokens = tokenize(normalized.diacritics);

  final dateMatch = findDate(tokens, clock: clock);
  final ParsedDate date;
  final List<Token> afterDate;
  if (dateMatch != null) {
    date = dateMatch.date;
    afterDate = _removeRange(tokens, dateMatch.startIndex, dateMatch.endIndex);
  } else {
    date = defaultDate(clock);
    afterDate = tokens;
  }

  final amountMatch = findAmount(afterDate);
  final ParsedAmount? amount;
  final List<Token> afterAmount;
  if (amountMatch != null) {
    amount = amountMatch.amount;
    afterAmount = _removeRange(
      afterDate,
      amountMatch.startIndex,
      amountMatch.endIndex,
    );
  } else {
    amount = null;
    afterAmount = afterDate;
  }

  final leftoverText = afterAmount
      .where((t) => t.type == TokenType.word)
      .map((t) => t.text)
      .join(' ');

  // Ý định "cất vào tiết kiệm" xét TRƯỚC danh mục và loại trừ nó: một dòng
  // để dành không thuộc danh mục nào (xem [SavingsMatch]). Chấm điểm danh
  // mục xong rồi mới ghi đè sẽ chỉ tốn công — mà tệ hơn, "chuyển 5tr vào quỹ
  // mua nhà" vẫn còn dính điểm của danh mục "Nhà cửa" nếu ai đó lỡ đọc
  // `category` mà quên `savings`.
  final savings = matchSavings(normalize(leftoverText).ascii, savingsTargets);
  if (savings != null) {
    return ParsedDraft(
      rawText: rawSegment,
      leftoverText: leftoverText,
      amount: amount,
      date: date,
      category: null,
      savings: savings,
    );
  }

  // Nhãn buổi nằm TRONG cụm ngày ("trưa nay", "tối qua") đã bị `findDate`
  // cắt khỏi token, nên nếu chỉ đưa `leftoverText` cho bộ khớp thì "hủ tíu
  // trưa nay 30k" mất sạch chữ "trưa" và không bao giờ xuống được danh mục
  // con "Ăn trưa …", trong khi "hủ tíu trưa 30k" (không có "nay") thì lại
  // xuống được — cùng một ý, hai kết quả khác nhau. Nối lại đúng lời hứa ở
  // doc comment của [TimeOfDayLabel]: buổi là TÍN HIỆU PHÂN LOẠI.
  //
  // Chỉ nối vào chuỗi đem đi CHẤM ĐIỂM. `leftoverText` giữ nguyên vì nó còn
  // là note của giao dịch và là thứ vòng lặp học ghi vào `category_keywords`
  // (`correctCategory`) — nhét thêm chữ vào đó là làm bẩn dữ liệu học.
  final timeOfDayWord = date.timeOfDayLabel == null
      ? null
      : timeOfDayWords.entries
            .firstWhere((e) => e.value == date.timeOfDayLabel)
            .key;
  final category = matchCategory(
    timeOfDayWord == null ? leftoverText : '$leftoverText $timeOfDayWord',
    categoryKeywords,
  );

  return ParsedDraft(
    rawText: rawSegment,
    leftoverText: leftoverText,
    amount: amount,
    date: date,
    category: category,
  );
}

List<Token> _removeRange(List<Token> tokens, int start, int end) => [
  ...tokens.sublist(0, start),
  ...tokens.sublist(end),
];
