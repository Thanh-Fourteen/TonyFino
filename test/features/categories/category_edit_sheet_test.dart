// Sheet thêm/sửa danh mục — bộ icon 114 mã chia nhóm, và nút gạt Chi/Thu.
//
// Khung hình test cố ý CAO (360×1600 logic) thay vì 800×600 mặc định: sheet
// này dài, và trên khung thật người dùng chỉ việc cuộn xuống — một test đỏ vì
// "nút nằm ngoài khung 600px" là nói về khung hình test chứ không nói gì về
// app. Cho cả sheet vào khung rồi kiểm HÀNH VI (chọn icon nào thì lưu icon
// ấy, chọn cha thì mất nút gạt), không kiểm chỗ ngồi của từng pixel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/categories/categories_screen.dart';
import 'package:tonyfino/theme/tokens/icons.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> openAddSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, db: db, child: const CategoriesScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('bộ chọn icon chia NHÓM, và nút Lưu vẫn nằm trong sheet', (
    tester,
  ) async {
    await openAddSheet(tester);

    expect(find.text('Tiền bạc'), findsOneWidget);
    expect(find.text('Đi lại'), findsOneWidget);
    expect(find.text('Lưu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chọn được một icon MỚI (ngoài 15 mã seed cũ)', (tester) async {
    await openAddSheet(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Tên danh mục'),
      'Bún bò',
    );
    await tapVisible(tester, find.byIcon(kIconRamenDining));
    await tapVisible(tester, find.text('Lưu'));

    final saved = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Bún bò'))).getSingle();
    expect(saved.iconCode, 'ramen_dining');
  });

  testWidgets(
    '🚨 danh mục CON không hiện nút gạt Chi/Thu — nó theo chiều tiền của cha',
    (tester) async {
      await openAddSheet(tester);
      expect(find.widgetWithText(SegmentedButton<bool>, 'Chi'), findsOneWidget);

      // "Lương" là danh mục THU seed sẵn — chọn nó làm cha thì nút gạt biến
      // mất và sheet nói rõ danh mục con sẽ là THU.
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Lương'));

      expect(find.byType(SegmentedButton<bool>), findsNothing);
      expect(find.text('Danh mục THU — theo danh mục cha'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Tên danh mục'),
        'Thưởng',
      );
      await tapVisible(tester, find.text('Lưu'));

      final saved = await (db.select(
        db.categories,
      )..where((c) => c.name.equals('Thưởng'))).getSingle();
      expect(saved.kind, 'income');
    },
  );
}
