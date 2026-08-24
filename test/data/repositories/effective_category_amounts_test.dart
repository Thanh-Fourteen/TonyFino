// Kiểm chứng ĐỘC LẬP `effectiveCategoryAmounts` (Phase 14) trước khi tin
// tưởng nó bên trong ReportsRepository/BudgetRepository — nếu UNION ALL/
// Subquery.ref sai, muốn bắt lỗi ở đây, không phải giữa một query gộp phức
// tạp 4-5 tầng.
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/effective_category_amounts.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late int cat1;
  late int cat2;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    walletId = await defaultWalletId(db);
    cat1 = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Ăn uống',
            kind: 'expense',
            categoryColorId: 0,
            iconCode: 'restaurant',
            walletId: walletId,
          ),
        );
    cat2 = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Di chuyển',
            kind: 'expense',
            categoryColorId: 1,
            iconCode: 'directions_car',
            walletId: walletId,
          ),
        );
  });
  tearDown(() => db.close());

  Future<Map<int?, int>> sumByCategory() async {
    final eff = effectiveCategoryAmounts(db);
    final effCategoryId = eff.ref(db.transactions.categoryId);
    final effAmount = eff.ref(db.transactions.amountMinor);
    final sumExpr = effAmount.sum();

    final query = db.selectOnly(eff)
      ..addColumns([effCategoryId, sumExpr])
      ..groupBy([effCategoryId]);

    final rows = await query.get();
    return {
      for (final row in rows) row.read(effCategoryId): row.read(sumExpr) ?? 0,
    };
  }

  test(
    'giao dịch KHÔNG tách dòng — gộp thẳng theo transactions.category_id',
    () async {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -10000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 1),
              walletId: walletId,
              categoryId: Value(cat1),
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -5000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 1),
              walletId: walletId,
              categoryId: Value(cat2),
            ),
          );

      final sums = await sumByCategory();
      expect(sums, {cat1: -10000, cat2: -5000});
    },
  );

  test(
    'giao dịch CÓ tách dòng — mỗi dòng con cộng vào ĐÚNG danh mục của nó, KHÔNG dùng transactions.category_id (đã NULL)',
    () async {
      final parentId = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -30000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 1),
              walletId: walletId,
              categoryId: const Value(null),
            ),
          );
      await db
          .into(db.transactionLines)
          .insert(
            TransactionLinesCompanion.insert(
              transactionId: parentId,
              categoryId: Value(cat1),
              amountMinor: -10000,
            ),
          );
      await db
          .into(db.transactionLines)
          .insert(
            TransactionLinesCompanion.insert(
              transactionId: parentId,
              categoryId: Value(cat2),
              amountMinor: -20000,
            ),
          );
      // Một giao dịch KHÔNG tách khác, cùng cat1 — phải CỘNG DỒN với dòng con
      // cat1 ở trên, không phải hai nhóm tách biệt.
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -1000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 1),
              walletId: walletId,
              categoryId: Value(cat1),
            ),
          );

      final sums = await sumByCategory();
      expect(sums, {cat1: -11000, cat2: -20000});
      // Tổng effective PHẢI khớp tổng amountMinor thật của mọi giao dịch cha
      // (-30000 + -1000 = -31000) — bất biến quan trọng nhất: tách dòng không
      // được làm lệch tổng.
      final grandTotal = sums.values.fold<int>(0, (a, b) => a + b);
      expect(grandTotal, -31000);
    },
  );
}
