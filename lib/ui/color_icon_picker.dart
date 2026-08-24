import 'package:flutter/material.dart';

import '../theme/context_ext.dart';

/// Chọn `categoryColorId` (D10: chỉ số INTEGER vào bảng màu cố định của
/// theme, TUYỆT ĐỐI không lưu hex) — dùng chung cho sheet sửa danh mục VÀ ví
/// (cả hai đều theo đúng quy ước D10, xem `Wallets.categoryColorId`).
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.selectedColorId,
    required this.onSelected,
  });

  final int selectedColorId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final fills = context.colors.categoryFills;
    return Wrap(
      spacing: context.space.xs,
      runSpacing: context.space.xs,
      children: [
        for (var i = 0; i < fills.length; i++)
          GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: fills[i],
                shape: BoxShape.circle,
                border: i == selectedColorId
                    ? Border.all(color: context.scheme.onSurface, width: 3)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Chọn `iconCode` từ một bộ icon cố định — dùng chung cho danh mục
/// (`categoryIconByCode`) và ví (`walletIconByCode`).
class AppIconPicker extends StatelessWidget {
  const AppIconPicker({
    super.key,
    required this.icons,
    required this.selectedCode,
    required this.onSelected,
  });

  final Map<String, IconData> icons;
  final String selectedCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.space.xs,
      runSpacing: context.space.xs,
      children: [
        for (final entry in icons.entries)
          GestureDetector(
            onTap: () => onSelected(entry.key),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: entry.key == selectedCode
                    ? context.scheme.primaryContainer
                    : context.colors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(entry.value, size: 20),
            ),
          ),
      ],
    );
  }
}
