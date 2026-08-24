import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/tags/tags_screen.dart';
import 'package:tonyfino/theme/tokens/icons.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<void> pumpTags(WidgetTester tester) async {
    await pumpApp(tester, db: db, child: const TagsScreen());
    await tester.pumpAndSettle();
  }

  testWidgets('chưa có thẻ nào → hiện trạng thái rỗng', (tester) async {
    await pumpTags(tester);
    expect(find.text('Chưa có thẻ nào'), findsOneWidget);
  });

  testWidgets('thêm thẻ mới qua sheet — hiện ngay trên danh sách', (
    tester,
  ) async {
    await pumpTags(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Thêm thẻ'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Tên thẻ'),
      'Công tác',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Công tác'), findsOneWidget);
  });

  testWidgets(
    'sửa tên thẻ qua chạm vào hàng — cập nhật ngay, không tạo hàng mới',
    (tester) async {
      await db
          .into(db.tags)
          .insert(TagsCompanion.insert(name: 'Cũ', categoryColorId: 0));
      await pumpTags(tester);

      await tester.tap(find.text('Cũ'));
      await tester.pumpAndSettle();
      expect(find.text('Sửa thẻ'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Tên thẻ'), 'Mới');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(find.text('Mới'), findsOneWidget);
      expect(find.text('Cũ'), findsNothing);
    },
  );

  testWidgets('🚨 xoá thẻ — xác nhận rồi mới xoá, huỷ thì giữ nguyên', (
    tester,
  ) async {
    await db
        .into(db.tags)
        .insert(TagsCompanion.insert(name: 'Sẽ xoá', categoryColorId: 0));
    await pumpTags(tester);

    await tester.tap(find.byIcon(kIconDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(
      find.text('Sẽ xoá'),
      findsOneWidget,
      reason: 'Huỷ phải giữ nguyên thẻ',
    );

    await tester.tap(find.byIcon(kIconDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();

    expect(find.text('Sẽ xoá'), findsNothing);
    expect(find.text('Chưa có thẻ nào'), findsOneWidget);
  });
}
