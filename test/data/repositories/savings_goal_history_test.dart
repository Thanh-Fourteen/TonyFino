import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/savings_goal_repository.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';

import '../../support/open_test_database.dart';

/// Lịch sử nạp/rút của MỘT quỹ — nguồn cho `SavingsGoalDetailScreen`.
/// Trước bản này `watchAllWithCategory` không có đường lọc theo quỹ nào cả,
/// nên không màn nào xem được một quỹ đã nạp/rút những gì.
void main() {
  late AppDatabase db;
  late TransactionRepository transactions;
  late SavingsGoalRepository goals;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    transactions = TransactionRepository(db);
    goals = SavingsGoalRepository(db);
    walletId = await defaultWalletId(db);
  });
  tearDown(() => db.close());

  Future<int> newGoal(String name) async {
    final result = await goals.insert(
      name: name,
      targetAmount: const Money.vnd(50000000),
    );
    return result.when(ok: (id) => id, err: (e) => fail(e.message));
  }

  Future<void> addGoalMove({
    required int amountMinor,
    required int goalId,
    DateTime? at,
  }) async {
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: amountMinor,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: at ?? DateTime(2026, 9, 4),
            walletId: walletId,
            goalId: Value(goalId),
          ),
        );
  }

  test('watchAllWithCategory(goalId:) chỉ trả về giao dịch của ĐÚNG quỹ đó — '
      'quỹ khác và giao dịch thường đều bị loại', () async {
    final mine = await newGoal('Mua nha');
    final other = await newGoal('Mua xe');

    await addGoalMove(amountMinor: -5000000, goalId: mine);
    await addGoalMove(amountMinor: 2000000, goalId: mine);
    await addGoalMove(amountMinor: -9000000, goalId: other);
    await transactions.insert(
      amount: const Money.vnd(-35000),
      occurredAt: DateTime(2026, 9, 4),
      walletId: walletId,
    );

    final rows = await transactions.watchAllWithCategory(goalId: mine).first;

    expect(rows, hasLength(2));
    expect(rows.map((r) => r.transaction.amountMinor).toSet(), {
      -5000000,
      2000000,
    });
    // Mỗi hàng mang sẵn TÊN quỹ để UI khỏi phải tra thêm một query nữa.
    expect(rows.every((r) => r.goal?.name == 'Mua nha'), isTrue);
  });

  test(
    'không truyền goalId thì KHÔNG lọc gì, nhưng hàng gắn quỹ vẫn mang theo '
    'tên quỹ — đây là thứ để danh sách chung thôi gọi nó là "Chưa phân loại"',
    () async {
      final goalId = await newGoal('Mua nha');
      await addGoalMove(amountMinor: -5000000, goalId: goalId);
      await transactions.insert(
        amount: const Money.vnd(-35000),
        occurredAt: DateTime(2026, 9, 4),
        walletId: walletId,
      );

      final rows = await transactions.watchAllWithCategory().first;

      expect(rows, hasLength(2));
      final savingsRow = rows.firstWhere(
        (r) => r.transaction.amountMinor == -5000000,
      );
      final plainRow = rows.firstWhere(
        (r) => r.transaction.amountMinor == -35000,
      );
      expect(savingsRow.goal?.name, 'Mua nha');
      expect(plainRow.goal, isNull);
    },
  );

  test('quỹ chưa có lần nạp nào thì lịch sử rỗng, không phải lỗi', () async {
    final goalId = await newGoal('Mua nha');
    final rows = await transactions.watchAllWithCategory(goalId: goalId).first;
    expect(rows, isEmpty);
  });
}
