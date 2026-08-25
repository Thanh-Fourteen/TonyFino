import 'package:flutter/material.dart';

import '../../../data/db/database.dart';
import '../../../ui/two_level_category_picker_sheet.dart';

/// Sheet chọn danh mục cho một thẻ xác nhận chat — bottom-sheet-first (Luật
/// bố cục). Chọn xong = vòng lặp học ghi nhận ngay
/// (`QuickAddController.correctCategory`), không cần nút "Xong" riêng.
///
/// Toàn bộ hành vi hai tầng (kể cả bug "sheet đóng trước khi hàng danh mục
/// con kịp hiện") nằm ở `showTwoLevelCategoryPickerSheet` dùng chung — hàm
/// này chỉ còn là chỗ đặt tiêu đề. `kind: null` vì sheet này mở cho cả
/// khoản thu lẫn chi.
Future<int?> showCategoryPickerSheet({
  required BuildContext context,
  required List<Category> categories,
  int? selectedCategoryId,
}) {
  return showTwoLevelCategoryPickerSheet(
    context: context,
    categories: categories,
    kind: null,
    selectedCategoryId: selectedCategoryId,
  );
}
