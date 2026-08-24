import 'package:flutter/material.dart';

import '../../../data/db/database.dart';
import '../../../theme/context_ext.dart';
import '../../../ui/two_level_category_picker.dart';

/// Sheet chọn danh mục cho một thẻ xác nhận chat — bottom-sheet-first (Luật
/// bố cục), tái dùng đúng kiểu `Wrap` chip đã có ở `TransactionFormSheet`
/// (Phase 6) thay vì phát minh lại. Chọn xong = vòng lặp học ghi nhận ngay
/// (`QuickAddController.correctCategory`), không cần nút "Xong" riêng.
Future<int?> showCategoryPickerSheet({
  required BuildContext context,
  required List<Category> categories,
  int? selectedCategoryId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: sheetContext.space.screenHorizontal,
          right: sheetContext.space.screenHorizontal,
          top: sheetContext.space.lg,
          bottom:
              sheetContext.space.lg +
              MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chọn danh mục', style: sheetContext.text.titleLarge),
            SizedBox(height: sheetContext.space.lg),
            // Hai tầng, dùng chung `TwoLevelCategoryPicker` với form ghi
            // khoản — trước đây đây là một `Wrap` đổ phẳng 27 danh mục.
            // `kind: null` vì sheet này mở cho cả khoản thu lẫn chi.
            TwoLevelCategoryPicker(
              categories: categories,
              kind: null,
              selectedId: selectedCategoryId,
              onChanged: (id) => Navigator.of(sheetContext).pop(id),
            ),
          ],
        ),
      );
    },
  );
}
