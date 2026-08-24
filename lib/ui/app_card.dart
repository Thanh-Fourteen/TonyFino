import 'package:flutter/material.dart';

import '../theme/context_ext.dart';

/// Card bậc 1 — `elevation: 0` (Luật #4), tự vẽ `BoxShadow` qua
/// `context.shadows.level1Shadow` (bóng HAI LỚP: vệt tiếp xúc + quầng toả),
/// ở cả light lẫn dark.
///
/// Thêm một dải sáng rất mảnh chạy dọc mép TRÊN, mờ dần xuống — mô phỏng
/// ánh sáng hắt lên cạnh trên của một tấm nổi. Đây là nửa còn lại của cảm
/// giác khối: bóng nói "vật này nằm trên mặt phẳng", vệt sáng nói "vật này
/// có bề dày và đang được chiếu sáng từ trên".
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(context.radii.lg);
    final inner = Padding(
      padding: padding ?? EdgeInsets.all(context.space.cardPadding),
      child: child,
    );

    final highlight = context.shadows.level1TopHighlight;

    return Container(
      // boxShadow vẽ ở Container NGOÀI, KHÔNG bọc trong ClipRRect — nếu clip
      // sẽ cắt mất phần bóng tràn ra ngoài bo góc.
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: radius,
        border: Border.all(color: context.shadows.level1Border, width: 1),
        boxShadow: context.shadows.level1Shadow,
        // Vệt sáng phải TRỘN SẴN vào màu card chứ không phủ lên: trong
        // `BoxDecoration`, `gradient` ĐÈ `color` hoàn toàn, nên một gradient
        // từ "sáng" sang "trong suốt" sẽ làm thân card trong suốt luôn.
        // Hai mốc màu ở đây đều đục: (sáng trộn lên card) → (card).
        gradient: highlight.a == 0
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(highlight, context.colors.card),
                  context.colors.card,
                ],
                stops: const [0.0, 0.06],
              ),
      ),
      child: onTap == null
          ? inner
          : ClipRRect(
              borderRadius: radius,
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap, child: inner),
              ),
            ),
    );
  }
}
