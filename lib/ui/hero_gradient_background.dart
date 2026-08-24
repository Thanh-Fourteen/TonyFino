import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Nền gradient động NHẸ — CHỈ dùng sau hero card màn Giao dịch (Phase 22,
/// Hướng 1 "phong phú có giới hạn"). Tự viết bằng `CustomPainter` (không
/// thêm phụ thuộc `mesh_gradient`/`flutter_shaders` — vài khối màu mềm đủ
/// đạt hiệu ứng, giữ đúng D9 "tự viết, không lối tắt" và tránh thêm một
/// dependency graph mới cho một hiệu ứng nhỏ).
///
/// 🚨 TUYỆT ĐỐI không đặt widget này ở nơi nào bị cuộn qua lại (danh sách
/// giao dịch, v.v.) — animation này chạy liên tục (`repeat`), đúng bài học
/// hồi quy GPU `BackdropFilter`/Impeller đã ghi trong `docs/design-research-2.md`.
/// Widget hero card chỉ dựng MỘT lần, không nằm trong vùng cuộn của
/// `SliverList` danh sách giao dịch — xem `docs/decisions.md` § Phase 22 và
/// số đo hiệu năng cuộn trong `TODOS.md` § Phase 22 "Kết quả".
class HeroGradientBackground extends StatefulWidget {
  const HeroGradientBackground({super.key, required this.colors});

  /// 2-3 màu mềm (đã lấy `withValues(alpha:)` thấp từ call site) — không
  /// hardcode màu mới ở đây, luôn nhận từ `context.colors`/`context.scheme`.
  final List<Color> colors;

  @override
  State<HeroGradientBackground> createState() => _HeroGradientBackgroundState();
}

class _HeroGradientBackgroundState extends State<HeroGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Chậm, có chủ đích — hiệu ứng "trôi" gần như không nhận ra đang chuyển
    // động khi nhìn thoáng qua, đúng tinh thần "không gì chuyển động trừ khi
    // mang nghĩa" của design system, chỉ khác đây là nền trang trí có giới
    // hạn phạm vi rõ ràng (hero card), không phải một con số.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Cùng lý do như `AppMascot` — không `repeat()` vô hạn khi cờ trợ năng
    // "giảm chuyển động" bật (widget test toàn dự án bật cờ này, xem
    // test/flutter_test_config.dart), tránh treo `pumpAndSettle()`.
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _MeshBlobPainter(
            t: _controller.value,
            colors: widget.colors,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _MeshBlobPainter extends CustomPainter {
  _MeshBlobPainter({required this.t, required this.colors});

  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final blobs = [
      (dx: 0.15, dy: 0.25, r: 0.55, speed: 1.0, color: colors[0]),
      (
        dx: 0.85,
        dy: 0.15,
        r: 0.45,
        speed: -0.7,
        color: colors[1 % colors.length],
      ),
      (
        dx: 0.75,
        dy: 0.85,
        r: 0.50,
        speed: 0.5,
        color: colors[2 % colors.length],
      ),
    ];
    for (final blob in blobs) {
      final angle = t * 2 * math.pi * blob.speed;
      final cx = (blob.dx + 0.06 * math.cos(angle)) * size.width;
      final cy = (blob.dy + 0.06 * math.sin(angle)) * size.height;
      final radius = blob.r * math.max(size.width, size.height) * 0.5;
      final paint = Paint()
        ..color = blob.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.45);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshBlobPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.colors != colors;
}
