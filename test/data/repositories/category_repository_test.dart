import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/result/result.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/category_repository.dart';

import '../../support/open_test_database.dart';

int _unwrap(Result<int, AppError> result) =>
    result.when(ok: (v) => v, err: (e) => throw Exception('$e'));

void main() {
  test(
    'recordKeywordCorrection — từ khoá mới bắt đầu ở trọng số khởi tạo',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = CategoryRepository(db);
      final categories = await db.select(db.categories).get();
      final targetId = categories.first.id;

      final result = await repo.recordKeywordCorrection(
        categoryId: targetId,
        leftoverText: 'sửa xe đạp',
      );
      expect(result.isOk, isTrue);

      final rows = await (db.select(
        db.categoryKeywords,
      )..where((k) => k.keyword.equals('sửa xe đạp'))).get();
      expect(rows, hasLength(1));
      expect(rows.single.categoryId, targetId);
      expect(rows.single.weight, kLearnedKeywordInitialWeight);
    },
  );

  test(
    'recordKeywordCorrection — sửa lặp lại cùng khoá thì CỘNG DỒN trọng số',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = CategoryRepository(db);
      final categories = await db.select(db.categories).get();
      final targetId = categories.first.id;

      await repo.recordKeywordCorrection(
        categoryId: targetId,
        leftoverText: 'quán quen',
      );
      await repo.recordKeywordCorrection(
        categoryId: targetId,
        leftoverText: 'quán quen',
      );

      final rows = await (db.select(
        db.categoryKeywords,
      )..where((k) => k.keyword.equals('quán quen'))).get();
      expect(
        rows,
        hasLength(1),
      ); // KHÔNG nhân bản dòng — cùng khoá thì cộng dồn.
      expect(
        rows.single.weight,
        kLearnedKeywordInitialWeight + kLearnedKeywordIncrement,
      );
    },
  );

  test(
    'recordKeywordCorrection — trọng số có trần, không tăng vô hạn',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = CategoryRepository(db);
      final categories = await db.select(db.categories).get();
      final targetId = categories.first.id;

      for (var i = 0; i < 20; i++) {
        await repo.recordKeywordCorrection(
          categoryId: targetId,
          leftoverText: 'từ hay sửa',
        );
      }

      final rows = await (db.select(
        db.categoryKeywords,
      )..where((k) => k.keyword.equals('từ hay sửa'))).get();
      expect(rows.single.weight, kLearnedKeywordMaxWeight);
    },
  );

  test('recordKeywordCorrection — chữ rỗng không ghi gì, không lỗi', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = CategoryRepository(db);
    final categories = await db.select(db.categories).get();

    final before = await db.select(db.categoryKeywords).get();
    final result = await repo.recordKeywordCorrection(
      categoryId: categories.first.id,
      leftoverText: '   ',
    );
    expect(result.isOk, isTrue);
    final after = await db.select(db.categoryKeywords).get();
    expect(after.length, before.length);
  });

  test('🚨 hasKeyword — danh mục có HAI khoá trùng nhau sau khi bỏ dấu vẫn trả '
      'lời được, không ném "Too many elements"', () async {
    // Seed "Ăn uống" có cả "bách hoá xanh" lẫn "bách hóa xanh" — hai cách
    // viết dấu, cùng ra `bach hoa xanh`. `getSingleOrNull` ném ở đúng ca
    // này và làm gãy luồng sửa danh mục ở màn chat.
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = CategoryRepository(db);
    final anUong = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Ăn uống'))).getSingle();

    expect(
      await repo.hasKeyword(categoryId: anUong.id, keyword: 'bách hoá xanh'),
      isTrue,
    );
    // Không phân biệt dấu: hỏi bằng cách viết nào cũng ra.
    expect(
      await repo.hasKeyword(categoryId: anUong.id, keyword: 'BACH HOA XANH'),
      isTrue,
    );
    expect(
      await repo.hasKeyword(categoryId: anUong.id, keyword: 'chưa từng có'),
      isFalse,
    );
  });

  test('learnKeywords — mỗi phần tử thành một khoá RIÊNG', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = CategoryRepository(db);
    final diChuyen = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Di chuyển'))).getSingle();

    await repo.learnKeywords(
      categoryId: diChuyen.id,
      keywords: ['hủ tíu', 'trưa'],
    );

    final rows = await (db.select(
      db.categoryKeywords,
    )..where((k) => k.categoryId.equals(diChuyen.id))).get();
    final learned = rows.map((k) => k.keyword).toSet();
    expect(learned, containsAll(['hủ tíu', 'trưa']));
  });

  test('deleteKeyword rồi restoreKeyword giữ NGUYÊN trọng số cũ', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = CategoryRepository(db);
    final diChuyen = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Di chuyển'))).getSingle();

    // Dạy ba lần → 1.5 + 0.5 + 0.5 = 2.5.
    for (var i = 0; i < 3; i++) {
      await repo.recordKeywordCorrection(
        categoryId: diChuyen.id,
        leftoverText: 'hủ tíu',
      );
    }
    final before =
        await (db.select(db.categoryKeywords)..where(
              (k) =>
                  k.categoryId.equals(diChuyen.id) & k.keyword.equals('hủ tíu'),
            ))
            .getSingle();
    expect(before.weight, closeTo(2.5, 0.001));

    expect((await repo.deleteKeyword(before.id)).isOk, isTrue);
    expect(
      await repo.hasKeyword(categoryId: diChuyen.id, keyword: 'hủ tíu'),
      isFalse,
    );

    await repo.restoreKeyword(
      categoryId: diChuyen.id,
      keyword: before.keyword,
      weight: before.weight,
    );
    final after =
        await (db.select(db.categoryKeywords)..where(
              (k) =>
                  k.categoryId.equals(diChuyen.id) & k.keyword.equals('hủ tíu'),
            ))
            .getSingle();
    // Hoàn tác KHÔNG được âm thầm hạ một khoá đã dạy ba lần về 1.5.
    expect(after.weight, closeTo(2.5, 0.001));
  });

  test(
    'watchAllKeywords — có sẵn ~300 khoá seed và phản ánh khoá học mới',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = CategoryRepository(db);
      final categories = await db.select(db.categories).get();

      final seeded = await repo.watchAllKeywords().first;
      expect(seeded.length, greaterThan(250));

      await repo.recordKeywordCorrection(
        categoryId: categories.first.id,
        leftoverText: 'từ khoá vừa học',
      );
      final afterLearning = await repo.watchAllKeywords().first;
      expect(afterLearning.length, seeded.length + 1);
    },
  );

  test(
    'insert danh mục cấp gốc mới → xếp CUỐI danh sách gốc (sortOrder lớn nhất)',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = CategoryRepository(db);

      final id = _unwrap(
        await repo.insert(
          name: 'Danh mục mới',
          kind: 'expense',
          walletId: await defaultWalletId(db),
          categoryColorId: 5,
          iconCode: 'more_horiz',
        ),
      );
      final all = await repo.watchAll().first;
      expect(all.last.id, id);
    },
  );

  test(
    'insert với parentCategoryId trỏ tới danh mục ĐÃ có cha → lỗi rõ ràng (chỉ một cấp)',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = CategoryRepository(db);
      final categories = await db.select(db.categories).get();
      final topId = categories.first.id;

      final childId = _unwrap(
        await repo.insert(
          name: 'Con',
          kind: 'expense',
          categoryColorId: 0,
          iconCode: 'more_horiz',
          parentCategoryId: topId,
        ),
      );

      final result = await repo.insert(
        name: 'Cháu',
        kind: 'expense',
        categoryColorId: 0,
        iconCode: 'more_horiz',
        parentCategoryId: childId,
      );
      expect(result.isErr, isTrue);
    },
  );

  test(
    'setArchived(true) rồi false — round-trip đúng, không mất dữ liệu khác',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = CategoryRepository(db);
      final categories = await db.select(db.categories).get();
      final targetId = categories.first.id;

      await repo.setArchived(targetId, true);
      var row = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(targetId))).getSingle();
      expect(row.isArchived, isTrue);

      await repo.setArchived(targetId, false);
      row = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(targetId))).getSingle();
      expect(row.isArchived, isFalse);
    },
  );

  test('reorderSiblings ghi đúng sortOrder tuần tự theo thứ tự mới', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = CategoryRepository(db);
    final categories = await (db.select(
      db.categories,
    )..orderBy([(c) => OrderingTerm.asc(c.id)])).get();
    final ids = categories.map((c) => c.id).toList();
    final reversed = ids.reversed.toList();

    final result = await repo.reorderSiblings(reversed);
    expect(result.isOk, isTrue, reason: '$result');

    final afterReorder = await repo.watchAll().first;
    expect(afterReorder.map((c) => c.id).toList(), reversed);
  });

  test(
    'mergeInto: chuyển hết giao dịch/ngân sách/từ khoá sang đích, tổng tiền giữ nguyên, nguồn bị archive KHÔNG xoá',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = CategoryRepository(db);
      final categories = await db.select(db.categories).get();
      final sourceId = categories[0].id;
      final targetId = categories[1].id;

      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -50000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 1),
              walletId: (await db.select(db.wallets).get()).first.id,
              categoryId: Value(sourceId),
            ),
          );
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              categoryId: sourceId,
              yearMonth: '2026-08',
              amountMinor: 1000000,
              currency: 'VND',
              currencyScale: 0,
            ),
          );
      await repo.recordKeywordCorrection(
        categoryId: sourceId,
        leftoverText: 'từ khoá nguồn',
      );

      final result = await repo.mergeInto(
        sourceId: sourceId,
        targetId: targetId,
      );
      expect(result.isOk, isTrue, reason: '$result');

      final movedTransactions = await (db.select(
        db.transactions,
      )..where((t) => t.categoryId.equals(targetId))).get();
      expect(movedTransactions, hasLength(1));
      expect(movedTransactions.single.amountMinor, -50000);

      final movedBudgets = await (db.select(
        db.budgets,
      )..where((b) => b.categoryId.equals(targetId))).get();
      expect(movedBudgets, hasLength(1));

      final movedKeywords =
          await (db.select(db.categoryKeywords)..where(
                (k) =>
                    k.categoryId.equals(targetId) &
                    k.keyword.equals('từ khoá nguồn'),
              ))
              .get();
      expect(movedKeywords, hasLength(1));

      final sourceRow = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(sourceId))).getSingle();
      expect(
        sourceRow.isArchived,
        isTrue,
        reason: 'Gộp KHÔNG được xoá cứng danh mục nguồn',
      );

      final noOrphans = await (db.select(
        db.transactions,
      )..where((t) => t.categoryId.equals(sourceId))).get();
      expect(noOrphans, isEmpty);
    },
  );

  test(
    'mergeInto: budget cùng tháng ở cả hai bên → giữ của đích, bỏ của nguồn (không vi phạm UNIQUE)',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = CategoryRepository(db);
      final categories = await db.select(db.categories).get();
      final sourceId = categories[0].id;
      final targetId = categories[1].id;

      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              categoryId: sourceId,
              yearMonth: '2026-08',
              amountMinor: 500000,
              currency: 'VND',
              currencyScale: 0,
            ),
          );
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              categoryId: targetId,
              yearMonth: '2026-08',
              amountMinor: 2000000,
              currency: 'VND',
              currencyScale: 0,
            ),
          );

      final result = await repo.mergeInto(
        sourceId: sourceId,
        targetId: targetId,
      );
      expect(result.isOk, isTrue, reason: '$result');

      final targetBudgets = await (db.select(
        db.budgets,
      )..where((b) => b.categoryId.equals(targetId))).get();
      expect(targetBudgets, hasLength(1));
      expect(
        targetBudgets.single.amountMinor,
        2000000,
        reason: 'Giữ ngân sách của ĐÍCH, không phải nguồn',
      );
    },
  );

  test(
    '🚨 Phase 17: insert/update với emoji — round-trip đúng, null giữ nguyên hành vi cũ',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = CategoryRepository(db);

      final withEmojiId = _unwrap(
        await repo.insert(
          name: 'Ăn vặt',
          kind: 'expense',
          walletId: await defaultWalletId(db),
          categoryColorId: 0,
          iconCode: 'restaurant',
          emoji: '🍜',
        ),
      );
      final withoutEmojiId = _unwrap(
        await repo.insert(
          name: 'Khác 2',
          kind: 'expense',
          walletId: await defaultWalletId(db),
          categoryColorId: 0,
          iconCode: 'more_horiz',
        ),
      );

      final rows = await db.select(db.categories).get();
      expect(rows.firstWhere((c) => c.id == withEmojiId).emoji, '🍜');
      expect(rows.firstWhere((c) => c.id == withoutEmojiId).emoji, null);

      final updateResult = await repo.update(
        id: withEmojiId,
        name: 'Ăn vặt',
        categoryColorId: 0,
        iconCode: 'restaurant',
        emoji: null,
      );
      expect(updateResult.isOk, isTrue, reason: '$updateResult');
      final afterUpdate = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(withEmojiId))).getSingle();
      expect(
        afterUpdate.emoji,
        null,
        reason: 'update() với emoji: null phải GỠ emoji, không giữ nguyên',
      );
    },
  );
}
