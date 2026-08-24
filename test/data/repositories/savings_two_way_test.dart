import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/repositories/savings_goal_repository.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late SavingsGoalRepository repo;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    repo = SavingsGoalRepository(db);
    walletId = await defaultWalletId(db);
  });
  tearDown(() => db.close());

  Future<void> addTransaction({
    required int amountMinor,
    required int goalId,
  }) async {
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: amountMinor,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: DateTime(2026, 8, 20),
            walletId: walletId,
            goalId: Value(goalId),
          ),
        );
  }

  test(
    'nạp vào rồi rút ra: tiến độ mục tiêu tăng rồi giảm đúng số — hai chiều '
    'dùng CHUNG một công thức, không có nhánh riêng nào để lệch dấu',
    () async {
      final inserted = await repo.insert(
        name: 'CCTG',
        targetAmount: const Money.vnd(10000000),
      );
      final goalId = inserted.when(ok: (id) => id, err: (e) => fail(e.message));

      // Nạp 3.000.000 — ví CHI ra (âm) nên tiến độ mục tiêu DƯƠNG.
      await addTransaction(amountMinor: -3000000, goalId: goalId);
      var progress = (await repo.watchActiveWithProgress().first).single;
      expect(progress.savedMinor, 3000000);

      // Rút 1.000.000 về ví — ví THU vào (dương) nên tiến độ GIẢM.
      await addTransaction(amountMinor: 1000000, goalId: goalId);
      progress = (await repo.watchActiveWithProgress().first).single;
      expect(
        progress.savedMinor,
        2000000,
        reason: 'rút về ví phải trừ đúng vào tiến độ, không cộng thêm',
      );

      // Tổng số dư ví phản ánh đúng chiều tiền: −3tr rồi +1tr = −2tr.
      final sum = await db
          .customSelect('SELECT SUM(amount_minor) AS s FROM transactions')
          .getSingle();
      expect(sum.read<int>('s'), -2000000);
    },
  );
}
