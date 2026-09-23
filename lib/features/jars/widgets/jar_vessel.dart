import 'package:flutter/material.dart';

import '../../../data/repositories/jar_repository.dart'
    show JarKind, JarProgress;
import '../../../theme/context_ext.dart';
import '../jars_screen.dart' show jarProgressColor;

/// Hũ vẽ thành hũ THẬT — nghiên cứu 2026-09-23 mục 27
/// (`docs/competitor-feature-research.md` § Bổ sung), thay vì chỉ đọc số
/// trên [JarProgressBar]. Mực "nước" dâng theo đúng `progress.ratio` (kẹp
/// 0-1, giống hệt luật của thanh tiến độ), màu lấy qua [jarProgressColor] —
/// KHÔNG tự vẽ luật màu riêng, tránh lệch với thanh tiến độ đang dùng ở nơi
/// khác cho CÙNG một hũ.
///
/// 🚨 CỐ Ý không có animation LẶP VÔ HẠN (vd sóng sánh liên tục kiểu
/// `AppMascot._idleController.repeat()`) — `TweenAnimationBuilder` bên dưới
/// chỉ chạy MỘT LẦN mỗi khi `progress.ratio` đổi rồi TỰ DỪNG. Một controller
/// lặp mãi sẽ khiến `tester.pumpAndSettle()` treo vô thời hạn ở MỌI test
/// dựng `JarDetailScreen` (xác nhận bằng thực nghiệm: bản đầu tiên có
/// `AnimationController..repeat()` cho sóng làm 3 ca trong
/// `jar_detail_screen_test.dart` timeout) — mặt nước cong tĩnh vẫn đủ gợi
/// "chất lỏng", không cần động liên tục.
///
/// Chỉ dùng ở `JarDetailScreen` (một hũ, đủ chỗ cho hình lớn) — KHÔNG thay
/// [JarProgressBar] ở danh sách/Trang chủ, nơi mỗi hàng chỉ cao 4-8px,
/// không đủ chỗ cho một hình vuông đứng.
class JarVessel extends StatelessWidget {
  const JarVessel({super.key, required this.progress, this.height = 140});

  final JarProgress progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = jarProgressColor(context, progress);
    final targetRatio = progress.ratio.clamp(0.0, 1.0);
    final width = height * 0.78;
    final outlineColor = context.colors.onSurfaceVariant;
    final isSaving = progress.kind == JarKind.saving;

    return SizedBox(
      width: width,
      height: height,
      child: TweenAnimationBuilder<double>(
        // Mực nước DÂNG khi ratio đổi (vd vừa ghi thêm một khoản) — chạy
        // MỘT LẦN rồi dừng, xem lý do ở doc comment của lớp.
        tween: Tween(begin: 0, end: targetRatio),
        duration: context.durations.countUp,
        curve: context.curves.countUp,
        builder: (context, fillT, _) {
          return CustomPaint(
            size: Size(width, height),
            painter: _JarVesselPainter(
              fillT: fillT,
              liquidColor: color,
              outlineColor: outlineColor,
              isSaving: isSaving,
            ),
          );
        },
      ),
    );
  }
}

class _JarVesselPainter extends CustomPainter {
  _JarVesselPainter({
    required this.fillT,
    required this.liquidColor,
    required this.outlineColor,
    required this.isSaving,
  });

  /// 0-1, đã kẹp — % chiều cao thân hũ mực nước dâng tới.
  final double fillT;
  final Color liquidColor;
  final Color outlineColor;

  /// Hũ tiết kiệm: nắp có một vạch nhỏ gợi "đồng xu bỏ vào" thay vì để trơn
  /// — khác biệt nhỏ, không thêm hình mới, chỉ đổi một chi tiết trên nắp.
  final bool isSaving;

  @override
  void paint(Canvas canvas, Size size) {
    final neckHeight = size.height * 0.14;
    final neckWidth = size.width * 0.5;
    final bodyRect = Rect.fromLTWH(
      0,
      neckHeight,
      size.width,
      size.height - neckHeight,
    );
    final bodyRadius = Radius.circular(size.width * 0.16);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, bodyRadius);

    // Nắp/cổ hũ — hình chữ nhật bo góc trên, căn giữa phía trên thân.
    final neckRect = Rect.fromLTWH(
      (size.width - neckWidth) / 2,
      0,
      neckWidth,
      neckHeight + 4, // +4: lấn nhẹ xuống thân, tránh khe hở khi bo góc.
    );
    final neckRRect = RRect.fromRectAndCorners(
      neckRect,
      topLeft: Radius.circular(size.width * 0.06),
      topRight: Radius.circular(size.width * 0.06),
    );

    // Chất lỏng — clip theo đúng thân hũ. Mặt trên là một đường cong TĨNH
    // (không animate theo thời gian, chỉ theo fillT) — đủ gợi "mặt nước"
    // mà không cần controller lặp vô hạn (xem doc comment của widget).
    canvas.save();
    canvas.clipRRect(bodyRRect);
    final liquidTop = bodyRect.bottom - (bodyRect.height * fillT);
    final curveDepth = fillT > 0.02 && fillT < 0.98
        ? size.height * 0.02
        : 0.0;
    final liquidPath = Path()
      ..moveTo(bodyRect.left, bodyRect.bottom + 1)
      ..lineTo(bodyRect.left, liquidTop)
      ..quadraticBezierTo(
        size.width / 2,
        liquidTop - curveDepth,
        bodyRect.right,
        liquidTop,
      )
      ..lineTo(bodyRect.right, bodyRect.bottom + 1)
      ..close();
    canvas.drawPath(liquidPath, Paint()..color = liquidColor.withValues(alpha: 0.85));
    canvas.restore();

    // Viền hũ (thân + cổ) — vẽ SAU chất lỏng để đường viền luôn rõ, không
    // bị mực nước che mất.
    final outlinePaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02;
    canvas.drawRRect(bodyRRect, outlinePaint);
    canvas.drawRRect(neckRRect, outlinePaint);

    if (isSaving) {
      // Vạch nắp — gợi khe bỏ tiền, một đường ngắn giữa nắp.
      canvas.drawLine(
        Offset(size.width / 2 - neckWidth * 0.2, neckHeight * 0.5),
        Offset(size.width / 2 + neckWidth * 0.2, neckHeight * 0.5),
        outlinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _JarVesselPainter oldDelegate) =>
      oldDelegate.fillT != fillT ||
      oldDelegate.liquidColor != liquidColor ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.isSaving != isSaving;
}
