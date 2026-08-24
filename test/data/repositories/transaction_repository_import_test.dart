import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  setUp(() {
    db = openTestDatabase();
    repo = TransactionRepository(db);
  });
  tearDown(() => db.close());

  Future<int> categoryId() async {
    final categories = await db.select(db.categories).get();
    return categories.first.id;
  }

  Future<int> walletId() async {
    final wallets = await db.select(db.wallets).get();
    return wallets.first.id;
  }

  test(
    'findExistingSourceIds trả đúng tập con đã tồn tại, bỏ qua id chưa từng ghi',
    () async {
      await repo.insert(
        amount: Money.vnd(-35000),
        occurredAt: DateTime(2026, 5, 10),
        walletId: await walletId(),
        sourceId: 'rolly:1001',
      );
      await repo.insert(
        amount: Money.vnd(-5000),
        occurredAt: DateTime(2026, 5, 11),
        walletId: await walletId(),
      );

      final existing = await repo.findExistingSourceIds([
        'rolly:1001',
        'rolly:9999',
      ]);
      expect(existing, {'rolly:1001'});
    },
  );

  test(
    'insertImportBatch: import LẦN ĐẦU ghi hết, LẦN HAI cùng dữ liệu KHÔNG tạo trùng',
    () async {
      final catId = await categoryId();
      final rows = [
        (
          amountMinor: -35000,
          occurredAt: DateTime(2026, 5, 10),
          categoryId: catId,
          note: 'cà phê',
          sourceId: 'rolly:1001',
          isTransfer: false,
        ),
        (
          amountMinor: 15000000,
          occurredAt: DateTime(2026, 5, 1),
          categoryId: null,
          note: 'lương',
          sourceId: 'rolly:1003',
          isTransfer: false,
        ),
      ];

      final first = await repo.insertImportBatch(
        rows,
        walletId: await walletId(),
      );
      expect(first.valueOrNull?.inserted, 2);
      expect(first.valueOrNull?.skippedDuplicate, 0);
      expect(await db.select(db.transactions).get(), hasLength(2));

      final second = await repo.insertImportBatch(
        rows,
        walletId: await walletId(),
      );
      expect(second.valueOrNull?.inserted, 0);
      expect(second.valueOrNull?.skippedDuplicate, 2);
      // Vẫn đúng 2 dòng trong DB — import lần hai không nhân đôi.
      expect(await db.select(db.transactions).get(), hasLength(2));
    },
  );

  test(
    'insertImportBatch: giao dịch không sourceId (quick-add) không va chạm nhau',
    () async {
      final rows = [
        (
          amountMinor: -1000,
          occurredAt: DateTime(2026, 1, 1),
          categoryId: null,
          note: 'a',
          sourceId: 'csv:1',
          isTransfer: false,
        ),
      ];
      // Hai giao dịch tạo tay KHÔNG sourceId đã tồn tại trước đó — cột
      // sourceId null không được va chạm UNIQUE với nhau (SQLite: nhiều NULL
      // không trùng nhau).
      final wid = await walletId();
      await repo.insert(
        amount: Money.vnd(-1),
        occurredAt: DateTime(2026, 1, 1),
        walletId: wid,
      );
      await repo.insert(
        amount: Money.vnd(-2),
        occurredAt: DateTime(2026, 1, 1),
        walletId: wid,
      );

      final result = await repo.insertImportBatch(rows, walletId: wid);
      expect(result.valueOrNull?.inserted, 1);
      expect(await db.select(db.transactions).get(), hasLength(3));
    },
  );

  test(
    '🚨 chuyển sang mục tiêu tiết kiệm KHÔNG bị tính là chi, kể cả khi dòng '
    'đó có isTransfer = false (dữ liệu nhập từ Rolly trước khi có cờ)',
    () async {
      final wid = await walletId();
      final goalId = await db
          .into(db.savingsGoals)
          .insert(
            SavingsGoalsCompanion.insert(
              name: 'Quỹ dự phòng',
              targetAmountMinor: 50000000,
              currency: 'VND',
              currencyScale: 0,
            ),
          );

      await repo.insert(
        amount: Money.vnd(-200000),
        occurredAt: DateTime(2026, 5, 10),
        walletId: wid,
      );
      // Dòng "chuyển sang tiết kiệm" kiểu CŨ: có goalId nhưng isTransfer
      // vẫn false. Nếu thẻ tổng đếm cả dòng này thì chi vọt lên 43.420.000.
      await repo.insert(
        amount: Money.vnd(-43220000),
        occurredAt: DateTime(2026, 5, 11),
        walletId: wid,
        goalId: goalId,
      );

      final summary = await repo
          .watchMonthToDateSummary(DateTime(2026, 5, 15))
          .first;
      expect(summary.expense.minorUnits, -200000);
      // Tiền cất vào mục tiêu tách riêng — không nằm trong "chi", nhưng
      // PHẢI bị trừ khỏi "còn lại".
      expect(summary.savings.minorUnits, -43220000);
      expect(summary.net.minorUnits, -43420000);
    },
  );
}
