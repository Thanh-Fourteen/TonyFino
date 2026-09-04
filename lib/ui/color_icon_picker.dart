import 'package:flutter/material.dart';

import '../theme/context_ext.dart';
import '../theme/tokens/icons.dart';

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
/// (`categoryIconByCode` + [groups]) và ví (`walletIconByCode`, phẳng).
///
/// Truyền [groups] thì vẽ theo NHÓM có nhãn; bỏ trống thì vẽ phẳng như cũ.
/// Bộ icon danh mục đã lên 114 mã nên một `Wrap` phẳng là một tấm thảm 13
/// hàng không có mốc nào để định vị — nhóm là thứ cho mắt bám vào. Bộ icon
/// ví vẫn 6 mã, chia nhóm ở đó chỉ thêm chữ thừa.
class AppIconPicker extends StatelessWidget {
  const AppIconPicker({
    super.key,
    required this.icons,
    required this.selectedCode,
    required this.onSelected,
    this.groups,
  });

  final Map<String, IconData> icons;
  final String selectedCode;
  final ValueChanged<String> onSelected;

  /// Nhóm hiển thị (nhãn + danh sách `iconCode`). Mã không có trong [icons]
  /// bị bỏ qua — bảng icon mới là nguồn sự thật, nhóm chỉ là cách bày.
  final List<CategoryIconGroup>? groups;

  @override
  Widget build(BuildContext context) {
    final groups = this.groups;
    if (groups == null) return _wrap(context, icons.keys);
    // Khung CAO CỐ ĐỊNH có thanh cuộn riêng: 114 icon + 10 nhãn nhóm trải
    // thẳng ra sẽ đẩy nút Lưu của sheet đi xa cả nghìn pixel — đúng lớp lỗi
    // đã làm nút chọn danh mục cha bị khuất khỏi mép sheet ở v13 (xem
    // `category_edit_sheet.dart`). Bảng icon tự cuộn thì phần còn lại của
    // sheet giữ nguyên chiều dài dù bộ icon có lớn thêm bao nhiêu nữa.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: SizedBox(
        height: 240,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final group in groups) ...[
                Text(
                  group.label,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: context.space.xs),
                _wrap(context, group.codes),
                SizedBox(height: context.space.md),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrap(BuildContext context, Iterable<String> codes) {
    return Wrap(
      spacing: context.space.xs,
      runSpacing: context.space.xs,
      children: [
        for (final code in codes)
          if (icons[code] case final icon?)
            GestureDetector(
              onTap: () => onSelected(code),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: code == selectedCode
                      ? context.scheme.primaryContainer
                      : context.colors.card,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20),
              ),
            ),
      ],
    );
  }
}
