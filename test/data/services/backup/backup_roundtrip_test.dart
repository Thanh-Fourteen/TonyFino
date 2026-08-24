// Test bắt buộc #3 (Phase 4): seed 500 giao dịch → export → xoá DB → import
// → khớp từng byte + tổng theo tháng. Đây là bài test quan trọng nhất phase
// này — D3 nói backup/restore ở Phase 4 chứ không phải Phase 13 chính vì nó
// là đường phục hồi DUY NHẤT khi `allowBackup="false"` chặn hết đường khác.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/services/backup/backup_service.dart';
import 'package:tonyfino/data/services/receipt_image_service.dart';

import '../../../support/fake_path_provider.dart';
import '../../../support/open_test_database.dart';

void main() {
  test(
    'round-trip 500 giao dịch: export → xoá DB → import → khớp từng byte + tổng theo tháng',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final backup = BackupService(db);
      final exportedAt = DateTime.utc(2026, 8, 21, 12, 0, 0);

      final categories = await db.select(db.categories).get();
      final categoryIds = categories.map((c) => c.id).toList();
      final walletId = (await db.select(db.wallets).get()).first.id;
      final random = Random(20260821);

      final notes = <String?>[
        null,
        'cà phê 35k',
        'ăn trưa bún bò',
        'gửi xe máy',
        'lương tháng 8',
        'quà cho mẹ, không nhớ giá',
        'đổ xăng 50.000đ',
        '“chi tiêu” lặt vặt — dấu ngoặc kép + gạch ngang',
      ];

      final companions = List.generate(500, (i) {
        final isIncome =
            random.nextInt(10) == 0; // ít giao dịch thu, giống Rolly thật
        final amount =
            (random.nextInt(2000) + 1) * 1000; // bội số 1.000đ, whole VND
        final day = random.nextInt(180); // trải trên ~6 tháng
        final occurredAt = DateTime.utc(2026, 3, 1).add(
          Duration(
            days: day,
            hours: random.nextInt(24),
            minutes: random.nextInt(60),
          ),
        );
        return TransactionsCompanion.insert(
          amountMinor: isIncome ? amount : -amount,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: occurredAt,
          walletId: walletId,
          categoryId: Value(categoryIds[random.nextInt(categoryIds.length)]),
          note: Value(notes[random.nextInt(notes.length)]),
        );
      });

      await db.batch((batch) => batch.insertAll(db.transactions, companions));

      // Snapshot "trước" đã đi qua DB một lần (occurredAt bị làm tròn giây bởi
      // drift mặc định — so sánh với chính snapshot này, không phải DateTime
      // gốc sinh ra ở Dart, để phép so khớp không dính lỗi làm tròn).
      final originalTransactions = await (db.select(
        db.transactions,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(originalTransactions, hasLength(500));

      final originalMonthlySums = _monthlySums(originalTransactions);

      final firstExport = await backup.exportToJson(exportedAt: exportedAt);

      // "Xoá DB": xoá sạch mọi bảng mà backup phủ tới, mô phỏng đúng kịch bản
      // mất máy/mất app rồi cài lại — restore phải tự đứng dậy từ con số 0.
      await db.delete(db.categoryKeywords).go();
      await db.delete(db.budgets).go();
      await db.delete(db.transactions).go();
      await db.delete(db.categories).go();
      await db.delete(db.wallets).go();
      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await db.select(db.categories).get(), isEmpty);
      expect(await db.select(db.wallets).get(), isEmpty);

      final importResult = await backup.importFromJson(firstExport);
      expect(importResult.isOk, isTrue, reason: '$importResult');

      final importedTransactions = await (db.select(
        db.transactions,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

      // Khớp TỪNG BYTE, không phải "gần đúng": so trực tiếp danh sách data
      // class (drift sinh `==` theo từng field) — amount, currency, note,
      // ngày giờ, tất cả phải giống hệt, không lệch một ký tự hay một đồng.
      expect(importedTransactions, originalTransactions);

      final importedCategories = await (db.select(
        db.categories,
      )..orderBy([(c) => OrderingTerm.asc(c.id)])).get();
      // 12 gốc + 1 con mặc định ("Tiêu vặt" dưới "Ăn uống", Phase 22 addendum).
      expect(importedCategories, hasLength(13));

      expect(_monthlySums(importedTransactions), originalMonthlySums);

      // Re-export sau import, cùng exportedAt cố định: phải ra ĐÚNG CÙNG MẢNG
      // BYTE — chứng minh export/import không có bất kỳ rò rỉ phi-quyết-định
      // nào (thứ tự, làm tròn số, encoding) có thể âm thầm đổi dữ liệu.
      final secondExport = await backup.exportToJson(exportedAt: exportedAt);
      expect(secondExport, equals(firstExport));
    },
  );

  test(
    '🚨 Phase 17: ảnh hoá đơn đính kèm sống qua export → xoá DB LẪN FILE → import',
    () async {
      final pathProvider = await FakePathProviderPlatform.install();
      addTearDown(pathProvider.dispose);
      const receiptImages = ReceiptImageService();

      final db = openTestDatabase();
      addTearDown(db.close);
      final backup = BackupService(db, receiptImageService: receiptImages);

      final walletId = (await db.select(db.wallets).get()).first.id;
      final imageBytes = Uint8List.fromList(List.generate(64, (i) => i % 256));
      final fileName = await receiptImages.saveImage(
        imageBytes,
        now: DateTime.utc(2026, 8, 22),
        extension: 'jpg',
      );

      final transactionId = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -50000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime.utc(2026, 8, 20),
              walletId: walletId,
              receiptImageFilename: Value(fileName),
            ),
          );

      final export = await backup.exportToJson(
        exportedAt: DateTime.utc(2026, 8, 22, 12),
      );

      // "Mất máy" thật sự: xoá CẢ hàng DB LẪN file ảnh trên đĩa, không chỉ
      // một trong hai — nếu chỉ xoá DB thì test này không chứng minh được gì
      // (ReceiptImageService vẫn đọc lại được file cũ mà không cần backup).
      await db.delete(db.transactions).go();
      await receiptImages.deleteImage(fileName);
      expect(await receiptImages.readImage(fileName), null);

      final importResult = await backup.importFromJson(export);
      expect(importResult.isOk, isTrue, reason: '$importResult');

      final restored = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(transactionId))).getSingle();
      expect(restored.receiptImageFilename, fileName);

      final restoredBytes = await receiptImages.readImage(fileName);
      expect(restoredBytes, imageBytes);
    },
  );

  test('🚨 Phase 24: 7 bảng bị bỏ sót trước đó (recurring/lines/templates/'
      'savingsGoals/debts/tags/transactionTags) + goalId/debtId/carryOver — '
      'export → xoá DB → import → khớp TỪNG BẢNG', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final backup = BackupService(db);

    final categories = await db.select(db.categories).get();
    final categoryId = categories.first.id;
    final walletId = (await db.select(db.wallets).get()).first.id;

    final goalId = await db
        .into(db.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            name: 'Xe máy',
            targetAmountMinor: 50000000,
            currency: 'VND',
            currencyScale: 0,
            sourceId: const Value('test:goal'),
          ),
        );
    final debtId = await db
        .into(db.debts)
        .insert(
          DebtsCompanion.insert(
            counterpartyName: 'Ngân hàng',
            kind: 'debt',
            principalMinor: 10000000,
            currency: 'VND',
            currencyScale: 0,
            startDate: DateTime.utc(2026, 1, 1),
          ),
        );
    final tagId = await db
        .into(db.tags)
        .insert(TagsCompanion.insert(name: 'công tác', categoryColorId: 0));
    final txnId = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: -1500000,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: DateTime.utc(2026, 8, 1),
            walletId: walletId,
            categoryId: const Value(null),
            goalId: Value(goalId),
            debtId: Value(debtId),
          ),
        );
    await db
        .into(db.transactionLines)
        .insert(
          TransactionLinesCompanion.insert(
            transactionId: txnId,
            categoryId: Value(categoryId),
            amountMinor: -1500000,
          ),
        );
    await db
        .into(db.transactionTags)
        .insert(
          TransactionTagsCompanion.insert(transactionId: txnId, tagId: tagId),
        );
    await db
        .into(db.recurringTransactions)
        .insert(
          RecurringTransactionsCompanion.insert(
            categoryId: Value(categoryId),
            amountMinor: -200000,
            currency: 'VND',
            currencyScale: 0,
            frequency: 'monthly',
            nextOccurrenceDate: DateTime.utc(2026, 9, 1),
          ),
        );
    await db
        .into(db.transactionTemplates)
        .insert(
          TransactionTemplatesCompanion.insert(
            name: 'Cà phê sáng',
            amountMinor: -30000,
            currency: 'VND',
            currencyScale: 0,
            categoryId: Value(categoryId),
          ),
        );
    await db
        .into(db.budgets)
        .insert(
          BudgetsCompanion.insert(
            categoryId: categoryId,
            yearMonth: '2026-08',
            amountMinor: 2000000,
            currency: 'VND',
            currencyScale: 0,
            carryOver: const Value(true),
          ),
        );

    final export = await backup.exportToJson(
      exportedAt: DateTime.utc(2026, 8, 22),
    );

    await db.delete(db.transactionTags).go();
    await db.delete(db.transactionLines).go();
    await db.delete(db.recurringTransactions).go();
    await db.delete(db.transactionTemplates).go();
    await db.delete(db.budgets).go();
    await db.delete(db.transactions).go();
    await db.delete(db.savingsGoals).go();
    await db.delete(db.debts).go();
    await db.delete(db.tags).go();

    final importResult = await backup.importFromJson(export);
    expect(importResult.isOk, isTrue, reason: '$importResult');

    final restoredGoal = await (db.select(
      db.savingsGoals,
    )..where((g) => g.id.equals(goalId))).getSingle();
    expect(restoredGoal.name, 'Xe máy');
    expect(restoredGoal.sourceId, 'test:goal');

    final restoredDebt = await (db.select(
      db.debts,
    )..where((d) => d.id.equals(debtId))).getSingle();
    expect(restoredDebt.counterpartyName, 'Ngân hàng');

    final restoredTag = await (db.select(
      db.tags,
    )..where((t) => t.id.equals(tagId))).getSingle();
    expect(restoredTag.name, 'công tác');

    final restoredTxn = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(txnId))).getSingle();
    expect(restoredTxn.goalId, goalId);
    expect(restoredTxn.debtId, debtId);

    final restoredLines = await (db.select(
      db.transactionLines,
    )..where((l) => l.transactionId.equals(txnId))).get();
    expect(restoredLines, hasLength(1));
    expect(restoredLines.single.amountMinor, -1500000);

    final restoredTags = await (db.select(
      db.transactionTags,
    )..where((t) => t.transactionId.equals(txnId))).get();
    expect(restoredTags, hasLength(1));
    expect(restoredTags.single.tagId, tagId);

    final restoredRecurring = await db.select(db.recurringTransactions).get();
    expect(restoredRecurring, hasLength(1));
    expect(restoredRecurring.single.frequency, 'monthly');

    final restoredTemplates = await db.select(db.transactionTemplates).get();
    expect(restoredTemplates, hasLength(1));
    expect(restoredTemplates.single.name, 'Cà phê sáng');

    final restoredBudget = await (db.select(
      db.budgets,
    )..where((b) => b.categoryId.equals(categoryId))).getSingle();
    expect(restoredBudget.carryOver, isTrue);
  });

  test(
    'backup CŨ (trước Phase 24, thiếu 7 khoá mới) vẫn import được — thiếu bảng '
    'coi như rỗng, không lỗi',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final backup = BackupService(db);

      final walletId = (await db.select(db.wallets).get()).first.id;
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -10000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime.utc(2026, 8, 1),
              walletId: walletId,
            ),
          );
      final fullExport =
          jsonDecode(
                utf8.decode(
                  await backup.exportToJson(
                    exportedAt: DateTime.utc(2026, 8, 22),
                  ),
                ),
              )
              as Map<String, Object?>;
      // Giả lập backup CŨ — xoá đúng 7 khoá Phase 24 thêm, y hệt một file
      // export TRƯỚC phase này.
      final oldFormat = Map<String, Object?>.from(fullExport)
        ..remove('recurringTransactions')
        ..remove('transactionLines')
        ..remove('transactionTemplates')
        ..remove('savingsGoals')
        ..remove('debts')
        ..remove('tags')
        ..remove('transactionTags');
      final oldBytes = Uint8List.fromList(utf8.encode(jsonEncode(oldFormat)));

      final importResult = await backup.importFromJson(oldBytes);
      expect(importResult.isOk, isTrue, reason: '$importResult');
      expect(await db.select(db.savingsGoals).get(), isEmpty);
      expect(await db.select(db.tags).get(), isEmpty);
      expect(await db.select(db.transactions).get(), hasLength(1));
    },
  );

  test(
    'import báo lỗi rõ ràng với version không tương thích, không phá dữ liệu cũ',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final backup = BackupService(db);

      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion(
              name: const Value('Giữ nguyên'),
              kind: const Value('expense'),
              categoryColorId: const Value(0),
              iconCode: const Value('home'),
              walletId: Value(await defaultWalletId(db)),
            ),
          );
      final beforeCount = (await db.select(db.categories).get()).length;

      final badBytes = Uint8List.fromList(utf8.encode('{"version": 999}'));
      final result = await backup.importFromJson(badBytes);
      expect(result.isErr, isTrue);
      expect(await db.select(db.categories).get(), hasLength(beforeCount));
    },
  );
  test('🚨 Hũ chia thu nhập (v13) + categories.jarId sống sót qua round-trip — '
      'bảng này bị bỏ sót khỏi backup từ lúc thêm, gỡ cài rồi restore là mất '
      'sạch cách chia hũ mà không báo gì', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final backup = BackupService(db);

    final walletId = (await db.select(db.wallets).get()).first.id;
    final jarId = await db
        .into(db.jars)
        .insert(
          JarsCompanion.insert(
            walletId: walletId,
            name: 'Tiết kiệm dài hạn',
            percent: 10,
            categoryColorId: 3,
            iconCode: 'savings',
            carryOver: const Value(true),
            sortOrder: const Value(2),
          ),
        );
    final categoryId = (await db.select(db.categories).get()).first.id;
    await (db.update(db.categories)..where((c) => c.id.equals(categoryId)))
        .write(CategoriesCompanion(jarId: Value(jarId)));

    final export = await backup.exportToJson(exportedAt: DateTime(2026, 8, 23));

    // Xoá đúng như một lần gỡ cài đặt: hũ biến mất, dây nối cũng vậy.
    await (db.update(db.categories)..where((c) => c.id.equals(categoryId)))
        .write(const CategoriesCompanion(jarId: Value(null)));
    await db.delete(db.jars).go();
    expect(await db.select(db.jars).get(), isEmpty);

    final result = await backup.importFromJson(export);
    expect(result.isOk, isTrue, reason: '$result');

    final restored = await (db.select(
      db.jars,
    )..where((j) => j.id.equals(jarId))).getSingle();
    expect(restored.name, 'Tiết kiệm dài hạn');
    expect(restored.percent, 10);
    expect(restored.carryOver, isTrue);
    expect(restored.sortOrder, 2);

    // Dây nối danh mục ↔ hũ: hũ về mà không có dây thì hũ nào cũng rỗng.
    final restoredCategory = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(categoryId))).getSingle();
    expect(restoredCategory.jarId, jarId);
  });

  test('backup CŨ (trước v13, không có khoá "jars") vẫn import được', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final backup = BackupService(db);

    final export = await backup.exportToJson(exportedAt: DateTime(2026, 8, 23));
    final map = jsonDecode(utf8.decode(export)) as Map<String, Object?>;
    map.remove('jars');
    for (final c in (map['categories'] as List).cast<Map<String, Object?>>()) {
      c.remove('jarId');
    }
    final old = Uint8List.fromList(utf8.encode(jsonEncode(map)));

    final result = await backup.importFromJson(old);
    expect(result.isOk, isTrue, reason: '$result');
    expect(await db.select(db.jars).get(), isEmpty);
  });
}

/// `'YYYY-MM' -> tổng amountMinor` — oracle độc lập kiểu Phase 2 (đối chiếu
/// `wallet_view` của Rolly), viết lại bằng tay ở đây thay vì tái dùng
/// `BackupService` để không tự kiểm chứng bằng chính code đang test.
Map<String, int> _monthlySums(List<Transaction> transactions) {
  final sums = <String, int>{};
  for (final t in transactions) {
    final key =
        '${t.occurredAt.year.toString().padLeft(4, '0')}-${t.occurredAt.month.toString().padLeft(2, '0')}';
    sums[key] = (sums[key] ?? 0) + t.amountMinor;
  }
  return sums;
}
