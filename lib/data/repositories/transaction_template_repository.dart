import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../core/result/result.dart';
import '../db/database.dart';

/// Mẫu giao dịch có tên (Phase 14) — CRUD đơn giản, KHÔNG có khái niệm lưu
/// trữ (khác `wallets`/`categories`): xoá là xoá thật, vì không có gì tham
/// chiếu ngược từ `transactions` về một mẫu (xem `TransactionTemplates` ở
/// `tables.dart`) — sửa/xoá một mẫu không thể nào ảnh hưởng giao dịch đã tạo
/// từ nó trước đây, đúng theo cấu trúc bảng, không cần logic riêng để đảm
/// bảo điều đó.
class TransactionTemplateRepository {
  TransactionTemplateRepository(this._db);

  final AppDatabase _db;

  Stream<List<TransactionTemplate>> watchAll() {
    final query = _db.select(_db.transactionTemplates)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch();
  }

  /// Snapshot MỘT LẦN — dùng cho "Áp dụng mẫu nhanh" (mở từ FAB nhấn giữ ở
  /// `TransactionsScreen`), một lần đọc rời rạc lúc mở sheet, không cần
  /// stream sống. Cùng lý do tách [getLinesFor]/`watchLinesFor` khỏi nhau ở
  /// `TransactionRepository` (Phase 14) — một `Future` một lần đáng tin cậy
  /// hơn `ref.read(provider.future)`/`Stream.first` gọi rời rạc ngoài
  /// `build()`, không qua `ref.watch` nào giữ subscription sống.
  Future<List<TransactionTemplate>> getAll() {
    final query = _db.select(_db.transactionTemplates)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.get();
  }

  Future<Result<int, AppError>> insert({
    required String name,
    required Money amount,
    int? categoryId,
    String? note,
  }) async {
    try {
      final id = await _db
          .into(_db.transactionTemplates)
          .insert(
            TransactionTemplatesCompanion.insert(
              name: name,
              amountMinor: amount.minorUnits,
              currency: amount.currency,
              currencyScale: amount.currencyScale,
              categoryId: Value(categoryId),
              note: Value(note),
            ),
          );
      return Ok(id);
    } catch (e) {
      final error = AppError('Không lưu được mẫu giao dịch.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  Future<Result<void, AppError>> update({
    required int id,
    required String name,
    required Money amount,
    int? categoryId,
    String? note,
  }) async {
    try {
      await (_db.update(
        _db.transactionTemplates,
      )..where((t) => t.id.equals(id))).write(
        TransactionTemplatesCompanion(
          name: Value(name),
          amountMinor: Value(amount.minorUnits),
          currency: Value(amount.currency),
          currencyScale: Value(amount.currencyScale),
          categoryId: Value(categoryId),
          note: Value(note),
        ),
      );
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không sửa được mẫu giao dịch.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  Future<Result<void, AppError>> delete(int id) async {
    try {
      await (_db.delete(
        _db.transactionTemplates,
      )..where((t) => t.id.equals(id))).go();
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không xoá được mẫu giao dịch.', cause: e);
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
