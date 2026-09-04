// Màn chat ghi thẳng vào MỤC TIÊU TIẾT KIỆM, và dấu tiền của danh mục THU.
//
// Hai lỗi Tony báo cùng một lượt:
//  * "thưởng 1tr" (Thưởng là danh mục THU tự thêm) ra −1tr;
//  * gõ câu chuyển tiền vào tiết kiệm ở màn chat không đi tới đâu.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/quick_add/quick_add_screen.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<int> walletId() async => (await db.select(db.wallets).get()).first.id;

  Future<int> addGoal(String name) => db
      .into(db.savingsGoals)
      .insert(
        SavingsGoalsCompanion.insert(
          name: name,
          targetAmountMinor: 50000000,
          currency: 'VND',
          currencyScale: 0,
        ),
      );

  testWidgets(
    '🚨 "chuyển 5tr vào tiết kiệm" ghi vào MỤC TIÊU, không thành khoản chi có '
    'danh mục',
    (tester) async {
      final goalId = await addGoal('Mua nhà');

      await pumpApp(tester, db: db, child: const QuickAddScreen());
      await tester.pumpAndSettle();
      await _send(tester, 'chuyển 5tr vào tiết kiệm');

      final rows = await db.select(db.transactions).get();
      expect(rows, hasLength(1));
      expect(rows.single.goalId, goalId);
      expect(rows.single.categoryId, isNull);
      expect(
        rows.single.amountMinor,
        -5000000,
        reason: 'cất vào là tiền RỜI ví — tiến độ mục tiêu là -SUM(amountMinor)',
      );
      expect(find.textContaining('Mua nhà'), findsWidgets);
    },
  );

  testWidgets('"rút 2tr từ tiết kiệm" là dòng THU gắn cùng mục tiêu', (
    tester,
  ) async {
    final goalId = await addGoal('Mua nhà');

    await pumpApp(tester, db: db, child: const QuickAddScreen());
    await tester.pumpAndSettle();
    await _send(tester, 'rút 2tr từ tiết kiệm');

    final rows = await db.select(db.transactions).get();
    expect(rows.single.goalId, goalId);
    expect(rows.single.amountMinor, 2000000);
  });

  testWidgets('câu chi tiêu thường KHÔNG bị hút vào mục tiêu tiết kiệm', (
    tester,
  ) async {
    await addGoal('Mua nhà');

    await pumpApp(tester, db: db, child: const QuickAddScreen());
    await tester.pumpAndSettle();
    await _send(tester, 'cà phê 30k');

    final rows = await db.select(db.transactions).get();
    expect(rows.single.goalId, isNull);
    expect(rows.single.categoryId, isNotNull);
    expect(rows.single.amountMinor, -30000);
  });

  testWidgets(
    '🚨 "thưởng 1tr" với danh mục CON thuộc nhánh THU ghi ra +1tr',
    (tester) async {
      final wallet = await walletId();
      final parentId = await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Thu nhập phụ',
              kind: 'income',
              categoryColorId: 3,
              iconCode: 'payments',
              walletId: wallet,
            ),
          );
      // `kind: 'expense'` là ĐÚNG thứ sheet cũ ghi ra khi Tony để nút gạt ở
      // "Chi" — danh mục vẫn hiện trong mục "Danh mục thu" vì nó nằm dưới
      // một gốc THU. `repairSubcategoryKinds` phải dọn hàng này lúc mở sổ.
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Thưởng',
              kind: 'expense',
              categoryColorId: 3,
              iconCode: 'payments',
              parentCategoryId: Value(parentId),
              walletId: wallet,
            ),
          );
      await repairSubcategoryKinds(db);

      await pumpApp(tester, db: db, child: const QuickAddScreen());
      await tester.pumpAndSettle();
      await _send(tester, 'thưởng 1tr');

      final rows = await db.select(db.transactions).get();
      expect(rows.single.amountMinor, 1000000);
    },
  );
}
