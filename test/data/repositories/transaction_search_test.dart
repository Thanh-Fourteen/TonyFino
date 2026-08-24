// Tìm kiếm FTS5 (Phase 17) — bảng ảo `transactions_fts` khai qua
// `transactions_fts.drift` (drift's Dart Table DSL không có API cho virtual
// table, xem docs/decisions.md § Phase 17 "Tìm kiếm FTS5"), đồng bộ tường
// minh ở `TransactionRepository` (không phải external-content + trigger).
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    repo = TransactionRepository(db);
    walletId = (await db.select(db.wallets).get()).first.id;
  });
  tearDown(() => db.close());

  test(
    'tìm theo từ khoá không dấu — khớp cả note CÓ dấu lẫn KHÔNG dấu',
    () async {
      await repo.insert(
        amount: Money.vnd(-35000),
        occurredAt: DateTime.utc(2026, 8, 20),
        walletId: walletId,
        note: 'ăn trưa bún bò',
      );
      await repo.insert(
        amount: Money.vnd(-50000),
        occurredAt: DateTime.utc(2026, 8, 21),
        walletId: walletId,
        note: 'đổ xăng',
      );

      final byUnaccented = await repo.watchSearch('an trua').first;
      expect(byUnaccented, hasLength(1));
      expect(byUnaccented.single.transaction.note, 'ăn trưa bún bò');

      final byAccented = await repo.watchSearch('ăn trưa').first;
      expect(byAccented, hasLength(1));
      expect(byAccented.single.transaction.note, 'ăn trưa bún bò');
    },
  );

  test('khớp TIỀN TỐ — gõ dở từ vẫn ra kết quả', () async {
    await repo.insert(
      amount: Money.vnd(-100000),
      occurredAt: DateTime.utc(2026, 8, 20),
      walletId: walletId,
      note: 'cắt tóc',
    );

    final results = await repo.watchSearch('cat').first;
    expect(results, hasLength(1));
  });

  test('không khớp gì → danh sách rỗng, không lỗi', () async {
    await repo.insert(
      amount: Money.vnd(-100000),
      occurredAt: DateTime.utc(2026, 8, 20),
      walletId: walletId,
      note: 'cắt tóc',
    );

    expect(await repo.watchSearch('xyz không tồn tại').first, isEmpty);
  });

  test(
    'chuỗi rỗng/toàn khoảng trắng → rỗng ngay, không MATCH \'\' (cú pháp FTS5 không hợp lệ)',
    () async {
      expect(await repo.watchSearch('').first, isEmpty);
      expect(await repo.watchSearch('   ').first, isEmpty);
    },
  );

  test('giao dịch KHÔNG có ghi chú không khớp bất kỳ từ khoá nào', () async {
    await repo.insert(
      amount: Money.vnd(-20000),
      occurredAt: DateTime.utc(2026, 8, 20),
      walletId: walletId,
    );

    expect(await repo.watchSearch('gì đó').first, isEmpty);
  });

  test(
    '🚨 sửa ghi chú → kết quả tìm kiếm cập nhật theo, không còn khớp từ khoá cũ',
    () async {
      final insertResult = await repo.insert(
        amount: Money.vnd(-30000),
        occurredAt: DateTime.utc(2026, 8, 20),
        walletId: walletId,
        note: 'cà phê sáng',
      );
      final id = insertResult.when(
        ok: (v) => v,
        err: (e) => throw Exception('$e'),
      );

      expect(await repo.watchSearch('ca phe').first, hasLength(1));

      await repo.update(
        id: id,
        amount: Money.vnd(-30000),
        occurredAt: DateTime.utc(2026, 8, 20),
        updatedAt: DateTime.utc(2026, 8, 20),
        note: 'trà sữa chiều',
      );

      expect(await repo.watchSearch('ca phe').first, isEmpty);
      expect(await repo.watchSearch('tra sua').first, hasLength(1));
    },
  );

  test(
    '🚨 xoá giao dịch → biến mất khỏi kết quả tìm kiếm, không để lại chỉ mục mồ côi',
    () async {
      final insertResult = await repo.insert(
        amount: Money.vnd(-30000),
        occurredAt: DateTime.utc(2026, 8, 20),
        walletId: walletId,
        note: 'sửa xe máy',
      );
      final id = insertResult.when(
        ok: (v) => v,
        err: (e) => throw Exception('$e'),
      );
      expect(await repo.watchSearch('sua xe').first, hasLength(1));

      await repo.delete(id);
      expect(await repo.watchSearch('sua xe').first, isEmpty);
    },
  );

  test(
    'nhiều từ khoá — ĐỀU phải khớp (AND), không phải khớp một trong hai (OR)',
    () async {
      await repo.insert(
        amount: Money.vnd(-35000),
        occurredAt: DateTime.utc(2026, 8, 20),
        walletId: walletId,
        note: 'ăn trưa bún bò',
      );
      await repo.insert(
        amount: Money.vnd(-50000),
        occurredAt: DateTime.utc(2026, 8, 21),
        walletId: walletId,
        note: 'ăn sáng phở bò',
      );

      final results = await repo.watchSearch('an bun').first;
      expect(results, hasLength(1));
      expect(results.single.transaction.note, 'ăn trưa bún bò');
    },
  );

  test(
    '🚨 migration từ trước Phase 17: ghi chú cũ (chèn thẳng SQL, note_ascii có sẵn) vẫn tìm được nhờ backfill',
    () async {
      // Mô phỏng dữ liệu ĐÃ TỒN TẠI trước khi FTS5 ra đời (vd import Rolly cũ)
      // — chèn thẳng qua companion như mọi giao dịch khác, KHÔNG qua
      // `TransactionRepository.insert` (đường đó luôn đồng bộ FTS5 mới) — bài
      // test migration thật (`migration_test.dart`) đã chứng minh bước
      // `from7To8` backfill đúng cho DB nâng cấp; test này xác nhận GIẢ ĐỊNH
      // đó bằng cách backfill thủ công cùng cách rồi tìm lại.
      final id = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -35000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime.utc(2026, 3, 1),
              walletId: walletId,
              note: const Value('cà phê sữa đá'),
              noteAscii: const Value('ca phe sua da'),
            ),
          );
      await db
          .into(db.transactionsFts)
          .insert(
            TransactionsFtsCompanion.insert(
              noteAscii: 'ca phe sua da',
              transactionId: id.toString(),
            ),
          );

      final results = await repo.watchSearch('ca phe').first;
      expect(results, hasLength(1));
    },
  );
}
