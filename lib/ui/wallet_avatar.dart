import 'package:flutter/material.dart';

import '../theme/context_ext.dart';
import '../theme/tokens/icons.dart';

/// Avatar tròn của ví (Phase 13) — cùng khuôn `CategoryAvatar`, khác bộ icon
/// (`walletIconByCode` thay vì `categoryIconByCode`). Tách riêng thay vì
/// tham số hoá `CategoryAvatar` vì hai bộ icon là hai khái niệm khác nhau
/// (ví không phải danh mục), dù cùng chia sẻ quy ước màu D10.
class WalletAvatar extends StatelessWidget {
  const WalletAvatar({
    super.key,
    required this.categoryColorId,
    required this.iconCode,
    this.size = 40,
  });

  final int categoryColorId;
  final String iconCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fills = context.colors.categoryFills;
    final fill = fills[categoryColorId % fills.length];
    final icon = resolveWalletIcon(iconCode);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // Nền xanh chung, cùng lý do với `CategoryAvatar`: màu ấm pha 16%
        // trên nền tối ra nâu đục. Khác chỗ đó ở một điểm — icon ví là glyph
        // ĐƠN SẮC nên màu ví phải ở lại trên chính glyph, đó là chỗ duy nhất
        // còn mang màu Tony chọn cho ví.
        color: context.colors.brandText.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: fill, fill: 1),
    );
  }
}
