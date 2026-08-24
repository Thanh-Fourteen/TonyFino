// Nợ vay (Phase 16) — số dư CÒN LẠI luôn dẫn xuất từ `principalMinor` (tĩnh)
// + SQL aggregate trên giao dịch gắn `debtId`, KHÔNG lưu cột "còn nợ bao
// nhiêu". Công thức khác nhau theo `DebtKind` (mình nợ vs mình cho vay) —
// test cả hai chiều, KHÔNG dùng ABS() nên phải test cả ca dấu trái chiều
// (hoàn lại một phần) để xác nhận không sai như ABS(SUM(...)) sẽ sai.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/debt_repository.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/features/savings/domain/debt_kind.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late DebtRepository repo;
  late TransactionRepository txRepo;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    repo = DebtRepository(db);
    txRepo = TransactionRepository(db);
    walletId = (await db.select(db.wallets).get()).first.id;
  });
  tearDown(() => db.close());

  test(
    'khoản MỚI chưa trả/thu đồng nào → remaining = principal đầy đủ',
    () async {
      await repo.insert(
        counterpartyName: 'Anh Long',
        kind: DebtKind.debt,
        principal: Money.vnd(5000000),
        startDate: DateTime(2026, 8, 1),
      );

      final result = await repo.watchActiveWithProgress().first;
      expect(result.single.remainingMinor, 5000000);
      expect(result.single.progressFraction, 0.0);
    },
  );

  test(
    '🚨 kind = debt (mình NỢ): trả nợ là giao dịch CHI (âm) → remaining GIẢM đúng',
    () async {
      final debtId = (await repo.insert(
        counterpartyName: 'Anh Long',
        kind: DebtKind.debt,
        principal: Money.vnd(5000000),
        startDate: DateTime(2026, 8, 1),
      )).valueOrNull!;

      await txRepo.insert(
        amount: Money.vnd(-2000000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        debtId: debtId,
      );

      final result = await repo.watchActiveWithProgress().first;
      expect(result.single.paidMinor, 2000000);
      expect(result.single.remainingMinor, 3000000);
    },
  );

  test(
    '🚨 kind = loan (mình CHO VAY): thu nợ là giao dịch THU (dương) → remaining GIẢM đúng',
    () async {
      final debtId = (await repo.insert(
        counterpartyName: 'Chị Mai',
        kind: DebtKind.loan,
        principal: Money.vnd(3000000),
        startDate: DateTime(2026, 8, 1),
      )).valueOrNull!;

      await txRepo.insert(
        amount: Money.vnd(1000000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        debtId: debtId,
      );

      final result = await repo.watchActiveWithProgress().first;
      expect(result.single.paidMinor, 1000000);
      expect(result.single.remainingMinor, 2000000);
    },
  );

  test(
    '🚨 hoàn lại một phần đã trả (dấu trái chiều) vẫn cộng dồn đúng — KHÔNG như ABS(SUM(...)) sẽ sai',
    () async {
      final debtId = (await repo.insert(
        counterpartyName: 'Anh Long',
        kind: DebtKind.debt,
        principal: Money.vnd(5000000),
        startDate: DateTime(2026, 8, 1),
      )).valueOrNull!;

      // Trả 3tr (chi, âm), rồi được hoàn lại 1tr do trả nhầm (thu, dương).
      await txRepo.insert(
        amount: Money.vnd(-3000000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        debtId: debtId,
      );
      await txRepo.insert(
        amount: Money.vnd(1000000),
        occurredAt: DateTime(2026, 8, 12),
        walletId: walletId,
        debtId: debtId,
      );

      final result = await repo.watchActiveWithProgress().first;
      // SUM = -3tr + 1tr = -2tr. paidMinor (kind=debt) = -(-2tr) = 2tr —
      // ĐÚNG (thực trả ròng 2tr). ABS(SUM) sẽ vẫn ra 2tr ở CA NÀY (trùng hợp
      // vì net vẫn âm) — ca sau (net dương) mới lộ khác biệt thật.
      expect(result.single.paidMinor, 2000000);
      expect(result.single.remainingMinor, 3000000);
    },
  );

  test(
    '🚨 hoàn lại VƯỢT quá phần đã trả (net đổi dấu) — chứng minh khác ABS(SUM(...))',
    () async {
      final debtId = (await repo.insert(
        counterpartyName: 'Anh Long',
        kind: DebtKind.debt,
        principal: Money.vnd(5000000),
        startDate: DateTime(2026, 8, 1),
      )).valueOrNull!;

      // Trả 1tr (chi, âm), rồi được hoàn lại 3tr (thu, dương, hoàn cả gốc lẫn
      // một phần bù trừ giả định) — SUM = -1tr + 3tr = +2tr (net DƯƠNG).
      await txRepo.insert(
        amount: Money.vnd(-1000000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        debtId: debtId,
      );
      await txRepo.insert(
        amount: Money.vnd(3000000),
        occurredAt: DateTime(2026, 8, 12),
        walletId: walletId,
        debtId: debtId,
      );

      final result = await repo.watchActiveWithProgress().first;
      // paidMinor (kind=debt) = -SUM = -(+2tr) = -2tr (đã trả ròng ÂM, tức
      // THỰC RA đã NHẬN LẠI nhiều hơn đã trả) → remaining = 5tr - (-2tr) = 7tr
      // (LỚN HƠN gốc — đúng, vì net tiền đã chảy NGƯỢC vào ví). `ABS(SUM)` sẽ
      // cho paidMinor = 2tr (SAI dấu hoàn toàn — sẽ báo remaining = 3tr thay
      // vì 7tr thật).
      expect(result.single.contributionsSumMinor, 2000000);
      expect(result.single.paidMinor, -2000000);
      expect(result.single.remainingMinor, 7000000);
    },
  );

  test(
    '🚨 xoá giao dịch trả nợ → remaining tự tăng lại, không cần đồng bộ lại',
    () async {
      final debtId = (await repo.insert(
        counterpartyName: 'Anh Long',
        kind: DebtKind.debt,
        principal: Money.vnd(5000000),
        startDate: DateTime(2026, 8, 1),
      )).valueOrNull!;

      final txId = (await txRepo.insert(
        amount: Money.vnd(-2000000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        debtId: debtId,
      )).valueOrNull!;
      expect(
        (await repo.watchActiveWithProgress().first).single.remainingMinor,
        3000000,
      );

      await txRepo.delete(txId);

      final result = await repo.watchActiveWithProgress().first;
      expect(result.single.remainingMinor, 5000000);
    },
  );

  test(
    'trả đủ/vượt gốc → isSettled true, progressFraction kẹp ở 1.0',
    () async {
      final debtId = (await repo.insert(
        counterpartyName: 'Anh Long',
        kind: DebtKind.debt,
        principal: Money.vnd(2000000),
        startDate: DateTime(2026, 8, 1),
      )).valueOrNull!;

      await txRepo.insert(
        amount: Money.vnd(-2500000), // trả thừa.
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        debtId: debtId,
      );

      final result = await repo.watchActiveWithProgress().first;
      expect(result.single.isSettled, isTrue);
      expect(result.single.progressFraction, 1.0);
      expect(result.single.remainingMinor, -500000);
    },
  );

  test(
    'sửa số tiền một giao dịch trả nợ (không truyền debtId) → GIỮ NGUYÊN gắn kết, remaining tự đổi theo',
    () async {
      final debtId = (await repo.insert(
        counterpartyName: 'Anh Long',
        kind: DebtKind.debt,
        principal: Money.vnd(5000000),
        startDate: DateTime(2026, 8, 1),
      )).valueOrNull!;
      final txId = (await txRepo.insert(
        amount: Money.vnd(-1000000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        debtId: debtId,
      )).valueOrNull!;

      await txRepo.update(
        id: txId,
        amount: Money.vnd(-2500000),
        occurredAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
      );

      final result = await repo.watchActiveWithProgress().first;
      expect(result.single.remainingMinor, 2500000);
    },
  );

  test(
    'update() với debtId: Value(null) tường minh THÁO gắn kết khỏi khoản vay',
    () async {
      final debtId = (await repo.insert(
        counterpartyName: 'Anh Long',
        kind: DebtKind.debt,
        principal: Money.vnd(5000000),
        startDate: DateTime(2026, 8, 1),
      )).valueOrNull!;
      final txId = (await txRepo.insert(
        amount: Money.vnd(-1000000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        debtId: debtId,
      )).valueOrNull!;

      await txRepo.update(
        id: txId,
        amount: Money.vnd(-1000000),
        occurredAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
        debtId: const Value(null),
      );

      final result = await repo.watchActiveWithProgress().first;
      expect(result.single.remainingMinor, 5000000);
    },
  );

  test(
    'setArchived(true) → khoản rời khỏi watchActive*, hiện trong watchArchived',
    () async {
      final debtId = (await repo.insert(
        counterpartyName: 'Anh Long',
        kind: DebtKind.debt,
        principal: Money.vnd(5000000),
        startDate: DateTime(2026, 8, 1),
      )).valueOrNull!;
      await repo.setArchived(debtId, true);

      expect(await repo.watchActive().first, isEmpty);
      expect(await repo.watchActiveWithProgress().first, isEmpty);
      expect((await repo.watchArchived().first).single.id, debtId);
    },
  );
}
