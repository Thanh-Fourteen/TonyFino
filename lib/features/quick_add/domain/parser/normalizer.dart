import 'package:diacritic/diacritic.dart';

/// Chuẩn hoá chuỗi tiếng Việt thô thành hai luồng dùng xuyên suốt parser:
/// [diacritics] (giữ nguyên dấu, dùng để phân biệt các từ chỉ khác nhau ở
/// dấu — vd. "năm" số 5 vs "lăm" biến thể, hay "thứ" vs "thư") và [ascii]
/// (bỏ dấu, dùng để so khớp từ khoá danh mục không phân biệt dấu, giống cột
/// bóng `keyword_ascii`/`note_ascii` đã có ở Phase 4).
class NormalizedText {
  const NormalizedText({required this.diacritics, required this.ascii});

  final String diacritics;
  final String ascii;
}

/// **Nghiên cứu trước (đã kiểm chứng thực nghiệm, không đoán):** `đ`
/// (U+0111) KHÔNG phân rã dưới NFD — nó là một chữ cái Unicode riêng, không
/// phải `d` ghép với dấu tổ hợp, nên không thư viện chuẩn hoá NFD/NFC nào tự
/// xử lý được nếu không map tường minh. Đã thử `removeDiacritics` của package
/// `diacritic` với chuỗi thật ("Đồng, đường, cà phê, phở, rưỡi, thứ Tư") và
/// xác nhận nó ĐÃ map `đ→d`, `Đ→D` đúng — nhưng vẫn giữ map tường minh dưới
/// đây làm lớp phòng thủ thứ hai, độc lập với hành vi nội bộ của package:
/// bỏ sót map này là hỏng ÂM THẦM mọi phép khớp "dong"/"đồng" (không ném lỗi,
/// chỉ đơn giản không bao giờ khớp được — loại bug khó phát hiện nhất).
///
/// **Phạm vi cố ý bỏ qua:** chuẩn hoá NFC đầy đủ (tổ hợp mọi nguyên âm có dấu
/// từ dạng phân rã) không được cài — Dart không có API NFC dựng sẵn và
/// pubspec dự án không liệt kê package nào làm việc này. Trong thực tế, văn
/// bản gõ từ bàn phím Android (Gboard) luôn ra dạng đã tổ hợp sẵn (NFC), và
/// `đ` — landmine duy nhất Tony chỉ rõ — không phải vấn đề tổ hợp/phân rã mà
/// là "không bao giờ phân rã", đã xử lý ở trên. Nếu sau này nhập liệu từ
/// nguồn khác (dán từ web, OCR) sinh ra dạng phân rã thật, sẽ cần thêm
/// package NFC lúc đó — ghi chú lại thay vì cài đặt one lượng lớn code
/// "phòng hờ" chưa có bằng chứng cần dùng.
const _explicitDMap = {'đ': 'd', 'Đ': 'D'};

/// ~50 mục teencode tiếng Việt thường gặp khi nhắn tin nhanh cho chính mình
/// (self-note) — tự chọn, ưu tiên những từ **không** tự khớp qua ascii-fold
/// (vd. "dc"→"được" hữu ích vì ascii("được")="duoc" ≠ "dc"; "khong"→"không"
/// thì KHÔNG cần vì ascii("không") đã là "khong" sẵn). Cố tình tránh mọi
/// token 1 ký tự và các từ trùng với token ngữ pháp số tiền/ngày
/// (`k`, `tr`, `đ`, `d`, `vnd`, `h`, số đếm, tên thứ) để không phá tokenizer.
const Map<String, String> teencodeMap = {
  'ko': 'không',
  'k0': 'không',
  'hok': 'không',
  'hong': 'không',
  'kg': 'không',
  'khg': 'không',
  'dc': 'được',
  'đc': 'được',
  'dk': 'được',
  'đk': 'được',
  'vs': 'với',
  'z': 'vậy',
  'v': 'vậy',
  'j': 'gì',
  'jì': 'gì',
  'bn': 'bao nhiêu',
  'mn': 'mọi người',
  'ng': 'người',
  'nt': 'nhắn tin',
  'bit': 'biết',
  'bík': 'biết',
  'r': 'rồi',
  'oy': 'rồi',
  'roài': 'rồi',
  'hnay': 'hôm nay',
  'hnai': 'hôm nay',
  'hqua': 'hôm qua',
  'cmon': 'cảm ơn',
  'thanks': 'cảm ơn',
  'tks': 'cảm ơn',
  'thank': 'cảm ơn',
  'sr': 'xin lỗi',
  'sorry': 'xin lỗi',
  'ck': 'chồng',
  'vk': 'vợ',
  'nhìu': 'nhiều',
  'nhiu': 'nhiều',
  'mik': 'mình',
  'mjk': 'mình',
  'ok': 'được',
  'okela': 'được',
  'thoy': 'thôi',
  'wa': 'quá',
  'qa': 'quá',
  'mk': 'mình',
  'trc': 'trước',
  'tv': 'tivi',
  'dt': 'điện thoại',
  'nc': 'nước',
  'sp': 'sản phẩm',
};

/// Chuẩn hoá một từ đơn qua bảng teencode — dùng lại cho cả token hoá lẫn
/// test đơn vị, không lặp logic tra cứu.
String expandTeencode(String word) => teencodeMap[word] ?? word;

NormalizedText normalize(String raw) {
  final lowered = raw.trim().toLowerCase();
  final collapsed = lowered.replaceAll(RegExp(r'\s+'), ' ');

  // Tách theo khoảng trắng, mở rộng teencode theo TỪNG TỪ nguyên (không phá
  // token số/đơn vị dính liền như "2tr5" — teencode chỉ khớp khi cả từ giữa
  // hai khoảng trắng trùng khớp tuyệt đối, "2tr5" không nằm trong bảng nên
  // giữ nguyên).
  final expanded = collapsed.split(' ').map(expandTeencode).join(' ');

  // Luồng GIỮ DẤU: không đụng vào đ/Đ — "được"/"đường" vẫn cần đ nguyên vẹn
  // để so khớp với các từ ngữ pháp ngày/số giữ dấu (vd. phân biệt "năm" số 5
  // với "lăm").
  final diacritics = expanded;

  // Luồng BỎ DẤU: map đ→d tường minh TRƯỚC (lớp phòng thủ độc lập, xem doc
  // comment `_explicitDMap`), rồi mới bỏ toàn bộ dấu còn lại qua package.
  final dMapped = expanded
      .split('')
      .map((ch) => _explicitDMap[ch] ?? ch)
      .join();
  final ascii = removeDiacritics(dMapped);

  return NormalizedText(diacritics: diacritics, ascii: ascii);
}
