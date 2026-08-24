import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/recurring_transaction_repository.dart';
import 'package:tonyfino/data/repositories/safe_to_spend_repository.dart';
import 'package:tonyfino/features/settings/recurring/domain/recurring_frequency.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late SafeToSpendRepository repo;
  late RecurringTransactionRepository recurringRepo;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    repo = SafeToSpendRepository(db);
    recurringRepo = RecurringTransactionRepository(db);
    walletId = (await db.select(db.wallets).get()).first.id;
  });
  tearDown(() => db.close());

  Future<int> insertTransaction({
    required int amountMinor,
    required DateTime occurredAt,
    int? categoryId,
    bool isTransfer = false,
  }) {
    return db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: amountMinor,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: occurredAt,
            walletId: walletId,
            categoryId: Value(categoryId),
            isTransfer: Value(isTransfer),
          ),
        );
  }

  test(
    'không giao dịch, không định kỳ nào trong kỳ → 0 đồng/ngày, không lỗi chia 0',
    () async {
      // Kỳ tháng 8 (anchorDay mặc định 1), "hôm nay" = 10/8 → còn 22 ngày.
      final result = await repo
          .watchSafeToSpendToday(DateTime(2026, 8, 10))
          .first;
      expect(result.minorUnits, 0);
    },
  );

  test(
    'thu − chi trong kỳ, chia đều cho số ngày còn lại (không có định kỳ nào)',
    () async {
      final category = (await db.select(db.categories).get()).first;
      await insertTransaction(
        amountMinor: 5000000,
        occurredAt: DateTime(2026, 8, 1),
        categoryId: category.id,
      );
      await insertTransaction(
        amountMinor: -1000000,
        occurredAt: DateTime(2026, 8, 5),
        categoryId: category.id,
      );
      // net = 5.000.000 − 1.000.000 = 4.000.000. "Hôm nay" = 10/8 → kỳ kết
      // thúc 1/9 → còn 22 ngày (1/9 − 10/8). 4.000.000 / 22 = 181.818,18 → 181.818.
      final result = await repo
          .watchSafeToSpendToday(DateTime(2026, 8, 10))
          .first;
      expect(result.minorUnits, (4000000 / 22).round());
    },
  );

  test('🚨 giao dịch NGOÀI kỳ (tháng trước) KHÔNG được tính', () async {
    final category = (await db.select(db.categories).get()).first;
    await insertTransaction(
      amountMinor: 5000000,
      occurredAt: DateTime(2026, 7, 31),
      categoryId: category.id,
    );
    await insertTransaction(
      amountMinor: 1000000,
      occurredAt: DateTime(2026, 8, 1),
      categoryId: category.id,
    );
    final result = await repo.watchSafeToSpendToday(DateTime(2026, 8, 1)).first;
    // Chỉ 1.000.000 (giao dịch tháng 7 bị loại) — kỳ 31 ngày trọn, "hôm nay"
    // = đúng đầu kỳ → còn 31 ngày.
    expect(result.minorUnits, (1000000 / 31).round());
  });

  test(
    'hoá đơn định kỳ CHƯA XẢY RA trong kỳ bị TRỪ vào số an toàn để tiêu',
    () async {
      final category = (await db.select(db.categories).get()).first;
      await insertTransaction(
        amountMinor: 3000000,
        occurredAt: DateTime(2026, 8, 1),
        categoryId: category.id,
      );
      await recurringRepo.insert(
        categoryId: category.id,
        amount: Money.vnd(-1000000), // hoá đơn — âm, giống transactions.
        note: 'Tiền nhà',
        frequency: RecurringFrequency.monthly,
        nextOccurrenceDate: DateTime(2026, 8, 15),
      );
      final result = await repo
          .watchSafeToSpendToday(DateTime(2026, 8, 1))
          .first;
      // net = 3.000.000, sắp tới = −1.000.000 → (3.000.000 − 1.000.000) / 31.
      expect(result.minorUnits, (2000000 / 31).round());
    },
  );

  test(
    'thu định kỳ CHƯA XẢY RA (không phải hoá đơn) được CỘNG thêm, cùng một SUM có dấu',
    () async {
      final category = (await db.select(db.categories).get()).first;
      await recurringRepo.insert(
        categoryId: category.id,
        amount: Money.vnd(10000000), // lương — dương.
        note: 'Lương',
        frequency: RecurringFrequency.monthly,
        nextOccurrenceDate: DateTime(2026, 8, 25),
      );
      final result = await repo
          .watchSafeToSpendToday(DateTime(2026, 8, 1))
          .first;
      expect(result.minorUnits, (10000000 / 31).round());
    },
  );

  test('🚨 định kỳ TẠM DỪNG (isActive = false) KHÔNG được tính', () async {
    final category = (await db.select(db.categories).get()).first;
    final insertResult = await recurringRepo.insert(
      categoryId: category.id,
      amount: Money.vnd(-1000000),
      note: 'Tiền nhà',
      frequency: RecurringFrequency.monthly,
      nextOccurrenceDate: DateTime(2026, 8, 15),
    );
    expect(insertResult.isOk, isTrue);
    final row = (await db.select(db.recurringTransactions).get()).single;
    await recurringRepo.setActive(row.id, false);

    final result = await repo.watchSafeToSpendToday(DateTime(2026, 8, 1)).first;
    expect(result.minorUnits, 0);
  });

  test(
    '🚨 định kỳ với next_occurrence_date NGOÀI kỳ (kỳ sau) KHÔNG được tính',
    () async {
      final category = (await db.select(db.categories).get()).first;
      await recurringRepo.insert(
        categoryId: category.id,
        amount: Money.vnd(-1000000),
        note: 'Tiền nhà tháng sau',
        frequency: RecurringFrequency.monthly,
        nextOccurrenceDate: DateTime(2026, 9, 1),
      );
      final result = await repo
          .watchSafeToSpendToday(DateTime(2026, 8, 1))
          .first;
      expect(result.minorUnits, 0);
    },
  );

  test(
    'định kỳ với next_occurrence_date ĐÃ QUA (quá hạn) NHƯNG vẫn trong kỳ vẫn được tính — "chưa xảy ra" nghĩa là chưa ghi vào transactions',
    () async {
      final category = (await db.select(db.categories).get()).first;
      await recurringRepo.insert(
        categoryId: category.id,
        amount: Money.vnd(-500000),
        note: 'Hoá đơn quá hạn',
        frequency: RecurringFrequency.monthly,
        nextOccurrenceDate: DateTime(
          2026,
          8,
          5,
        ), // đã qua so với "hôm nay" 20/8.
      );
      final result = await repo
          .watchSafeToSpendToday(DateTime(2026, 8, 20))
          .first;
      // "Hôm nay" 20/8 → còn 12 ngày tới 1/9. net = 0, sắp tới = −500.000.
      expect(result.minorUnits, (-500000 / 12).round());
    },
  );

  test(
    '🚨 chuyển khoản (cặp +X/−X) tự triệt tiêu trong tổng TOÀN VÍ, không cần lọc isTransfer',
    () async {
      final category = (await db.select(db.categories).get()).first;
      await insertTransaction(
        amountMinor: 2000000,
        occurredAt: DateTime(2026, 8, 1),
        categoryId: category.id,
      );
      // Một cặp chuyển khoản giữa 2 ví (mô phỏng bằng categoryId null, isTransfer true).
      await insertTransaction(
        amountMinor: -1000000,
        occurredAt: DateTime(2026, 8, 5),
        isTransfer: true,
      );
      await insertTransaction(
        amountMinor: 1000000,
        occurredAt: DateTime(2026, 8, 5),
        isTransfer: true,
      );
      final result = await repo
          .watchSafeToSpendToday(DateTime(2026, 8, 1))
          .first;
      // Cặp chuyển khoản cộng/trừ ra 0 — chỉ còn 2.000.000 / 31 ngày.
      expect(result.minorUnits, (2000000 / 31).round());
    },
  );

  test(
    '🚨 kỳ theo ngày neo tuỳ chỉnh (anchorDay) — số ngày còn lại tính theo RANH GIỚI KỲ, không phải cuối tháng lịch',
    () async {
      final category = (await db.select(db.categories).get()).first;
      await insertTransaction(
        amountMinor: 3100000,
        occurredAt: DateTime(2026, 8, 25),
        categoryId: category.id,
      );
      // anchorDay = 25: kỳ "tháng 8" là 25/8 → 25/9 (31 ngày). "Hôm nay" = 25/8
      // (đúng đầu kỳ) → còn nguyên 31 ngày.
      final result = await repo
          .watchSafeToSpendToday(DateTime(2026, 8, 25), anchorDay: 25)
          .first;
      expect(result.minorUnits, (3100000 / 31).round());
    },
  );

  test(
    'ngày cuối cùng của kỳ vẫn chia cho tối thiểu 1 ngày, không chia cho 0',
    () async {
      final category = (await db.select(db.categories).get()).first;
      await insertTransaction(
        amountMinor: 3100000,
        occurredAt: DateTime(2026, 8, 1),
        categoryId: category.id,
      );
      // "Hôm nay" = 31/8, kỳ kết thúc 1/9 → còn đúng 1 ngày.
      final result = await repo
          .watchSafeToSpendToday(DateTime(2026, 8, 31))
          .first;
      expect(result.minorUnits, 3100000);
    },
  );
}
