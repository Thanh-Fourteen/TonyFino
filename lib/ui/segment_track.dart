import 'package:flutter/material.dart';

import '../theme/context_ext.dart';

/// Rãnh chọn một trong vài lựa chọn — viên đang chọn là mảng TRẮNG nổi lên
/// trên rãnh xám (kiểu Apple Stocks/Robinhood), KHÔNG tô cam: đây là mảng
/// lớn, lặp lại nhiều lần trên trang; cam chỉ dành cho mảng nhỏ và đậm.
class SegmentTrack<T> extends StatelessWidget {
  const SegmentTrack({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;

  /// `null` = không viên nào đang chọn (vd đang xem khoảng tự chọn).
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // Nền tối: màu thẻ gần như trùng màu rãnh — viên đang chọn biến mất
    // (bắt trên máy ảo 2026-09-28). Làm sáng viên thêm một nấc bằng chính
    // màu chữ phủ mỏng lên màu thẻ, vẫn là token chứ không thêm màu mới.
    final selectedFill = Theme.of(context).brightness == Brightness.dark
        ? Color.alphaBlend(
            context.colors.onSurface.withValues(alpha: 0.14),
            context.colors.card,
          )
        : context.colors.card;
    return Container(
      padding: EdgeInsets.all(context.space.xxs),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(context.radii.full),
      ),
      child: Row(
        children: [
          for (final (v, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: context.durations.navMorph,
                    curve: context.curves.navMorph,
                    constraints: const BoxConstraints(minHeight: 36),
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.space.xs,
                      vertical: context.space.xs,
                    ),
                    decoration: BoxDecoration(
                      color: v == value ? selectedFill : null,
                      borderRadius: BorderRadius.circular(context.radii.full),
                      boxShadow: v == value
                          ? context.shadows.level1Shadow
                          : null,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: context.text.labelMedium?.copyWith(
                        fontWeight: v == value
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: v == value
                            ? context.colors.onSurface
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
