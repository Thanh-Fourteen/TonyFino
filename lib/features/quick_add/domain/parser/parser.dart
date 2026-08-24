import 'package:clock/clock.dart';

import 'amount_evaluator.dart';
import 'category_matcher.dart';
import 'date_parser.dart';
import 'normalizer.dart';
import 'parse_result.dart';
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
}) {
  final normalizedWhole = normalize(rawMessage);
  final segments = segmentMessage(normalizedWhole.diacritics);
  return segments
      .map(
        (segment) => _parseSegment(
          segment,
          clock: clock,
          categoryKeywords: categoryKeywords,
        ),
      )
      .toList(growable: false);
}

ParsedDraft _parseSegment(
  String rawSegment, {
  required Clock clock,
  required List<CategoryKeywordEntry> categoryKeywords,
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

  final category = matchCategory(leftoverText, categoryKeywords);

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
