import 'package:drift/drift.dart';

import '../../core/result/result.dart';
import '../db/database.dart';

/// Ghi chú tự do (v16). Không có gì thông minh ở đây — chính vì vậy nó mới
/// dùng được: mở ra là gõ.
class NoteRepository {
  NoteRepository(this._db);
  final AppDatabase _db;

  /// Ghim lên đầu, rồi mới nhất trước. `updatedAt` chứ không phải
  /// `createdAt`: ghi chú vừa sửa là ghi chú đang dùng.
  Stream<List<Note>> watchAll() {
    return (_db.select(_db.notes)..orderBy([
          (n) => OrderingTerm.desc(n.isPinned),
          (n) => OrderingTerm.desc(n.updatedAt),
          (n) => OrderingTerm.desc(n.id),
        ]))
        .watch();
  }

  Future<Result<int, AppError>> insert({
    required String title,
    required String body,
    required DateTime now,
  }) async {
    try {
      final id = await _db
          .into(_db.notes)
          .insert(
            NotesCompanion.insert(
              title: Value(title),
              body: Value(body),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return Ok(id);
    } catch (e) {
      return Err(AppError('Không lưu được ghi chú.', cause: e));
    }
  }

  Future<Result<void, AppError>> update({
    required int id,
    required String title,
    required String body,
    required DateTime now,
  }) async {
    try {
      await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(
          title: Value(title),
          body: Value(body),
          updatedAt: Value(now),
        ),
      );
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không sửa được ghi chú.', cause: e));
    }
  }

  /// Ghim/bỏ ghim KHÔNG đụng `updatedAt` — ghim không phải là sửa nội dung,
  /// để nó đẩy ghi chú lên đầu danh sách "mới sửa" là nói sai.
  Future<Result<void, AppError>> setPinned({
    required int id,
    required bool pinned,
  }) async {
    try {
      await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(isPinned: Value(pinned)),
      );
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không ghim được ghi chú.', cause: e));
    }
  }

  Future<Result<void, AppError>> delete(int id) async {
    try {
      await (_db.delete(_db.notes)..where((n) => n.id.equals(id))).go();
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không xoá được ghi chú.', cause: e));
    }
  }
}

/// Nhãn hiện trong danh sách: tiêu đề nếu có, không thì DÒNG ĐẦU của nội
/// dung, không thì một chữ trung tính. Thuần hàm để test không cần DB.
String noteDisplayTitle(String title, String body) {
  final trimmedTitle = title.trim();
  if (trimmedTitle.isNotEmpty) return trimmedTitle;
  for (final line in body.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) {
      return trimmed.length <= 80 ? trimmed : '${trimmed.substring(0, 80)}…';
    }
  }
  return 'Ghi chú trống';
}

/// Phần xem trước dưới nhãn — bỏ đúng dòng đã dùng làm nhãn để không lặp
/// lại y hệt hai dòng liền nhau.
String notePreview(String title, String body) {
  final lines = body.split('\n').map((l) => l.trim()).toList();
  final start = title.trim().isNotEmpty
      ? 0
      : lines.indexWhere((l) => l.isNotEmpty) + 1;
  if (start <= 0 && title.trim().isEmpty) return '';
  return lines.skip(start).where((l) => l.isNotEmpty).join(' · ');
}
