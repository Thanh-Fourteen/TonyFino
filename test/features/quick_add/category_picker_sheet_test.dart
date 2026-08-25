// 🚨 Sheet chọn danh mục phải cho chọn TỚI danh mục con.
//
// Bug thật Tony bắt được: "Tôi nhấn 'hủ tíu trưa 30k' chỉ có thể chọn được
// thư mục đồ ăn, chưa chọn được thư mục con". `TwoLevelCategoryPicker` vốn
// đúng — hàng danh mục con của nó chỉ hiện SAU KHI chọn một cha — nhưng
// sheet lại `Navigator.pop` ngay trong `onChanged`, nên đúng cái frame hàng
// con lẽ ra hiện lên thì sheet đã đóng. Tầng hai không cách nào chạm tới.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/quick_add/quick_add_screen.dart';
import 'package:tonyfino/ui/app_chip.dart';
import 'package:tonyfino/ui/two_level_category_picker.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<void> insertSubcategory(String name, String parentName) async {
    final all = await db.select(db.categories).get();
    final parent = all.firstWhere((c) => c.name == parentName);
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            kind: parent.kind,
            categoryColorId: parent.categoryColorId,
            iconCode: parent.iconCode,
            walletId: parent.walletId,
            parentCategoryId: Value(parent.id),
          ),
        );
  }

  /// Chip BÊN TRONG sheet — cùng tên danh mục cũng đang hiện trên thẻ chat,
  /// nên phải neo theo `TwoLevelCategoryPicker` mới chắc đang bấm đúng chỗ.
  Finder chipInSheet(String label) => find.descendant(
    of: find.byType(TwoLevelCategoryPicker),
    matching: find.widgetWithText(AppChip, label),
  );

  Future<void> openSheetFor(WidgetTester tester, String text) async {
    await pumpApp(tester, db: db, child: const QuickAddScreen());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppChip, 'Ăn uống').first);
    await tester.pumpAndSettle();
  }

  testWidgets('🚨 chọn cha CÓ con → sheet ở lại, hàng danh mục con hiện ra', (
    tester,
  ) async {
    await insertSubcategory('Ăn trưa', 'Ăn uống');
    await openSheetFor(tester, 'hủ tíu 30k');

    expect(find.text('Chọn danh mục'), findsOneWidget);
    await tester.tap(chipInSheet('Ăn uống'));
    await tester.pumpAndSettle();

    // Sheet KHÔNG được đóng — đây chính là chỗ bản cũ hỏng.
    expect(find.text('Chọn danh mục'), findsOneWidget);
    expect(find.text('Danh mục con'), findsOneWidget);
    expect(chipInSheet('Ăn trưa'), findsOneWidget);
  });

  testWidgets('chọn con → sheet đóng, thẻ nhận đúng danh mục con', (
    tester,
  ) async {
    await insertSubcategory('Ăn trưa', 'Ăn uống');
    await openSheetFor(tester, 'hủ tíu 30k');

    await tester.tap(chipInSheet('Ăn uống'));
    await tester.pumpAndSettle();
    await tester.tap(chipInSheet('Ăn trưa'));
    await tester.pumpAndSettle();

    expect(find.text('Chọn danh mục'), findsNothing);
    expect(find.widgetWithText(AppChip, 'Ăn uống › Ăn trưa'), findsOneWidget);
  });

  testWidgets('nút "Dùng ..." chốt ở mức CHA khi không muốn xuống con', (
    tester,
  ) async {
    await insertSubcategory('Ăn trưa', 'Ăn uống');
    await openSheetFor(tester, 'hủ tíu 30k');

    await tester.tap(chipInSheet('Ăn uống'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dùng "Ăn uống"'));
    await tester.pumpAndSettle();

    expect(find.text('Chọn danh mục'), findsNothing);
    expect(find.widgetWithText(AppChip, 'Ăn uống'), findsOneWidget);
  });

  testWidgets('cha KHÔNG có con → đóng ngay, không thêm cú bấm thừa', (
    tester,
  ) async {
    await insertSubcategory('Ăn trưa', 'Ăn uống');
    await openSheetFor(tester, 'hủ tíu 30k');

    await tester.tap(chipInSheet('Di chuyển'));
    await tester.pumpAndSettle();

    expect(find.text('Chọn danh mục'), findsNothing);
    expect(find.widgetWithText(AppChip, 'Di chuyển'), findsOneWidget);
  });
}
