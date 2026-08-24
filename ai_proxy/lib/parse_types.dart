/// Kiểu dữ liệu dùng ở "mặt ngoài" của proxy — hợp đồng riêng giữa
/// `tailnet_fallback.dart` (app Flutter) và proxy này, KHÔNG phải kiểu dữ
/// liệu thô của Gemini (xem `gemini_client.dart` cho việc dịch qua lại).
library;

/// Một lựa chọn danh mục thật của Tony — app gửi kèm mỗi request vì proxy
/// không có DB riêng, danh mục (kể cả danh mục con Tony tự thêm) chỉ sống
/// trong app. `enum` của Gemini schema được dựng động từ danh sách này mỗi
/// request, không hardcode ở proxy.
class CategoryOption {
  const CategoryOption({required this.id, required this.name});

  final String id;
  final String name;

  factory CategoryOption.fromJson(Map<String, dynamic> json) {
    return CategoryOption(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class ParseRequest {
  const ParseRequest({
    required this.message,
    required this.todayIso,
    required this.categories,
  });

  final String message;

  /// `YYYY-MM-DD`, "hôm nay" theo `Clock` inject của app (Luật #3) — proxy
  /// không tự suy ngày, luôn nhận từ app.
  final String todayIso;
  final List<CategoryOption> categories;

  factory ParseRequest.fromJson(Map<String, dynamic> json) {
    return ParseRequest(
      message: json['message'] as String,
      todayIso: json['todayIso'] as String,
      categories: [
        for (final c in (json['categories'] as List))
          CategoryOption.fromJson(c as Map<String, dynamic>),
      ],
    );
  }
}

/// Kết quả phẳng trả về app — ánh xạ 1-1 vào `ParsedDraft` phía Flutter
/// (`amountFound == false` ⇒ `ParsedAmount? amount = null`, tức thẻ lỗi "Mình
/// chưa hiểu", y hệt hành vi parser cục bộ khi không tìm thấy số tiền).
class ParseResult {
  const ParseResult({
    required this.amountFound,
    required this.amountMinor,
    required this.confident,
    required this.dateIso,
    required this.dateExplicit,
    required this.categoryId,
    required this.note,
  });

  final bool amountFound;
  final int amountMinor;
  final bool confident;
  final String dateIso;
  final bool dateExplicit;

  /// `null` = "none" (Gemini không chắc danh mục nào) — luôn là một id nằm
  /// trong danh sách `ParseRequest.categories` đã gửi, KHÔNG BAO GIỜ một
  /// chuỗi bịa ra (ép ở cả hai lớp: `enum` trong schema Gemini VÀ kiểm tra
  /// lại thủ công ở `parseModelJson` — phòng thủ hai lớp, không tin tưởng
  /// một mình ràng buộc schema).
  final String? categoryId;
  final String note;

  Map<String, dynamic> toJson() => {
    'amountFound': amountFound,
    'amountMinor': amountMinor,
    'confident': confident,
    'dateIso': dateIso,
    'dateExplicit': dateExplicit,
    'categoryId': categoryId,
    'note': note,
  };
}
