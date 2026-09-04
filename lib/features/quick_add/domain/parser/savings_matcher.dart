/// Nhận ra ý định "cất tiền vào / rút tiền ra khỏi một mục tiêu tiết kiệm"
/// ngay trong câu chat — thứ trước đây màn chat KHÔNG hiểu: gõ "chuyển 5tr
/// vào tiết kiệm" thì `category_matcher` chấm điểm như mọi câu khác và ghi
/// ra một khoản CHI thường, mục tiêu tiết kiệm không nhúc nhích. Lối vào duy
/// nhất là chip "Chuyển quỹ" (mà nó lại mở sheet chuyển giữa hai VÍ, khác
/// hẳn) hoặc nút "+" bên màn Quỹ.
///
/// Dart thuần như cả thư mục `parser/` — danh sách mục tiêu do tầng gọi đọc
/// từ DB rồi truyền vào ([SavingsTargetEntry]), ở đây không biết gì về drift.
///
/// 🚨 THẬN TRỌNG LÀ MẶC ĐỊNH. Nhận nhầm một khoản chi thành khoản để dành
/// tệ hơn nhiều so với không nhận ra: khoản chi biến mất khỏi báo cáo chi
/// tiêu VÀ thổi phồng tiến độ một mục tiêu. Nên mọi đường ở đây đều đòi tín
/// hiệu TƯỜNG MINH, và khi không đủ chắc thì trả `null` để câu chạy tiếp
/// đúng luồng cũ (khoản chi bình thường), không đoán bừa.
library;

import 'parse_result.dart';

/// Từ/cụm nói thẳng ra là "để dành", không cần động từ nào đi kèm.
const Set<String> kSavingsWords = {
  'tiet kiem',
  'de danh',
  'bo ong',
  'bo heo',
  'tich luy',
  'quy',
};

/// Động từ chuyển tiền. MỘT MÌNH chúng chưa đủ ("chuyển khoản tiền nhà 2tr"
/// là một khoản chi) — phải đi kèm [kDirectionWords] hoặc [kSavingsWords].
const Set<String> kDepositVerbs = {'chuyen', 'nap', 'gui', 'cat', 'gop'};

/// Giới từ chỉ ĐÍCH — thứ biến "chuyển" thành "chuyển VÀO đâu đó".
const Set<String> kDirectionWords = {'vao', 'sang', 'qua', 'len'};

/// Động từ rút tiền RA khỏi mục tiêu.
const Set<String> kWithdrawVerbs = {'rut'};

/// Tên mục tiêu ngắn hơn ngần này (đã bỏ dấu, bỏ khoảng trắng) KHÔNG được
/// dùng làm bằng chứng — "Nhà" (`nha`) sẽ khớp vào "tiền nhà", "Xe" (`xe`)
/// khớp vào "xe ôm". Tên ngắn vẫn dùng được, chỉ là phải có thêm một từ
/// trong [kSavingsWords] ở câu thì mới tính.
const int kMinStrongTargetNameLength = 4;

/// Tìm ý định để dành trong [asciiText] (phần chữ CÒN LẠI của draft, đã bỏ
/// dấu — xem `parser.dart`), đối chiếu với [targets] là các mục tiêu tiết
/// kiệm đang hoạt động.
///
/// Trả `null` khi không đủ chắc — tầng gọi hiểu là "câu bình thường".
SavingsMatch? matchSavings(
  String asciiText,
  List<SavingsTargetEntry> targets,
) {
  if (targets.isEmpty) return null;
  final words = _wordsOf(asciiText);
  if (words.isEmpty) return null;

  final hasSavingsWord = kSavingsWords.any((w) => _containsPhrase(words, w));
  final hasDepositVerb = words.any(kDepositVerbs.contains);
  final hasDirectionWord = words.any(kDirectionWords.contains);
  final hasWithdrawVerb = words.any(kWithdrawVerbs.contains);

  final isWithdrawal = hasWithdrawVerb;
  final hasIntent = isWithdrawal
      ? (hasSavingsWord || hasDirectionWord)
      : (hasSavingsWord || (hasDepositVerb && hasDirectionWord));
  if (!hasIntent) return null;

  // Tên mục tiêu xuất hiện nguyên vẹn trong câu — dài nhất thắng ("Quỹ mua
  // nhà" phải thắng "Nhà" khi cả hai cùng khớp.)
  SavingsTargetEntry? named;
  for (final target in targets) {
    if (!_containsPhrase(words, target.nameAscii)) continue;
    final tooShort =
        target.nameAscii.replaceAll(' ', '').length <
        kMinStrongTargetNameLength;
    if (tooShort && !hasSavingsWord) continue;
    if (named == null || target.nameAscii.length > named.nameAscii.length) {
      named = target;
    }
  }

  // Không gọi tên mục tiêu nào: chỉ dám tự chọn khi câu đã nói thẳng "tiết
  // kiệm"/"để dành" VÀ trong sổ đúng một mục tiêu — hai mục tiêu trở lên thì
  // đoán là tung đồng xu, thà để câu chạy như một khoản chi bình thường và
  // Tony sửa tay còn hơn cộng nhầm vào mục tiêu kia.
  final target =
      named ?? (hasSavingsWord && targets.length == 1 ? targets.single : null);
  if (target == null) return null;

  return SavingsMatch(goalKey: target.goalKey, isWithdrawal: isWithdrawal);
}

List<String> _wordsOf(String asciiText) => asciiText
    .split(RegExp(r'[^a-z0-9]+'))
    .where((w) => w.isNotEmpty)
    .toList(growable: false);

/// `true` nếu [phrase] (một hoặc nhiều từ, đã bỏ dấu) xuất hiện thành một
/// dãy từ LIÊN TIẾP trong [words] — cùng quy ước khớp-theo-từ với
/// `category_matcher` (từ khoá `xe` không được khớp vào giữa `xem`).
bool _containsPhrase(List<String> words, String phrase) {
  final needle = _wordsOf(phrase);
  if (needle.isEmpty || needle.length > words.length) return false;
  for (var i = 0; i + needle.length <= words.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (words[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}
