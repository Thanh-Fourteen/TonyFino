import 'package:flutter/material.dart';

import '../theme/context_ext.dart';
import '../theme/tokens/icons.dart';

/// Chip pill bo `full`. `editable: true` (mặc định) vẽ viền 1px + caret `▾`
/// — **không phải pill tô đặc**: pill tô đặc đọc ra là nhãn tĩnh, trong khi
/// đây là chip người dùng chạm được để sửa (danh mục/ngày/ví ở thẻ xác nhận
/// chat, Phase 8). `unconfirmed: true` vẽ thêm dấu `?` mờ — tín hiệu độ tin
/// cậy khi parser không chắc field này.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.editable = true,
    this.unconfirmed = false,
    this.onTap,
  });

  final String label;
  final Widget? icon;
  final bool selected;
  final bool editable;
  final bool unconfirmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;

    final Color fg;
    final Color border;
    final Color? fill;
    if (selected) {
      fg = scheme.onPrimaryContainer;
      border = context.colors.brandText;
      fill = scheme.primaryContainer;
    } else if (unconfirmed) {
      fg = colors.budgetWarn;
      border = colors.budgetWarn;
      fill = null;
    } else {
      fg = colors.onSurface;
      border = colors.hairline;
      fill = null;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radii.full),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.md,
            vertical: context.space.xs,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(context.radii.full),
            border: Border.all(color: border, width: unconfirmed ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                IconTheme(
                  data: IconThemeData(color: fg, size: 16),
                  child: icon!,
                ),
                SizedBox(width: context.space.xs),
              ],
              Text(label, style: context.text.labelMedium?.copyWith(color: fg)),
              if (unconfirmed) ...[
                SizedBox(width: context.space.xxs),
                Text('?', style: context.text.labelMedium?.copyWith(color: fg)),
              ],
              if (editable && !unconfirmed) ...[
                SizedBox(width: context.space.xxs),
                Icon(kIconExpandMore, size: 16, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
