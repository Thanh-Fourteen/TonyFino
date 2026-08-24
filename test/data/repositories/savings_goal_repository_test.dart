// Mục tiêu tiết kiệm (Phase 16) — tiến độ LUÔN dẫn xuất bằng SQL (D7), không
// bao giờ lưu "đã tiết kiệm bao nhiêu" riêng. Test trọng tâm: tiến độ tự
// đúng lại sau khi thêm/sửa/xoá một giao dịch đóng góp, không cần thao tác
// "đồng bộ lại" nào — đúng yêu cầu Xác minh của TODOS.md § Phase 16.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/savings_goal_repository.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late SavingsGoalRepository repo;
  late TransactionRepository txRepo;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    repo = SavingsGoalRepository(db);
    txRepo = TransactionRepository(db);
    walletId = (await db.select(db.wallets).get()).first.id;
  });
  tearDown(() => db.close());

  test(
    'mục tiêu chưa có đóng góp nào → saved = 0, hiện đủ trong watchActiveWithProgress (LEFT JOIN)',
    () async {
      await repo.insert(name: 'Du lịch', targetAmount: Money.vnd(10000000));

      final result = await repo.watchActiveWithProgress().first;
      expect(result, hasLength(1));
      expect(result.single.savedMinor, 0);
      expect(result.single.progressFraction, 0.0);
    },
  );

  test(
    '🚨 đóng góp (giao dịch CHI gắn goalId) cộng dương vào saved — không cần đồng bộ lại',
    () async {
      final insertResult = await repo.insert(
        name: 'Du lịch',
        targetAmount: Money.vnd(10000000),
      );
      final goalId = insertResult.valueOrNull!;

      await txRepo.insert(
        amount: Money.vnd(-3000000),
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        goalId: goalId,
      );

      final result = await repo.watchActiveWithProgress().first;
      expect(result.single.savedMinor, 3000000);
      expect(result.single.progressFraction, closeTo(0.3, 1e-9));
    },
  );

  test(
    '🚨 rút khỏi mục tiêu (giao dịch THU gắn goalId) trừ ngược lại saved',
    () async {
      final insertResult = await repo.insert(
        name: 'Du lịch',
        targetAmount: Money.vnd(10000000),
      );
      final goalId = insertResult.valueOrNull!;

      await txRepo.insert(
        amount: Money.vnd(-5000000),
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        goalId: goalId,
      );
      await txRepo.insert(
        amount: Money.vnd(2000000), // rút một phần — THU, dương.
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        goalId: goalId,
      );

      final result = await repo.watchActiveWithProgress().first;
      expect(
        result.single.savedMinor,
        3000000,
      ); // 5tr - 2tr = 3tr, KHÔNG phải abs(-5tr+2tr).
    },
  );

  test(
    '🚨 sửa số tiền một giao dịch đóng góp → tiến độ tự đổi theo, không cần thao tác riêng',
    () async {
      final insertResult = await repo.insert(
        name: 'Du lịch',
        targetAmount: Money.vnd(10000000),
      );
      final goalId = insertResult.valueOrNull!;

      final txId = await txRepo.insert(
        amount: Money.vnd(-1000000),
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        goalId: goalId,
      );
      expect(
        (await repo.watchActiveWithProgress().first).single.savedMinor,
        1000000,
      );

      // KHÔNG truyền `goalId` (mặc định `Value.absent()`) — đúng ca thật của
      // `correctCategory`/`correctDate` (Phase 8): sửa số tiền mà không biết
      // gì về gắn kết mục tiêu, PHẢI giữ nguyên gắn kết đã có, không tháo mất.
      await txRepo.update(
        id: txId.valueOrNull!,
        amount: Money.vnd(-4000000),
        occurredAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );
      final progressAfterUpdate = await repo.watchActiveWithProgress().first;
      expect(progressAfterUpdate.single.savedMinor, 4000000);
    },
  );

  test(
    '🚨 xoá giao dịch đóng góp → tiến độ tự giảm theo, không còn dấu vết',
    () async {
      final insertResult = await repo.insert(
        name: 'Du lịch',
        targetAmount: Money.vnd(10000000),
      );
      final goalId = insertResult.valueOrNull!;

      final tx1 = await txRepo.insert(
        amount: Money.vnd(-3000000),
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        goalId: goalId,
      );
      await txRepo.insert(
        amount: Money.vnd(-2000000),
        occurredAt: DateTime(2026, 8, 2),
        walletId: walletId,
        goalId: goalId,
      );
      expect(
        (await repo.watchActiveWithProgress().first).single.savedMinor,
        5000000,
      );

      await txRepo.delete(tx1.valueOrNull!);

      final result = await repo.watchActiveWithProgress().first;
      expect(result.single.savedMinor, 2000000);
    },
  );

  test(
    '🚨 update() với goalId: Value(null) tường minh THÁO gắn kết — khác với KHÔNG truyền',
    () async {
      final goalId = (await repo.insert(
        name: 'Du lịch',
        targetAmount: Money.vnd(10000000),
      )).valueOrNull!;
      final txId = (await txRepo.insert(
        amount: Money.vnd(-1000000),
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        goalId: goalId,
      )).valueOrNull!;
      expect(
        (await repo.watchActiveWithProgress().first).single.savedMinor,
        1000000,
      );

      await txRepo.update(
        id: txId,
        amount: Money.vnd(-1000000),
        occurredAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
        goalId: const Value(null),
      );

      expect((await repo.watchActiveWithProgress().first).single.savedMinor, 0);
    },
  );

  test(
    'đạt/vượt mục tiêu → isAchieved true, progressFraction kẹp ở 1.0',
    () async {
      final insertResult = await repo.insert(
        name: 'Xe máy',
        targetAmount: Money.vnd(5000000),
      );
      final goalId = insertResult.valueOrNull!;

      await txRepo.insert(
        amount: Money.vnd(-6000000), // vượt mục tiêu.
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        goalId: goalId,
      );

      final progress = (await repo.watchActiveWithProgress().first).single;
      expect(progress.isAchieved, isTrue);
      expect(progress.progressFraction, 1.0);
      expect(
        progress.remainingMinor,
        -1000000,
      ); // âm — vượt 1tr, hiển thị rõ bằng số.
    },
  );

  test(
    'giao dịch gắn goalId của MỘT mục tiêu khác không ảnh hưởng tiến độ mục tiêu này',
    () async {
      final goal1 = (await repo.insert(
        name: 'A',
        targetAmount: Money.vnd(1000000),
      )).valueOrNull!;
      final goal2 = (await repo.insert(
        name: 'B',
        targetAmount: Money.vnd(1000000),
      )).valueOrNull!;

      await txRepo.insert(
        amount: Money.vnd(-500000),
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        goalId: goal1,
      );

      final result = await repo.watchActiveWithProgress().first;
      final byId = {for (final p in result) p.goal.id: p};
      expect(byId[goal1]!.savedMinor, 500000);
      expect(byId[goal2]!.savedMinor, 0);
    },
  );

  test(
    'setArchived(true) → mục tiêu rời khỏi watchActive*, hiện trong watchArchived',
    () async {
      final goalId = (await repo.insert(
        name: 'A',
        targetAmount: Money.vnd(1000000),
      )).valueOrNull!;
      await repo.setArchived(goalId, true);

      expect(await repo.watchActive().first, isEmpty);
      expect(await repo.watchActiveWithProgress().first, isEmpty);
      expect((await repo.watchArchived().first).single.id, goalId);
    },
  );
}
