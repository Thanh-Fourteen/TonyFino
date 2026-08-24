import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shadows.dart';
import 'app_typography.dart';
import 'tokens/curves.dart';
import 'tokens/durations.dart';
import 'tokens/radii.dart';
import 'tokens/spacing.dart';

/// Điểm truy cập token DUY NHẤT cho màn hình — `context.colors.incomeText`,
/// KHÔNG BAO GIỜ `Theme.of(context).extension<AppColors>()!` rải rác khắp nơi.
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  AppTypography get money => Theme.of(this).extension<AppTypography>()!;
  AppShadows get shadows => Theme.of(this).extension<AppShadows>()!;

  /// Style chữ thường (display/title/body/label) — sống trong `TextTheme`
  /// chuẩn, không phải `ThemeExtension` (xem `app_typography.dart`).
  TextTheme get text => Theme.of(this).textTheme;

  ColorScheme get scheme => Theme.of(this).colorScheme;

  AppSpacing get space => appSpacing;
  AppRadii get radii => appRadii;
  AppDurations get durations => appDurations;
  AppCurves get curves => appCurves;
}
