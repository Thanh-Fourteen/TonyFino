// Khôi phục danh mục phụ cho lịch sử Rolly (bổ sung sau Phase 20) —
// idempotency PHẢI được test bằng cách CHẠY BACKFILL HAI LẦN thật, cùng kỷ
// luật Phase 9/19: không chỉ đọc code rồi tin.
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/category_repository.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_subcategory_parser.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;
  late TransactionRepository txRepo;
  late int walletId;
  late Category foodCategory;

  setUp(() async {
    db = openTestDatabase();
    repo = CategoryRepository(db);
    txRepo = TransactionRepository(db);
    walletId = (await db.select(db.wallets).get()).first.id;
    foodCategory = (await db.select(db.categories).get()).first;
  });
  tearDown(() => db.close());

  Future<int> seedTransaction(String sourceId) async {
    final result = await txRepo.insert(
      amount: Money.vnd(-35000),
      occurredAt: DateTime(2026, 8, 10),
      walletId: walletId,
      categoryId: foodCategory.id,
      sourceId: sourceId,
    );
    return result.valueOrNull!;
  }

  test(
    '🚨 backfill lần 1: gán lại categoryId từ cha sang con MỚI TẠO, giữ nguyên tên/màu/icon thừa hưởng từ cha',
    () async {
      final txId = await seedTransaction('rolly:1');

      final result = await repo.backfillSubcategoriesFromRolly([
        const StagedSubcategoryBackfill(
          sourceId: 'rolly:1',
          subcategoryTitle: 'Ăn trưa thiết yếu',
        ),
      ]);

      final summary = result.valueOrNull!;
      expect(summary.reassigned, 1);
      expect(summary.createdSubcategories, 1);
      expect(summary.alreadyDone, 0);
      expect(summary.noCategory, 0);

      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      final subcategory = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(tx.categoryId!))).getSingle();
      expect(subcategory.name, 'Ăn trưa thiết yếu');
      expect(subcategory.parentCategoryId, foodCategory.id);
      expect(subcategory.kind, foodCategory.kind);
      expect(subcategory.categoryColorId, foodCategory.categoryColorId);
    },
  );

  test(
    '🚨 chạy backfill LẦN HAI trên cùng dữ liệu → không tạo danh mục con trùng, không đụng giao dịch đã xử lý',
    () async {
      final txId = await seedTransaction('rolly:1');
      const entry = StagedSubcategoryBackfill(
        sourceId: 'rolly:1',
        subcategoryTitle: 'Ăn trưa thiết yếu',
      );

      await repo.backfillSubcategoriesFromRolly([entry]);
      final secondRun = await repo.backfillSubcategoriesFromRolly([entry]);

      final summary = secondRun.valueOrNull!;
      expect(
        summary.reassigned,
        0,
        reason: 'đã là danh mục con — không được đụng lại',
      );
      expect(summary.createdSubcategories, 0);
      expect(summary.alreadyDone, 1);

      // Lọc theo TÊN cụ thể — không đếm MỌI con của `foodCategory`, vì từ
      // Phase 22 addendum, "Ăn uống" đã có sẵn 1 danh mục con mặc định ("Tiêu
      // vặt", seed lúc `onCreate`) trước khi backfill này chạy lần nào.
      final allSubcategories =
          await (db.select(db.categories)..where(
                (c) =>
                    c.parentCategoryId.equals(foodCategory.id) &
                    c.name.equals('Ăn trưa thiết yếu'),
              ))
              .get();
      expect(
        allSubcategories,
        hasLength(1),
        reason: 'chạy 2 lần KHÔNG được tạo danh mục con trùng',
      );

      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      expect(tx.categoryId, allSubcategories.single.id);
    },
  );

  test(
    'nhiều giao dịch cùng danh mục phụ dưới CÙNG một cha → chỉ tạo MỘT danh mục con, tái sử dụng',
    () async {
      await seedTransaction('rolly:1');
      await seedTransaction('rolly:2');
      const title = 'Ăn trưa thiết yếu';

      final result = await repo.backfillSubcategoriesFromRolly([
        const StagedSubcategoryBackfill(
          sourceId: 'rolly:1',
          subcategoryTitle: title,
        ),
        const StagedSubcategoryBackfill(
          sourceId: 'rolly:2',
          subcategoryTitle: title,
        ),
      ]);

      expect(result.valueOrNull!.createdSubcategories, 1);
      expect(result.valueOrNull!.reassigned, 2);
      final subcategories =
          await (db.select(db.categories)..where(
                (c) =>
                    c.parentCategoryId.equals(foodCategory.id) &
                    c.name.equals(title),
              ))
              .get();
      expect(subcategories, hasLength(1));
    },
  );

  test(
    'CÙNG tên danh mục phụ nhưng KHÁC cha → tạo hai danh mục con độc lập (vd "Phát sinh" dưới hai cha khác nhau)',
    () async {
      final transportCategory = (await db.select(db.categories).get())[1];
      final txFood = await txRepo.insert(
        amount: Money.vnd(-10000),
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        categoryId: foodCategory.id,
        sourceId: 'rolly:1',
      );
      final txTransport = await txRepo.insert(
        amount: Money.vnd(-20000),
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        categoryId: transportCategory.id,
        sourceId: 'rolly:2',
      );

      await repo.backfillSubcategoriesFromRolly([
        const StagedSubcategoryBackfill(
          sourceId: 'rolly:1',
          subcategoryTitle: 'Phát sinh',
        ),
        const StagedSubcategoryBackfill(
          sourceId: 'rolly:2',
          subcategoryTitle: 'Phát sinh',
        ),
      ]);

      final foodTx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txFood.valueOrNull!))).getSingle();
      final transportTx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txTransport.valueOrNull!))).getSingle();
      expect(foodTx.categoryId, isNot(transportTx.categoryId));

      // Tên "Phát sinh" cũng trùng với một danh mục CẤP GỐC có sẵn trong bộ
      // seed (đúng thật trong dữ liệu Rolly của Tony luôn) — chỉ đếm các danh
      // mục CON mới tạo (`parentCategoryId` khác null), không đếm nhầm nó.
      final subcategoriesNamedPhatSinh =
          await (db.select(db.categories)..where(
                (c) =>
                    c.name.equals('Phát sinh') & c.parentCategoryId.isNotNull(),
              ))
              .get();
      expect(subcategoriesNamedPhatSinh, hasLength(2));
    },
  );

  test(
    'sourceId không tìm thấy hoặc giao dịch chưa có danh mục → noCategory, không lỗi',
    () async {
      await seedTransaction('rolly:1');
      final untaggedTx = await txRepo.insert(
        amount: Money.vnd(-5000),
        occurredAt: DateTime(2026, 8, 1),
        walletId: walletId,
        sourceId: 'rolly:2',
      );
      expect(untaggedTx.isOk, isTrue);

      final result = await repo.backfillSubcategoriesFromRolly([
        const StagedSubcategoryBackfill(
          sourceId: 'rolly:khong-ton-tai',
          subcategoryTitle: 'X',
        ),
        const StagedSubcategoryBackfill(
          sourceId: 'rolly:2',
          subcategoryTitle: 'Y',
        ),
      ]);

      expect(result.valueOrNull!.noCategory, 2);
      expect(result.valueOrNull!.reassigned, 0);
    },
  );
}
