import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../core/result/result.dart';
import '../../features/savings/domain/savings_goal_progress.dart';
import '../../features/settings/import/domain/rolly_savings_parser.dart';
import '../db/database.dart';

/// Kết quả import lịch sử tiết kiệm Rolly (Phase 19) — [linkedContributions]
/// đếm số giao dịch CÓ `sourceId` khớp vừa được gán/giữ nguyên `goalId`
/// trong lần chạy này (kể cả khi mục tiêu đã tồn tại từ lần import trước).
class RollySavingsImportSummary {
  const RollySavingsImportSummary({
    required this.insertedGoals,
    required this.skippedDuplicateGoals,
    required this.linkedContributions,
  });

  final int insertedGoals;
  final int skippedDuplicateGoals;
  final int linkedContributions;
}

/// Tiến độ mục tiêu tiết kiệm LUÔN tính bằng SQL aggregate đối chiếu trực
/// tiếp với `transactions`, KHÔNG BAO GIỜ lưu cột "đã tiết kiệm bao nhiêu" —
/// cùng lý do D7 (số dư): không có cache thì không thể sai, đổi/xoá một
/// giao dịch đóng góp cũ tự động phản ánh đúng ở lần watch kế tiếp.
class SavingsGoalRepository {
  SavingsGoalRepository(this._db);

  final AppDatabase _db;

  Stream<List<SavingsGoal>> watchActive() {
    final query = _db.select(_db.savingsGoals)
      ..where((g) => g.isArchived.equals(false))
      ..orderBy([(g) => OrderingTerm.asc(g.id)]);
    return query.watch();
  }

  Stream<List<SavingsGoal>> watchArchived() {
    final query = _db.select(_db.savingsGoals)
      ..where((g) => g.isArchived.equals(true))
      ..orderBy([(g) => OrderingTerm.asc(g.id)]);
    return query.watch();
  }

  /// Một dòng cho MỖI mục tiêu active, JOIN sẵn `SUM(amountMinor)` các giao
  /// dịch gắn `goalId` — LEFT JOIN để mục tiêu chưa có đóng góp nào vẫn hiện
  /// (saved = 0), cùng kỹ thuật `WalletRepository.watchActiveBalances`.
  Stream<List<SavingsGoalProgress>> watchActiveWithProgress() {
    final g = _db.savingsGoals;
    final t = _db.transactions;
    final sumExpr = t.amountMinor.sum();

    final query =
        _db.select(g).join([leftOuterJoin(t, t.goalId.equalsExp(g.id))])
          ..addColumns([sumExpr])
          ..where(g.isArchived.equals(false))
          ..groupBy([g.id])
          ..orderBy([OrderingTerm.asc(g.id)]);

    return query.watch().map(
      (rows) => rows.map((row) {
        return SavingsGoalProgress(
          goal: row.readTable(g),
          savedMinor: -(row.read(sumExpr) ?? 0),
        );
      }).toList(),
    );
  }

  Future<Result<int, AppError>> insert({
    required String name,
    required Money targetAmount,
    DateTime? targetDate,
  }) async {
    try {
      final id = await _db
          .into(_db.savingsGoals)
          .insert(
            SavingsGoalsCompanion.insert(
              name: name,
              targetAmountMinor: targetAmount.minorUnits,
              currency: targetAmount.currency,
              currencyScale: targetAmount.currencyScale,
              targetDate: Value(targetDate),
            ),
          );
      return Ok(id);
    } catch (e) {
      final error = AppError('Không tạo được mục tiêu tiết kiệm.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  Future<Result<void, AppError>> update({
    required int id,
    required String name,
    required Money targetAmount,
    DateTime? targetDate,
  }) async {
    try {
      await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(id))).write(
        SavingsGoalsCompanion(
          name: Value(name),
          targetAmountMinor: Value(targetAmount.minorUnits),
          currency: Value(targetAmount.currency),
          currencyScale: Value(targetAmount.currencyScale),
          targetDate: Value(targetDate),
        ),
      );
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không sửa được mục tiêu tiết kiệm.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// Lưu trữ/khôi phục — KHÔNG BAO GIỜ xoá cứng một mục tiêu (đã có giao
  /// dịch tham chiếu qua FK `transactions.goalId`, giống `wallets`/`categories`).
  Future<Result<void, AppError>> setArchived(int id, bool archived) async {
    try {
      await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(id))).write(
        SavingsGoalsCompanion(isArchived: Value(archived)),
      );
      return const Ok(null);
    } catch (e) {
      final error = AppError(
        'Không cập nhật được trạng thái mục tiêu.',
        cause: e,
      );
      await _logError(error);
      return Err(error);
    }
  }

  /// Tập con `sourceId` (Phase 19) ĐÃ TỒN TẠI — nguồn cho preview trước khi
  /// commit, cùng vai trò `TransactionRepository.findExistingSourceIds`.
  Future<Set<String>> findExistingGoalSourceIds(
    Iterable<String> sourceIds,
  ) async {
    final ids = sourceIds.toList();
    if (ids.isEmpty) return {};
    final rows = await (_db.select(
      _db.savingsGoals,
    )..where((g) => g.sourceId.isIn(ids))).get();
    return rows.map((r) => r.sourceId!).toSet();
  }

  /// Import idempotent lịch sử tiết kiệm Rolly (Phase 19) — cùng mẫu
  /// `TransactionRepository.insertImportBatch` (Phase 9): tính trước
  /// `sourceId` nào ĐÃ có trong DB rồi mới ghi, KHÔNG dựa vào UNIQUE index
  /// tự chặn lúc insert. [contributionSourceIdsByRollyGoalId] gắn `goalId`
  /// NGƯỢC vào các giao dịch Phase 9 đã import từ trước (khớp qua
  /// `transactions.sourceId`) — chạy lại nhiều lần vẫn an toàn vì đây là
  /// UPDATE gán cùng một giá trị, không phải INSERT.
  Future<Result<RollySavingsImportSummary, AppError>> importFromRolly({
    required List<StagedRollySavingsGoal> goals,
    required Map<int, List<String>> contributionSourceIdsByRollyGoalId,
  }) async {
    try {
      final sourceIds = goals.map((g) => g.sourceId).toList();
      final existingRows = sourceIds.isEmpty
          ? <SavingsGoal>[]
          : await (_db.select(
              _db.savingsGoals,
            )..where((g) => g.sourceId.isIn(sourceIds))).get();
      final existingIdBySourceId = {
        for (final row in existingRows) row.sourceId!: row.id,
      };

      var inserted = 0;
      var linkedContributions = 0;

      await _db.transaction(() async {
        for (final goal in goals) {
          var goalId = existingIdBySourceId[goal.sourceId];
          if (goalId == null) {
            goalId = await _db
                .into(_db.savingsGoals)
                .insert(
                  SavingsGoalsCompanion.insert(
                    name: goal.name,
                    targetAmountMinor: goal.targetAmountMinor,
                    currency: goal.currency,
                    currencyScale: goal.currencyScale,
                    targetDate: Value(goal.targetDate),
                    isArchived: Value(goal.isArchived),
                    sourceId: Value(goal.sourceId),
                  ),
                );
            inserted++;
          }

          final contributionSourceIds =
              contributionSourceIdsByRollyGoalId[goal.rollyGoalId];
          if (contributionSourceIds == null || contributionSourceIds.isEmpty)
            continue;
          final result =
              await (_db.update(_db.transactions)
                    ..where((t) => t.sourceId.isIn(contributionSourceIds)))
                  .write(TransactionsCompanion(goalId: Value(goalId)));
          linkedContributions += result;
        }
      });

      return Ok(
        RollySavingsImportSummary(
          insertedGoals: inserted,
          skippedDuplicateGoals: goals.length - inserted,
          linkedContributions: linkedContributions,
        ),
      );
    } catch (e) {
      final error = AppError('Import tiết kiệm Rolly thất bại.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  Future<void> _logError(AppError error) async {
    await _db
        .into(_db.appEvents)
        .insert(
          AppEventsCompanion.insert(
            level: 'error',
            message: error.message,
            contextJson: Value(error.cause?.toString()),
          ),
        );
  }
}
