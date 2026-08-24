import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/result/result.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/tag_repository.dart';

import '../../support/open_test_database.dart';

int _unwrap(Result<int, AppError> result) =>
    result.when(ok: (v) => v, err: (e) => throw Exception('$e'));

void main() {
  test(
    'insert rồi watchAll() phát đúng thẻ vừa thêm, sắp theo tên (ASCII, SQLite BINARY collate mặc định)',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TagRepository(db);

      await repo.insert(name: 'Du lịch', categoryColorId: 2);
      await repo.insert(name: 'Công tác', categoryColorId: 0);

      final tags = await repo.watchAll().first;
      expect(tags.map((t) => t.name).toList(), ['Công tác', 'Du lịch']);
    },
  );

  test('tên trùng → lỗi rõ ràng (UNIQUE), không ghi trùng', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = TagRepository(db);

    await repo.insert(name: 'Gia đình', categoryColorId: 0);
    final result = await repo.insert(name: 'Gia đình', categoryColorId: 1);

    expect(result.isErr, isTrue);
    final tags = await db.select(db.tags).get();
    expect(tags, hasLength(1));
  });

  test('tên rỗng sau trim → lỗi, không ghi gì', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = TagRepository(db);

    final result = await repo.insert(name: '   ', categoryColorId: 0);
    expect(result.isErr, isTrue);
    expect(await db.select(db.tags).get(), isEmpty);
  });

  test(
    '🚨 gắn/gỡ thẻ cho giao dịch qua TransactionRepository.update — getForTransaction đọc đúng',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final tagRepo = TagRepository(db);
      final walletId = (await db.select(db.wallets).get()).first.id;

      final tagAId = _unwrap(
        await tagRepo.insert(name: 'A', categoryColorId: 0),
      );
      final tagBId = _unwrap(
        await tagRepo.insert(name: 'B', categoryColorId: 1),
      );

      final transactionId = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -10000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime.utc(2026, 8, 20),
              walletId: walletId,
            ),
          );
      await db
          .into(db.transactionTags)
          .insert(
            TransactionTagsCompanion.insert(
              transactionId: transactionId,
              tagId: tagAId,
            ),
          );
      await db
          .into(db.transactionTags)
          .insert(
            TransactionTagsCompanion.insert(
              transactionId: transactionId,
              tagId: tagBId,
            ),
          );

      final tags = await tagRepo.getForTransaction(transactionId);
      expect(tags.map((t) => t.id).toSet(), {tagAId, tagBId});
    },
  );

  test(
    '🚨 xoá thẻ dọn sạch dòng nối transaction_tags, không để lại tham chiếu mồ côi',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final tagRepo = TagRepository(db);
      final walletId = (await db.select(db.wallets).get()).first.id;

      final tagId = _unwrap(
        await tagRepo.insert(name: 'Tạm', categoryColorId: 0),
      );
      final transactionId = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -10000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime.utc(2026, 8, 20),
              walletId: walletId,
            ),
          );
      await db
          .into(db.transactionTags)
          .insert(
            TransactionTagsCompanion.insert(
              transactionId: transactionId,
              tagId: tagId,
            ),
          );

      final result = await tagRepo.delete(tagId);
      expect(result.isOk, isTrue, reason: '$result');

      expect(await db.select(db.tags).get(), isEmpty);
      expect(await db.select(db.transactionTags).get(), isEmpty);
    },
  );

  test('update sửa đúng tên/màu, không tạo hàng mới', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final tagRepo = TagRepository(db);

    final id = _unwrap(await tagRepo.insert(name: 'Cũ', categoryColorId: 0));
    final result = await tagRepo.update(
      id: id,
      name: 'Mới',
      categoryColorId: 3,
    );
    expect(result.isOk, isTrue, reason: '$result');

    final rows = await db.select(db.tags).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Mới');
    expect(rows.single.categoryColorId, 3);
  });
}
