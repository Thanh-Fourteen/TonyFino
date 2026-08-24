import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/core/result/result.dart';
import 'package:tonyfino/data/repositories/wallet_repository.dart';

import '../../support/open_test_database.dart';

int _unwrap(Result<int, AppError> result) =>
    result.when(ok: (v) => v, err: (e) => throw Exception('$e'));

void main() {
  test('onCreate luôn seed đúng MỘT "Ví mặc định", id nhỏ nhất', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = WalletRepository(db);

    final wallets = await repo.watchActive().first;
    expect(wallets, hasLength(1));
    expect(wallets.single.name, 'Ví mặc định');
    expect(await repo.defaultWalletId(), wallets.single.id);
  });

  test(
    'insert ví mới → hiện trong watchActive(), defaultWalletId() vẫn là ví CŨ NHẤT',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = WalletRepository(db);
      final originalDefaultId = await repo.defaultWalletId();

      final result = await repo.insert(
        name: 'Tiền mặt',
        categoryColorId: 1,
        iconCode: 'payments',
      );
      expect(result.isOk, isTrue, reason: '$result');

      final wallets = await repo.watchActive().first;
      expect(wallets, hasLength(2));
      expect(await repo.defaultWalletId(), originalDefaultId);
    },
  );

  test(
    'setArchived(true) ẩn khỏi watchActive() nhưng hiện trong watchArchived(), không xoá hàng',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = WalletRepository(db);
      final walletId = _unwrap(
        await repo.insert(
          name: 'Thẻ tín dụng',
          categoryColorId: 2,
          iconCode: 'credit_card',
        ),
      );

      await repo.setArchived(walletId, true);

      expect(await repo.watchActive().first, hasLength(1));
      final archived = await repo.watchArchived().first;
      expect(archived, hasLength(1));
      expect(archived.single.id, walletId);

      await repo.setArchived(walletId, false);
      expect(await repo.watchActive().first, hasLength(2));
      expect(await repo.watchArchived().first, isEmpty);
    },
  );

  test(
    'createTransfer: 2 dòng liên kết, số dư từng ví đổi đúng, TỔNG toàn ví KHÔNG đổi',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = WalletRepository(db);
      final cashId = _unwrap(
        await repo.insert(
          name: 'Tiền mặt',
          categoryColorId: 1,
          iconCode: 'payments',
        ),
      );
      final bankId = _unwrap(
        await repo.insert(
          name: 'Ngân hàng',
          categoryColorId: 2,
          iconCode: 'account_balance',
        ),
      );

      final result = await repo.createTransfer(
        sourceWalletId: cashId,
        destWalletId: bankId,
        amount: const Money.vnd(500000),
        occurredAt: DateTime(2026, 8, 22),
        note: 'Nộp tiền vào ngân hàng',
      );
      expect(result.isOk, isTrue, reason: '$result');

      final balances = await repo.watchActiveBalances().first;
      final cashBalance = balances
          .firstWhere((b) => b.wallet.id == cashId)
          .balance;
      final bankBalance = balances
          .firstWhere((b) => b.wallet.id == bankId)
          .balance;
      expect(cashBalance, const Money.vnd(-500000));
      expect(bankBalance, const Money.vnd(500000));

      final totalAcrossWallets = balances.fold<int>(
        0,
        (sum, b) => sum + b.balance.minorUnits,
      );
      expect(
        totalAcrossWallets,
        0,
        reason: 'Chuyển khoản không được tạo/mất tiền (D7 mở rộng)',
      );

      final rows = await db.select(db.transactions).get();
      final sourceRow = rows.firstWhere((t) => t.walletId == cashId);
      final destRow = rows.firstWhere((t) => t.walletId == bankId);
      expect(sourceRow.isTransfer, isTrue);
      expect(destRow.isTransfer, isTrue);
      expect(sourceRow.categoryId, isNull);
      expect(destRow.categoryId, isNull);
      expect(sourceRow.linkedTransactionId, destRow.id);
      expect(destRow.linkedTransactionId, sourceRow.id);
    },
  );

  test(
    'createTransfer: ví nguồn = ví đích → lỗi rõ ràng, không ghi gì',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = WalletRepository(db);
      final walletId = await repo.defaultWalletId();

      final result = await repo.createTransfer(
        sourceWalletId: walletId,
        destWalletId: walletId,
        amount: const Money.vnd(100000),
        occurredAt: DateTime(2026, 8, 22),
      );
      expect(result.isErr, isTrue);
      expect(await db.select(db.transactions).get(), isEmpty);
    },
  );
}
