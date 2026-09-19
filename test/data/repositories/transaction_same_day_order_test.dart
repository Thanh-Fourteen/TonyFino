import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';

import '../../support/open_test_database.dart';

/// Tony báo: trong MỘT ngày, thẻ "Gần đây" xếp khoản buổi sáng lên đầu —
/// ngược với màn chat. Nguyên nhân: màn chat ghi `occurredAt` là NGÀY TRẦN
/// (00:00), nên mọi khoản cùng ngày bằng nhau ở tiêu chí sắp duy nhất và
/// SQLite trả theo rowid tăng dần.
void main() {
  test('cùng một ngày: khoản ghi SAU nằm TRÊN', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = TransactionRepository(db);
    final walletId = await defaultWalletId(db);
    final day = DateTime(2026, 9, 19);

    Future<void> add(String note, DateTime createdAt) => db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: -10000,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: day,
            walletId: walletId,
            note: Value(note),
            createdAt: Value(createdAt),
          ),
        );

    await add('cà phê sáng', DateTime(2026, 9, 19, 7, 30));
    await add('ăn trưa', DateTime(2026, 9, 19, 12, 5));
    // Hai khoản gửi trong CÙNG một tin nhắn — trùng tới từng giây.
    await add('gửi xe', DateTime(2026, 9, 19, 18, 0));
    await add('ăn tối', DateTime(2026, 9, 19, 18, 0));
    // Ngày hôm trước, ghi SAU CÙNG — vẫn phải nằm dưới cả ngày 19.
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: -5000,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: DateTime(2026, 9, 18),
            walletId: walletId,
            note: const Value('hôm qua'),
            createdAt: Value(DateTime(2026, 9, 19, 20)),
          ),
        );

    final notes = (await repo.watchAllWithCategory(limit: 5).first)
        .map((t) => t.transaction.note)
        .toList();
    expect(notes, ['ăn tối', 'gửi xe', 'ăn trưa', 'cà phê sáng', 'hôm qua']);

    final plain = (await repo.watchAll().first).map((t) => t.note).toList();
    expect(plain, notes);
  });
}
