// Test bắt buộc #4 (Phase 4): 1000 thao tác ngẫu nhiên, số dư hiển thị phải
// luôn bằng SUM() (D7) ở MỌI bước — không có cột `balance` nào để lệch pha.
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/core/result/result.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';

import '../../support/open_test_database.dart';

void main() {
  test(
    'bất biến số dư qua 1000 thao tác ngẫu nhiên (insert xen delete)',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TransactionRepository(db);
      final random = Random(42);
      final liveIds = <int>[];
      final walletId = (await db.select(db.wallets).get()).first.id;

      Future<Money> readTrueSum() async {
        final sumExpr = db.transactions.amountMinor.sum();
        final row = await (db.selectOnly(
          db.transactions,
        )..addColumns([sumExpr])).getSingle();
        return Money.vnd(row.read(sumExpr) ?? 0);
      }

      for (var step = 0; step < 1000; step++) {
        final shouldDelete = liveIds.isNotEmpty && random.nextInt(3) == 0;

        if (shouldDelete) {
          final index = random.nextInt(liveIds.length);
          final id = liveIds.removeAt(index);
          final result = await repo.delete(id);
          expect(
            result.isOk,
            isTrue,
            reason: 'delete thất bại ở bước $step: $result',
          );
        } else {
          final amount = (random.nextInt(500) + 1) * 1000;
          final isExpense = random.nextBool();
          final result = await repo.insert(
            amount: Money.vnd(isExpense ? -amount : amount),
            occurredAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: step)),
            walletId: walletId,
          );
          expect(
            result.isOk,
            isTrue,
            reason: 'insert thất bại ở bước $step: $result',
          );
          liveIds.add((result as Ok<int, AppError>).value);
        }

        final displayed = await repo.watchBalance().first;
        final trueSum = await readTrueSum();
        expect(
          displayed,
          trueSum,
          reason:
              'Lệch ở bước $step: hiển thị ${displayed.format()}, SUM() thật ${trueSum.format()}',
        );
      }

      expect(
        liveIds,
        isNotEmpty,
        reason: 'phép thử vô nghĩa nếu không còn giao dịch nào sống sót',
      );
    },
  );
}
