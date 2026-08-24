// Mẫu giao dịch (Phase 14) — CRUD cơ bản + bất biến quan trọng nhất: sửa/xoá
// một mẫu KHÔNG ảnh hưởng giao dịch đã tạo từ mẫu đó trước đây (mẫu chỉ là
// khuôn lúc tạo, không phải tham chiếu sống — không có FK nào từ
// `transactions` trỏ ngược về `transaction_templates`).
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/data/repositories/transaction_template_repository.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late TransactionTemplateRepository repo;
  late int catId;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    repo = TransactionTemplateRepository(db);
    catId = (await db.select(db.categories).get()).first.id;
    walletId = (await db.select(db.wallets).get()).first.id;
  });
  tearDown(() => db.close());

  test('insert rồi watchAll() phát đúng các mẫu vừa thêm', () async {
    await repo.insert(
      name: 'Cà phê sáng',
      amount: Money.vnd(-25000),
      categoryId: catId,
    );
    await repo.insert(
      name: 'Ăn trưa',
      amount: Money.vnd(-50000),
      categoryId: catId,
    );

    final all = await repo.watchAll().first;
    expect(all.map((t) => t.name).toSet(), {'Ăn trưa', 'Cà phê sáng'});
  });

  test('update sửa đúng mẫu, không tạo hàng mới', () async {
    final insertResult = await repo.insert(
      name: 'Cà phê sáng',
      amount: Money.vnd(-25000),
      categoryId: catId,
    );
    final id = insertResult.when(
      ok: (id) => id,
      err: (_) => throw StateError('unreachable'),
    );

    await repo.update(
      id: id,
      name: 'Cà phê',
      amount: Money.vnd(-30000),
      categoryId: catId,
    );

    final all = await repo.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.name, 'Cà phê');
    expect(all.single.amountMinor, -30000);
  });

  test('delete xoá đúng mẫu', () async {
    final insertResult = await repo.insert(
      name: 'Cà phê sáng',
      amount: Money.vnd(-25000),
      categoryId: catId,
    );
    final id = insertResult.when(
      ok: (id) => id,
      err: (_) => throw StateError('unreachable'),
    );

    final result = await repo.delete(id);
    expect(result.isOk, isTrue);
    expect(await repo.watchAll().first, isEmpty);
  });

  test(
    '🚨 sửa/xoá một mẫu KHÔNG ảnh hưởng giao dịch đã tạo từ mẫu đó trước đây '
    '— mẫu chỉ là khuôn lúc tạo, không phải tham chiếu sống',
    () async {
      final insertResult = await repo.insert(
        name: 'Cà phê sáng',
        amount: Money.vnd(-25000),
        categoryId: catId,
        note: 'trước khi sửa',
      );
      final templateId = insertResult.when(
        ok: (id) => id,
        err: (_) => throw StateError('unreachable'),
      );
      final template = (await repo.watchAll().first).single;

      // "Áp dụng mẫu" = đọc snapshot rồi TỰ tạo một giao dịch mới bình
      // thường qua TransactionRepository — không lưu templateId ở đâu cả.
      final txRepo = TransactionRepository(db);
      final txResult = await txRepo.insert(
        amount: Money(
          minorUnits: template.amountMinor,
          currency: template.currency,
          currencyScale: template.currencyScale,
        ),
        occurredAt: DateTime(2026, 8, 20),
        walletId: walletId,
        categoryId: template.categoryId,
        note: template.note,
      );
      final txId = txResult.when(
        ok: (id) => id,
        err: (_) => throw StateError('unreachable'),
      );

      // Sửa mẫu — tên/số tiền/ghi chú đổi hẳn.
      await repo.update(
        id: templateId,
        name: 'Cà phê (đã sửa)',
        amount: Money.vnd(-99999),
        categoryId: catId,
        note: 'đã sửa',
      );
      var tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      expect(tx.amountMinor, -25000);
      expect(tx.note, 'trước khi sửa');

      // Xoá hẳn mẫu — giao dịch đã tạo từ nó vẫn còn nguyên, không bị xoá
      // theo (không có ON DELETE CASCADE nào cả vì không có FK).
      await repo.delete(templateId);
      tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      expect(tx.amountMinor, -25000);
    },
  );
}
