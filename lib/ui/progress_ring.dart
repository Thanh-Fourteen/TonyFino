import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vòng tiến độ dùng chung — `CustomPainter` tự viết (không `percent_indicator`,
/// TODOS.md § Package UI): đầu nét bo tròn, gradient quét, và một vạch nhịp
/// TUỲ CHỌN (chỉ vẽ nếu [paceFraction] khác `null`). Tách ra từ `BudgetRing`
/// (Phase 11) ở Phase 16 để `SavingsGoalRing`/`DebtRing` dùng CHUNG hình học
/// này mà không lặp code `CustomPainter` — chỉ khác nhau ở MÀU và ở việc có
/// vạch nhịp hay không, hai thứ widget này KHÔNG tự quyết định (nhận sẵn từ
/// call site, xem docs/decisions.md § Phase 16 "Vòng tiến độ tái dùng hình
/// học"). Widget này không biết gì về `Budget`/`SavingsGoal`/`Debt`.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    this.paceFraction,
    this.paceMarkColor,
    this.size = 96,
    this.strokeWidth = 10,
    this.child,
  }) : assert(
         (paceFraction == null) == (paceMarkColor == null),
         'paceFraction và paceMarkColor phải cùng null hoặc cùng có giá trị.',
       );

  /// 0.0–1.0 (đã kẹp ở call site nếu cần) — phần cung được tô.
  final double progress;
  final Color ringColor;
  final Color trackColor;

  /// Vị trí vạch nhịp trên vòng, 0.0–1.0 — `null` = KHÔNG vẽ vạch (mục
  /// tiêu/nợ không có khái niệm "nhịp thời gian trong kỳ").
  final double? paceFraction;
  final Color? paceMarkColor;

  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ProgressRingPainter(
          progress: progress.clamp(0.0, 1.0),
          trackColor: trackColor,
          ringColor: ringColor,
          paceFraction: paceFraction?.clamp(0.0, 1.0),
          paceMarkColor: paceMarkColor,
          strokeWidth: strokeWidth,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.ringColor,
    required this.strokeWidth,
    this.paceFraction,
    this.paceMarkColor,
  });

  final double progress;
  final double? paceFraction;
  final Color trackColor;
  final Color ringColor;
  final Color? paceMarkColor;
  final double strokeWidth;

  static const _startAngle = -math.pi / 2; // 12 giờ

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    if (progress > 0) {
      final sweep = 2 * math.pi * progress;
      final gradient = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        transform: GradientRotation(_startAngle),
        colors: [ringColor.withValues(alpha: 0.55), ringColor],
        stops: const [0, 1],
      );
      final ringPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, _startAngle, sweep, false, ringPaint);
    }

    final pace = paceFraction;
    final paceColor = paceMarkColor;
    if (pace != null && paceColor != null) {
      // Vạch nhịp — vẽ SAU cung tiến độ để luôn nổi rõ trên cả track lẫn
      // phần đã tô, dày hơn hẳn track để không bị nhầm với hairline trang trí.
      final paceAngle = _startAngle + 2 * math.pi * pace;
      final tickPaint = Paint()
        ..color = paceColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final inner =
          center +
          Offset(math.cos(paceAngle), math.sin(paceAngle)) *
              (radius - strokeWidth / 2 - 3);
      final outer =
          center +
          Offset(math.cos(paceAngle), math.sin(paceAngle)) *
              (radius + strokeWidth / 2 + 3);
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.paceFraction != paceFraction ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.paceMarkColor != paceMarkColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
