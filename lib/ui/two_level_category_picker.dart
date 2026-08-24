import 'package:flutter/material.dart';

import '../data/db/database.dart' show Category;
import '../theme/context_ext.dart';
import 'app_chip.dart';
import 'category_avatar.dart';

/// Bộ chọn danh mục HAI TẦNG dùng chung cho TOÀN APP: hàng trên là danh mục
/// CHA, hàng dưới là danh mục CON của đúng cha vừa chọn.
///
/// 🚨 Mọi chỗ cho chọn một danh mục PHẢI dùng widget này.
///
/// Trước đây mỗi màn tự dựng một `Wrap` đổ phẳng toàn bộ danh mục: form ghi
/// khoản, sheet chọn danh mục ở màn chat, giao dịch định kỳ, mẫu giao dịch,
/// hộp thoại chọn danh mục cho dòng tách. Sổ Tony có 27 danh mục nên chỗ nào
/// cũng là một mớ chip lẫn lộn cha-con — Tony đã nói ba lần là không được
/// làm phẳng. Sửa từng chỗ một là kiểu chắp vá và chắc chắn sót; gom về một
/// widget thì sửa một lần, mọi màn theo.
///
/// Trước đây form đổ TẤT CẢ danh mục vào một mớ chip phẳng — sổ thật của
/// Tony có 27 danh mục nên "Ăn uống", "Ăn sáng thiết yếu", "Ăn trưa thiết
/// yếu", "Xăng", "Gửi xe"… nằm lẫn lộn cùng một hàng, không nhìn ra cái nào
/// thuộc cái nào. Tony mô tả đúng cách nó phải chạy: gõ "bánh mì 30k" thì
/// chọn cha "Ăn uống", rồi mới chọn thêm con "Ăn sáng thiết yếu".
///
/// Lưu vào `transactions.categoryId` vẫn là MỘT id duy nhất — id của CON
/// nếu có chọn con, ngược lại id của cha. Không thêm cột nào: quan hệ
/// cha-con đã nằm sẵn ở `categories.parentCategoryId`, và mọi chỗ đọc
/// (danh sách, báo cáo rollup) đã hiểu quy ước này từ Phase 20.
class TwoLevelCategoryPicker extends StatelessWidget {
  const TwoLevelCategoryPicker({
    required this.categories,
    required this.kind,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Category> categories;

  /// `'expense'` / `'income'` để chỉ hiện danh mục đúng chiều tiền; `null`
  /// = hiện cả hai (dùng cho bộ lọc, nơi không có "chiều tiền đang chọn").
  final String? kind;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final c in categories) c.id: c};
    final roots = [
      for (final c in categories)
        if (c.parentCategoryId == null && (kind == null || c.kind == kind)) c,
    ];

    // Cha đang chọn = chính nó nếu đang chọn một cha, hoặc cha của con đang
    // chọn. Suy ra từ `selectedId` thay vì giữ thêm một biến state riêng —
    // hai nguồn sự thật cho cùng một lựa chọn là cách chắc chắn để chúng
    // lệch nhau khi sửa một giao dịch cũ.
    final selected = selectedId == null ? null : byId[selectedId];
    final rootId = selected == null
        ? null
        : (selected.parentCategoryId ?? selected.id);
    final children = rootId == null
        ? const <Category>[]
        : [
            for (final c in categories)
              if (c.parentCategoryId == rootId) c,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: context.space.xs,
          runSpacing: context.space.xs,
          children: [
            for (final root in roots)
              AppChip(
                label: root.name,
                editable: false,
                selected: root.id == rootId,
                icon: CategoryAvatar(
                  categoryColorId: root.categoryColorId,
                  iconCode: root.iconCode,
                  size: 18,
                ),
                // Đổi cha thì bỏ con đang chọn — giữ lại con của cha CŨ là
                // cách tạo ra giao dịch "Ăn uống / Xăng".
                onTap: () => onChanged(root.id),
              ),
          ],
        ),
        if (children.isNotEmpty) ...[
          SizedBox(height: context.space.md),
          Row(
            children: [
              Text('Danh mục con', style: context.text.labelMedium),
              SizedBox(width: context.space.xs),
              Text(
                '(không bắt buộc)',
                style: context.text.labelSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: context.space.xs),
          Wrap(
            spacing: context.space.xs,
            runSpacing: context.space.xs,
            children: [
              for (final child in children)
                AppChip(
                  label: child.name,
                  editable: false,
                  selected: child.id == selectedId,
                  // Bấm lại con đang chọn = bỏ chọn, về lại mức cha. Nếu
                  // không có đường lùi thì lỡ tay chọn con là phải xoá cả
                  // giao dịch làm lại.
                  onTap: () =>
                      onChanged(child.id == selectedId ? rootId : child.id),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
