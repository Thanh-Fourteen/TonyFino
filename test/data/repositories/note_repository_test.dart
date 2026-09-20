import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/note_repository.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late NoteRepository repo;

  setUp(() {
    db = openTestDatabase();
    repo = NoteRepository(db);
  });
  tearDown(() => db.close());

  test('ghim lên đầu, rồi mới SỬA gần nhất trước', () async {
    await repo.insert(title: 'A', body: '', now: DateTime(2026, 9, 1));
    final b = (await repo.insert(
      title: 'B',
      body: '',
      now: DateTime(2026, 9, 2),
    )).when(ok: (id) => id, err: (e) => throw e);
    final c = (await repo.insert(
      title: 'C',
      body: '',
      now: DateTime(2026, 9, 3),
    )).when(ok: (id) => id, err: (e) => throw e);

    expect(
      [for (final n in await repo.watchAll().first) n.title],
      ['C', 'B', 'A'],
    );

    await repo.setPinned(id: b, pinned: true);
    expect(
      [for (final n in await repo.watchAll().first) n.title],
      ['B', 'C', 'A'],
    );

    // Ghim KHÔNG phải sửa nội dung: `updatedAt` của B phải giữ nguyên.
    final pinned = (await repo.watchAll().first).first;
    expect(pinned.updatedAt, DateTime(2026, 9, 2));

    await repo.update(id: c, title: 'C2', body: 'x', now: DateTime(2026, 9, 9));
    await repo.setPinned(id: b, pinned: false);
    expect(
      [for (final n in await repo.watchAll().first) n.title],
      ['C2', 'B', 'A'],
    );
  });

  test('xoá thì mất hẳn', () async {
    final id = (await repo.insert(
      title: 'tạm',
      body: '',
      now: DateTime(2026, 9, 1),
    )).when(ok: (id) => id, err: (e) => throw e);
    await repo.delete(id);
    expect(await repo.watchAll().first, isEmpty);
  });

  group('nhãn hiển thị', () {
    test('có tiêu đề thì dùng tiêu đề', () {
      expect(noteDisplayTitle('Cần mua', 'sữa\nbánh'), 'Cần mua');
      expect(notePreview('Cần mua', 'sữa\nbánh'), 'sữa · bánh');
    });

    test('không tiêu đề thì lấy DÒNG ĐẦU, và không lặp lại nó ở phần xem '
        'trước', () {
      expect(noteDisplayTitle('', '  sữa\nbánh mì\n'), 'sữa');
      expect(notePreview('', '  sữa\nbánh mì\n'), 'bánh mì');
    });

    test('rỗng hoàn toàn vẫn có nhãn đọc được', () {
      expect(noteDisplayTitle('', '   '), 'Ghi chú trống');
      expect(notePreview('', '   '), '');
    });
  });
}
