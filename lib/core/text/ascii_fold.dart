import 'package:diacritic/diacritic.dart';

/// Chuẩn hoá chuỗi tiếng Việt về ASCII thường, dùng cho các cột bóng
/// (`note_ascii`, `keyword_ascii`) phục vụ tìm kiếm không dấu.
///
/// `đ` KHÔNG phân rã dưới NFD (Phase 7) — `removeDiacritics` của package
/// `diacritic` đã map tường minh nên không cần tự xử lý ở đây, nhưng đừng
/// thay bằng `unorm`/NFD thuần nếu sau này đổi thư viện.
String foldToAscii(String input) =>
    removeDiacritics(input.trim()).toLowerCase();
