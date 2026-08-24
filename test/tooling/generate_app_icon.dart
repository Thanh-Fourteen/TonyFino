// Công cụ render app icon THẬT (không phải test hồi quy) — sinh 3 lớp
// (nền gradient, foreground mascot "sổ cái" nổi khối, mặt nạ đơn sắc cho
// themed icon Android 13+) ở độ phân giải gốc 1024×1024 rồi ghi PNG ra đĩa
// bằng đúng `_MascotPainter`'s ngôn ngữ hình học (`lib/ui/mascot/app_mascot.dart`)
// — tái dùng ẩn dụ "cuốn sổ cái mỉm cười" đã có sẵn trong app (màn chào
// mừng/empty state), không phát minh biểu tượng mới. Chạy qua `flutter test`
// (không phải `dart run`) vì `dart:ui`'s `Canvas`/`toImage` cần engine Skia
// thật, chỉ có trong tiến trình test của Flutter. Giữ file này trong
// `test/tooling/` (không phải `test/` bình thường) để không lẫn với bộ test
// hồi quy — chạy lại bất cứ khi nào cần đổi icon, không phải chạy một lần
// rồi xoá.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _kSize = 1024.0;

// Đúng palette thương hiệu — kéo thẳng từ `lib/theme/tokens/palette.dart`,
// không bịa màu mới. Thương hiệu là CAM GẠCH (terracotta), không còn tím.
const _brick = Color(0xFFF4700A); // paletteBrickLight — primary
/// Gáy sổ — XANH PETROL, không còn nâu.
///
/// Trước là #8A3200 (nâu gạch nung). Tony yêu cầu bỏ nâu ở mọi chỗ "kể cả ở
/// avt app". Dùng đúng #0F6C87 — màu nhấn thật của app — nên icon mang đúng
/// hai màu thương hiệu: cam ở nền, petrol ở chi tiết.
const _brickDeep = Color(0xFF0F6C87); // paletteBrickTextLight
const _brickDust = Color(0xFFFFA24D); // paletteBrickDust
const _ink = Color(0xFF16161A); // paletteInkLight — onSurface

Future<void> _capture(
  WidgetTester tester,
  Widget child,
  String path, {
  Color? background,
}) async {
  // Surface test mặc định là 800×600 — `SizedBox(1024)` bị Center bó lại vừa
  // màn hình nên `toImage()` chỉ ra 800×600 (đã thực chứng ở lần chạy trước).
  // Phải phóng view lên đúng 1024×1024 với dpr=1 thì RepaintBoundary mới đo
  // được đủ khung gốc.
  tester.view.physicalSize = const Size(_kSize, _kSize);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: background ?? Colors.transparent,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(width: _kSize, height: _kSize, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  // PHẢI bọc trong `tester.runAsync` — `toImage()`/`toByteData()` đẩy việc
  // xuống engine Skia THẬT rồi chờ callback từ vòng lặp sự kiện thật, mà
  // trong `testWidgets` thời gian bị fake-async chặn nên future không bao
  // giờ hoàn thành → treo vô hạn (đã thực chứng: chạy 10 phút, PNG 0 byte).
  // Cùng một nguyên nhân gốc với gotcha `pumpBeforeTest: precacheImages`
  // của golden test có `Image.asset` thật — mọi I/O engine thật đều cần
  // `runAsync` để thoát khỏi đồng hồ giả.
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(path);
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('✓ $path (${image.width}×${image.height})');
  });
}

/// Mascot "sổ cái mỉm cười" — bản DÀY, xếp lớp.
///
/// Đổi hình theo yêu cầu của Tony ("có chiều sâu, dễ thương xíu"). Hai thay
/// đổi làm nên chiều sâu, và đều là hình học thật chứ không phải hiệu ứng
/// dán lên:
///
/// 1. **Xếp lớp**: hai tờ giấy nhô ra sau bìa trước, mỗi tờ lệch một chút và
///    tối dần về sau. Bản cũ là MỘT khối phẳng bo góc — bóng đổ có làm nó
///    tách khỏi nền, nhưng bản thân nó vẫn mỏng dính.
/// 2. **Gáy có khối**: dải petrol không còn phẳng mà có một vệt tối phía
///    trong (chỗ giấy gập vào) và một vệt sáng ở mép ngoài.
///
/// Phần "dễ thương" nằm ở tỉ lệ: thân bo tròn hơn hẳn (bán kính 0.20 thay vì
/// 0.14), mắt to hơn và có ĐỐM SÁNG, nụ cười ngắn và cong hơn, má hồng đậm
/// hơn một chút. Mắt có đốm sáng là chi tiết rẻ nhất biến một khuôn mặt
/// "ổn" thành một khuôn mặt có hồn.
///
/// [drawFace] tắt khi vẽ silhouette đơn sắc (themed icon) — mặt nạ chỉ cần
/// đúng hình dạng, Android tự tô màu.
class _MascotGlyphPainter extends CustomPainter {
  const _MascotGlyphPainter({this.monochrome = false, this.drawShadow = true});

  final bool monochrome;
  final bool drawShadow;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = Rect.fromLTWH(
      size.width * 0.23,
      size.height * 0.17,
      size.width * 0.54,
      size.height * 0.66,
    );
    final radius = Radius.circular(size.width * 0.20);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, radius);

    if (drawShadow && !monochrome) {
      canvas.drawRRect(
        bodyRRect.shift(Offset(size.width * 0.012, size.height * 0.030)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.30)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.05),
      );
    }

    // ── Các tờ giấy phía sau ────────────────────────────────────────────
    //
    // Vẽ TRƯỚC bìa trước, lệch dần sang phải-xuống dưới. Ở bản đơn sắc thì
    // BỎ QUA hẳn: silhouette cần một khối liền, ba lớp chồng nhau tô cùng
    // một màu trắng chỉ làm mép ngoài lởm chởm.
    if (!monochrome) {
      for (final layer in const [(0.055, 0.028, 0.55), (0.028, 0.014, 0.80)]) {
        final (dx, dy, lightness) = layer;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            bodyRect.shift(Offset(size.width * dx, size.height * dy)),
            radius,
          ),
          Paint()
            ..color = Color.lerp(
              const Color(0xFFB8541C),
              const Color(0xFFFFF3EA),
              lightness,
            )!,
        );
      }
    }

    final bodyPaint = Paint();
    if (monochrome) {
      bodyPaint.color = Colors.white;
    } else {
      bodyPaint.shader = ui.Gradient.linear(
        bodyRect.topLeft,
        bodyRect.bottomRight,
        [Colors.white, const Color(0xFFFDF1EA)],
      );
    }
    canvas.drawRRect(bodyRRect, bodyPaint);

    // ── Gáy sổ có khối ──────────────────────────────────────────────────
    final spineWidth = size.width * 0.115;
    final spineRect = Rect.fromLTWH(
      bodyRect.left,
      bodyRect.top,
      spineWidth,
      bodyRect.height,
    );
    canvas.save();
    canvas.clipRRect(bodyRRect);
    canvas.drawRect(
      spineRect,
      Paint()
        ..color = monochrome ? Colors.transparent : _brickDeep
        ..blendMode = monochrome ? BlendMode.clear : BlendMode.srcOver,
    );
    if (!monochrome) {
      // Vệt tối ở mép TRONG của gáy = chỗ giấy gập vào. Không có nó thì gáy
      // chỉ là một dải màu dán lên, không ra chiều dày.
      canvas.drawRect(
        Rect.fromLTWH(
          spineRect.right - size.width * 0.022,
          spineRect.top,
          size.width * 0.022,
          spineRect.height,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.22),
      );
      // Vệt sáng mép NGOÀI — ánh sáng liếm vào cạnh.
      canvas.drawRect(
        Rect.fromLTWH(
          spineRect.left,
          spineRect.top,
          size.width * 0.014,
          spineRect.height,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.20),
      );
    }
    canvas.restore();

    if (!monochrome) {
      // Viền sáng mép trên — PHẢI clip vào thân sổ, nếu không nét sáng chạy
      // thẳng qua góc bo và thò hẳn ra ngoài thành một vạch trắng lơ lửng.
      canvas.save();
      canvas.clipRRect(bodyRRect);
      canvas.drawPath(
        Path()
          ..moveTo(
            bodyRect.left + size.width * 0.17,
            bodyRect.top + size.height * 0.020,
          )
          ..lineTo(
            bodyRect.right - size.width * 0.07,
            bodyRect.top + size.height * 0.020,
          ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = size.width * 0.012
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      canvas.restore();
    }

    // ── Mặt ─────────────────────────────────────────────────────────────
    final faceCenter = Offset(
      bodyRect.left + bodyRect.width * 0.62,
      bodyRect.top + bodyRect.height * 0.45,
    );
    final eyeRadius = size.width * 0.050;
    final eyeOffsetX = size.width * 0.095;
    // Ở bản đơn sắc mắt/miệng phải KHOÉT THỦNG thân (BlendMode.clear) chứ
    // không tô trắng — tô trắng lên thân trắng thì mặt biến mất hoàn toàn.
    final eyePaint = monochrome
        ? (Paint()
            ..color = Colors.black
            ..blendMode = BlendMode.clear)
        : (Paint()..color = _ink);
    for (final dx in [-eyeOffsetX, eyeOffsetX]) {
      final eye = faceCenter + Offset(dx, 0);
      canvas.drawCircle(eye, eyeRadius, eyePaint);
      // Đốm sáng trong mắt — chỉ ở bản màu. Lệch lên trên-trái theo cùng
      // hướng nguồn sáng của cả icon.
      if (!monochrome) {
        canvas.drawCircle(
          eye + Offset(-eyeRadius * 0.32, -eyeRadius * 0.34),
          eyeRadius * 0.34,
          Paint()..color = Colors.white.withValues(alpha: 0.92),
        );
      }
    }

    final smileRect = Rect.fromCenter(
      center: faceCenter + Offset(0, size.height * 0.028),
      width: size.width * 0.21,
      height: size.height * 0.15,
    );
    canvas.drawPath(
      Path()..addArc(smileRect, 0.18 * 3.14159, 0.64 * 3.14159),
      Paint()
        ..color = monochrome ? Colors.black : _ink
        ..blendMode = monochrome ? BlendMode.clear : BlendMode.srcOver
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.034
        ..strokeCap = StrokeCap.round,
    );

    // Hai đốm má hồng — thứ duy nhất biến một khuôn mặt "ổn" thành khuôn mặt
    // VUI. Vẫn nhạt để ở 48dp nó chỉ còn là chút ấm, không thành hai chấm lạ.
    if (!monochrome) {
      final cheekPaint = Paint()
        ..color = const Color(0xFFFF7A4D).withValues(alpha: 0.60);
      // DƯỚI mắt và RA NGOÀI: đặt ngang mắt thì hai đốm hồng đè lên tròng
      // mắt, nhìn như lỗi vẽ chứ không ra má.
      final cheekY = faceCenter.dy + size.height * 0.058;
      final cheekDx = size.width * 0.150;
      for (final dx in [-cheekDx, cheekDx]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(faceCenter.dx + dx, cheekY),
            width: size.width * 0.078,
            height: size.height * 0.046,
          ),
          cheekPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MascotGlyphPainter oldDelegate) => false;
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brickDust, _brick, Color(0xFFD44E00)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      // Quầng sáng mềm sau lưng mascot — thêm chiều sâu, không phải phẳng
      // một màu.
      child: Center(
        child: Container(
          width: _kSize * 0.72,
          height: _kSize * 0.72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('render app icon layers', (tester) async {
    // 1) LEGACY (pre-Android-8) — nền gradient + mascot hợp nhất MỘT ảnh,
    // đầy khung vuông (launcher tự bo góc theo mask riêng của nó).
    await _capture(
      tester,
      Stack(
        children: [
          const Positioned.fill(child: _GradientBackground()),
          Center(
            child: SizedBox(
              width: _kSize * 0.82,
              height: _kSize * 0.82,
              child: const CustomPaint(painter: _MascotGlyphPainter()),
            ),
          ),
        ],
      ),
      'build/icon_master/legacy_1024.png',
    );

    // 2) ADAPTIVE FOREGROUND (Android 8+) — chỉ mascot, nền TRONG SUỐT, thu
    // nhỏ về đúng vùng an toàn (~66% khung 108dp) để không bị cắt khi
    // launcher mask thành tròn/vuông tròn/giọt nước.
    await _capture(
      tester,
      Center(
        child: SizedBox(
          width: _kSize * 0.62,
          height: _kSize * 0.62,
          child: const CustomPaint(painter: _MascotGlyphPainter()),
        ),
      ),
      'build/icon_master/foreground_1024.png',
    );

    // 3) ADAPTIVE BACKGROUND — gradient đầy khung, không mascot (layer nền
    // riêng theo đúng cơ chế adaptive icon 2 lớp của Android).
    await _capture(
      tester,
      const _GradientBackground(),
      'build/icon_master/background_1024.png',
    );

    // 4) MONOCHROME (Android 13+ themed icon) — silhouette trắng-trên-trong
    // suốt, Android tự tô theo màu hệ thống lúc chạy.
    await _capture(
      tester,
      Center(
        child: SizedBox(
          width: _kSize * 0.62,
          height: _kSize * 0.62,
          child: const CustomPaint(
            painter: _MascotGlyphPainter(monochrome: true, drawShadow: false),
          ),
        ),
      ),
      'build/icon_master/monochrome_1024.png',
    );
  });
}
