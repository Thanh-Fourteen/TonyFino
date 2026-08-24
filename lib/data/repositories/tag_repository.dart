import 'package:drift/drift.dart';

import '../../core/result/result.dart';
import '../db/database.dart';

/// Thẻ (Phase 17) — ĐỘC LẬP với cây danh mục (`CategoryRepository`), không
/// có `isArchived`/lưu trữ (v1 chưa cần, xoá cứng đủ dùng — số lượng thẻ cá
/// nhân thường nhỏ, khác 12+ danh mục có sẵn dữ liệu lịch sử cần giữ).
class TagRepository {
  TagRepository(this._db);

  final AppDatabase _db;

  Stream<List<Tag>> watchAll() {
    return (_db.select(
      _db.tags,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Stream<List<Tag>> watchForTransaction(int transactionId) {
    final query = _db.select(_db.tags).join([
      innerJoin(
        _db.transactionTags,
        _db.transactionTags.tagId.equalsExp(_db.tags.id),
      ),
    ])..where(_db.transactionTags.transactionId.equals(transactionId));
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_db.tags)).toList(),
    );
  }

  /// Snapshot MỘT LẦN — dùng lúc `TransactionFormSheet` mở ở chế độ Sửa,
  /// cùng lý do `TransactionRepository.getLinesFor` (Phase 14): một
  /// `Stream` tạo trực tiếp trong `initState` không đáng tin cậy hoàn tất
  /// trong `pumpAndSettle` của widget test.
  Future<List<Tag>> getForTransaction(int transactionId) {
    final query = _db.select(_db.tags).join([
      innerJoin(
        _db.transactionTags,
        _db.transactionTags.tagId.equalsExp(_db.tags.id),
      ),
    ])..where(_db.transactionTags.transactionId.equals(transactionId));
    return query.get().then(
      (rows) => rows.map((row) => row.readTable(_db.tags)).toList(),
    );
  }

  Future<Result<int, AppError>> insert({
    required String name,
    required int categoryColorId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(AppError('Nhập tên thẻ'));
    }
    try {
      final id = await _db
          .into(_db.tags)
          .insert(
            TagsCompanion.insert(
              name: trimmed,
              categoryColorId: categoryColorId,
            ),
          );
      return Ok(id);
    } catch (e) {
      final error = AppError(
        'Không tạo được thẻ — có thể tên đã tồn tại.',
        cause: e,
      );
      await _logError(error);
      return Err(error);
    }
  }

  Future<Result<void, AppError>> update({
    required int id,
    required String name,
    required int categoryColorId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(AppError('Nhập tên thẻ'));
    }
    try {
      await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
        TagsCompanion(
          name: Value(trimmed),
          categoryColorId: Value(categoryColorId),
        ),
      );
      return const Ok(null);
    } catch (e) {
      final error = AppError(
        'Không sửa được thẻ — có thể tên đã tồn tại.',
        cause: e,
      );
      await _logError(error);
      return Err(error);
    }
  }

  /// Xoá thẻ + mọi dòng nối `transaction_tags` tham chiếu nó. KHÔNG dựa vào
  /// cascade DB (app chưa bật `PRAGMA foreign_keys`, xem `tables.dart`) —
  /// dọn tường minh trong CÙNG một transaction, không để lại dòng nối mồ côi.
  Future<Result<void, AppError>> delete(int id) async {
    try {
      await _db.transaction(() async {
        await (_db.delete(
          _db.transactionTags,
        )..where((t) => t.tagId.equals(id))).go();
        await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
      });
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không xoá được thẻ.', cause: e);
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
