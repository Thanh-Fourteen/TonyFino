// Màn Ghi chú: tạo, sửa, ghim, xoá — qua cây sản xuất thật.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/notes/notes_screen.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  testWidgets('tạo ghi chú mới rồi thấy nó trong danh sách', (tester) async {
    await pumpApp(tester, db: db, child: const NotesScreen());
    await tester.pumpAndSettle();
    expect(find.text('Chưa có ghi chú nào'), findsOneWidget);

    await tester.tap(find.text('Ghi chú mới'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Cần mua');
    await tester.enterText(find.byType(TextField).last, 'sữa\nbánh mì');
    await tester.tap(find.byTooltip('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Cần mua'), findsOneWidget);
    expect(find.text('sữa · bánh mì'), findsOneWidget);
  });

  testWidgets('ghim đẩy ghi chú lên đầu', (tester) async {
    await pumpApp(tester, db: db, child: const NotesScreen());
    await tester.pumpAndSettle();
    for (final title in ['Cũ', 'Mới']) {
      await tester.tap(find.text('Ghi chú mới'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, title);
      await tester.tap(find.byTooltip('Lưu'));
      await tester.pumpAndSettle();
    }
    Offset yOf(String title) => tester.getCenter(find.text(title));
    expect(yOf('Mới').dy < yOf('Cũ').dy, isTrue);

    await tester.tap(find.byTooltip('Ghim lên đầu').last);
    await tester.pumpAndSettle();
    expect(yOf('Cũ').dy < yOf('Mới').dy, isTrue, reason: 'ghim phải lên đầu');
  });

  testWidgets('sửa nội dung và xoá', (tester) async {
    await pumpApp(tester, db: db, child: const NotesScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ghi chú mới'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Nháp');
    await tester.tap(find.byTooltip('Lưu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nháp'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Đã sửa');
    await tester.tap(find.byTooltip('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Đã sửa'), findsOneWidget);

    await tester.tap(find.text('Đã sửa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Xoá ghi chú'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Xoá'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có ghi chú nào'), findsOneWidget);
  });

  testWidgets('thoát ra khi chưa lưu thì hỏi trước khi bỏ', (tester) async {
    await pumpApp(tester, db: db, child: const NotesScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ghi chú mới'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Đang gõ dở');

    // Locale 'vi': tooltip nút back không phải "Back" tiếng Anh nên không
    // dùng được `tester.pageBack()` — bấm thẳng widget `BackButton`.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi?'), findsOneWidget);

    // "Tiếp tục sửa": vẫn ở màn soạn, chữ đã gõ còn nguyên.
    await tester.tap(find.widgetWithText(TextButton, 'Tiếp tục sửa'));
    await tester.pumpAndSettle();
    expect(find.text('Đang gõ dở'), findsOneWidget);

    // "Bỏ thay đổi": thoát hẳn, không tạo ghi chú rác.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có ghi chú nào'), findsOneWidget);
  });
}
