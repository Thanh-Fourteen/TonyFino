// `Curve`/`Curves` sống ở `package:flutter/animation.dart` — thư viện lõi
// framework, KHÔNG phải Material (khác hẳn `src/material/curves.dart`, nơi
// định nghĩa easing riêng của M3 mà file này TUYỆT ĐỐI không được chạm).
// Sống sót qua migration `material_ui` giống `painting.dart` (Luật #10).
import 'package:flutter/animation.dart' show Curve, Curves;

/// Đường cong dùng trong 5 animation ngân sách của design system.
class AppCurves {
  const AppCurves();

  final Curve countUp = Curves.easeOutExpo; // #1
  final Curve chartDraw = Curves.easeOutCubic; // #2
  final Curve listStagger = Curves.easeOutCubic; // #3 (fade + slideY)
  final Curve sheet = Curves.easeOutCubic; // #4
  final Curve confirmPulse = Curves.easeOutBack; // #5 — scale 0.85→1.04→1.0
  final Curve themeSwitch = Curves.easeOutCubic;

  /// Pill nav biến hình — "motion đàn hồi nhẹ, overshoot 1.02–1.04" (TODOS.md
  /// § Package UI), cùng họ overshoot với `confirmPulse`.
  final Curve navMorph = Curves.easeOutBack;
}

const appCurves = AppCurves();
