import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/savings_goal_repository.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';

import '../../support/open_test_database.dart';

/// 🚨 "Hoàn tác" phải trả lại giao dịch NGUYÊN VẸN, không phải gần đúng.
///
/// Đo trên máy thật TRƯỚC khi sửa: nạp 1tr vào quỹ (ví −11tr, quỹ 6tr) → xoá →
/// Hoàn tác → ví vẫn −11tr nhưng quỹ tụt về 5tr. Một triệu biến mất khỏi sổ và
/// hiện lại thành một khoản chi "Chưa phân loại" trong báo cáo, vì hàm undo
/// chèn lại đúng năm cột và bỏ rơi `goalId`.
void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    repo = TransactionRepository(db);
    walletId = await defaultWalletId(db);
  });
  tearDown(() => db.close());

  Future<Transaction> onlyTransaction() async =>
      (await repo.watchAll().first).single;

  test(
    '🚨 chụp → xoá → khôi phục một khoản NẠP QUỸ giữ nguyên `goalId` — nếu '
    'không thì ví đã trừ tiền mà quỹ không tăng, tức là tiền biến mất khỏi sổ',
    () async {
      final goals = SavingsGoalRepository(db);
      final goalId = (await goals.insert(
        name: 'Mua nha',
        targetAmount: const Money.vnd(50000000),
      )).when(ok: (id) => id, err: (e) => fail(e.message));

      await repo.insert(
        amount: const Money.vnd(-1000000),
        occurredAt: DateTime(2026, 9, 7),
        walletId: walletId,
        goalId: goalId,
      );
      final original = await onlyTransaction();
      expect(
        (await goals.watchActiveWithProgress().first).single.savedMinor,
        1000000,
      );

      final snapshot = await repo.captureForUndo(original.id);
      await repo.delete(original.id);
      expect(
        (await goals.watchActiveWithProgress().first).single.savedMinor,
        0,
        reason: 'xoá xong quỹ về 0 — phần này vốn đã đúng từ trước',
      );

      await repo.restore(snapshot!);

      final restored = await onlyTransaction();
      expect(restored.goalId, goalId);
      expect(restored.amountMinor, -1000000);
      expect(
        (await goals.watchActiveWithProgress().first).single.savedMinor,
        1000000,
        reason: 'tiến độ quỹ phải hồi lại y như trước khi xoá',
      );
    },
  );

  test('khôi phục trả lại cả DÒNG CON và THẺ — hai thứ nằm ở bảng khác, bị '
      '`delete()` xoá theo nên phải chụp TRƯỚC khi xoá', () async {
    final tagId = await db
        .into(db.tags)
        .insert(TagsCompanion.insert(name: 'Công tác', categoryColorId: 4));
    final categoryId = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Ăn uống',
            kind: 'expense',
            categoryColorId: 3,
            iconCode: 'restaurant',
            walletId: walletId,
          ),
        );

    await repo.insert(
      amount: const Money.vnd(-100000),
      occurredAt: DateTime(2026, 9, 7),
      walletId: walletId,
      lines: [
        TransactionLineInput(categoryId: categoryId, amountMinor: -60000),
        const TransactionLineInput(categoryId: null, amountMinor: -40000),
      ],
      tagIds: [tagId],
    );
    final original = await onlyTransaction();

    final snapshot = await repo.captureForUndo(original.id);
    await repo.delete(original.id);
    await repo.restore(snapshot!);

    final restored = await onlyTransaction();
    final lines = await repo.getLinesFor(restored.id);
    expect(lines, hasLength(2));
    expect(lines.map((l) => l.amountMinor).toSet(), {-60000, -40000});
    expect(lines.map((l) => l.categoryId).toSet(), {categoryId, null});

    final tagRows = await (db.select(
      db.transactionTags,
    )..where((t) => t.transactionId.equals(restored.id))).get();
    expect(tagRows.map((t) => t.tagId).toList(), [tagId]);
  });

  test('khoản NỢ VAY cũng giữ `debtId` — cùng lỗ hổng, cùng bản sửa', () async {
    final debtId = await db
        .into(db.debts)
        .insert(
          DebtsCompanion.insert(
            counterpartyName: 'Anh Ba',
            kind: 'debt',
            principalMinor: 5000000,
            currency: 'VND',
            currencyScale: 0,
            startDate: DateTime(2026, 9, 1),
          ),
        );
    await repo.insert(
      amount: const Money.vnd(-1000000),
      occurredAt: DateTime(2026, 9, 7),
      walletId: walletId,
      debtId: debtId,
    );
    final original = await onlyTransaction();

    final snapshot = await repo.captureForUndo(original.id);
    await repo.delete(original.id);
    await repo.restore(snapshot!);

    expect((await onlyTransaction()).debtId, debtId);
  });

  test('giao dịch thường (không quỹ, không thẻ, không dòng con) khôi phục đúng '
      'như cũ — bản sửa không được làm hỏng đường đi phổ biến nhất', () async {
    await repo.insert(
      amount: const Money.vnd(-35000),
      occurredAt: DateTime(2026, 9, 7),
      walletId: walletId,
      note: 'ca phe',
    );
    final original = await onlyTransaction();

    final snapshot = await repo.captureForUndo(original.id);
    await repo.delete(original.id);
    expect(await repo.watchAll().first, isEmpty);

    await repo.restore(snapshot!);

    final restored = await onlyTransaction();
    expect(restored.amountMinor, -35000);
    expect(restored.note, 'ca phe');
    expect(restored.goalId, isNull);
    expect(await repo.getLinesFor(restored.id), isEmpty);
  });

  test('chụp một id không tồn tại trả `null`, không ném lỗi', () async {
    expect(await repo.captureForUndo(9999), isNull);
  });
}
