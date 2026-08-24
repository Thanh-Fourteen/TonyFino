import 'package:flutter/material.dart';

import 'tokens/palette.dart';

/// `elevation: 0` trên MỌI component (Luật #11) — chiều sâu tự vẽ bằng
/// `BoxShadow`, ở CẢ hai theme.
///
/// Mỗi bậc là bóng HAI LỚP: một vệt tiếp xúc ngắn và đậm sát mép, cộng một
/// quầng toả rộng và mờ. Đây là điểm khác giữa "card có khối" và "card trôi
/// lơ lửng" — một lớp mờ đều không bao giờ ra được cảm giác đặt trên mặt.
///
/// Dark mode CÓ đổ bóng (đảo quy ước cũ "dark không bao giờ đổ bóng"): bóng
/// đen alpha cao trên nền gần đen vẫn đọc rõ — đúng cách Mercury làm — và
/// đó chính là thứ trước đây khiến màn tối phẳng lì. Vệt sáng mép trên
/// (`level1TopHighlight`) bù thêm hướng chiếu sáng từ trên xuống.
@immutable
class AppShadows extends ThemeExtension<AppShadows> {
  const AppShadows({
    required this.level1Shadow,
    required this.level1Border,
    required this.level2Shadow,
    required this.level2Border,
    required this.level2TopHighlight,
    required this.level1TopHighlight,
  });

  /// Bậc 1 — card.
  final List<BoxShadow> level1Shadow;
  final Color level1Border;

  /// Vệt sáng 1px mép TRÊN của card — `transparent` ở light (ở đó bóng đã đủ
  /// kể chuyện chiều sâu), có màu ở dark để card tách khỏi nền bằng ánh sáng
  /// chứ không chỉ bằng bóng.
  final Color level1TopHighlight;

  /// Bậc 2 — sheet, menu, nav mờ.
  final List<BoxShadow> level2Shadow;
  final Color level2Border;
  final Color level2TopHighlight;

  static const _transparent = Color(0x00000000);

  static const light = AppShadows(
    level1Shadow: [
      BoxShadow(
        color: paletteShadowCardContact,
        blurRadius: 3,
        offset: Offset(0, 1),
      ),
      BoxShadow(
        color: paletteShadowCard,
        blurRadius: 20,
        offset: Offset(0, 8),
        spreadRadius: -4,
      ),
    ],
    level1Border: paletteHairlineLight,
    level1TopHighlight: _transparent,
    level2Shadow: [
      BoxShadow(
        color: paletteShadowSheetContact,
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
      BoxShadow(
        color: paletteShadowSheet,
        blurRadius: 40,
        offset: Offset(0, 16),
        spreadRadius: -8,
      ),
    ],
    level2Border: _transparent,
    level2TopHighlight: _transparent,
  );

  static const dark = AppShadows(
    level1Shadow: [
      BoxShadow(
        color: paletteShadowCardDarkContact,
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
      BoxShadow(
        color: paletteShadowCardDark,
        blurRadius: 24,
        offset: Offset(0, 8),
        spreadRadius: -6,
      ),
    ],
    level1Border: paletteWhiteHairline6,
    level1TopHighlight: paletteWhiteHairline8,
    level2Shadow: [
      BoxShadow(
        color: paletteShadowSheetDark,
        blurRadius: 48,
        offset: Offset(0, 18),
        spreadRadius: -10,
      ),
    ],
    level2Border: paletteWhiteHairline8,
    level2TopHighlight: paletteWhiteHairline4,
  );

  @override
  AppShadows copyWith({
    List<BoxShadow>? level1Shadow,
    Color? level1Border,
    Color? level1TopHighlight,
    List<BoxShadow>? level2Shadow,
    Color? level2Border,
    Color? level2TopHighlight,
  }) {
    return AppShadows(
      level1Shadow: level1Shadow ?? this.level1Shadow,
      level1Border: level1Border ?? this.level1Border,
      level1TopHighlight: level1TopHighlight ?? this.level1TopHighlight,
      level2Shadow: level2Shadow ?? this.level2Shadow,
      level2Border: level2Border ?? this.level2Border,
      level2TopHighlight: level2TopHighlight ?? this.level2TopHighlight,
    );
  }

  /// Nội suy THẬT (Luật #3). `BoxShadow.lerpList` xử lý đúng trường hợp
  /// light↔dark có SỐ LƯỢNG shadow khác nhau (dark rỗng) — nó mờ dần shadow
  /// dư ra thay vì nhảy cứng ở giữa animation.
  @override
  AppShadows lerp(ThemeExtension<AppShadows>? other, double t) {
    if (other is! AppShadows) return this;
    return AppShadows(
      level1Shadow:
          BoxShadow.lerpList(level1Shadow, other.level1Shadow, t) ?? const [],
      level1Border: Color.lerp(level1Border, other.level1Border, t)!,
      level1TopHighlight: Color.lerp(
        level1TopHighlight,
        other.level1TopHighlight,
        t,
      )!,
      level2Shadow:
          BoxShadow.lerpList(level2Shadow, other.level2Shadow, t) ?? const [],
      level2Border: Color.lerp(level2Border, other.level2Border, t)!,
      level2TopHighlight: Color.lerp(
        level2TopHighlight,
        other.level2TopHighlight,
        t,
      )!,
    );
  }
}
