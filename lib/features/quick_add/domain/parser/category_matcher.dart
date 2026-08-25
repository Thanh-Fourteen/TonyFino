/// Chấm điểm danh mục cho phần chữ còn lại của một draft (`leftoverText`,
/// sau khi đã trừ cụm số tiền + cụm ngày) — điểm mỗi từ khoá khớp được là
/// `weight × độ dài khớp` (số ký tự của từ khoá, tính trên bản ascii-fold để
/// không phân biệt dấu), cộng dồn theo danh mục.
///
/// So khớp THEO TỪ, không phải substring — từ khoá `"xe"` không được khớp
/// vào giữa `"xem"`. Từ khoá nhiều từ phải xuất hiện thành một dãy từ LIÊN
/// TIẾP, và một từ đủ dài trong dãy được phép sai một ký tự (khớp mờ, xem
/// [kFuzzyMinWordLength]) để tên riêng gõ sai vẫn về đúng danh mục.
///
/// 🚨 CHỌN THEO NHÁNH, KHÔNG PHẢI ARGMAX PHẲNG.
///
/// Danh mục có hai tầng (`categories.parentCategoryId`), nên argmax phẳng
/// trên từng danh mục là sai hai chiều:
///
///  * Con bị cha đè: "hủ tíu trưa 30k" — "hủ tíu" là từ khoá của cha
///    "Ăn uống" (6 điểm), "trưa" là tín hiệu của con "Ăn trưa" (4.8 điểm).
///    Argmax phẳng trả về CHA, và Tony không bao giờ nhận được danh mục con
///    dù câu văn đã nói rõ là bữa trưa.
///  * Cha bị con cướp nhánh: một con khớp lẻ tẻ có thể thắng cả một cha
///    đang được nhiều từ khoá cùng nhánh đẩy lên.
///
/// Nên: cộng điểm mọi con VỀ NHÁNH của cha, chọn NHÁNH thắng trước (đây là
/// quyết định quan trọng — sai nhánh là sai hẳn danh mục), rồi mới chọn
/// trong nhánh: con nào có điểm cao nhất thì lấy con, không con nào có điểm
/// thì lấy cha. Cụ thể hơn luôn thắng khi có bằng chứng riêng cho nó.
library;

import 'normalizer.dart';
import 'parse_result.dart';

/// Hệ số điểm khi phải khớp MỜ (sai/thiếu/thừa đúng một ký tự ở một từ) —
/// thấp hơn khớp đúng để một từ khoá khớp chính xác luôn thắng một từ khoá
/// dài hơn nhưng chỉ khớp mờ.
const double kFuzzyMatchScoreFactor = 0.8;

/// Chỉ khớp mờ cho từ từ [kFuzzyMinWordLength] ký tự trở lên (đã bỏ dấu).
///
/// 🚨 Ngưỡng này là thứ giữ khớp mờ khỏi phá mọi thứ. Tiếng Việt bỏ dấu có
/// cực nhiều cặp từ ngắn cách nhau đúng một ký tự (`xang`/`xong`,
/// `bun`/`bum`, `me`/`mo`) — cho phép mờ ở đó là mời gọi khớp bậy. Từ 6 ký
/// tự trở lên gần như luôn là tên riêng/từ mượn (`oxytocin`, `katinat`,
/// `starbucks`, `internet`), đúng chỗ người ta gõ sai mà vẫn cần hiểu.
const int kFuzzyMinWordLength = 6;

/// `true` nếu hai chuỗi cách nhau **nhiều nhất một** thao tác sửa (thay,
/// thêm, hoặc bớt một ký tự). Duyệt tuyến tính, không dựng bảng quy hoạch
/// động — chỉ cần biết "≤ 1" chứ không cần khoảng cách chính xác.
bool _isWithinOneEdit(String a, String b) {
  final diff = a.length - b.length;
  if (diff > 1 || diff < -1) return false;
  var i = 0;
  var j = 0;
  var edits = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      i++;
      j++;
      continue;
    }
    if (++edits > 1) return false;
    if (a.length > b.length) {
      i++;
    } else if (a.length < b.length) {
      j++;
    } else {
      i++;
      j++;
    }
  }
  return edits + (a.length - i) + (b.length - j) <= 1;
}

/// `null` = không khớp; `false` = khớp đúng từng ký tự; `true` = khớp mờ.
bool? _wordMatch(String haystackWord, String needleWord) {
  if (haystackWord == needleWord) return false;
  if (needleWord.length < kFuzzyMinWordLength) return null;
  return _isWithinOneEdit(haystackWord, needleWord) ? true : null;
}

/// Tìm [needleWords] thành một dãy TỪ LIÊN TIẾP trong [haystackWords].
///
/// So theo TỪ chứ không phải substring — đó là cách giữ ràng buộc biên từ
/// (từ khoá `"xe"` không được khớp vào giữa `"xem"`) mà vẫn cho phép một từ
/// dài trong cụm khớp mờ: "chung oxytocin" phải bắt được "chung oxytoxin"
/// Tony gõ sai, trong khi "học phí xem online" vẫn không được coi là có
/// `"xe"`.
///
/// Trả `null` nếu không tìm thấy; `true`/`false` = có phải khớp mờ hay không.
bool? _findWordSequence(List<String> haystackWords, List<String> needleWords) {
  if (needleWords.isEmpty) return null;
  for (
    var start = 0;
    start + needleWords.length <= haystackWords.length;
    start++
  ) {
    var fuzzy = false;
    var matched = true;
    for (var k = 0; k < needleWords.length; k++) {
      final result = _wordMatch(haystackWords[start + k], needleWords[k]);
      if (result == null) {
        matched = false;
        break;
      }
      fuzzy = fuzzy || result;
    }
    if (matched) return fuzzy;
  }
  return null;
}

List<String> _wordsOf(String asciiText) =>
    asciiText.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();

/// Argmax ổn định trên một map điểm — giữ đúng hành vi cũ (`>` chứ không
/// `>=`, nên khi hoà điểm thì phần tử GẶP TRƯỚC thắng).
({String key, double score})? _argmax(Map<String, double> scores) {
  var bestKey = '';
  var bestScore = -1.0;
  for (final entry in scores.entries) {
    if (entry.value > bestScore) {
      bestScore = entry.value;
      bestKey = entry.key;
    }
  }
  return bestScore < 0 ? null : (key: bestKey, score: bestScore);
}

CategoryMatch? matchCategory(
  String leftoverTextDiacritics,
  List<CategoryKeywordEntry> keywords,
) {
  final leftoverAscii = normalize(leftoverTextDiacritics).ascii;
  if (leftoverAscii.trim().isEmpty || keywords.isEmpty) return null;

  final leftoverWords = _wordsOf(leftoverAscii);
  final scoreByCategory = <String, double>{};

  // Cây cha-con dựng từ chính danh sách từ khoá — mọi danh mục đang sống
  // đều có ít nhất một entry (tên của nó, xem `categoryKeywordEntriesProvider`),
  // nên không cần truyền thêm một tham số danh mục nào vào tầng parser thuần.
  final parentOfCategory = <String, String?>{};
  for (final entry in keywords) {
    parentOfCategory[entry.categoryKey] = entry.parentKey;
  }

  for (final entry in keywords) {
    final needle = entry.keywordAscii.trim();
    if (needle.isEmpty) continue;
    final fuzzy = _findWordSequence(leftoverWords, _wordsOf(needle));
    if (fuzzy == null) continue;
    final score =
        entry.weight * needle.length * (fuzzy ? kFuzzyMatchScoreFactor : 1.0);
    scoreByCategory.update(
      entry.categoryKey,
      (existing) => existing + score,
      ifAbsent: () => score,
    );
  }

  if (scoreByCategory.isEmpty) return null;

  // Điểm NHÁNH = điểm của cha + điểm mọi con của nó. Danh mục con mồ côi
  // (cha không còn trong danh sách) tự tính là một nhánh riêng thay vì bị
  // bỏ — không có lối nào tạo ra ca này ở v1, nhưng bỏ im lặng thì một
  // danh mục sẽ biến mất khỏi mọi kết quả mà không ai thấy tại sao.
  String rootOf(String key) {
    final parent = parentOfCategory[key];
    if (parent == null || !parentOfCategory.containsKey(parent)) return key;
    return parent;
  }

  final scoreByBranch = <String, double>{};
  for (final entry in scoreByCategory.entries) {
    scoreByBranch.update(
      rootOf(entry.key),
      (existing) => existing + entry.value,
      ifAbsent: () => entry.value,
    );
  }

  final bestBranch = _argmax(scoreByBranch);
  if (bestBranch == null) return null;

  // Trong nhánh thắng: con có điểm riêng cao nhất, nếu không thì chính cha.
  final childScores = {
    for (final entry in scoreByCategory.entries)
      if (entry.key != bestBranch.key && rootOf(entry.key) == bestBranch.key)
        entry.key: entry.value,
  };
  final bestChild = _argmax(childScores);

  return CategoryMatch(
    categoryKey: bestChild?.key ?? bestBranch.key,
    // Điểm trả về là điểm CẢ NHÁNH — đây là độ mạnh của tín hiệu "câu này
    // nói về nhóm đó", không phụ thuộc việc có tách được con hay không.
    score: bestBranch.score,
  );
}
