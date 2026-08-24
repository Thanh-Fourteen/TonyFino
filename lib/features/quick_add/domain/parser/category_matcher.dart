/// Chấm điểm danh mục cho phần chữ còn lại của một draft (`leftoverText`,
/// sau khi đã trừ cụm số tiền + cụm ngày) — điểm mỗi từ khoá khớp được là
/// `weight × độ dài khớp` (số ký tự của từ khoá, tính trên bản ascii-fold để
/// không phân biệt dấu), cộng dồn theo danh mục, chọn danh mục có tổng điểm
/// cao nhất (argmax).
///
/// So khớp CÓ RÀNG BUỘC BIÊN TỪ (đệm khoảng trắng hai đầu chuỗi rồi tìm
/// substring) — nếu không, từ khoá ngắn (vd `"xe"`) sẽ khớp nhầm vào giữa
/// một từ khác tình cờ chứa nó.
library;

import 'normalizer.dart';
import 'parse_result.dart';

bool _hasWordBoundaryMatch(String paddedHaystack, String needle) {
  if (needle.isEmpty) return false;
  var searchStart = 0;
  while (true) {
    final idx = paddedHaystack.indexOf(needle, searchStart);
    if (idx == -1) return false;
    final before = paddedHaystack[idx - 1];
    final after = paddedHaystack[idx + needle.length];
    if (before == ' ' && after == ' ') return true;
    searchStart = idx + 1;
  }
}

CategoryMatch? matchCategory(
  String leftoverTextDiacritics,
  List<CategoryKeywordEntry> keywords,
) {
  final leftoverAscii = normalize(leftoverTextDiacritics).ascii;
  if (leftoverAscii.trim().isEmpty || keywords.isEmpty) return null;

  final padded = ' $leftoverAscii ';
  final scoreByCategory = <String, double>{};

  for (final entry in keywords) {
    final needle = entry.keywordAscii.trim();
    if (needle.isEmpty) continue;
    if (_hasWordBoundaryMatch(padded, needle)) {
      final score = entry.weight * needle.length;
      scoreByCategory.update(
        entry.categoryKey,
        (existing) => existing + score,
        ifAbsent: () => score,
      );
    }
  }

  if (scoreByCategory.isEmpty) return null;

  var bestKey = '';
  var bestScore = -1.0;
  for (final entry in scoreByCategory.entries) {
    if (entry.value > bestScore) {
      bestScore = entry.value;
      bestKey = entry.key;
    }
  }
  return CategoryMatch(categoryKey: bestKey, score: bestScore);
}
