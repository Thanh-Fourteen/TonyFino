import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/budget_repository.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/features/budgets/domain/budget_period.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late BudgetRepository repo;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    repo = BudgetRepository(db);
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
    'watchBudgetsForPeriod: gộp SQL đúng — chỉ tính chi TRONG kỳ, budget chưa có giao dịch vẫn hiện (spent 0)',
    () async {
      final categories = await db.select(db.categories).get();
      final food = categories[0];
      final transport = categories[1];
      const period = BudgetPeriod(year: 2026, month: 8);

      await repo.upsertBudget(
        categoryId: food.id,
        period: period,
        amount: Money.vnd(1000000),
      );
      await repo.upsertBudget(
        categoryId: transport.id,
        period: period,
        amount: Money.vnd(500000),
      );

      await insertTransaction(
        amountMinor: -300000,
        occurredAt: DateTime(2026, 8, 10),
        categoryId: food.id,
      );
      await insertTransaction(
        amountMinor: -200000,
        occurredAt: DateTime(2026, 8, 20),
        categoryId: food.id,
      );
      await insertTransaction(
        amountMinor: 5000000,
        occurredAt: DateTime(2026, 8, 15),
        categoryId: food.id,
      ); // thu — không tính
      await insertTransaction(
        amountMinor: -50000,
        occurredAt: DateTime(2026, 7, 31),
        categoryId: food.id,
      ); // tháng trước — không tính
      // transport: có ngân sách nhưng CHƯA có giao dịch nào.

      final result = await repo.watchBudgetsForPeriod(period).first;

      expect(result, hasLength(2));
      final byName = {for (final r in result) r.categoryName: r};
      expect(byName[food.name]!.spentMinor, -500000);
      expect(byName[food.name]!.budgetAmountMinor, 1000000);
      expect(byName[transport.name]!.spentMinor, 0);
      expect(byName[transport.name]!.budgetAmountMinor, 500000);
    },
  );

  test(
    '🚨 watchBudgetsForPeriod: ranh giới tháng — giao dịch đúng 00:00 đầu tháng SAU KHÔNG được tính',
    () async {
      final category = (await db.select(db.categories).get()).first;
      const period = BudgetPeriod(year: 2026, month: 8);
      await repo.upsertBudget(
        categoryId: category.id,
        period: period,
        amount: Money.vnd(1000000),
      );

      await insertTransaction(
        amountMinor: -111,
        occurredAt: DateTime(2026, 8, 1),
        categoryId: category.id,
      ); // đầu kỳ — tính
      await insertTransaction(
        amountMinor: -222,
        occurredAt: DateTime(2026, 8, 1, 0, 0, 0, 0, 1),
        categoryId: category.id,
      ); // vẫn 1/8, gần nửa đêm
      await insertTransaction(
        amountMinor: -444,
        occurredAt: DateTime(2026, 9, 1),
        categoryId: category.id,
      ); // đầu tháng sau — KHÔNG tính
      await insertTransaction(
        amountMinor: -888,
        occurredAt: DateTime(2026, 8, 31, 23, 59, 59),
        categoryId: category.id,
      ); // cuối tháng — tính

      final result = await repo.watchBudgetsForPeriod(period).first;
      expect(result.single.spentMinor, -(111 + 222 + 888));
    },
  );

  test(
    '🚨 watchBudgetsForPeriod: ranh giới CHUYỂN NĂM — ngân sách tháng 12 không lẫn giao dịch tháng 1 năm sau',
    () async {
      final category = (await db.select(db.categories).get()).first;
      const december = BudgetPeriod(year: 2026, month: 12);
      await repo.upsertBudget(
        categoryId: category.id,
        period: december,
        amount: Money.vnd(2000000),
      );

      await insertTransaction(
        amountMinor: -500000,
        occurredAt: DateTime(2026, 12, 31, 23, 59, 59),
        categoryId: category.id,
      );
      await insertTransaction(
        amountMinor: -999999,
        occurredAt: DateTime(2027, 1, 1),
        categoryId: category.id,
      ); // năm sau — KHÔNG tính

      final result = await repo.watchBudgetsForPeriod(december).first;
      expect(result.single.spentMinor, -500000);
    },
  );

  test(
    'upsertBudget: gọi lần hai với cùng danh mục+kỳ SỬA hàng cũ, không tạo hàng trùng',
    () async {
      final category = (await db.select(db.categories).get()).first;
      const period = BudgetPeriod(year: 2026, month: 8);

      await repo.upsertBudget(
        categoryId: category.id,
        period: period,
        amount: Money.vnd(1000000),
      );
      final firstRow = await (db.select(
        db.budgets,
      )..where((b) => b.categoryId.equals(category.id))).getSingle();

      await repo.upsertBudget(
        categoryId: category.id,
        period: period,
        amount: Money.vnd(1500000),
      );
      final rows = await db.select(db.budgets).get();

      expect(rows, hasLength(1));
      expect(
        rows.single.id,
        firstRow.id,
      ); // sửa TẠI CHỖ, không phải xoá-chèn-lại
      expect(rows.single.amountMinor, 1500000);
    },
  );

  test(
    'deleteBudget: xoá đúng hàng, các kỳ/danh mục khác không bị ảnh hưởng',
    () async {
      final categories = await db.select(db.categories).get();
      const period = BudgetPeriod(year: 2026, month: 8);
      await repo.upsertBudget(
        categoryId: categories[0].id,
        period: period,
        amount: Money.vnd(1000000),
      );
      await repo.upsertBudget(
        categoryId: categories[1].id,
        period: period,
        amount: Money.vnd(500000),
      );

      final toDelete = await (db.select(
        db.budgets,
      )..where((b) => b.categoryId.equals(categories[0].id))).getSingle();
      final result = await repo.deleteBudget(toDelete.id);

      expect(result.isOk, isTrue);
      final remaining = await db.select(db.budgets).get();
      expect(remaining, hasLength(1));
      expect(remaining.single.categoryId, categories[1].id);
    },
  );

  test(
    '🚨 Phase 13: chuyển khoản KHÔNG tính vào spentMinor dù cùng danh mục/kỳ',
    () async {
      final category = (await db.select(db.categories).get()).first;
      const period = BudgetPeriod(year: 2026, month: 8);
      await repo.upsertBudget(
        categoryId: category.id,
        period: period,
        amount: Money.vnd(1000000),
      );

      await insertTransaction(
        amountMinor: -300000,
        occurredAt: DateTime(2026, 8, 10),
        categoryId: category.id,
      );
      // Chuyển khoản thực tế luôn có categoryId null (xem WalletRepository),
      // nhưng vẫn thử ca "có categoryId" để chứng minh cờ isTransfer MỚI LÀ
      // điều kiện loại trừ thật sự, không phải suy luận từ categoryId null.
      await insertTransaction(
        amountMinor: -900000,
        occurredAt: DateTime(2026, 8, 15),
        categoryId: category.id,
        isTransfer: true,
      );

      final result = await repo.watchBudgetsForPeriod(period).first;
      expect(result.single.spentMinor, -300000);
    },
  );

  test(
    '🚨 Phase 14: giao dịch TÁCH DÒNG đóng góp vào ngân sách của TỪNG danh '
    'mục dòng con, không phải danh mục của giao dịch cha (đã null)',
    () async {
      final categories = await db.select(db.categories).get();
      final food = categories[0];
      final transport = categories[1];
      const period = BudgetPeriod(year: 2026, month: 8);
      await repo.upsertBudget(
        categoryId: food.id,
        period: period,
        amount: Money.vnd(1000000),
      );
      await repo.upsertBudget(
        categoryId: transport.id,
        period: period,
        amount: Money.vnd(500000),
      );

      final txRepo = TransactionRepository(db);
      await txRepo.insert(
        amount: Money.vnd(-300000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        lines: [
          TransactionLineInput(categoryId: food.id, amountMinor: -200000),
          TransactionLineInput(categoryId: transport.id, amountMinor: -100000),
        ],
      );

      final result = await repo.watchBudgetsForPeriod(period).first;
      final byName = {for (final r in result) r.categoryName: r};
      expect(byName[food.name]!.spentMinor, -200000);
      expect(byName[transport.name]!.spentMinor, -100000);
    },
  );

  group('🚨 Phase 15: carry-over — bounded ĐÚNG MỘT kỳ liền trước', () {
    test(
      'carryOver TẮT (mặc định) → carryInMinor luôn 0, hành xử ĐÚNG HỆT Phase 11',
      () async {
        final category = (await db.select(db.categories).get()).first;
        const july = BudgetPeriod(year: 2026, month: 7);
        const august = BudgetPeriod(year: 2026, month: 8);
        // Tháng 7 dư hẳn 700.000 (ngân sách 1tr, chi 300k) nhưng KHÔNG bật cờ.
        await repo.upsertBudget(
          categoryId: category.id,
          period: july,
          amount: Money.vnd(1000000),
        );
        await insertTransaction(
          amountMinor: -300000,
          occurredAt: DateTime(2026, 7, 10),
          categoryId: category.id,
        );
        await repo.upsertBudget(
          categoryId: category.id,
          period: august,
          amount: Money.vnd(1000000),
        );

        final result = await repo.watchBudgetsForPeriod(august).first;
        expect(result.single.carryInMinor, 0);
        expect(result.single.effectiveBudgetAmountMinor, 1000000);
        expect(result.single.carryOverEnabled, isFalse);
      },
    );

    test(
      'carryOver BẬT, kỳ trước DƯ → carryIn DƯƠNG, ngân sách hiệu lực = gốc + dư kỳ trước',
      () async {
        final category = (await db.select(db.categories).get()).first;
        const july = BudgetPeriod(year: 2026, month: 7);
        const august = BudgetPeriod(year: 2026, month: 8);
        await repo.upsertBudget(
          categoryId: category.id,
          period: july,
          amount: Money.vnd(1000000),
        );
        await insertTransaction(
          amountMinor: -300000,
          occurredAt: DateTime(2026, 7, 10),
          categoryId: category.id,
        );
        // Dư tháng 7 = 1.000.000 − 300.000 = 700.000.
        await repo.upsertBudget(
          categoryId: category.id,
          period: august,
          amount: Money.vnd(1000000),
          carryOver: true,
        );

        final result = await repo.watchBudgetsForPeriod(august).first;
        expect(result.single.carryInMinor, 700000);
        expect(result.single.effectiveBudgetAmountMinor, 1700000);
        expect(result.single.carryOverEnabled, isTrue);
      },
    );

    test(
      'carryOver BẬT, kỳ trước VƯỢT → carryIn ÂM, ngân sách hiệu lực GIẢM (phạt kỳ sau, KHÔNG kẹp về 0)',
      () async {
        final category = (await db.select(db.categories).get()).first;
        const july = BudgetPeriod(year: 2026, month: 7);
        const august = BudgetPeriod(year: 2026, month: 8);
        await repo.upsertBudget(
          categoryId: category.id,
          period: july,
          amount: Money.vnd(1000000),
        );
        // Vượt tháng 7: chi 1.500.000, ngân sách chỉ 1.000.000 → dư = −500.000.
        await insertTransaction(
          amountMinor: -1500000,
          occurredAt: DateTime(2026, 7, 10),
          categoryId: category.id,
        );
        await repo.upsertBudget(
          categoryId: category.id,
          period: august,
          amount: Money.vnd(1000000),
          carryOver: true,
        );

        final result = await repo.watchBudgetsForPeriod(august).first;
        expect(result.single.carryInMinor, -500000);
        expect(result.single.effectiveBudgetAmountMinor, 500000);
      },
    );

    test(
      '🚨 carryOver BẬT, vượt kỳ trước LỚN HƠN ngân sách gốc kỳ này → ngân sách hiệu lực ÂM, không kẹp/không lỗi',
      () async {
        final category = (await db.select(db.categories).get()).first;
        const july = BudgetPeriod(year: 2026, month: 7);
        const august = BudgetPeriod(year: 2026, month: 8);
        await repo.upsertBudget(
          categoryId: category.id,
          period: july,
          amount: Money.vnd(1000000),
        );
        // Vượt rất nặng: dư tháng 7 = 1.000.000 − 4.000.000 = −3.000.000.
        await insertTransaction(
          amountMinor: -4000000,
          occurredAt: DateTime(2026, 7, 10),
          categoryId: category.id,
        );
        await repo.upsertBudget(
          categoryId: category.id,
          period: august,
          amount: Money.vnd(1000000),
          carryOver: true,
        );

        final result = await repo.watchBudgetsForPeriod(august).first;
        expect(result.single.carryInMinor, -3000000);
        expect(result.single.effectiveBudgetAmountMinor, -2000000);
        // progressFraction/remainingMinor không NaN/không ném lỗi dù mẫu số âm.
        expect(result.single.progressFraction, isNotNaN);
      },
    );

    test(
      'carryOver BẬT nhưng KHÔNG có ngân sách kỳ trước → carryIn = 0 (không có gì để cộng)',
      () async {
        final category = (await db.select(db.categories).get()).first;
        const august = BudgetPeriod(year: 2026, month: 8);
        // KHÔNG đặt ngân sách tháng 7 — chỉ có tháng 8.
        await repo.upsertBudget(
          categoryId: category.id,
          period: august,
          amount: Money.vnd(1000000),
          carryOver: true,
        );

        final result = await repo.watchBudgetsForPeriod(august).first;
        expect(result.single.carryInMinor, 0);
        expect(result.single.effectiveBudgetAmountMinor, 1000000);
      },
    );

    test(
      '🚨 BOUNDED — carry-in KHÔNG đệ quy: kỳ 3 chỉ nhìn về kỳ 2 (ngân sách GỐC), không "thừa kế" khoản dư kỳ 1 qua kỳ 2',
      () async {
        final category = (await db.select(db.categories).get()).first;
        const june = BudgetPeriod(year: 2026, month: 6);
        const july = BudgetPeriod(year: 2026, month: 7);
        const august = BudgetPeriod(year: 2026, month: 8);

        // Kỳ 6: ngân sách 1tr, KHÔNG chi gì → dư 1.000.000.
        await repo.upsertBudget(
          categoryId: category.id,
          period: june,
          amount: Money.vnd(1000000),
        );
        // Kỳ 7: ngân sách GỐC 1tr, carryOver BẬT, chi ĐÚNG BẰNG ngân sách gốc
        // (1tr) → dư TỰ THÂN của kỳ 7 (so với ngân sách GỐC, không phải hiệu
        // lực) = 0, dù carryIn của CHÍNH kỳ 7 (từ kỳ 6) là +1.000.000.
        await repo.upsertBudget(
          categoryId: category.id,
          period: july,
          amount: Money.vnd(1000000),
          carryOver: true,
        );
        await insertTransaction(
          amountMinor: -1000000,
          occurredAt: DateTime(2026, 7, 15),
          categoryId: category.id,
        );
        // Kỳ 8: carryOver BẬT — nếu carry-in ĐỆ QUY (bug), kỳ 8 sẽ thừa kế
        // luôn khoản dư 1.000.000 gốc từ kỳ 6 (chưa "tiêu" hết vì kỳ 7 chỉ chi
        // đúng ngân sách GỐC của nó). Thiết kế BOUNDED đúng: kỳ 8 chỉ nhìn
        // ngân sách GỐC kỳ 7 (1.000.000) trừ chi tiêu THẬT kỳ 7 (1.000.000) =
        // 0 — khoản dư kỳ 6 đã "biến mất" khỏi công thức sau đúng một kỳ.
        await repo.upsertBudget(
          categoryId: category.id,
          period: august,
          amount: Money.vnd(1000000),
          carryOver: true,
        );

        final julyResult = await repo.watchBudgetsForPeriod(july).first;
        expect(
          julyResult.single.carryInMinor,
          1000000,
        ); // kỳ 7 THẬT SỰ nhận dư kỳ 6.
        expect(julyResult.single.effectiveBudgetAmountMinor, 2000000);

        final augustResult = await repo.watchBudgetsForPeriod(august).first;
        expect(
          augustResult.single.carryInMinor,
          0,
        ); // KHÔNG thừa kế dư kỳ 6 qua kỳ 7.
        expect(augustResult.single.effectiveBudgetAmountMinor, 1000000);
      },
    );
  });
}
