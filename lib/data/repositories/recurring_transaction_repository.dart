import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../core/result/result.dart';
import '../../features/settings/recurring/domain/recurring_frequency.dart';
import '../db/database.dart';

/// Mẫu giao dịch định kỳ (Phase 12) — CHỈ quản lý mẫu + lịch nhắc, KHÔNG bao
/// giờ tự ghi vào `transactions` (xem docs/decisions.md § Phase 12 "Nhắc
/// định kỳ CHỈ là thông báo").
class RecurringTransactionRepository {
  RecurringTransactionRepository(this._db);

  final AppDatabase _db;

  Stream<List<RecurringTransaction>> watchActive() {
    final query = _db.select(_db.recurringTransactions)
      ..where((r) => r.isActive.equals(true))
      ..orderBy([(r) => OrderingTerm.asc(r.nextOccurrenceDate)]);
    return query.watch();
  }

  Future<Result<void, AppError>> insert({
    required int? categoryId,
    required Money amount,
    required String? note,
    required RecurringFrequency frequency,
    required DateTime nextOccurrenceDate,
  }) async {
    try {
      await _db
          .into(_db.recurringTransactions)
          .insert(
            RecurringTransactionsCompanion.insert(
              categoryId: Value(categoryId),
              amountMinor: amount.minorUnits,
              currency: amount.currency,
              currencyScale: amount.currencyScale,
              note: Value(note),
              frequency: frequency.dbValue,
              nextOccurrenceDate: nextOccurrenceDate,
            ),
          );
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không lưu được giao dịch định kỳ.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// Đẩy `nextOccurrenceDate` sang kỳ kế tiếp theo `frequency` của chính
  /// dòng đó — con trỏ lịch trình, không phải cache (xem docs/decisions.md).
  Future<Result<void, AppError>> advanceToNextOccurrence(int id) async {
    try {
      final row = await (_db.select(
        _db.recurringTransactions,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (row == null) return const Ok(null);

      final next = computeNextOccurrence(
        row.nextOccurrenceDate,
        RecurringFrequency.fromDbValue(row.frequency),
      );
      await (_db.update(
        _db.recurringTransactions,
      )..where((r) => r.id.equals(id))).write(
        RecurringTransactionsCompanion(nextOccurrenceDate: Value(next)),
      );
      return const Ok(null);
    } catch (e) {
      final error = AppError(
        'Không cập nhật được kỳ tới của giao dịch định kỳ.',
        cause: e,
      );
      await _logError(error);
      return Err(error);
    }
  }

  Future<Result<void, AppError>> setActive(int id, bool active) async {
    try {
      await (_db.update(_db.recurringTransactions)
            ..where((r) => r.id.equals(id)))
          .write(RecurringTransactionsCompanion(isActive: Value(active)));
      return const Ok(null);
    } catch (e) {
      final error = AppError(
        'Không cập nhật được trạng thái giao dịch định kỳ.',
        cause: e,
      );
      await _logError(error);
      return Err(error);
    }
  }

  Future<Result<void, AppError>> delete(int id) async {
    try {
      await (_db.delete(
        _db.recurringTransactions,
      )..where((r) => r.id.equals(id))).go();
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không xoá được giao dịch định kỳ.', cause: e);
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
