// Màn "Chi tiết danh mục" (Phase 25) — widget test qua cây sản xuất thật,
// bắt đầu từ CategoriesScreen (đúng đường điều hướng thật: bấm vào một
// danh mục CẤP GỐC).
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/features/categories/categories_screen.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpCategories(WidgetTester tester) async {
    await pumpApp(tester, db: db, child: const CategoriesScreen());
    await tester.pumpAndSettle();
  }

  testWidgets(
    '🚨 bấm danh mục CẤP GỐC → mở màn chi tiết, hiện đúng breakdown + danh sách con + giao dịch',
    (tester) async {
      final parent = (await db.select(db.categories).get()).first;
      final walletId = (await db.select(db.wallets).get()).first.id;
      final childId = await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Ăn trưa',
              kind: parent.kind,
              categoryColorId: parent.categoryColorId,
              iconCode: parent.iconCode,
              parentCategoryId: Value(parent.id),
              walletId: parent.walletId,
            ),
          );
      final txRepo = TransactionRepository(db);
      await txRepo.insert(
        amount: Money.vnd(-500000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        categoryId: parent.id,
      );
      await txRepo.insert(
        amount: Money.vnd(-100000),
        occurredAt: DateTime(2026, 8, 11),
        walletId: walletId,
        categoryId: childId,
      );

      await pumpCategories(tester);
      await tester.tap(find.text(parent.name).first);
      await tester.pumpAndSettle();

      // Đúng màn chi tiết — tiêu đề AppBar = tên danh mục cha.
      expect(find.widgetWithText(AppBar, parent.name), findsOneWidget);
      // Tổng = 500.000 + 100.000 = 600.000.
      expect(find.textContaining('600.000'), findsWidgets);
      // Danh mục con hiện trong danh sách quản lý.
      expect(find.text('Ăn trưa'), findsWidgets);
    },
  );

  testWidgets(
    'bấm nút + trong màn chi tiết → thêm danh mục con MỚI, gán đúng cha',
    (tester) async {
      final parent = (await db.select(db.categories).get()).first;

      await pumpCategories(tester);
      await tester.tap(find.text(parent.name).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Tên danh mục'),
        'Ăn sáng',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      final saved = await (db.select(
        db.categories,
      )..where((c) => c.name.equals('Ăn sáng'))).getSingle();
      expect(saved.parentCategoryId, parent.id);
      expect(find.text('Ăn sáng'), findsWidgets);
    },
  );

  testWidgets(
    'bấm danh mục CON (đã lồng dưới cha) vẫn mở sheet sửa như cũ, KHÔNG mở màn chi tiết',
    (tester) async {
      final parent = (await db.select(db.categories).get()).first;
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Con test',
              kind: parent.kind,
              categoryColorId: parent.categoryColorId,
              iconCode: parent.iconCode,
              parentCategoryId: Value(parent.id),
              walletId: parent.walletId,
            ),
          );

      await pumpCategories(tester);
      await tester.tap(find.text('Con test'));
      await tester.pumpAndSettle();

      // Sheet sửa mở (tiêu đề "Sửa danh mục"), KHÔNG phải màn chi tiết.
      expect(find.text('Sửa danh mục'), findsOneWidget);
    },
  );
}
