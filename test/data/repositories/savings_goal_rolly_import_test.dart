// Phase 19 — import lịch sử tiết kiệm Rolly: idempotency PHẢI được test
// bằng cách CHẠY IMPORT HAI LẦN thật (không chỉ đọc code rồi tin), đúng yêu
// cầu TODOS.md § Phase 19 lặp lại kỷ luật Phase 9.
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/savings_goal_repository.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_savings_parser.dart';

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

  /// Mô phỏng đúng trạng thái thật trên máy Tony: 4 giao dịch "Chuyển khoản
  /// / Tiết kiệm" (âm, đã import ở Phase 9) với sourceId khớp 4 sourceId
  /// walletLeg thật của goal 49755 — TRƯỚC KHI có bất kỳ savings_goal nào.
  Future<void> seedPhase9Contributions() async {
    for (final (sourceId, amountMinor) in const [
      ('rolly:12450889', -7000000),
      ('rolly:13061034', -16200000),
      ('rolly:13381944', -10000000),
      ('rolly:11916359', -10000000),
    ]) {
      await txRepo.insert(
        amount: Money.vnd(amountMinor),
        occurredAt: DateTime(2026, 7, 1),
        walletId: walletId,
        sourceId: sourceId,
      );
    }
  }

  final goal = StagedRollySavingsGoal(
    sourceId: 'rolly-savings:49755',
    rollyGoalId: 49755,
    name: 'CCTG',
    targetAmountMinor: 30000000,
    currency: 'VND',
    currencyScale: 0,
    targetDate: DateTime(2026, 8, 22),
    isArchived: true,
    totalContributedMinor: 43200000,
  );
  const contributionMap = {
    49755: [
      'rolly:12450889',
      'rolly:13061034',
      'rolly:13381944',
      'rolly:11916359',
    ],
  };

  test(
    '🚨 import lần 1: tạo goal + gắn goalId vào 4 giao dịch Phase 9 cũ — saved khớp oracle total_amount',
    () async {
      await seedPhase9Contributions();

      final result = await repo.importFromRolly(
        goals: [goal],
        contributionSourceIdsByRollyGoalId: contributionMap,
      );

      final summary = result.valueOrNull!;
      expect(summary.insertedGoals, 1);
      expect(summary.skippedDuplicateGoals, 0);
      expect(summary.linkedContributions, 4);

      final archived = await repo.watchArchived().first;
      expect(archived, hasLength(1));
      expect(archived.single.name, 'CCTG');

      // Tiến độ tính lại từ SUM(transactions) — PHẢI khớp CHÍNH XÁC oracle
      // total_amount của Rolly (43.200.000), không phải một con số cache.
      final linked = await (db.select(
        db.transactions,
      )..where((t) => t.goalId.equals(archived.single.id))).get();
      final savedMinor = -linked.fold<int>(0, (acc, t) => acc + t.amountMinor);
      expect(savedMinor, goal.totalContributedMinor);
    },
  );

  test(
    '🚨 chạy import LẦN HAI trên cùng dữ liệu → không tạo goal trùng, không đếm nhầm liên kết',
    () async {
      await seedPhase9Contributions();

      await repo.importFromRolly(
        goals: [goal],
        contributionSourceIdsByRollyGoalId: contributionMap,
      );
      final secondRun = await repo.importFromRolly(
        goals: [goal],
        contributionSourceIdsByRollyGoalId: contributionMap,
      );

      final summary = secondRun.valueOrNull!;
      expect(
        summary.insertedGoals,
        0,
        reason: 'goal đã có sourceId trùng — không được tạo thêm',
      );
      expect(summary.skippedDuplicateGoals, 1);
      // UPDATE gán lại đúng cùng goalId cho 4 dòng — vẫn "linked" nhưng KHÔNG
      // tạo dòng transactions mới, không nhân đôi liên kết.
      expect(summary.linkedContributions, 4);

      final allGoals = await (db.select(db.savingsGoals)).get();
      expect(
        allGoals,
        hasLength(1),
        reason: 'chạy 2 lần KHÔNG được tạo goal trùng',
      );

      final allTransactions = await db.select(db.transactions).get();
      expect(
        allTransactions,
        hasLength(4),
        reason: 'chạy 2 lần KHÔNG được tạo giao dịch trùng',
      );
    },
  );

  test(
    'mục tiêu KHÔNG có giao dịch đóng góp nào khớp (chưa import Phase 9) → vẫn tạo goal, linkedContributions=0',
    () async {
      final result = await repo.importFromRolly(
        goals: [goal],
        contributionSourceIdsByRollyGoalId: contributionMap,
      );
      final summary = result.valueOrNull!;
      expect(summary.insertedGoals, 1);
      expect(summary.linkedContributions, 0);
    },
  );
}
