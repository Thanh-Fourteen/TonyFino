import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../core/result/result.dart';
import '../../features/savings/domain/debt_kind.dart';
import '../../features/savings/domain/debt_progress.dart';
import '../db/database.dart';

/// Số dư còn lại của một khoản vay/cho vay LUÔN dẫn xuất từ `principalMinor`
/// (tĩnh, lưu lúc tạo) + SQL aggregate trên `transactions` gắn `debtId` —
/// KHÔNG BAO GIỜ lưu cột "còn nợ bao nhiêu" (D7, cùng triết lý
/// `SavingsGoalRepository`).
class DebtRepository {
  DebtRepository(this._db);

  final AppDatabase _db;

  Stream<List<Debt>> watchActive() {
    final query = _db.select(_db.debts)
      ..where((d) => d.isArchived.equals(false))
      ..orderBy([(d) => OrderingTerm.asc(d.id)]);
    return query.watch();
  }

  Stream<List<Debt>> watchArchived() {
    final query = _db.select(_db.debts)
      ..where((d) => d.isArchived.equals(true))
      ..orderBy([(d) => OrderingTerm.asc(d.id)]);
    return query.watch();
  }

  /// Một dòng cho MỖI khoản active, JOIN sẵn `SUM(amountMinor)` các giao
  /// dịch gắn `debtId` — LEFT JOIN để khoản chưa trả/thu đồng nào vẫn hiện
  /// (contributionsSum = 0, remaining = principal đầy đủ).
  Stream<List<DebtProgress>> watchActiveWithProgress() {
    final d = _db.debts;
    final t = _db.transactions;
    final sumExpr = t.amountMinor.sum();

    final query =
        _db.select(d).join([leftOuterJoin(t, t.debtId.equalsExp(d.id))])
          ..addColumns([sumExpr])
          ..where(d.isArchived.equals(false))
          ..groupBy([d.id])
          ..orderBy([OrderingTerm.asc(d.id)]);

    return query.watch().map(
      (rows) => rows.map((row) {
        return DebtProgress(
          debt: row.readTable(d),
          contributionsSumMinor: row.read(sumExpr) ?? 0,
        );
      }).toList(),
    );
  }

  Future<Result<int, AppError>> insert({
    required String counterpartyName,
    required DebtKind kind,
    required Money principal,
    required DateTime startDate,
  }) async {
    try {
      final id = await _db
          .into(_db.debts)
          .insert(
            DebtsCompanion.insert(
              counterpartyName: counterpartyName,
              kind: kind.dbValue,
              principalMinor: principal.minorUnits,
              currency: principal.currency,
              currencyScale: principal.currencyScale,
              startDate: startDate,
            ),
          );
      return Ok(id);
    } catch (e) {
      final error = AppError('Không tạo được khoản vay/cho vay.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  Future<Result<void, AppError>> update({
    required int id,
    required String counterpartyName,
    required DebtKind kind,
    required Money principal,
    required DateTime startDate,
  }) async {
    try {
      await (_db.update(_db.debts)..where((d) => d.id.equals(id))).write(
        DebtsCompanion(
          counterpartyName: Value(counterpartyName),
          kind: Value(kind.dbValue),
          principalMinor: Value(principal.minorUnits),
          currency: Value(principal.currency),
          currencyScale: Value(principal.currencyScale),
          startDate: Value(startDate),
        ),
      );
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không sửa được khoản vay/cho vay.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// Lưu trữ/khôi phục — KHÔNG BAO GIỜ xoá cứng, cùng lý do `wallets`/
  /// `savings_goals` (đã có giao dịch tham chiếu qua FK).
  Future<Result<void, AppError>> setArchived(int id, bool archived) async {
    try {
      await (_db.update(_db.debts)..where((d) => d.id.equals(id))).write(
        DebtsCompanion(isArchived: Value(archived)),
      );
      return const Ok(null);
    } catch (e) {
      final error = AppError(
        'Không cập nhật được trạng thái khoản vay.',
        cause: e,
      );
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
