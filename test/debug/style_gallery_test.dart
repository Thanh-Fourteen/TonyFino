// Smoke test — Style Gallery phải dựng được không lỗi và đổi được
// light/dark, vì đây là công cụ soi mắt chính của Phase 5.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/debug/style_gallery.dart';

void main() {
  testWidgets('StyleGalleryScreen dựng không lỗi và đổi được brightness', (
    tester,
  ) async {
    // Nội dung dài hơn viewport test mặc định (800×600) — phóng to khung test
    // thay vì cuộn, để chạm được mọi widget bằng offset thật, không cận biên.
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: StyleGalleryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Style Gallery'), findsOneWidget);
    expect(find.text('Brightness: light'), findsOneWidget);

    await tester.tap(find.text('Đổi light ↔ dark'));
    await tester.pumpAndSettle();

    expect(find.text('Brightness: dark'), findsOneWidget);

    // Chạm nút "Tăng số" phải không ném lỗi — kích hoạt CountUpText animate.
    await tester.tap(find.text('Tăng số'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  });
}
