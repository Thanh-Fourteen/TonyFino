import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/features/transactions/domain/transaction_row_display.dart';

/// BA khái niệm cùng có `category == null` — nạp/rút quỹ, giao dịch tách
/// dòng, và "chưa phân loại" thật. Trước bản này cả ba đều hiện ra là
/// "Chưa phân loại" ở mọi màn danh sách.
void main() {
  Transaction tx({required int amountMinor, int? categoryId, int? goalId}) =>
      Transaction(
        id: 1,
        amountMinor: amountMinor,
        currency: 'VND',
        currencyScale: 0,
        occurredAt: DateTime(2026, 9, 7),
        createdAt: DateTime(2026, 9, 7),
        updatedAt: DateTime(2026, 9, 7),
        walletId: 1,
        categoryId: categoryId,
        goalId: goalId,
        isTransfer: false,
      );

  SavingsGoal goal(String name) => SavingsGoal(
    id: 7,
    name: name,
    targetAmountMinor: 50000000,
    currency: 'VND',
    currencyScale: 0,
    isArchived: false,
    createdAt: DateTime(2026, 9, 7),
    sortOrder: 0,
  );

  Category category({
    required int id,
    required String name,
    int? parentCategoryId,
  }) => Category(
    id: id,
    name: name,
    kind: 'expense',
    categoryColorId: 3,
    iconCode: 'restaurant',
    isArchived: false,
    parentCategoryId: parentCategoryId,
    sortOrder: 0,
    createdAt: DateTime(2026, 9, 7),
    walletId: 1,
  );

  test('khoản NẠP quỹ đọc ra "Để dành › <tên quỹ>", không phải "Chưa phân '
      'loại"', () {
    final row = transactionRowDisplay(
      TransactionWithCategory(
        transaction: tx(amountMinor: -2000000, goalId: 7),
        goal: goal('Mua nha'),
      ),
      const {},
    );

    expect(row.title, 'Để dành');
    expect(row.subcategoryLabel, 'Mua nha');
    expect(row.iconCode, kSavingsRowIconCode);
    expect(row.categoryColorId, kSavingsRowColorId);
  });

  test('khoản RÚT quỹ (dòng dương) đọc ra "Rút từ quỹ"', () {
    final row = transactionRowDisplay(
      TransactionWithCategory(
        transaction: tx(amountMinor: 2000000, goalId: 7),
        goal: goal('Mua nha'),
      ),
      const {},
    );

    expect(row.title, 'Rút từ quỹ');
    expect(row.subcategoryLabel, 'Mua nha');
  });

  test('giao dịch tách dòng vẫn là "Nhiều danh mục", không nhầm sang quỹ', () {
    final row = transactionRowDisplay(
      TransactionWithCategory(
        transaction: tx(amountMinor: -100000),
        linesCount: 2,
      ),
      const {},
    );

    expect(row.title, 'Nhiều danh mục');
    expect(row.subcategoryLabel, isNull);
  });

  test('"chưa phân loại" thật vẫn giữ nguyên nhãn cũ', () {
    final row = transactionRowDisplay(
      TransactionWithCategory(transaction: tx(amountMinor: -35000)),
      const {},
    );

    expect(row.title, 'Chưa phân loại');
    expect(row.iconCode, 'more_horiz');
  });

  test('danh mục con lấy màu/icon/tên của CHA, tên con thành chip', () {
    final parent = category(id: 1, name: 'Ăn uống');
    final child = category(id: 2, name: 'Cà phê', parentCategoryId: 1);
    final row = transactionRowDisplay(
      TransactionWithCategory(
        transaction: tx(amountMinor: -35000, categoryId: 2),
        category: child,
      ),
      {1: parent, 2: child},
    );

    expect(row.title, 'Ăn uống');
    expect(row.subcategoryLabel, 'Cà phê');
  });
}
