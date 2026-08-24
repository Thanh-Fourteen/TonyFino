import 'package:flutter/material.dart';

import 'tokens/palette.dart';

/// Mọi màu mà `ColorScheme` (M3) không mô hình hoá — thu/chi, ngân sách,
/// 12 màu danh mục, heatmap, skeleton, kính mờ — cộng thêm vài tên gọi rõ
/// nghĩa hơn cho các bề mặt trung tính hay dùng (`card`, `sheet`, `hairline`)
/// mà tên gốc `surfaceContainerLowest`/`outline` của M3 khó đọc tại call site.
///
/// Đọc qua `context.colors.X` (`context_ext.dart`), không bao giờ
/// `Theme.of(context).extension<AppColors>()!` trực tiếp ở màn hình.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.card,
    required this.surfaceContainer,
    required this.sheet,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.hairline,
    required this.incomeText,
    required this.incomeFill,
    required this.incomeContainer,
    required this.expenseText,
    required this.expenseFill,
    required this.expenseContainer,
    required this.transfer,
    required this.budgetOk,
    required this.budgetWarn,
    required this.budgetOver,
    required this.categoryFills,
    required this.chartGrid,
    required this.chartAxisLabel,
    required this.heatmapScale,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.glassTint,
    required this.brandText,
  });

  final Color canvas;
  final Color card;
  final Color surfaceContainer;
  final Color sheet;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color hairline;

  final Color incomeText;
  final Color incomeFill;
  final Color incomeContainer;
  final Color expenseText;
  final Color expenseFill;
  final Color expenseContainer;

  /// Màu trung tính cho giao dịch chuyển khoản/tiết kiệm — không phải thu,
  /// không phải chi, nên không mượn xanh/đỏ (D7/nguyên tắc màu #2).
  final Color transfer;

  final Color budgetOk;
  final Color budgetWarn;
  final Color budgetOver;

  /// 12 màu, chỉ số vào đây LÀ `categoryColorId` (D10) — không phải tên.
  final List<Color> categoryFills;

  final Color chartGrid;
  final Color chartAxisLabel;

  /// 5 bậc, nhạt → đậm.
  final List<Color> heatmapScale;

  final Color skeletonBase;
  final Color skeletonHighlight;

  /// Nền cho `GlassSurface` (nav bar + thanh nhập chat, hai chỗ duy nhất).
  final Color glassTint;

  /// Cam thương hiệu dùng làm CHỮ/ICON trên nền sáng — ĐẬM hơn
  /// `colorScheme.primary` (vốn là màu NỀN nút, tươi hơn nhiều).
  ///
  /// Dùng token này cho mọi chỗ chữ/icon màu thương hiệu đặt trên canvas
  /// hoặc card: nút văn bản, liên kết, icon điều hướng. Dùng `primary` ở đó
  /// là chữ cam nhạt trên nền trắng — chỉ 2.83:1, không đọc được.
  final Color brandText;

  static const light = AppColors(
    canvas: paletteCanvasLight,
    card: paletteCardLight,
    surfaceContainer: paletteSubtleLight,
    sheet: paletteOverlayLight,
    onSurface: paletteInkLight,
    onSurfaceVariant: paletteInkMutedLight,
    hairline: paletteHairlineLight,
    incomeText: paletteIncomeTextLight,
    incomeFill: paletteIncomeFill,
    incomeContainer: paletteBrickSoftLight,
    expenseText: paletteInkLight, // trung tính — nguyên tắc màu #2
    expenseFill: paletteRedFill,
    expenseContainer: paletteSubtleLight,
    transfer: paletteBrickLight,
    budgetOk: paletteIncomeFill,
    budgetWarn: paletteAmberFill,
    budgetOver: paletteRedFill,
    categoryFills: paletteCategoryColors,
    chartGrid: paletteHairlineLight,
    chartAxisLabel: paletteInkMutedLight,
    heatmapScale: paletteHeatmapLight,
    skeletonBase: paletteSubtleLight,
    skeletonHighlight: paletteCardLight,
    glassTint: Color(0xCCFFFFFF), // card ~80%
    brandText: paletteBrickTextLight,
  );

  static const dark = AppColors(
    canvas: paletteCanvasDark,
    card: paletteCardDark,
    surfaceContainer: paletteSubtleDark,
    sheet: paletteOverlayDark,
    onSurface: paletteInkDark,
    onSurfaceVariant: paletteInkMutedDark,
    hairline: paletteHairlineDark,
    incomeText: paletteIncomeTextDark,
    incomeFill: paletteIncomeFill,
    incomeContainer: paletteBrickSoftDark,
    expenseText: paletteInkDark, // trung tính — nguyên tắc màu #2
    expenseFill: paletteRedFill,
    expenseContainer: paletteSubtleDark,
    transfer: paletteBrickDark,
    budgetOk: paletteIncomeFill,
    budgetWarn: paletteAmberFill,
    budgetOver: paletteRedFill,
    categoryFills: paletteCategoryColors, // cố ý giống light — legend ổn định
    chartGrid: paletteHairlineDark,
    chartAxisLabel: paletteInkMutedDark,
    heatmapScale: paletteHeatmapDark,
    skeletonBase: paletteSubtleDark,
    skeletonHighlight: Color(0xFF22262C),
    glassTint: Color(0xCC14161A), // card ~80%
    brandText: paletteBrickTextDark,
  );

  @override
  AppColors copyWith({
    Color? canvas,
    Color? card,
    Color? surfaceContainer,
    Color? sheet,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? hairline,
    Color? incomeText,
    Color? incomeFill,
    Color? incomeContainer,
    Color? expenseText,
    Color? expenseFill,
    Color? expenseContainer,
    Color? transfer,
    Color? budgetOk,
    Color? budgetWarn,
    Color? budgetOver,
    List<Color>? categoryFills,
    Color? chartGrid,
    Color? chartAxisLabel,
    List<Color>? heatmapScale,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? glassTint,
    Color? brandText,
  }) {
    return AppColors(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      sheet: sheet ?? this.sheet,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      hairline: hairline ?? this.hairline,
      incomeText: incomeText ?? this.incomeText,
      incomeFill: incomeFill ?? this.incomeFill,
      incomeContainer: incomeContainer ?? this.incomeContainer,
      expenseText: expenseText ?? this.expenseText,
      expenseFill: expenseFill ?? this.expenseFill,
      expenseContainer: expenseContainer ?? this.expenseContainer,
      transfer: transfer ?? this.transfer,
      budgetOk: budgetOk ?? this.budgetOk,
      budgetWarn: budgetWarn ?? this.budgetWarn,
      budgetOver: budgetOver ?? this.budgetOver,
      categoryFills: categoryFills ?? this.categoryFills,
      chartGrid: chartGrid ?? this.chartGrid,
      chartAxisLabel: chartAxisLabel ?? this.chartAxisLabel,
      heatmapScale: heatmapScale ?? this.heatmapScale,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      glassTint: glassTint ?? this.glassTint,
      brandText: brandText ?? this.brandText,
    );
  }

  /// Nội suy THẬT (Luật #3) — không `=> other`. Theme switch animate; lerp
  /// lười khiến màu tuỳ biến giật trong khi màu Material chuyển mượt.
  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      sheet: Color.lerp(sheet, other.sheet, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      incomeText: Color.lerp(incomeText, other.incomeText, t)!,
      incomeFill: Color.lerp(incomeFill, other.incomeFill, t)!,
      incomeContainer: Color.lerp(incomeContainer, other.incomeContainer, t)!,
      expenseText: Color.lerp(expenseText, other.expenseText, t)!,
      expenseFill: Color.lerp(expenseFill, other.expenseFill, t)!,
      expenseContainer: Color.lerp(
        expenseContainer,
        other.expenseContainer,
        t,
      )!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      budgetOk: Color.lerp(budgetOk, other.budgetOk, t)!,
      budgetWarn: Color.lerp(budgetWarn, other.budgetWarn, t)!,
      budgetOver: Color.lerp(budgetOver, other.budgetOver, t)!,
      categoryFills: _lerpColorList(categoryFills, other.categoryFills, t),
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      chartAxisLabel: Color.lerp(chartAxisLabel, other.chartAxisLabel, t)!,
      heatmapScale: _lerpColorList(heatmapScale, other.heatmapScale, t),
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight: Color.lerp(
        skeletonHighlight,
        other.skeletonHighlight,
        t,
      )!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      brandText: Color.lerp(brandText, other.brandText, t)!,
    );
  }
}

List<Color> _lerpColorList(List<Color> a, List<Color> b, double t) {
  final length = a.length < b.length ? a.length : b.length;
  return [for (var i = 0; i < length; i++) Color.lerp(a[i], b[i], t)!];
}
