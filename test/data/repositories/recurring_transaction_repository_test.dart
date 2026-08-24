import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/repositories/recurring_transaction_repository.dart';
import 'package:tonyfino/features/settings/recurring/domain/recurring_frequency.dart';

import '../../support/open_test_database.dart';

void main() {
  test('insert rồi watchActive() phát đúng dòng vừa thêm', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = RecurringTransactionRepository(db);

    final categories = await db.select(db.categories).get();

    final result = await repo.insert(
      categoryId: categories.first.id,
      amount: const Money.vnd(-500000),
      note: 'Tiền nhà',
      frequency: RecurringFrequency.monthly,
      nextOccurrenceDate: DateTime(2026, 9, 1),
    );
    expect(result.isOk, isTrue, reason: '$result');

    final rows = await repo.watchActive().first;
    expect(rows, hasLength(1));
    expect(rows.first.note, 'Tiền nhà');
    expect(rows.first.amountMinor, -500000);
    expect(rows.first.frequency, 'monthly');
    expect(rows.first.isActive, isTrue);
  });

  test(
    'advanceToNextOccurrence đẩy đúng kỳ tới theo frequency của dòng đó',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = RecurringTransactionRepository(db);
      final categories = await db.select(db.categories).get();

      await repo.insert(
        categoryId: categories.first.id,
        amount: const Money.vnd(-500000),
        note: 'Tiền nhà',
        frequency: RecurringFrequency.monthly,
        nextOccurrenceDate: DateTime(2026, 1, 31),
      );
      final inserted = (await repo.watchActive().first).single;

      final result = await repo.advanceToNextOccurrence(inserted.id);
      expect(result.isOk, isTrue, reason: '$result');

      final updated = (await repo.watchActive().first).single;
      // 31/1 hàng tháng → kẹp về 28/2 (2026 không nhuận), không tràn sang 3/3.
      expect(updated.nextOccurrenceDate, DateTime(2026, 2, 28));
    },
  );

  test(
    'setActive(false) làm dòng biến mất khỏi watchActive() nhưng vẫn còn trong DB',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = RecurringTransactionRepository(db);
      final categories = await db.select(db.categories).get();

      await repo.insert(
        categoryId: categories.first.id,
        amount: const Money.vnd(1000000),
        note: 'Lương',
        frequency: RecurringFrequency.monthly,
        nextOccurrenceDate: DateTime(2026, 9, 1),
      );
      final inserted = (await repo.watchActive().first).single;

      final result = await repo.setActive(inserted.id, false);
      expect(result.isOk, isTrue, reason: '$result');
      expect(await repo.watchActive().first, isEmpty);

      final all = await db.select(db.recurringTransactions).get();
      expect(all, hasLength(1));
      expect(all.single.isActive, isFalse);
    },
  );

  test('delete xoá hẳn dòng khỏi DB', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = RecurringTransactionRepository(db);
    final categories = await db.select(db.categories).get();

    await repo.insert(
      categoryId: categories.first.id,
      amount: const Money.vnd(-100000),
      note: 'Internet',
      frequency: RecurringFrequency.monthly,
      nextOccurrenceDate: DateTime(2026, 9, 5),
    );
    final inserted = (await repo.watchActive().first).single;

    final result = await repo.delete(inserted.id);
    expect(result.isOk, isTrue, reason: '$result');
    expect(await db.select(db.recurringTransactions).get(), isEmpty);
  });
}
