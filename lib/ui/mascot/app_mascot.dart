import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/context_ext.dart';
import 'mascot_mood.dart';

/// Nhân vật vẽ tay bằng `CustomPainter`/`AnimationController` THUẦN Flutter —
/// KHÔNG dùng package `rive` như nghiên cứu Phase 22 ban đầu đề xuất. Lý do
/// đầy đủ (Rive Editor là công cụ đồ hoạ tương tác, không viết được bằng
/// code; asset cộng đồng có sẵn vi phạm D9) ở `docs/decisions.md` § Phase
/// 22. Hình dáng: một cuốn sổ nhỏ bo góc (khớp ẩn dụ "cuốn sổ cái" xuyên
/// suốt app) với hai mắt + một miệng, phản ứng theo [MascotMood] — chỉ dùng
/// màu từ `context.scheme`/`context.colors`, không thêm màu mới nào.
class AppMascot extends StatefulWidget {
  const AppMascot({
    super.key,
    required this.mood,
    this.size = 96,
    this.festive = false,
  });

  final MascotMood mood;
  final double size;

  /// "Áo Tết" (nghiên cứu 2026-09-23 mục 29) — `true` trong khoảng
  /// `isTetSeason()` (`features/home/domain/tet_season.dart`), gắn thêm một
  /// hoa mai nhỏ ở góc trên-phải, CHỈ dùng hai màu thương hiệu đã có (cam +
  /// petrol) — không thêm màu đỏ/vàng mới, giữ đúng nguyên tắc "cam + petrol,
  /// không nâu không tím" đã chốt nhiều lần. Mặc định `false` — mọi call
  /// site không truyền tham số này giữ nguyên pixel-identical (cùng khuôn
  /// mẫu với `CategoryAvatar.emoji`, D10).
  final bool festive;

  @override
  State<AppMascot> createState() => _AppMascotState();
}

class _AppMascotState extends State<AppMascot> with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _blinkController;
  late final AnimationController _popController;
  Timer? _blinkTimer;
  bool _ambientStarted = false;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.mood == MascotMood.celebrate) _popController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ambientStarted) return;
    _ambientStarted = true;
    // 🚨 `MediaQuery.disableAnimationsOf` (cờ trợ năng "giảm chuyển động",
    // widget test toàn dự án bật SẴN qua `test/flutter_test_config.dart`) —
    // KHÔNG BAO GIỜ lặp animation vô hạn (`repeat()`) mà không kiểm tra cờ
    // này trước: `pumpAndSettle()` (dùng ở HẦU HẾT test màn hình) đợi animation
    // dừng hẳn, một `AnimationController` lặp vô hạn khiến nó treo timeout —
    // đã tự bắt được lỗi này khi thêm mascot/nền động, xem
    // docs/decisions.md § Phase 22 và project_tonyfino_gotchas.
    if (MediaQuery.disableAnimationsOf(context)) return;
    _idleController.repeat(reverse: true);
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(
      Duration(milliseconds: 2200 + math.Random().nextInt(2200)),
      () async {
        if (!mounted) return;
        await _blinkController.forward();
        if (!mounted) return;
        await _blinkController.reverse();
        if (!mounted) return;
        _scheduleBlink();
      },
    );
  }

  @override
  void didUpdateWidget(covariant AppMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != MascotMood.celebrate &&
        widget.mood == MascotMood.celebrate) {
      _popController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idleController.dispose();
    _blinkController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = context.colors.incomeContainer; // kem cam nhạt
    // Gáy sổ dùng PETROL, đúng như app icon (`test/tooling/generate_app_icon`).
    // Trước đây là `scheme.primary` (cam) nên linh vật trong app và icon
    // ngoài launcher là hai con khác nhau — cùng hình mà khác màu chi tiết.
    final accentColor = context.colors.brandText;
    final faceColor = context.colors.onSurface;
    final festiveColor = context.scheme.primary; // cam — hoa mai "áo Tết"
    // 🚨 TOÀN BỘ nội dung (kể cả overlay icon streak/celebrate bên dưới)
    // PHẢI nằm trong CÙNG MỘT `AnimatedBuilder` này — từng thử tách
    // `CustomPaint` ra một `AnimatedBuilder` con riêng trong khi overlay đọc
    // thẳng `_popController.value` ở `build()` ngoài: overlay chỉ thấy giá
    // trị TẠI THỜI ĐIỂM `build()` chạy lần đầu (0), không bao giờ cập nhật
    // theo animation vì không có gì gọi lại `setState`/rebuild widget NGOÀI
    // khi controller tick — bắt được qua golden test (trophy/pháo giấy
    // không bao giờ hiện), xem docs/decisions.md § Phase 22.
    return AnimatedBuilder(
      animation: Listenable.merge([
        _idleController,
        _blinkController,
        _popController,
      ]),
      builder: (context, _) {
        final mascot = CustomPaint(
          size: Size.square(widget.size),
          painter: _MascotPainter(
            mood: widget.mood,
            idleT: _idleController.value,
            blinkT: _blinkController.value,
            popT: _popController.value,
            bodyColor: bodyColor,
            accentColor: accentColor,
            faceColor: faceColor,
            festive: widget.festive,
            festiveColor: festiveColor,
          ),
        );

        if (widget.mood == MascotMood.idle) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: mascot,
          );
        }

        // streak/celebrate: overlay icon 3D chọn lọc (MIT, xem
        // assets/icons3d/NOTICE.md) — KHÔNG BAO GIỜ trong danh sách/form,
        // chỉ ở đây (empty state/celebration).
        return SizedBox(
          width: widget.size,
          height: widget.size * 1.15,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 0,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: mascot,
                ),
              ),
              // Opacity/Transform.scale THẲNG (không phải AnimatedOpacity/
              // AnimatedScale) — giá trị đã được `AnimatedBuilder` ngoài
              // đẩy sống theo từng tick rồi, bọc thêm một lớp animation ngầm
              // (dù `duration: Duration.zero`) chỉ tạo ra một tầng
              // interpolation THỨ HAI không cần thiết và từng khiến overlay
              // không bao giờ thực sự hiện (xem docs/decisions.md § Phase 22).
              if (widget.mood == MascotMood.streak)
                Positioned(
                  top: 0,
                  right: widget.size * 0.02,
                  child: Transform.scale(
                    scale: 0.85 + 0.15 * _popPulse(_idleController.value),
                    child: Image.asset(
                      'assets/icons3d/fire_3d.png',
                      width: widget.size * 0.34,
                      height: widget.size * 0.34,
                    ),
                  ),
                ),
              if (widget.mood == MascotMood.celebrate) ...[
                Positioned(
                  top: 0,
                  child: Transform.scale(
                    scale: Curves.easeOutBack.transform(_popController.value),
                    child: Image.asset(
                      'assets/icons3d/trophy_3d.png',
                      width: widget.size * 0.4,
                      height: widget.size * 0.4,
                    ),
                  ),
                ),
                Positioned(
                  bottom: widget.size * 0.55,
                  left: -widget.size * 0.08,
                  child: Opacity(
                    opacity: _popController.value,
                    child: Image.asset(
                      'assets/icons3d/party_popper_3d.png',
                      width: widget.size * 0.3,
                    ),
                  ),
                ),
                Positioned(
                  bottom: widget.size * 0.55,
                  right: -widget.size * 0.08,
                  child: Opacity(
                    opacity: _popController.value,
                    child: Transform.flip(
                      flipX: true,
                      child: Image.asset(
                        'assets/icons3d/party_popper_3d.png',
                        width: widget.size * 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  double _popPulse(double t) => (math.sin(t * math.pi * 2) + 1) / 2;
}

class _MascotPainter extends CustomPainter {
  _MascotPainter({
    required this.mood,
    required this.idleT,
    required this.blinkT,
    required this.popT,
    required this.bodyColor,
    required this.accentColor,
    required this.faceColor,
    this.festive = false,
    this.festiveColor,
  });

  final MascotMood mood;
  final double idleT; // 0..1..0, thở nhẹ
  final double blinkT; // 0..1, chớp mắt
  final double popT; // 0..1, "pop" khi celebrate
  final Color bodyColor;
  final Color accentColor;
  final Color faceColor;

  /// "Áo Tết" — xem doc comment `AppMascot.festive`.
  final bool festive;
  final Color? festiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bob = math.sin(idleT * math.pi) * size.height * 0.02;
    final popScale = mood == MascotMood.celebrate
        ? 1 + (Curves.easeOutBack.transform(popT) - 1) * 0.12
        : 1.0;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + bob);
    canvas.scale(popScale);
    canvas.translate(-size.width / 2, -size.height / 2);

    // Thân — hình cuốn sổ bo góc, khớp ẩn dụ "sổ cái" của app.
    final bodyRect = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.10,
      size.width * 0.76,
      size.height * 0.80,
    );
    final bodyRRect = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(size.width * 0.22),
    );
    canvas.drawRRect(bodyRRect, Paint()..color = bodyColor);

    // "Gáy sổ" — dải nhấn màu tím, mép trái.
    final spineRect = Rect.fromLTWH(
      bodyRect.left,
      bodyRect.top,
      size.width * 0.10,
      bodyRect.height,
    );
    canvas.save();
    canvas.clipRRect(bodyRRect);
    canvas.drawRect(
      spineRect,
      Paint()..color = accentColor.withValues(alpha: 0.85),
    );
    canvas.restore();

    // Mắt.
    final eyeY = bodyRect.top + bodyRect.height * 0.42;
    final eyeDx = bodyRect.width * 0.19;
    final eyeOpen = size.height * 0.05 * (1 - blinkT);
    for (final dir in [-1, 1]) {
      final cx = size.width / 2 + dir * eyeDx;
      final rect = Rect.fromCenter(
        center: Offset(cx, eyeY),
        width: size.width * 0.07,
        height: math.max(eyeOpen, size.height * 0.006),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.width / 2)),
        Paint()..color = faceColor,
      );
    }

    // Miệng — cười nhỏ (idle/streak) hoặc cười to (celebrate).
    final mouthY = eyeY + size.height * 0.14;
    final mouthWidth =
        size.width * (mood == MascotMood.celebrate ? 0.30 : 0.20);
    final mouthDepth =
        size.height * (mood == MascotMood.celebrate ? 0.09 : 0.05);
    final mouthPath = Path()
      ..moveTo(size.width / 2 - mouthWidth / 2, mouthY)
      ..quadraticBezierTo(
        size.width / 2,
        mouthY + mouthDepth,
        size.width / 2 + mouthWidth / 2,
        mouthY,
      );
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color = faceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.022
        ..strokeCap = StrokeCap.round,
    );

    if (festive && festiveColor != null) {
      _paintPlumBlossom(
        canvas,
        center: Offset(bodyRect.right - size.width * 0.06, bodyRect.top),
        petalRadius: size.width * 0.09,
        petalColor: festiveColor!,
        centerColor: accentColor,
      );
    }

    canvas.restore();
  }

  /// Hoa mai cách điệu: 5 cánh tròn (CAM — thương hiệu, không phải vàng
  /// thật) quanh một nhuỵ PETROL — chỉ hai màu đã có sẵn của app, không
  /// thêm sắc mới (xem doc comment `AppMascot.festive`).
  void _paintPlumBlossom(
    Canvas canvas, {
    required Offset center,
    required double petalRadius,
    required Color petalColor,
    required Color centerColor,
  }) {
    final petalPaint = Paint()..color = petalColor;
    const petalCount = 5;
    for (var i = 0; i < petalCount; i++) {
      final angle = (i / petalCount) * 2 * math.pi;
      final petalCenter =
          center + Offset(math.cos(angle), math.sin(angle)) * petalRadius;
      canvas.drawCircle(petalCenter, petalRadius * 0.62, petalPaint);
    }
    canvas.drawCircle(
      center,
      petalRadius * 0.42,
      Paint()..color = centerColor,
    );
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      oldDelegate.mood != mood ||
      oldDelegate.idleT != idleT ||
      oldDelegate.blinkT != blinkT ||
      oldDelegate.popT != popT ||
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.faceColor != faceColor ||
      oldDelegate.festive != festive ||
      oldDelegate.festiveColor != festiveColor;
}
