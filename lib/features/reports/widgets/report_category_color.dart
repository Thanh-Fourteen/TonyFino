import 'package:flutter/material.dart';

import '../../../theme/context_ext.dart';

/// Màu danh mục cho mọi widget báo cáo — CÙNG công thức modulo
/// `CategoryAvatar` đã dùng (`lib/ui/category_avatar.dart`), nhân tiện xử lý
/// đúng sentinel `-1` ("Khác"/"Chưa phân loại", xem `category_slice.dart`)
/// mà không cần nhánh riêng: `%` trên `int` ở Dart luôn trả kết quả KHÔNG ÂM
/// khi chia cho số dương (khác Java/C), nên `-1 % 12 == 11` — đúng chỉ số
/// màu xám cuối bảng `paletteCategoryColors`, không phải lỗi tràn số.
Color reportCategoryColor(BuildContext context, int categoryColorId) {
  final fills = context.colors.categoryFills;
  return fills[categoryColorId % fills.length];
}
