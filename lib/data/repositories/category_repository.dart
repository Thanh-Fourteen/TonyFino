import 'package:drift/drift.dart';

import '../../core/result/result.dart';
import '../../core/text/ascii_fold.dart';
import '../../features/settings/import/domain/rolly_subcategory_parser.dart';
import '../db/database.dart';

/// Kết quả khôi phục danh mục phụ từ Rolly (đặc biệt: import bổ sung sau
/// Phase 20, không phải một Phase riêng — xem docs/decisions.md).
class SubcategoryBackfillSummary {
  const SubcategoryBackfillSummary({
    required this.reassigned,
    required this.createdSubcategories,
    required this.alreadyDone,
    required this.noCategory,
  });

  /// Số giao dịch VỪA được đổi `categoryId` từ cha sang con.
  final int reassigned;
  final int createdSubcategories;

  /// Đã là danh mục con từ trước (chạy lần 2 trở đi) — bỏ qua, KHÔNG báo lỗi.
  final int alreadyDone;

  /// Không tìm thấy giao dịch (sourceId lạ) hoặc giao dịch chưa có danh mục
  /// nào (categoryId null) — không có cha để gắn con vào.
  final int noCategory;
}

/// Trọng số khởi tạo khi một từ khoá MỚI được học từ vòng lặp sửa danh mục
/// (Phase 8) — cao hơn trọng số mặc định 1.0 của từ khoá seed, để một sửa
/// đã dạy thắng ngay từ lần đầu trước các khoá chung chung trùng điểm.
const double kLearnedKeywordInitialWeight = 1.5;

/// Mỗi lần người dùng sửa LẶP LẠI cùng một khoá, tăng thêm — dạy nhiều lần
/// càng chắc càng thắng — nhưng có trần để một khoá học không lấn át vĩnh
/// viễn nếu người dùng đổi ý ở lần sau. Từ bản 1.0.3 xoá được từng khoá đã
/// học trong `CategoryDetailScreen` (trước đó chỉ cộng, không gỡ được).
const double kLearnedKeywordIncrement = 0.5;
const double kLearnedKeywordMaxWeight = 5.0;

/// Chỉ đọc danh mục ở v1 — 12 danh mục seed sẵn (Phase 4), chưa có màn quản lý danh
/// mục (Backlog). `Stream` giống mọi read khác (D7) dù danh mục hiếm đổi,
/// để nhất quán và tự động phản ánh nếu Phase sau thêm sửa/xoá danh mục.
///
/// Từ khoá (`category_keywords`) thì GHI được từ Phase 8 — đây là toàn bộ
/// "vòng lặp học" không ML không mạng: mỗi lần Tony sửa danh mục của một
/// draft ở màn chat, `leftoverText` của draft đó được chèn/tăng trọng số
/// vào bảng này, gắn với danh mục vừa chọn.
class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  /// [walletId] `null` = MỌI ví — chỉ dùng cho tra cứu lịch sử/sao lưu,
  /// KHÔNG dùng cho bộ chọn: từ v11 hai ví có thể cùng có "Ăn uống", gộp lại
  /// thì người dùng thấy hai dòng trùng tên không phân biệt được.
  Stream<List<Category>> watchAll({int? walletId}) {
    final query = _db.select(_db.categories)
      ..where(
        (c) => walletId == null
            ? const Constant(true)
            : c.walletId.equals(walletId),
      )
      ..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.id),
      ]);
    return query.watch();
  }

  /// Danh mục CHƯA lưu trữ — nguồn cho MỌI bộ chọn danh mục cho một khoản
  /// MỚI (form giao dịch, quick-add, mẫu định kỳ, gợi ý import). `watchAll()`
  /// (không lọc) vẫn dùng cho tra cứu/hiển thị lịch sử — một giao dịch cũ
  /// gắn danh mục đã lưu trữ vẫn phải hiện đúng tên/màu/icon của nó.
  Stream<List<Category>> watchActive({int? walletId}) {
    final query = _db.select(_db.categories)
      ..where(
        (c) =>
            c.isArchived.equals(false) &
            (walletId == null
                ? const Constant(true)
                : c.walletId.equals(walletId)),
      )
      ..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.id),
      ]);
    return query.watch();
  }

  /// Thêm danh mục mới (Phase 13) — tự xếp CUỐI nhóm cùng cấp
  /// (`parentCategoryId`), không cần chỉ định `sortOrder` tay. [parentCategoryId]
  /// PHẢI là một danh mục CẤP GỐC (không tự nó có cha) — validate ở đây,
  /// không phải CHECK constraint DB (xem docs/decisions.md § Phase 13 "Danh
  /// mục con CHỈ MỘT CẤP").
  /// [walletId] bắt buộc khi tạo danh mục CẤP GỐC. Với danh mục CON thì bỏ
  /// qua và LUÔN thừa hưởng ví của danh mục cha — một danh mục con nằm khác
  /// ví với cha nó là trạng thái vô nghĩa, chặn ngay ở đây thay vì tin call
  /// site truyền đúng.
  ///
  /// 🚨 [kind] cũng thừa hưởng y hệt: danh mục CON luôn mang `kind` của cha,
  /// giá trị truyền vào bị BỎ QUA. Xem [kindIsInheritedFromParent].
  Future<Result<int, AppError>> insert({
    required String name,
    required String kind,
    required int categoryColorId,
    required String iconCode,
    int? walletId,
    int? parentCategoryId,
    String? emoji,
  }) async {
    try {
      int? resolvedWalletId = walletId;
      var resolvedKind = kind;
      if (parentCategoryId != null) {
        final parent = await (_db.select(
          _db.categories,
        )..where((c) => c.id.equals(parentCategoryId))).getSingleOrNull();
        if (parent == null || parent.parentCategoryId != null) {
          return const Err(
            AppError(
              'Danh mục cha không hợp lệ — chỉ danh mục cấp gốc mới làm cha được.',
            ),
          );
        }
        resolvedWalletId = parent.walletId;
        resolvedKind = parent.kind;
      }
      if (resolvedWalletId == null) {
        return const Err(
          AppError('Thiếu ví cho danh mục mới — mỗi danh mục thuộc về một ví.'),
        );
      }
      final maxOrder =
          await (_db.selectOnly(_db.categories)
                ..addColumns([_db.categories.sortOrder.max()])
                ..where(
                  parentCategoryId == null
                      ? _db.categories.parentCategoryId.isNull()
                      : _db.categories.parentCategoryId.equals(
                          parentCategoryId,
                        ),
                ))
              .map((row) => row.read(_db.categories.sortOrder.max()))
              .getSingle();

      final id = await _db
          .into(_db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: name,
              kind: resolvedKind,
              categoryColorId: categoryColorId,
              iconCode: iconCode,
              parentCategoryId: Value(parentCategoryId),
              sortOrder: Value((maxOrder ?? -1) + 1),
              emoji: Value(emoji),
              walletId: resolvedWalletId,
            ),
          );
      return Ok(id);
    } catch (e) {
      final error = AppError('Không tạo được danh mục.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// 🚨 [kind] LÀ tham số bắt buộc, và nó thực sự được GHI.
  ///
  /// Trước bản này `update` không nhận `kind` gì cả: sheet sửa danh mục vẫn
  /// vẽ nút gạt "Chi/Thu", Tony bấm "Thu", bấm Lưu, sheet đóng lại như đã
  /// thành công — mà cột `kind` không hề đổi. Hậu quả không nằm ở màn danh
  /// mục (chỉ xếp sai nhóm) mà ở màn chat: dấu tiền của một thẻ quick-add
  /// lấy đúng từ `Categories.kind` (`QuickAddController._resolveMoney`), nên
  /// một danh mục THU còn kẹt `kind = 'expense'` biến "thưởng 1tr" thành
  /// −1.000.000 — đúng lỗi Tony báo, và không có cách nào sửa được từ trong
  /// app.
  ///
  /// Danh mục CON không có `kind` riêng: nó luôn mang `kind` của cha (xem
  /// [kindIsInheritedFromParent]). Đổi `kind` của một danh mục GỐC vì thế
  /// phải kéo theo mọi con của nó trong CÙNG một `transaction()`, nếu không
  /// cây danh mục lại rơi vào đúng trạng thái nửa vời vừa sửa xong.
  Future<Result<void, AppError>> update({
    required int id,
    required String name,
    required String kind,
    required int categoryColorId,
    required String iconCode,
    int? parentCategoryId,
    String? emoji,
  }) async {
    try {
      var resolvedKind = kind;
      if (parentCategoryId != null) {
        if (parentCategoryId == id) {
          return const Err(AppError('Danh mục không thể là cha của chính nó.'));
        }
        final parent = await (_db.select(
          _db.categories,
        )..where((c) => c.id.equals(parentCategoryId))).getSingleOrNull();
        if (parent == null || parent.parentCategoryId != null) {
          return const Err(
            AppError(
              'Danh mục cha không hợp lệ — chỉ danh mục cấp gốc mới làm cha được.',
            ),
          );
        }
        resolvedKind = parent.kind;
      }
      await _db.transaction(() async {
        await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
          CategoriesCompanion(
            name: Value(name),
            kind: Value(resolvedKind),
            categoryColorId: Value(categoryColorId),
            iconCode: Value(iconCode),
            parentCategoryId: Value(parentCategoryId),
            emoji: Value(emoji),
          ),
        );
        if (parentCategoryId == null) {
          await (_db.update(_db.categories)
                ..where((c) => c.parentCategoryId.equals(id)))
              .write(CategoriesCompanion(kind: Value(resolvedKind)));
        }
      });
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không sửa được danh mục.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// Hằng số tài liệu (không phải cờ bật/tắt): trong TonyFino, `kind` của một
  /// danh mục CON luôn bằng `kind` của cha nó.
  ///
  /// Vì sao là luật chứ không phải tuỳ chọn: mọi bộ chọn danh mục lọc theo
  /// `kind` ở CẤP GỐC rồi hiện TẤT CẢ con của gốc đang chọn
  /// (`TwoLevelCategoryPicker`), và màn Danh mục cũng xếp con theo nhóm
  /// Thu/Chi của gốc. Nghĩa là `kind` riêng của một con KHÔNG hiện ra ở bất
  /// kỳ đâu — nhưng nó lại là thứ quyết định dấu tiền ở màn chat. Một con
  /// `expense` nằm dưới gốc `income` vì thế là một cái bẫy im lặng: nó hiện
  /// trong mục "Danh mục thu", chọn được như một danh mục thu, rồi ghi ra
  /// một khoản CHI.
  static const bool kindIsInheritedFromParent = true;

  Future<Result<void, AppError>> setArchived(int id, bool archived) async {
    try {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(isArchived: Value(archived)),
      );
      return const Ok(null);
    } catch (e) {
      final error = AppError(
        'Không cập nhật được trạng thái danh mục.',
        cause: e,
      );
      await _logError(error);
      return Err(error);
    }
  }

  /// Sắp lại thứ tự các danh mục CÙNG NHÓM (cùng `parentCategoryId`) —
  /// [orderedIds] là danh sách id theo thứ tự MỚI sau khi kéo-thả; ghi đè
  /// `sortOrder` tuần tự 0..N-1 trong MỘT `db.transaction()`.
  Future<Result<void, AppError>> reorderSiblings(List<int> orderedIds) async {
    try {
      await _db.transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await (_db.update(_db.categories)
                ..where((c) => c.id.equals(orderedIds[i])))
              .write(CategoriesCompanion(sortOrder: Value(i)));
        }
      });
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không lưu được thứ tự danh mục.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// Gộp [sourceId] vào [targetId] (Phase 13) — chuyển hết giao dịch/mẫu
  /// định kỳ sang [targetId]; ngân sách/từ khoá học được TRÙNG với
  /// [targetId] (cùng `yearMonth`/cùng `keyword`) thì bỏ của [sourceId] (giữ
  /// của [targetId], tránh vi phạm UNIQUE), không trùng thì chuyển sang.
  /// Sau đó lưu trữ (archive) [sourceId] — KHÔNG BAO GIỜ xoá cứng (xem
  /// docs/decisions.md § Phase 13 "Gộp danh mục").
  Future<Result<void, AppError>> mergeInto({
    required int sourceId,
    required int targetId,
  }) async {
    if (sourceId == targetId) {
      return const Err(AppError('Không thể gộp một danh mục vào chính nó.'));
    }
    try {
      await _db.transaction(() async {
        await (_db.update(_db.transactions)
              ..where((t) => t.categoryId.equals(sourceId)))
            .write(TransactionsCompanion(categoryId: Value(targetId)));
        await (_db.update(_db.recurringTransactions)
              ..where((r) => r.categoryId.equals(sourceId)))
            .write(RecurringTransactionsCompanion(categoryId: Value(targetId)));

        final sourceBudgets = await (_db.select(
          _db.budgets,
        )..where((b) => b.categoryId.equals(sourceId))).get();
        final targetBudgetMonths =
            (await (_db.select(
                  _db.budgets,
                )..where((b) => b.categoryId.equals(targetId))).get())
                .map((b) => b.yearMonth)
                .toSet();
        for (final budget in sourceBudgets) {
          if (targetBudgetMonths.contains(budget.yearMonth)) {
            await (_db.delete(
              _db.budgets,
            )..where((b) => b.id.equals(budget.id))).go();
          } else {
            await (_db.update(_db.budgets)
                  ..where((b) => b.id.equals(budget.id)))
                .write(BudgetsCompanion(categoryId: Value(targetId)));
          }
        }

        final sourceKeywords = await (_db.select(
          _db.categoryKeywords,
        )..where((k) => k.categoryId.equals(sourceId))).get();
        final targetKeywordTexts =
            (await (_db.select(
                  _db.categoryKeywords,
                )..where((k) => k.categoryId.equals(targetId))).get())
                .map((k) => k.keyword)
                .toSet();
        for (final keyword in sourceKeywords) {
          if (targetKeywordTexts.contains(keyword.keyword)) {
            await (_db.delete(
              _db.categoryKeywords,
            )..where((k) => k.id.equals(keyword.id))).go();
          } else {
            await (_db.update(_db.categoryKeywords)
                  ..where((k) => k.id.equals(keyword.id)))
                .write(CategoryKeywordsCompanion(categoryId: Value(targetId)));
          }
        }

        await (_db.update(_db.categories)..where((c) => c.id.equals(sourceId)))
            .write(const CategoriesCompanion(isArchived: Value(true)));
      });
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không gộp được danh mục.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// Toàn bộ từ khoá sống (seed + đã học) — nguồn nạp cho
  /// `category_matcher.dart` (Phase 7, không phụ thuộc DB) ở tầng gọi
  /// (`quick_add_providers.dart` chuyển sang `CategoryKeywordEntry`, dùng
  /// `categoryId.toString()` làm `categoryKey` vì v1 chưa có màn đổi/xoá
  /// danh mục nên id ổn định suốt vòng đời).
  Stream<List<CategoryKeyword>> watchAllKeywords() {
    return _db.select(_db.categoryKeywords).watch();
  }

  /// Từ khoá đã học/seed của MỘT danh mục, mới nhất trước — nguồn cho mục
  /// "Từ khoá đã học" ở `CategoryDetailScreen`.
  Stream<List<CategoryKeyword>> watchKeywordsFor(int categoryId) {
    final query = _db.select(_db.categoryKeywords)
      ..where((k) => k.categoryId.equals(categoryId))
      ..orderBy([
        (k) => OrderingTerm.desc(k.weight),
        (k) => OrderingTerm.desc(k.id),
      ]);
    return query.watch();
  }

  /// `true` nếu danh mục này ĐÃ có đúng khoá đó — dùng để không hỏi lại
  /// "có muốn nhớ không" cho thứ đã nhớ rồi.
  Future<bool> hasKeyword({
    required int categoryId,
    required String keyword,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return false;
    // 🚨 `getSingleOrNull` là SAI ở đây: một danh mục HOÀN TOÀN có thể có
    // hai khoá khác nhau mà trùng nhau sau khi bỏ dấu — seed "Ăn uống" có cả
    // "bách hoá xanh" lẫn "bách hóa xanh" (hai cách viết dấu, cùng ra
    // `bach hoa xanh`). Dùng `getSingleOrNull` thì hàm này ném
    // `Bad state: Too many elements` giữa luồng sửa danh mục.
    final rows =
        await (_db.select(_db.categoryKeywords)
              ..where(
                (k) =>
                    k.categoryId.equals(categoryId) &
                    k.keywordAscii.equals(foldToAscii(trimmed)),
              )
              ..limit(1))
            .get();
    return rows.isNotEmpty;
  }

  /// Xoá MỘT từ khoá (đã học hoặc seed). Không có "hoàn tác" ở tầng này —
  /// UI gọi hàm này phải tự lo hoàn tác nếu cần.
  Future<Result<void, AppError>> deleteKeyword(int id) async {
    try {
      await (_db.delete(
        _db.categoryKeywords,
      )..where((k) => k.id.equals(id))).go();
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không xoá được từ khoá.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// Chèn lại một khoá vừa bị xoá, GIỮ NGUYÊN trọng số cũ — dành riêng cho
  /// nút "Hoàn tác" sau khi quên một từ. Khác [learnKeywords]: hàm kia luôn
  /// bắt đầu từ [kLearnedKeywordInitialWeight], nên dùng nó để hoàn tác sẽ
  /// âm thầm hạ điểm một khoá đã được dạy nhiều lần.
  Future<Result<void, AppError>> restoreKeyword({
    required int categoryId,
    required String keyword,
    required double weight,
  }) async {
    try {
      await _db
          .into(_db.categoryKeywords)
          .insert(
            CategoryKeywordsCompanion.insert(
              categoryId: categoryId,
              keyword: keyword,
              keywordAscii: foldToAscii(keyword),
              weight: Value(weight),
            ),
          );
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không khôi phục được từ khoá.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// Học NHIỀU khoá cùng lúc cho một danh mục — mỗi phần tử là một tín hiệu
  /// ĐỘC LẬP, không phải một cụm phải khớp trọn.
  ///
  /// 🚨 Vì sao nhiều khoá rời chứ không một cụm: sửa "hủ tíu trưa" thành
  /// "Ăn trưa thiết yếu" mà chỉ nhớ nguyên chuỗi thì lần sau gõ "hủ tíu"
  /// hay "bún chả trưa" học được đúng con số không. Nhớ `hủ tíu` và `trưa`
  /// thành hai khoá rời thì `category_matcher` cộng dồn điểm: có đủ hai từ
  /// là chắc nhất, có một từ vẫn là tín hiệu thật.
  Future<Result<void, AppError>> learnKeywords({
    required int categoryId,
    required List<String> keywords,
  }) async {
    for (final keyword in keywords) {
      final result = await recordKeywordCorrection(
        categoryId: categoryId,
        leftoverText: keyword,
      );
      if (result is Err<void, AppError>) return result;
    }
    return const Ok(null);
  }

  /// Vòng lặp học: chèn `leftoverText` làm từ khoá mới (trọng số
  /// [kLearnedKeywordInitialWeight]), hoặc tăng trọng số nếu khoá này đã
  /// gắn với CHÍNH danh mục này rồi (trần [kLearnedKeywordMaxWeight]).
  /// Chuỗi rỗng sau khi trim không có gì để học — coi là thành công, không
  /// phải lỗi, chỉ đơn giản không ghi gì.
  Future<Result<void, AppError>> recordKeywordCorrection({
    required int categoryId,
    required String leftoverText,
  }) async {
    final keyword = leftoverText.trim();
    if (keyword.isEmpty) return const Ok(null);
    final keywordAscii = foldToAscii(keyword);

    try {
      final existing =
          await (_db.select(_db.categoryKeywords)..where(
                (k) =>
                    k.categoryId.equals(categoryId) & k.keyword.equals(keyword),
              ))
              .getSingleOrNull();

      if (existing != null) {
        final newWeight = (existing.weight + kLearnedKeywordIncrement).clamp(
          0.0,
          kLearnedKeywordMaxWeight,
        );
        await (_db.update(_db.categoryKeywords)
              ..where((k) => k.id.equals(existing.id)))
            .write(CategoryKeywordsCompanion(weight: Value(newWeight)));
      } else {
        await _db
            .into(_db.categoryKeywords)
            .insert(
              CategoryKeywordsCompanion.insert(
                categoryId: categoryId,
                keyword: keyword,
                keywordAscii: keywordAscii,
                weight: const Value(kLearnedKeywordInitialWeight),
              ),
            );
      }
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không lưu được từ khoá học được.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// Khôi phục danh mục PHỤ cho lịch sử Rolly đã nhập từ Phase 9 (Phase 9 bỏ
  /// qua `subcategory_id`, xem `rolly_subcategory_parser.dart`). Với mỗi
  /// [entries], tìm giao dịch qua `sourceId` — CHỈ xử lý nếu danh mục HIỆN
  /// TẠI của nó là danh mục CẤP GỐC (`parentCategoryId == null`); nếu đã là
  /// danh mục con (chạy lần 2 trở đi, hoặc Tony đã tự sửa tay) thì BỎ QUA,
  /// không đụng — đây chính là cơ chế idempotent (không cần cột đánh dấu
  /// "đã xử lý" riêng, tự suy ra từ hình dạng dữ liệu hiện tại). Danh mục
  /// con trùng tên dưới CÙNG một cha được TÁI SỬ DỤNG (không tạo trùng),
  /// khác cha thì tạo riêng (vd "Phát sinh" vừa là con của "Giao thông" vừa
  /// là con của "Mua sắm" trong dữ liệu thật của Tony — hai danh mục con
  /// độc lập, không lẫn nhau).
  Future<Result<SubcategoryBackfillSummary, AppError>>
  backfillSubcategoriesFromRolly(
    List<StagedSubcategoryBackfill> entries,
  ) async {
    try {
      var reassigned = 0;
      var created = 0;
      var alreadyDone = 0;
      var noCategory = 0;
      final subcategoryIdByKey = <String, int>{};

      await _db.transaction(() async {
        for (final entry in entries) {
          final tx = await (_db.select(
            _db.transactions,
          )..where((t) => t.sourceId.equals(entry.sourceId))).getSingleOrNull();
          if (tx == null || tx.categoryId == null) {
            noCategory++;
            continue;
          }

          final currentCategory = await (_db.select(
            _db.categories,
          )..where((c) => c.id.equals(tx.categoryId!))).getSingle();
          if (currentCategory.parentCategoryId != null) {
            alreadyDone++;
            continue;
          }

          final cacheKey = '${currentCategory.id}::${entry.subcategoryTitle}';
          var subcategoryId = subcategoryIdByKey[cacheKey];
          if (subcategoryId == null) {
            final existing =
                await (_db.select(_db.categories)..where(
                      (c) =>
                          c.parentCategoryId.equals(currentCategory.id) &
                          c.name.equals(entry.subcategoryTitle),
                    ))
                    .getSingleOrNull();
            if (existing != null) {
              subcategoryId = existing.id;
            } else {
              final maxOrder =
                  await (_db.selectOnly(_db.categories)
                        ..addColumns([_db.categories.sortOrder.max()])
                        ..where(
                          _db.categories.parentCategoryId.equals(
                            currentCategory.id,
                          ),
                        ))
                      .map((row) => row.read(_db.categories.sortOrder.max()))
                      .getSingle();
              subcategoryId = await _db
                  .into(_db.categories)
                  .insert(
                    CategoriesCompanion.insert(
                      name: entry.subcategoryTitle,
                      kind: currentCategory.kind,
                      categoryColorId: currentCategory.categoryColorId,
                      iconCode: currentCategory.iconCode,
                      parentCategoryId: Value(currentCategory.id),
                      sortOrder: Value((maxOrder ?? -1) + 1),
                      // Danh mục con luôn cùng ví với cha.
                      walletId: currentCategory.walletId,
                    ),
                  );
              created++;
            }
            subcategoryIdByKey[cacheKey] = subcategoryId;
          }

          await (_db.update(_db.transactions)..where((t) => t.id.equals(tx.id)))
              .write(TransactionsCompanion(categoryId: Value(subcategoryId)));
          reassigned++;
        }
      });

      return Ok(
        SubcategoryBackfillSummary(
          reassigned: reassigned,
          createdSubcategories: created,
          alreadyDone: alreadyDone,
          noCategory: noCategory,
        ),
      );
    } catch (e) {
      final error = AppError('Khôi phục danh mục phụ thất bại.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  Future<void> _logError(AppError error) async {
    await _db
        .into(_db.appEvents)
        .insert(
          AppEventsCompanion.insert(
            level: 'error',
            message: error.message,
            contextJson: Value(error.cause?.toString()),
          ),
        );
  }
}
