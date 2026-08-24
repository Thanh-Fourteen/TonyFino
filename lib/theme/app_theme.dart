import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shadows.dart';
import 'app_typography.dart';
import 'tokens/palette.dart';
import 'tokens/radii.dart';

/// **MỘT** hàm sinh cả `lightTheme` và `darkTheme` (Luật #2) — hai `ThemeData`
/// viết tay riêng SẼ lệch nhau theo thời gian; một hàm nhận `Brightness` thì
/// không thể lệch, vì mọi nhánh khác biệt đều tường minh ngay tại chỗ rẽ.
///
/// [amoled] chỉ có ý nghĩa khi `brightness == dark` — đổi MỖI `canvas` sang
/// đen tuyền (`#000000`), đúng 1 dòng vì token có cấu trúc đúng (design
/// system § Màu: "Ship thêm toggle Đen tuyền — 3 dòng nếu token có cấu trúc
/// đúng"). Card/surfaceContainer/sheet KHÔNG đổi — chỉ nền trang.
///
/// [dynamicScheme] (Phase 17, opt-in, mặc định `null` = tắt — D9): khi có,
/// GHI ĐÈ các vai trò `primary`/`surface` TRUNG TÍNH của `ColorScheme` chuẩn
/// Material — KHÔNG BAO GIỜ chạm `AppColors` (bảng `canvas`/`card`/12 màu
/// danh mục/thu-chi cố định, đọc qua `context.colors`, không phải
/// `context.scheme`) — mọi màn hình trong app đọc màu qua `context.colors`,
/// KHÔNG qua `colorScheme` (trừ 2-3 chỗ hiếm dùng `context.scheme.primary`
/// cho trạng thái chọn) — nên đè `ColorScheme` không thể làm lệch bảng màu
/// biểu đồ/thu-chi dù dynamicScheme trả về màu gì. Xem docs/decisions.md
/// § Phase 17 "Dynamic color".
ThemeData _build(
  Brightness brightness, {
  bool amoled = false,
  ColorScheme? dynamicScheme,
}) {
  final isDark = brightness == Brightness.dark;
  var colors = isDark ? AppColors.dark : AppColors.light;
  final typography = isDark ? AppTypography.dark : AppTypography.light;
  final shadows = isDark ? AppShadows.dark : AppShadows.light;

  if (isDark && amoled) {
    colors = colors.copyWith(canvas: paletteCanvasAmoled);
  }

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary:
        dynamicScheme?.primary ??
        (isDark ? paletteBrickDark : paletteBrickLight),
    onPrimary:
        dynamicScheme?.onPrimary ??
        (isDark ? paletteBrickContrastDark : paletteBrickContrastLight),
    primaryContainer:
        dynamicScheme?.primaryContainer ??
        (isDark ? paletteBrickSoftDark : paletteBrickSoftLight),
    onPrimaryContainer:
        dynamicScheme?.onPrimaryContainer ??
        (isDark ? paletteBrickSoftContrastDark : paletteBrickSoftContrastLight),
    // Không dùng ở call site (đọc qua context.colors thay vì colorScheme.secondary/tertiary) —
    // giữ để ColorScheme hợp lệ, mượn thẳng primary cho nhất quán thị giác.
    secondary:
        dynamicScheme?.primary ??
        (isDark ? paletteBrickDark : paletteBrickLight),
    onSecondary:
        dynamicScheme?.onPrimary ??
        (isDark ? paletteBrickContrastDark : paletteBrickContrastLight),
    tertiary:
        dynamicScheme?.primary ??
        (isDark ? paletteBrickDark : paletteBrickLight),
    onTertiary:
        dynamicScheme?.onPrimary ??
        (isDark ? paletteBrickContrastDark : paletteBrickContrastLight),
    error: paletteRedFill,
    onError: const Color(0xFFFFFFFF),
    errorContainer: colors.expenseContainer,
    onErrorContainer: colors.expenseText,
    surface: dynamicScheme?.surface ?? colors.canvas,
    onSurface: dynamicScheme?.onSurface ?? colors.onSurface,
    surfaceContainerLowest:
        dynamicScheme?.surfaceContainerLowest ?? colors.card,
    surfaceContainerLow:
        dynamicScheme?.surfaceContainerLow ?? colors.surfaceContainer,
    surfaceContainer:
        dynamicScheme?.surfaceContainer ?? colors.surfaceContainer,
    surfaceContainerHigh: dynamicScheme?.surfaceContainerHigh ?? colors.sheet,
    surfaceContainerHighest:
        dynamicScheme?.surfaceContainerHighest ?? colors.sheet,
    onSurfaceVariant:
        dynamicScheme?.onSurfaceVariant ?? colors.onSurfaceVariant,
    outline: dynamicScheme?.outline ?? colors.hairline,
    outlineVariant: dynamicScheme?.outlineVariant ?? colors.hairline,
    surfaceTint: Colors.transparent, // elevation:0 mọi nơi — không tint M3
  );

  const beVietnamPro = 'BeVietnamPro';

  TextStyle vnStyle({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacingEm = 0,
  }) {
    return TextStyle(
      fontFamily: beVietnamPro,
      color: colors.onSurface,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacingEm * size,
      // Luật #12 — bắt buộc, nếu không dấu chồng tiếng Việt (ế ữ ỗ ặ) bị cắt.
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  final textTheme = TextTheme(
    displayLarge: vnStyle(
      size: 30,
      weight: FontWeight.w700,
      height: 1.25,
      letterSpacingEm: -0.01,
    ),
    titleLarge: vnStyle(size: 20, weight: FontWeight.w600, height: 1.30),
    titleMedium: vnStyle(size: 16, weight: FontWeight.w600, height: 1.35),
    bodyLarge: vnStyle(size: 15, weight: FontWeight.w400, height: 1.50),
    bodyMedium: vnStyle(size: 14, weight: FontWeight.w400, height: 1.50),
    labelMedium: vnStyle(
      size: 12,
      weight: FontWeight.w500,
      height: 1.45,
      letterSpacingEm: 0.01,
    ),
  );

  return ThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colors.canvas,
    // Nút CHỮ/VIỀN phải dùng `brandText`, KHÔNG phải `colorScheme.primary`.
    // `primary` giờ là màu NỀN nút (cam sáng #F4700A) — đặt nó lên nền trắng
    // làm chữ thì chỉ 2.83:1, không đọc được. Material mặc định lấy
    // `primary` cho foreground của TextButton/OutlinedButton nên phải ghi
    // đè tường minh ở đây, một lần, thay vì sửa từng call site.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: colors.brandText),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: colors.brandText),
    ),
    fontFamily: beVietnamPro,
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    iconTheme: IconThemeData(color: colors.onSurface),
    dividerTheme: DividerThemeData(
      color: colors.hairline,
      thickness: 1,
      space: 0,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colors.canvas,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0, // Luật #4 — mọi component, tự vẽ BoxShadow (xem AppCard)
      color: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appRadii.lg),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appRadii.lg),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      modalElevation: 0,
      backgroundColor: colors.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(appRadii.xxl)),
      ),
    ),
    // Tab dùng PETROL (`brandText`), không dùng `colorScheme.primary`: cam
    // #F4700A chỉ đạt 2.83:1 so với canvas nên làm nhãn tab là không đọc
    // được, còn để Material tự lấy primary thì nhãn ra đúng tông đó. Cam ở
    // lại chỗ nó khoẻ nhất — mảng nền: FAB, nút bơm đầy, viên nav dưới.
    tabBarTheme: TabBarThemeData(
      labelColor: colors.brandText,
      unselectedLabelColor: colors.onSurfaceVariant,
      indicatorColor: colors.brandText,
      dividerColor: Colors.transparent,
    ),
    // FAB: nền CAM ĐẬM + chữ tối, không phải `primaryContainer` (cam 10%).
    //
    // Nút hành động chính mà là một mảng be nhạt thì vừa không nổi bật vừa
    // góp thêm vào cái "nhiều màu nâu" Tony thấy. Đúng khuôn đã ghi ở
    // `palette.dart`: nền rực + chữ tối (#06202E trên #F4700A, 5.72:1).
    // Cam giờ chỉ xuất hiện ở những mảng NHỎ và ĐẬM như thế này.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: colors.canvas,
      surfaceTintColor: Colors.transparent,
      // Viên chỉ báo tab cũng chuyển sang cam đậm — cùng lý do FAB.
      indicatorColor: colorScheme.primary,
    ),
    extensions: [colors, typography, shadows],
  );
}

final ThemeData lightTheme = _build(Brightness.light);
final ThemeData darkTheme = _build(Brightness.dark);

/// Bản public của [_build] — dùng ở runtime khi theme phụ thuộc lựa chọn
/// của Tony (toggle AMOLED ở Settings, dynamic color ở Settings từ Phase
/// 17), khác với hai hằng số tĩnh ở trên chỉ đủ cho golden test/màn hình
/// không cần AMOLED/dynamic color.
ThemeData appTheme(
  Brightness brightness, {
  bool amoled = false,
  ColorScheme? dynamicScheme,
}) {
  return _build(brightness, amoled: amoled, dynamicScheme: dynamicScheme);
}
