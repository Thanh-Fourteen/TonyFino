// watchAllWithCategory({categoryIds}) — Phase 25, màn "Chi tiết danh mục".
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late int walletId;
  late Category parent;
  late Category child;
  late Category other;

  setUp(() async {
    db = openTestDatabase();
    repo = TransactionRepository(db);
    walletId = (await db.select(db.wallets).get()).first.id;
    final categories = await db.select(db.categories).get();
    parent = categories[0];
    other = categories[1];
    final childId = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Con',
            kind: parent.kind,
            categoryColorId: parent.categoryColorId,
            iconCode: parent.iconCode,
            parentCategoryId: Value(parent.id),
            walletId: parent.walletId,
          ),
        );
    child = (await (db.select(
      db.categories,
    )..where((c) => c.id.equals(childId))).getSingle());
  });
  tearDown(() => db.close());

  test(
    'categoryIds: giao dịch gán cha + con của cha đều khớp, giao dịch danh mục khác thì không',
    () async {
      await repo.insert(
        amount: Money.vnd(-10000),
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        categoryId: parent.id,
      );
      await repo.insert(
        amount: Money.vnd(-20000),
        occurredAt: DateTime(2026, 8, 2),
        walletId: walletId,
        categoryId: child.id,
      );
      await repo.insert(
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 3),
        walletId: walletId,
        categoryId: other.id,
      );

      final result = await repo
          .watchAllWithCategory(categoryIds: {parent.id, child.id})
          .first;

      expect(result, hasLength(2));
      expect(result.map((t) => t.transaction.amountMinor).toSet(), {
        -10000,
        -20000,
      });
    },
  );

  test(
    'categoryIds: giao dịch TÁCH DÒNG có một dòng con thuộc tập lọc thì khớp cả giao dịch cha',
    () async {
      final txId = (await repo.insert(
        amount: Money.vnd(-50000),
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        lines: [
          TransactionLineInput(categoryId: parent.id, amountMinor: -20000),
          TransactionLineInput(categoryId: other.id, amountMinor: -30000),
        ],
      )).valueOrNull!;

      final matchedByParent = await repo
          .watchAllWithCategory(categoryIds: {parent.id})
          .first;
      expect(matchedByParent.single.transaction.id, txId);

      final matchedByOther = await repo
          .watchAllWithCategory(categoryIds: {other.id})
          .first;
      expect(matchedByOther.single.transaction.id, txId);
    },
  );

  test(
    'categoryIds null → không lọc, trả về mọi giao dịch (hành vi cũ không đổi)',
    () async {
      await repo.insert(
        amount: Money.vnd(-10000),
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        categoryId: parent.id,
      );
      await repo.insert(
        amount: Money.vnd(-20000),
        occurredAt: DateTime(2026, 8, 2),
        walletId: walletId,
        categoryId: other.id,
      );

      final result = await repo.watchAllWithCategory().first;
      expect(result, hasLength(2));
    },
  );
}
