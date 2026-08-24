// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;
import 'generated/schema_v10.dart' as v10;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // Phase 9: v1→v2 chỉ thêm `transactions.source_id` (nullable) — test này
  // xác nhận dữ liệu ĐÃ CÓ trước khi nâng cấp (một danh mục + một giao dịch
  // tạo tay, không có sourceId) sống sót nguyên vẹn qua migration, và cột
  // mới mặc định `null` chứ không phải lỗi/mất dữ liệu.
  test('migration from v1 to v2 does not corrupt data', () async {
    final oldCategoriesData = <v1.CategoriesData>[
      const v1.CategoriesData(
        id: 1,
        name: 'Ăn uống',
        kind: 'expense',
        categoryColorId: 0,
        iconCode: 'restaurant',
        isArchived: 0,
        createdAt: 1755734400,
      ),
    ];
    final expectedNewCategoriesData = <v2.CategoriesData>[
      const v2.CategoriesData(
        id: 1,
        name: 'Ăn uống',
        kind: 'expense',
        categoryColorId: 0,
        iconCode: 'restaurant',
        isArchived: 0,
        createdAt: 1755734400,
      ),
    ];

    final oldTransactionsData = <v1.TransactionsData>[
      const v1.TransactionsData(
        id: 1,
        amountMinor: -35000,
        currency: 'VND',
        currencyScale: 0,
        occurredAt: 1755734400,
        categoryId: 1,
        note: 'cà phê',
        noteAscii: 'ca phe',
        createdAt: 1755734400,
        updatedAt: 1755734400,
      ),
    ];
    // sourceId phải mặc định null cho dòng ĐÃ CÓ TRƯỚC migration — đây là
    // dòng tạo tay/quick-add, không phải import.
    final expectedNewTransactionsData = <v2.TransactionsData>[
      const v2.TransactionsData(
        id: 1,
        amountMinor: -35000,
        currency: 'VND',
        currencyScale: 0,
        occurredAt: 1755734400,
        categoryId: 1,
        note: 'cà phê',
        noteAscii: 'ca phe',
        sourceId: null,
        createdAt: 1755734400,
        updatedAt: 1755734400,
      ),
    ];

    final oldCategoryKeywordsData = <v1.CategoryKeywordsData>[];
    final expectedNewCategoryKeywordsData = <v2.CategoryKeywordsData>[];

    final oldBudgetsData = <v1.BudgetsData>[];
    final expectedNewBudgetsData = <v2.BudgetsData>[];

    final oldAppEventsData = <v1.AppEventsData>[];
    final expectedNewAppEventsData = <v2.AppEventsData>[];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.categories, oldCategoriesData);
        batch.insertAll(oldDb.transactions, oldTransactionsData);
        batch.insertAll(oldDb.categoryKeywords, oldCategoryKeywordsData);
        batch.insertAll(oldDb.budgets, oldBudgetsData);
        batch.insertAll(oldDb.appEvents, oldAppEventsData);
      },
      validateItems: (newDb) async {
        expect(
          expectedNewCategoriesData,
          await newDb.select(newDb.categories).get(),
        );
        expect(
          expectedNewTransactionsData,
          await newDb.select(newDb.transactions).get(),
        );
        expect(
          expectedNewCategoryKeywordsData,
          await newDb.select(newDb.categoryKeywords).get(),
        );
        expect(expectedNewBudgetsData, await newDb.select(newDb.budgets).get());
        expect(
          expectedNewAppEventsData,
          await newDb.select(newDb.appEvents).get(),
        );
      },
    );
  });

  // Phase 12: v2→v3 chỉ thêm bảng MỚI `recurring_transactions` — không đụng
  // cột nào của 5 bảng cũ, nên bài test này xác nhận dữ liệu cũ (một danh
  // mục + một giao dịch + một ngân sách, y hệt kiểu dữ liệu thật đã dùng ở
  // Phase 11) sống sót nguyên vẹn, và bảng mới tồn tại nhưng trống (không có
  // gì để backfill vào nó).
  test('migration from v2 to v3 does not corrupt data', () async {
    final oldCategoriesData = <v2.CategoriesData>[
      const v2.CategoriesData(
        id: 1,
        name: 'Ăn uống',
        kind: 'expense',
        categoryColorId: 0,
        iconCode: 'restaurant',
        isArchived: 0,
        createdAt: 1755734400,
      ),
    ];
    final expectedNewCategoriesData = <v3.CategoriesData>[
      const v3.CategoriesData(
        id: 1,
        name: 'Ăn uống',
        kind: 'expense',
        categoryColorId: 0,
        iconCode: 'restaurant',
        isArchived: 0,
        createdAt: 1755734400,
      ),
    ];

    final oldTransactionsData = <v2.TransactionsData>[
      const v2.TransactionsData(
        id: 1,
        amountMinor: -35000,
        currency: 'VND',
        currencyScale: 0,
        occurredAt: 1755734400,
        categoryId: 1,
        note: 'cà phê',
        noteAscii: 'ca phe',
        sourceId: 'rolly:1',
        createdAt: 1755734400,
        updatedAt: 1755734400,
      ),
    ];
    final expectedNewTransactionsData = <v3.TransactionsData>[
      const v3.TransactionsData(
        id: 1,
        amountMinor: -35000,
        currency: 'VND',
        currencyScale: 0,
        occurredAt: 1755734400,
        categoryId: 1,
        note: 'cà phê',
        noteAscii: 'ca phe',
        sourceId: 'rolly:1',
        createdAt: 1755734400,
        updatedAt: 1755734400,
      ),
    ];

    final oldBudgetsData = <v2.BudgetsData>[
      const v2.BudgetsData(
        id: 1,
        categoryId: 1,
        yearMonth: '2026-08',
        amountMinor: 2000000,
        currency: 'VND',
        currencyScale: 0,
        createdAt: 1755734400,
      ),
    ];
    final expectedNewBudgetsData = <v3.BudgetsData>[
      const v3.BudgetsData(
        id: 1,
        categoryId: 1,
        yearMonth: '2026-08',
        amountMinor: 2000000,
        currency: 'VND',
        currencyScale: 0,
        createdAt: 1755734400,
      ),
    ];

    final oldCategoryKeywordsData = <v2.CategoryKeywordsData>[];
    final expectedNewCategoryKeywordsData = <v3.CategoryKeywordsData>[];

    final oldAppEventsData = <v2.AppEventsData>[];
    final expectedNewAppEventsData = <v3.AppEventsData>[];

    // Bảng mới, không có gì trong v2 để backfill — kỳ vọng trống sau upgrade.
    final expectedNewRecurringTransactionsData =
        <v3.RecurringTransactionsData>[];

    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.categories, oldCategoriesData);
        batch.insertAll(oldDb.transactions, oldTransactionsData);
        batch.insertAll(oldDb.categoryKeywords, oldCategoryKeywordsData);
        batch.insertAll(oldDb.budgets, oldBudgetsData);
        batch.insertAll(oldDb.appEvents, oldAppEventsData);
      },
      validateItems: (newDb) async {
        expect(
          expectedNewCategoriesData,
          await newDb.select(newDb.categories).get(),
        );
        expect(
          expectedNewTransactionsData,
          await newDb.select(newDb.transactions).get(),
        );
        expect(
          expectedNewCategoryKeywordsData,
          await newDb.select(newDb.categoryKeywords).get(),
        );
        expect(expectedNewBudgetsData, await newDb.select(newDb.budgets).get());
        expect(
          expectedNewAppEventsData,
          await newDb.select(newDb.appEvents).get(),
        );
        expect(
          expectedNewRecurringTransactionsData,
          await newDb.select(newDb.recurringTransactions).get(),
        );
      },
    );
  });

  // Phase 13: v3→v4 — migration schema LỚN NHẤT từ trước tới giờ. Fixture
  // nhỏ ở ĐÂY chỉ để CI/máy khác (không có `raw_rolly/input.json`) vẫn có
  // coverage cơ bản — bài test THẬT với 354 giao dịch Rolly thật nằm ở
  // `test/data/db/migration_v3_v4_real_data_test.dart` (SKIP nếu thiếu file).
  test(
    'migration from v3 to v4 does not corrupt data — thêm wallets + walletId + isTransfer/linkedTransactionId + parentCategoryId/sortOrder',
    () async {
      final oldCategoriesData = <v3.CategoriesData>[
        const v3.CategoriesData(
          id: 1,
          name: 'Ăn uống',
          kind: 'expense',
          categoryColorId: 0,
          iconCode: 'restaurant',
          isArchived: 0,
          createdAt: 1755734400,
        ),
      ];
      final expectedNewCategoriesData = <v4.CategoriesData>[
        const v4.CategoriesData(
          id: 1,
          name: 'Ăn uống',
          kind: 'expense',
          categoryColorId: 0,
          iconCode: 'restaurant',
          isArchived: 0,
          createdAt: 1755734400,
          parentCategoryId: null,
          sortOrder: 0,
        ),
      ];

      final oldTransactionsData = <v3.TransactionsData>[
        const v3.TransactionsData(
          id: 1,
          amountMinor: -35000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: 1755734400,
          categoryId: 1,
          note: 'cà phê',
          noteAscii: 'ca phe',
          sourceId: 'rolly:1',
          createdAt: 1755734400,
          updatedAt: 1755734400,
        ),
        const v3.TransactionsData(
          id: 2,
          amountMinor: 5000000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: 1755734400,
          categoryId: null,
          note: 'lương',
          noteAscii: 'luong',
          sourceId: null,
          createdAt: 1755734400,
          updatedAt: 1755734400,
        ),
      ];
      // Cả hai dòng cũ phải backfill `walletId` vào "Ví mặc định" (id=1, ví
      // DUY NHẤT sau migration), `isTransfer` mặc định 0 (false), KHÔNG mất
      // dòng nào và KHÔNG đổi bất kỳ cột cũ nào khác.
      final expectedNewTransactionsData = <v4.TransactionsData>[
        const v4.TransactionsData(
          id: 1,
          amountMinor: -35000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: 1755734400,
          categoryId: 1,
          note: 'cà phê',
          walletId: 1,
          isTransfer: 0,
          linkedTransactionId: null,
          noteAscii: 'ca phe',
          sourceId: 'rolly:1',
          createdAt: 1755734400,
          updatedAt: 1755734400,
        ),
        const v4.TransactionsData(
          id: 2,
          amountMinor: 5000000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: 1755734400,
          categoryId: null,
          note: 'lương',
          walletId: 1,
          isTransfer: 0,
          linkedTransactionId: null,
          noteAscii: 'luong',
          sourceId: null,
          createdAt: 1755734400,
          updatedAt: 1755734400,
        ),
      ];

      final oldBudgetsData = <v3.BudgetsData>[];
      final expectedNewBudgetsData = <v4.BudgetsData>[];
      final oldCategoryKeywordsData = <v3.CategoryKeywordsData>[];
      final expectedNewCategoryKeywordsData = <v4.CategoryKeywordsData>[];
      final oldAppEventsData = <v3.AppEventsData>[];
      final expectedNewAppEventsData = <v4.AppEventsData>[];
      final oldRecurringTransactionsData = <v3.RecurringTransactionsData>[];
      final expectedNewRecurringTransactionsData =
          <v4.RecurringTransactionsData>[];

      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 4,
        createOld: v3.DatabaseAtV3.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.categories, oldCategoriesData);
          batch.insertAll(oldDb.transactions, oldTransactionsData);
          batch.insertAll(oldDb.categoryKeywords, oldCategoryKeywordsData);
          batch.insertAll(oldDb.budgets, oldBudgetsData);
          batch.insertAll(oldDb.appEvents, oldAppEventsData);
          batch.insertAll(
            oldDb.recurringTransactions,
            oldRecurringTransactionsData,
          );
        },
        validateItems: (newDb) async {
          expect(
            expectedNewCategoriesData,
            await newDb.select(newDb.categories).get(),
          );
          expect(
            expectedNewTransactionsData,
            await newDb.select(newDb.transactions).get(),
          );
          expect(
            expectedNewCategoryKeywordsData,
            await newDb.select(newDb.categoryKeywords).get(),
          );
          expect(
            expectedNewBudgetsData,
            await newDb.select(newDb.budgets).get(),
          );
          expect(
            expectedNewAppEventsData,
            await newDb.select(newDb.appEvents).get(),
          );
          expect(
            expectedNewRecurringTransactionsData,
            await newDb.select(newDb.recurringTransactions).get(),
          );
          final wallets = await newDb.select(newDb.wallets).get();
          expect(wallets, hasLength(1));
          expect(wallets.single.name, 'Ví mặc định');
        },
      );
    },
  );

  // Phase 14: v4→v5 chỉ thêm hai bảng MỚI hoàn toàn (`transaction_lines`,
  // `transaction_templates`) — cùng mức rủi ro thấp như v2→v3 (Phase 12),
  // không đụng cột nào của 7 bảng cũ. Test xác nhận dữ liệu cũ (một danh
  // mục + một ví + một giao dịch) sống sót nguyên vẹn và hai bảng mới tồn
  // tại nhưng trống.
  test(
    'migration from v4 to v5 does not corrupt data — thêm transaction_lines + transaction_templates',
    () async {
      final oldCategoriesData = <v4.CategoriesData>[
        const v4.CategoriesData(
          id: 1,
          name: 'Ăn uống',
          kind: 'expense',
          categoryColorId: 0,
          iconCode: 'restaurant',
          isArchived: 0,
          createdAt: 1755734400,
          parentCategoryId: null,
          sortOrder: 0,
        ),
      ];
      final expectedNewCategoriesData = <v5.CategoriesData>[
        const v5.CategoriesData(
          id: 1,
          name: 'Ăn uống',
          kind: 'expense',
          categoryColorId: 0,
          iconCode: 'restaurant',
          isArchived: 0,
          createdAt: 1755734400,
          parentCategoryId: null,
          sortOrder: 0,
        ),
      ];

      final oldWalletsData = <v4.WalletsData>[
        const v4.WalletsData(
          id: 1,
          name: 'Ví mặc định',
          categoryColorId: 0,
          iconCode: 'account_balance_wallet',
          isArchived: 0,
          createdAt: 1755734400,
        ),
      ];
      final expectedNewWalletsData = <v5.WalletsData>[
        const v5.WalletsData(
          id: 1,
          name: 'Ví mặc định',
          categoryColorId: 0,
          iconCode: 'account_balance_wallet',
          isArchived: 0,
          createdAt: 1755734400,
        ),
      ];

      final oldTransactionsData = <v4.TransactionsData>[
        const v4.TransactionsData(
          id: 1,
          amountMinor: -35000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: 1755734400,
          categoryId: 1,
          note: 'cà phê',
          walletId: 1,
          isTransfer: 0,
          linkedTransactionId: null,
          noteAscii: 'ca phe',
          sourceId: null,
          createdAt: 1755734400,
          updatedAt: 1755734400,
        ),
      ];
      final expectedNewTransactionsData = <v5.TransactionsData>[
        const v5.TransactionsData(
          id: 1,
          amountMinor: -35000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: 1755734400,
          categoryId: 1,
          note: 'cà phê',
          walletId: 1,
          isTransfer: 0,
          linkedTransactionId: null,
          noteAscii: 'ca phe',
          sourceId: null,
          createdAt: 1755734400,
          updatedAt: 1755734400,
        ),
      ];

      final oldBudgetsData = <v4.BudgetsData>[];
      final expectedNewBudgetsData = <v5.BudgetsData>[];
      final oldCategoryKeywordsData = <v4.CategoryKeywordsData>[];
      final expectedNewCategoryKeywordsData = <v5.CategoryKeywordsData>[];
      final oldAppEventsData = <v4.AppEventsData>[];
      final expectedNewAppEventsData = <v5.AppEventsData>[];
      final oldRecurringTransactionsData = <v4.RecurringTransactionsData>[];
      final expectedNewRecurringTransactionsData =
          <v5.RecurringTransactionsData>[];

      // Bảng mới, không có gì trong v4 để backfill — kỳ vọng trống sau upgrade.
      final expectedNewTransactionLinesData = <v5.TransactionLinesData>[];
      final expectedNewTransactionTemplatesData =
          <v5.TransactionTemplatesData>[];

      await verifier.testWithDataIntegrity(
        oldVersion: 4,
        newVersion: 5,
        createOld: v4.DatabaseAtV4.new,
        createNew: v5.DatabaseAtV5.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.categories, oldCategoriesData);
          batch.insertAll(oldDb.wallets, oldWalletsData);
          batch.insertAll(oldDb.transactions, oldTransactionsData);
          batch.insertAll(oldDb.categoryKeywords, oldCategoryKeywordsData);
          batch.insertAll(oldDb.budgets, oldBudgetsData);
          batch.insertAll(oldDb.appEvents, oldAppEventsData);
          batch.insertAll(
            oldDb.recurringTransactions,
            oldRecurringTransactionsData,
          );
        },
        validateItems: (newDb) async {
          expect(
            expectedNewCategoriesData,
            await newDb.select(newDb.categories).get(),
          );
          expect(
            expectedNewWalletsData,
            await newDb.select(newDb.wallets).get(),
          );
          expect(
            expectedNewTransactionsData,
            await newDb.select(newDb.transactions).get(),
          );
          expect(
            expectedNewCategoryKeywordsData,
            await newDb.select(newDb.categoryKeywords).get(),
          );
          expect(
            expectedNewBudgetsData,
            await newDb.select(newDb.budgets).get(),
          );
          expect(
            expectedNewAppEventsData,
            await newDb.select(newDb.appEvents).get(),
          );
          expect(
            expectedNewRecurringTransactionsData,
            await newDb.select(newDb.recurringTransactions).get(),
          );
          expect(
            expectedNewTransactionLinesData,
            await newDb.select(newDb.transactionLines).get(),
          );
          expect(
            expectedNewTransactionTemplatesData,
            await newDb.select(newDb.transactionTemplates).get(),
          );
        },
      );
    },
  );

  // Phase 15: v5→v6 chỉ thêm MỘT cột mới `budgets.carry_over` (BOOLEAN,
  // DEFAULT false) — `addColumn` thường (hằng số biên dịch, không cần
  // backfill runtime như Phase 13's `walletId`). Test xác nhận một ngân sách
  // đã đặt TRƯỚC migration sống sót nguyên vẹn và `carryOver` mặc định về
  // `false` (0) — không đổi hành vi carry-over cho ngân sách cũ nào.
  test(
    'migration from v5 to v6 does not corrupt data — thêm budgets.carry_over',
    () async {
      final oldCategoriesData = <v5.CategoriesData>[
        const v5.CategoriesData(
          id: 1,
          name: 'Ăn uống',
          kind: 'expense',
          categoryColorId: 0,
          iconCode: 'restaurant',
          isArchived: 0,
          createdAt: 1755734400,
          parentCategoryId: null,
          sortOrder: 0,
        ),
      ];
      final expectedNewCategoriesData = <v6.CategoriesData>[
        const v6.CategoriesData(
          id: 1,
          name: 'Ăn uống',
          kind: 'expense',
          categoryColorId: 0,
          iconCode: 'restaurant',
          isArchived: 0,
          createdAt: 1755734400,
          parentCategoryId: null,
          sortOrder: 0,
        ),
      ];

      final oldBudgetsData = <v5.BudgetsData>[
        const v5.BudgetsData(
          id: 1,
          categoryId: 1,
          yearMonth: '2026-08',
          amountMinor: 2000000,
          currency: 'VND',
          currencyScale: 0,
          createdAt: 1755734400,
        ),
      ];
      // Cột mới `carryOver` phải mặc định `false` (0) cho hàng ĐÃ CÓ TRƯỚC
      // migration — không có ngân sách cũ nào tự nhiên bật carry-over. Kiểu
      // `int` (0/1) chứ không `bool`: lớp snapshot bare dùng kiểu lưu trữ SQL
      // thô cho `BoolColumn`, xem [[project_tonyfino_gotchas]] § Phase 13.
      final expectedNewBudgetsData = <v6.BudgetsData>[
        const v6.BudgetsData(
          id: 1,
          categoryId: 1,
          yearMonth: '2026-08',
          amountMinor: 2000000,
          currency: 'VND',
          currencyScale: 0,
          carryOver: 0,
          createdAt: 1755734400,
        ),
      ];

      final oldWalletsData = <v5.WalletsData>[];
      final expectedNewWalletsData = <v6.WalletsData>[];
      final oldTransactionsData = <v5.TransactionsData>[];
      final expectedNewTransactionsData = <v6.TransactionsData>[];
      final oldCategoryKeywordsData = <v5.CategoryKeywordsData>[];
      final expectedNewCategoryKeywordsData = <v6.CategoryKeywordsData>[];
      final oldAppEventsData = <v5.AppEventsData>[];
      final expectedNewAppEventsData = <v6.AppEventsData>[];
      final oldRecurringTransactionsData = <v5.RecurringTransactionsData>[];
      final expectedNewRecurringTransactionsData =
          <v6.RecurringTransactionsData>[];
      final oldTransactionLinesData = <v5.TransactionLinesData>[];
      final expectedNewTransactionLinesData = <v6.TransactionLinesData>[];
      final oldTransactionTemplatesData = <v5.TransactionTemplatesData>[];
      final expectedNewTransactionTemplatesData =
          <v6.TransactionTemplatesData>[];

      await verifier.testWithDataIntegrity(
        oldVersion: 5,
        newVersion: 6,
        createOld: v5.DatabaseAtV5.new,
        createNew: v6.DatabaseAtV6.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.categories, oldCategoriesData);
          batch.insertAll(oldDb.wallets, oldWalletsData);
          batch.insertAll(oldDb.transactions, oldTransactionsData);
          batch.insertAll(oldDb.categoryKeywords, oldCategoryKeywordsData);
          batch.insertAll(oldDb.budgets, oldBudgetsData);
          batch.insertAll(oldDb.appEvents, oldAppEventsData);
          batch.insertAll(
            oldDb.recurringTransactions,
            oldRecurringTransactionsData,
          );
          batch.insertAll(oldDb.transactionLines, oldTransactionLinesData);
          batch.insertAll(
            oldDb.transactionTemplates,
            oldTransactionTemplatesData,
          );
        },
        validateItems: (newDb) async {
          expect(
            expectedNewCategoriesData,
            await newDb.select(newDb.categories).get(),
          );
          expect(
            expectedNewWalletsData,
            await newDb.select(newDb.wallets).get(),
          );
          expect(
            expectedNewTransactionsData,
            await newDb.select(newDb.transactions).get(),
          );
          expect(
            expectedNewCategoryKeywordsData,
            await newDb.select(newDb.categoryKeywords).get(),
          );
          expect(
            expectedNewBudgetsData,
            await newDb.select(newDb.budgets).get(),
          );
          expect(
            expectedNewAppEventsData,
            await newDb.select(newDb.appEvents).get(),
          );
          expect(
            expectedNewRecurringTransactionsData,
            await newDb.select(newDb.recurringTransactions).get(),
          );
          expect(
            expectedNewTransactionLinesData,
            await newDb.select(newDb.transactionLines).get(),
          );
          expect(
            expectedNewTransactionTemplatesData,
            await newDb.select(newDb.transactionTemplates).get(),
          );
        },
      );
    },
  );

  // Phase 16: v6→v7 — hai bảng MỚI hoàn toàn (`savings_goals`, `debts`) + hai
  // cột nullable MỚI trên `transactions` (`goal_id`/`debt_id`) — cùng mức
  // rủi ro thấp như v4→v5, không đụng cột nào của bảng cũ.
  test(
    'migration from v6 to v7 does not corrupt data — thêm savings_goals + debts + transactions.goal_id/debt_id',
    () async {
      final oldTransactionsData = <v6.TransactionsData>[
        const v6.TransactionsData(
          id: 1,
          amountMinor: -35000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: 1755734400,
          categoryId: null,
          note: 'cà phê',
          walletId: 1,
          isTransfer: 0,
          linkedTransactionId: null,
          noteAscii: null,
          sourceId: null,
          createdAt: 1755734400,
          updatedAt: 1755734400,
        ),
      ];
      final expectedNewTransactionsData = <v7.TransactionsData>[
        const v7.TransactionsData(
          id: 1,
          amountMinor: -35000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: 1755734400,
          categoryId: null,
          note: 'cà phê',
          walletId: 1,
          isTransfer: 0,
          linkedTransactionId: null,
          goalId: null,
          debtId: null,
          noteAscii: null,
          sourceId: null,
          createdAt: 1755734400,
          updatedAt: 1755734400,
        ),
      ];

      final oldWalletsData = <v6.WalletsData>[
        const v6.WalletsData(
          id: 1,
          name: 'Ví mặc định',
          categoryColorId: 0,
          iconCode: 'account_balance_wallet',
          isArchived: 0,
          createdAt: 1755734400,
        ),
      ];
      final expectedNewWalletsData = <v7.WalletsData>[
        const v7.WalletsData(
          id: 1,
          name: 'Ví mặc định',
          categoryColorId: 0,
          iconCode: 'account_balance_wallet',
          isArchived: 0,
          createdAt: 1755734400,
        ),
      ];

      final oldCategoriesData = <v6.CategoriesData>[];
      final expectedNewCategoriesData = <v7.CategoriesData>[];
      final oldCategoryKeywordsData = <v6.CategoryKeywordsData>[];
      final expectedNewCategoryKeywordsData = <v7.CategoryKeywordsData>[];
      final oldBudgetsData = <v6.BudgetsData>[];
      final expectedNewBudgetsData = <v7.BudgetsData>[];
      final oldAppEventsData = <v6.AppEventsData>[];
      final expectedNewAppEventsData = <v7.AppEventsData>[];
      final oldRecurringTransactionsData = <v6.RecurringTransactionsData>[];
      final expectedNewRecurringTransactionsData =
          <v7.RecurringTransactionsData>[];
      final oldTransactionLinesData = <v6.TransactionLinesData>[];
      final expectedNewTransactionLinesData = <v7.TransactionLinesData>[];
      final oldTransactionTemplatesData = <v6.TransactionTemplatesData>[];
      final expectedNewTransactionTemplatesData =
          <v7.TransactionTemplatesData>[];

      // Hai bảng mới, không có gì trong v6 để backfill — kỳ vọng trống sau
      // upgrade.
      final expectedNewSavingsGoalsData = <v7.SavingsGoalsData>[];
      final expectedNewDebtsData = <v7.DebtsData>[];

      await verifier.testWithDataIntegrity(
        oldVersion: 6,
        newVersion: 7,
        createOld: v6.DatabaseAtV6.new,
        createNew: v7.DatabaseAtV7.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.categories, oldCategoriesData);
          batch.insertAll(oldDb.wallets, oldWalletsData);
          batch.insertAll(oldDb.transactions, oldTransactionsData);
          batch.insertAll(oldDb.categoryKeywords, oldCategoryKeywordsData);
          batch.insertAll(oldDb.budgets, oldBudgetsData);
          batch.insertAll(oldDb.appEvents, oldAppEventsData);
          batch.insertAll(
            oldDb.recurringTransactions,
            oldRecurringTransactionsData,
          );
          batch.insertAll(oldDb.transactionLines, oldTransactionLinesData);
          batch.insertAll(
            oldDb.transactionTemplates,
            oldTransactionTemplatesData,
          );
        },
        validateItems: (newDb) async {
          expect(
            expectedNewCategoriesData,
            await newDb.select(newDb.categories).get(),
          );
          expect(
            expectedNewWalletsData,
            await newDb.select(newDb.wallets).get(),
          );
          expect(
            expectedNewTransactionsData,
            await newDb.select(newDb.transactions).get(),
          );
          expect(
            expectedNewCategoryKeywordsData,
            await newDb.select(newDb.categoryKeywords).get(),
          );
          expect(
            expectedNewBudgetsData,
            await newDb.select(newDb.budgets).get(),
          );
          expect(
            expectedNewAppEventsData,
            await newDb.select(newDb.appEvents).get(),
          );
          expect(
            expectedNewRecurringTransactionsData,
            await newDb.select(newDb.recurringTransactions).get(),
          );
          expect(
            expectedNewTransactionLinesData,
            await newDb.select(newDb.transactionLines).get(),
          );
          expect(
            expectedNewTransactionTemplatesData,
            await newDb.select(newDb.transactionTemplates).get(),
          );
          expect(
            expectedNewSavingsGoalsData,
            await newDb.select(newDb.savingsGoals).get(),
          );
          expect(expectedNewDebtsData, await newDb.select(newDb.debts).get());
        },
      );
    },
  );

  // v10→v11 (2026-08-23): mỗi ví có bộ danh mục riêng — thêm
  // `categories.wallet_id`. Đây là migration có BACKFILL PHỤ THUỘC DỮ LIỆU
  // (id ví lấy lúc chạy, không phải hằng số), nên phải chứng minh bằng dữ
  // liệu thật rằng danh mục cũ không mất và được gắn đúng ví ĐANG CÓ —
  // không phải id `1` đoán bừa. Ví trong test cố ý mang id 7.
  test(
    'migration from v10 to v11 — danh mục cũ giữ nguyên và nhận đúng ví đang có',
    () async {
      final schema = await verifier.schemaAt(10);
      final oldDb = v10.DatabaseAtV10(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insert(
          oldDb.wallets,
          const v10.WalletsData(
            id: 7,
            name: 'Ví mặc định',
            categoryColorId: 0,
            iconCode: 'account_balance_wallet',
            isArchived: 0,
            createdAt: 1755734400,
          ),
        );
        batch.insertAll(oldDb.categories, const <v10.CategoriesData>[
          v10.CategoriesData(
            id: 1,
            name: 'Ăn uống',
            kind: 'expense',
            categoryColorId: 0,
            iconCode: 'restaurant',
            isArchived: 0,
            createdAt: 1755734400,
            parentCategoryId: null,
            sortOrder: 0,
          ),
          v10.CategoriesData(
            id: 2,
            name: 'Tiêu vặt',
            kind: 'expense',
            categoryColorId: 0,
            iconCode: 'local_cafe',
            isArchived: 0,
            createdAt: 1755734400,
            parentCategoryId: 1,
            sortOrder: 0,
          ),
        ]);
      });
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 11);

      final rows = await db.select(db.categories).get();
      expect(rows, hasLength(2));
      expect(
        rows.map((c) => c.name),
        containsAll(<String>['Ăn uống', 'Tiêu vặt']),
        reason: 'không được mất danh mục nào',
      );
      expect(
        rows.every((c) => c.walletId == 7),
        isTrue,
        reason: 'phải gắn vào ví ĐANG CÓ (id 7), không phải hằng số 1',
      );
      // Quan hệ cha–con còn nguyên sau khi `alterTable` dựng lại bảng.
      expect(rows.firstWhere((c) => c.name == 'Tiêu vặt').parentCategoryId, 1);

      await db.close();
    },
  );
}
