// Tách giao dịch (Phase 14) — kiểm ở tầng `TransactionRepository`: validate
// tổng dòng con, `categoryId` cha bị null hoá khi tách, ba trạng thái của
// tham số `lines` trong `update()` (absent/rỗng/đầy), và `delete()` dọn sạch
// dòng con theo (không mồ côi hàng trong `transaction_lines`).
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late int cat1;
  late int cat2;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    repo = TransactionRepository(db);
    final categories = await db.select(db.categories).get();
    cat1 = categories[0].id;
    cat2 = categories[1].id;
    walletId = (await db.select(db.wallets).get()).first.id;
  });
  tearDown(() => db.close());

  test(
    'insert với lines: tổng khớp → thành công, categoryId cha = null, 2 dòng con được ghi',
    () async {
      final result = await repo.insert(
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        categoryId: cat1, // bị bỏ qua vì có lines
        lines: [
          TransactionLineInput(categoryId: cat1, amountMinor: -10000),
          TransactionLineInput(categoryId: cat2, amountMinor: -20000),
        ],
      );

      expect(result.isOk, isTrue);
      final id = result.when(
        ok: (id) => id,
        err: (_) => throw StateError('unreachable'),
      );

      final parent = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(parent.categoryId, isNull);

      final lines = await repo.watchLinesFor(id).first;
      expect(lines, hasLength(2));
      expect(lines.map((l) => l.amountMinor).toSet(), {-10000, -20000});
    },
  );

  test(
    'insert với lines: tổng LỆCH → Err rõ ràng, KHÔNG ghi giao dịch cha lẫn dòng con',
    () async {
      final result = await repo.insert(
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        lines: [
          TransactionLineInput(categoryId: cat1, amountMinor: -10000),
          TransactionLineInput(
            categoryId: cat2,
            amountMinor: -15000,
          ), // tổng -25000 ≠ -30000
        ],
      );

      expect(result.isErr, isTrue);
      final all = await db.select(db.transactions).get();
      expect(all, isEmpty);
      final allLines = await db.select(db.transactionLines).get();
      expect(allLines, isEmpty);
    },
  );

  test(
    'insert KHÔNG có lines — hành vi cũ giữ nguyên, categoryId cha giữ đúng giá trị truyền vào',
    () async {
      final result = await repo.insert(
        amount: Money.vnd(-5000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        categoryId: cat1,
      );
      final id = result.when(
        ok: (id) => id,
        err: (_) => throw StateError('unreachable'),
      );
      final parent = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(parent.categoryId, cat1);
      expect(await repo.watchLinesFor(id).first, isEmpty);
    },
  );

  test(
    'update: lines Value.absent (không truyền) — KHÔNG đụng tới dòng con hiện có',
    () async {
      final insertResult = await repo.insert(
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        lines: [
          TransactionLineInput(categoryId: cat1, amountMinor: -10000),
          TransactionLineInput(categoryId: cat2, amountMinor: -20000),
        ],
      );
      final id = insertResult.when(
        ok: (id) => id,
        err: (_) => throw StateError('unreachable'),
      );

      // Giả lập call site không biết gì về tách dòng (như
      // `QuickAddController.correctDate`) — chỉ sửa ngày, không truyền `lines`.
      final updateResult = await repo.update(
        id: id,
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 11),
        updatedAt: DateTime(2026, 8, 11),
      );
      expect(updateResult.isOk, isTrue);
      expect(await repo.watchLinesFor(id).first, hasLength(2));
    },
  );

  test(
    'update: lines Value([]) — bỏ tách, xoá hết dòng con, quay về categoryId đơn',
    () async {
      final insertResult = await repo.insert(
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        lines: [
          TransactionLineInput(categoryId: cat1, amountMinor: -10000),
          TransactionLineInput(categoryId: cat2, amountMinor: -20000),
        ],
      );
      final id = insertResult.when(
        ok: (id) => id,
        err: (_) => throw StateError('unreachable'),
      );

      final updateResult = await repo.update(
        id: id,
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
        categoryId: cat1,
        lines: const Value([]),
      );
      expect(updateResult.isOk, isTrue);
      expect(await repo.watchLinesFor(id).first, isEmpty);
      final parent = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(parent.categoryId, cat1);
    },
  );

  test(
    'update: lines Value([...]) mới — THAY TOÀN BỘ dòng con cũ, không cộng dồn',
    () async {
      final insertResult = await repo.insert(
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        lines: [TransactionLineInput(categoryId: cat1, amountMinor: -30000)],
      );
      final id = insertResult.when(
        ok: (id) => id,
        err: (_) => throw StateError('unreachable'),
      );

      final updateResult = await repo.update(
        id: id,
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
        lines: Value([
          TransactionLineInput(categoryId: cat1, amountMinor: -12000),
          TransactionLineInput(categoryId: cat2, amountMinor: -18000),
        ]),
      );
      expect(updateResult.isOk, isTrue);
      final lines = await repo.watchLinesFor(id).first;
      expect(lines, hasLength(2));
      expect(lines.map((l) => l.amountMinor).toSet(), {-12000, -18000});
    },
  );

  test(
    'update: lines mới TỔNG LỆCH → Err, dòng con CŨ giữ nguyên (không xoá dở dang)',
    () async {
      final insertResult = await repo.insert(
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        lines: [TransactionLineInput(categoryId: cat1, amountMinor: -30000)],
      );
      final id = insertResult.when(
        ok: (id) => id,
        err: (_) => throw StateError('unreachable'),
      );

      final updateResult = await repo.update(
        id: id,
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
        lines: Value([
          TransactionLineInput(categoryId: cat2, amountMinor: -999),
        ]),
      );
      expect(updateResult.isErr, isTrue);
      final lines = await repo.watchLinesFor(id).first;
      expect(lines, hasLength(1));
      expect(lines.single.amountMinor, -30000);
    },
  );

  test(
    'delete: xoá giao dịch tách dòng dọn sạch cả transaction_lines, không mồ côi hàng',
    () async {
      final insertResult = await repo.insert(
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        lines: [
          TransactionLineInput(categoryId: cat1, amountMinor: -10000),
          TransactionLineInput(categoryId: cat2, amountMinor: -20000),
        ],
      );
      final id = insertResult.when(
        ok: (id) => id,
        err: (_) => throw StateError('unreachable'),
      );

      final deleteResult = await repo.delete(id);
      expect(deleteResult.isOk, isTrue);
      final remainingLines = await db.select(db.transactionLines).get();
      expect(remainingLines, isEmpty);
    },
  );

  test(
    'watchAllWithCategory: linesCount phản ánh đúng số dòng con, 0 cho giao dịch không tách',
    () async {
      await repo.insert(
        amount: Money.vnd(-1000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        categoryId: cat1,
      );
      await repo.insert(
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        lines: [
          TransactionLineInput(categoryId: cat1, amountMinor: -10000),
          TransactionLineInput(categoryId: cat2, amountMinor: -20000),
        ],
      );

      final all = await repo.watchAllWithCategory().first;
      final byAmount = {for (final t in all) t.transaction.amountMinor: t};
      expect(byAmount[-1000]!.linesCount, 0);
      expect(byAmount[-1000]!.isSplit, isFalse);
      expect(byAmount[-30000]!.linesCount, 2);
      expect(byAmount[-30000]!.isSplit, isTrue);
    },
  );
}
