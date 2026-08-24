// Chọn danh mục HAI TẦNG trong form nhập (cha → con), theo mô tả của Tony:
// "nhập bánh mì 30k gom vào Ăn uống nhưng tôi chỉnh thêm mục con là Ăn sáng
// thiết yếu". Chạy qua cây sản xuất thật (`TransactionsScreen` → FAB →
// `TransactionFormSheet`), không dựng widget rời.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/transactions/transactions_screen.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<Category> expenseRoot() async {
    final all = await db.select(db.categories).get();
    return all.firstWhere(
      (c) => c.parentCategoryId == null && c.kind == 'expense',
    );
  }

  Future<int> addChild(Category parent, String name) => db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          name: name,
          kind: parent.kind,
          categoryColorId: parent.categoryColorId,
          iconCode: parent.iconCode,
          parentCategoryId: Value(parent.id),
          walletId: parent.walletId,
        ),
      );

  Future<void> openAddSheet(WidgetTester tester) async {
    await pumpApp(tester, db: db, child: const TransactionsScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    '🚨 danh mục CON chỉ hiện SAU khi chọn cha — không đổ chung một mớ chip',
    (tester) async {
      final parent = await expenseRoot();
      await addChild(parent, 'Ăn sáng thiết yếu');
      await openAddSheet(tester);

      // Chưa chọn cha: nhãn hàng hai và tên con đều chưa có mặt.
      expect(find.text('Danh mục con'), findsNothing);
      expect(find.text('Ăn sáng thiết yếu'), findsNothing);

      await tester.tap(find.text(parent.name));
      await tester.pumpAndSettle();

      expect(find.text('Danh mục con'), findsOneWidget);
      expect(find.text('Ăn sáng thiết yếu'), findsOneWidget);
    },
  );

  testWidgets('chọn cha rồi chọn con → lưu categoryId của CON', (tester) async {
    final parent = await expenseRoot();
    final childId = await addChild(parent, 'Ăn sáng thiết yếu');
    await openAddSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '30000');
    await tester.tap(find.text(parent.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn sáng thiết yếu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final saved = await db.select(db.transactions).getSingle();
    expect(saved.categoryId, childId);
    expect(saved.amountMinor, -30000);
  });

  testWidgets('chỉ chọn cha, không chọn con → lưu categoryId của CHA', (
    tester,
  ) async {
    final parent = await expenseRoot();
    await addChild(parent, 'Ăn sáng thiết yếu');
    await openAddSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '30000');
    await tester.tap(find.text(parent.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final saved = await db.select(db.transactions).getSingle();
    expect(saved.categoryId, parent.id);
  });

  testWidgets('bấm lại con đang chọn = bỏ chọn, lùi về mức cha', (
    tester,
  ) async {
    final parent = await expenseRoot();
    await addChild(parent, 'Ăn sáng thiết yếu');
    await openAddSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '30000');
    await tester.tap(find.text(parent.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn sáng thiết yếu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn sáng thiết yếu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final saved = await db.select(db.transactions).getSingle();
    expect(saved.categoryId, parent.id);
  });

  testWidgets('🚨 form "Chi" KHÔNG liệt kê danh mục thu (và ngược lại)', (
    tester,
  ) async {
    final all = await db.select(db.categories).get();
    final income = all.firstWhere((c) => c.kind == 'income');
    await openAddSheet(tester);

    expect(find.text(income.name), findsNothing);

    // "Thu" xuất hiện cả ở nút phân đoạn lẫn nhãn thống kê — chỉ định rõ
    // nút phân đoạn, nếu không finder mơ hồ và test hỏng vì lý do vô can.
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<bool>),
        matching: find.text('Thu'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(income.name), findsOneWidget);
  });
}
