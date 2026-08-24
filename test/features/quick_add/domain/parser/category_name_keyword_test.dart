// TÊN danh mục là từ khoá mạnh nhất của chính nó.
//
// Tony có danh mục "Giặt đồ" (nhập từ Rolly, không kèm từ khoá) nhưng gõ
// "giặt đồ 50k" lại ra Nhà cửa — vì `giặt đồ` là từ khoá SEED của Nhà cửa.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/quick_add/quick_add_screen.dart';

import '../../../../support/fake_shared_preferences.dart';
import '../../../../support/open_test_database.dart';
import '../../../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  testWidgets(
    '🚨 có danh mục tên "Giặt đồ" → gõ "giặt đồ 50k" vào ĐÚNG danh mục đó, '
    'không rơi vào Nhà cửa (nơi có từ khoá seed cùng chữ)',
    (tester) async {
      final walletId = (await db.select(db.wallets).get()).first.id;
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Giặt đồ',
              kind: 'expense',
              categoryColorId: 4,
              iconCode: 'local_laundry_service',
              walletId: walletId,
            ),
          );

      await pumpApp(tester, db: db, child: const QuickAddScreen());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'giặt đồ 50k');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(find.textContaining('Giặt đồ'), findsWidgets);
      expect(find.textContaining('Nhà cửa'), findsNothing);
    },
  );

  testWidgets('tên danh mục MẶC ĐỊNH cũng khớp: "giáo dục 2tr" → Giáo dục', (
    tester,
  ) async {
    await pumpApp(tester, db: db, child: const QuickAddScreen());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'giáo dục 2tr');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.textContaining('Giáo dục'), findsWidgets);
  });
}
