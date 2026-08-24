import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../core/result/result.dart';
import '../db/database.dart';
import 'effective_category_amounts.dart';

/// Bộ 6 hũ mặc định — JARS của T. Harv Eker ("Secrets of the Millionaire
/// Mind"), tỉ lệ 55/10/10/10/10/5 cộng đúng 100%.
///
/// KHÔNG tự tạo lúc migration: bật sẵn một phương pháp tài chính lên sổ của
/// người khác là quyết định thay họ. Tony bấm "Dùng mẫu 6 hũ" thì mới có.
const kDefaultJarSeeds =
    <
      ({String name, int percent, int colorId, String iconCode, bool carryOver})
    >[
      (
        name: 'Thiết yếu',
        percent: 55,
        colorId: 0,
        iconCode: 'home',
        carryOver: false,
      ),
      (
        name: 'Tiết kiệm dài hạn',
        percent: 10,
        colorId: 10,
        iconCode: 'savings',
        // Quỹ chìm: dư kỳ này phải cộng dồn, không thì "tiết kiệm dài hạn"
        // chẳng dài hạn ở chỗ nào.
        carryOver: true,
      ),
      (
        name: 'Giáo dục',
        percent: 10,
        colorId: 7,
        iconCode: 'school',
        carryOver: true,
      ),
      (
        name: 'Hưởng thụ',
        percent: 10,
        colorId: 3,
        iconCode: 'theater_comedy',
        carryOver: false,
      ),
      (
        name: 'Tự do tài chính',
        percent: 10,
        colorId: 4,
        iconCode: 'payments',
        carryOver: true,
      ),
      (
        name: 'Cho đi',
        percent: 5,
        colorId: 9,
        iconCode: 'handshake',
        carryOver: false,
      ),
    ];

/// Một hũ kèm số liệu của kỳ đang xem.
class JarProgress {
  const JarProgress({
    required this.jar,
    required this.allotted,
    required this.spent,
    required this.categoryCount,
  });

  final Jar jar;

  /// Hạn mức kỳ này = `percent%` × TỔNG THU của kỳ. Không phải số cố định —
  /// đó chính là điểm khác giữa hũ và ngân sách.
  final Money allotted;

  /// Đã chi trong các danh mục thuộc hũ (số DƯƠNG cho dễ so sánh).
  final Money spent;

  final int categoryCount;

  Money get remaining => allotted - spent;
  double get ratio =>
      allotted.minorUnits == 0 ? 0 : spent.minorUnits / allotted.minorUnits;
}

class JarRepository {
  JarRepository(this._db);
  final AppDatabase _db;

  Stream<List<Jar>> watchActive(int walletId) {
    return (_db.select(_db.jars)
          ..where(
            (j) => j.walletId.equals(walletId) & j.isArchived.equals(false),
          )
          ..orderBy([
            (j) => OrderingTerm.asc(j.sortOrder),
            (j) => OrderingTerm.asc(j.id),
          ]))
        .watch();
  }

  /// Hũ + số liệu kỳ `[start, end)`.
  ///
  /// Thu nhập của kỳ tính MỘT LẦN cho cả bộ hũ (mọi hũ chia từ cùng một
  /// nguồn), rồi mỗi hũ lấy `percent%` của nó. Chi tính qua
  /// [effectiveCategoryAmounts] để giao dịch TÁCH DÒNG (Phase 14) rơi đúng
  /// vào danh mục của từng dòng con chứ không dồn hết vào danh mục cha.
  Stream<List<JarProgress>> watchProgress({
    required int walletId,
    required DateTime start,
    required DateTime end,
  }) {
    final eff = effectiveCategoryAmounts(_db);
    final effCategoryId = eff.ref(_db.transactions.categoryId);
    final effAmount = eff.ref(_db.transactions.amountMinor);
    final effOccurredAt = eff.ref(_db.transactions.occurredAt);
    final effIsTransfer = eff.ref(_db.transactions.isTransfer);
    final effWalletId = eff.ref(_db.transactions.walletId);

    final inWindow =
        effOccurredAt.isBiggerOrEqualValue(start) &
        effOccurredAt.isSmallerThanValue(end) &
        effIsTransfer.equals(false) &
        effWalletId.equals(walletId);

    // Tổng THU của kỳ — nguồn chia cho mọi hũ.
    final incomeExpr = effAmount.sum(
      filter: inWindow & effAmount.isBiggerThanValue(0),
    );
    final incomeQuery = eff.selectOnly()..addColumns([incomeExpr]);

    // Chi theo hũ. 🚨 Hũ chỉ gắn trên danh mục CẤP GỐC, nhưng phần lớn
    // giao dịch thật lại ghi vào danh mục CON ("Ăn uống → Ăn trưa thiết
    // yếu"). Nếu chỉ đọc `c.jar_id` thì mọi khoản chi ở danh mục con rơi ra
    // ngoài mọi hũ và màn Hũ hiện "đã tiêu 0đ" giữa lúc sổ đầy giao dịch —
    // bắt được tận tay trên máy với 324 giao dịch nằm ở danh mục con.
    //
    // Nên hũ hiệu lực = `COALESCE(chính nó, của cha)`: đúng lời hứa "danh
    // mục con thừa hưởng hũ của cha" mà bảng chọn danh mục đang nói.
    final c = _db.categories;
    final parent = _db.categories.createAlias('parent_category');
    final effectiveJarId = coalesce([c.jarId, parent.jarId]);

    final spentExpr = effAmount.sum(
      filter: inWindow & effAmount.isSmallerThanValue(0),
    );
    final spentQuery =
        eff.selectOnly().join([
            innerJoin(c, c.id.equalsExp(effCategoryId), useColumns: false),
            leftOuterJoin(
              parent,
              parent.id.equalsExp(c.parentCategoryId),
              useColumns: false,
            ),
          ])
          ..addColumns([effectiveJarId, spentExpr])
          ..where(effectiveJarId.isNotNull())
          ..groupBy([effectiveJarId]);

    // Số danh mục thì CHỈ đếm cấp gốc — đó mới là thứ Tony tick trong bảng
    // chọn; đếm cả con sẽ ra những con số vô nghĩa như "1 danh mục" cho hũ
    // có 1 danh mục cha và 8 danh mục con.
    final countQuery = _db.selectOnly(c)
      ..addColumns([c.jarId, c.id.count()])
      ..where(c.jarId.isNotNull() & c.isArchived.equals(false))
      ..groupBy([c.jarId]);

    // 🚨 Nguồn phát PHẢI theo dõi CẢ BA bảng.
    //
    // Trước đây stream này dựng từ `watchActive(walletId)` — chỉ theo dõi
    // bảng `jars`. Ba truy vấn gộp bên trong `asyncMap` là đọc MỘT LẦN, nên
    // xếp một danh mục vào hũ (đổi `categories.jar_id`) hay ghi một giao
    // dịch mới KHÔNG làm stream phát lại: màn Hũ đứng im ở "0 danh mục /
    // đã tiêu 0đ" cho tới khi mở lại app. Bắt được tận tay trên máy.
    //
    // `customSelect(readsFrom:)` là cách khai báo phụ thuộc tường minh của
    // drift — nó phát lại khi BẤT KỲ bảng nào trong tập đó thay đổi.
    final tick = _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.jars,
            _db.categories,
            _db.transactions,
            _db.transactionLines,
          },
        )
        .watch();

    return tick.asyncMap((_) async {
      final jars = await watchActive(walletId).first;
      if (jars.isEmpty) return const <JarProgress>[];
      final incomeMinor = (await incomeQuery.getSingle()).read(incomeExpr) ?? 0;
      final spentByJar = {
        for (final row in await spentQuery.get())
          row.read(effectiveJarId)!: row.read(spentExpr) ?? 0,
      };
      final countByJar = {
        for (final row in await countQuery.get())
          row.read(c.jarId)!: row.read(c.id.count()) ?? 0,
      };
      return [
        for (final jar in jars)
          JarProgress(
            jar: jar,
            // Làm tròn XUỐNG: hũ hứa ít hơn thực tế một đồng thì vô hại,
            // hứa nhiều hơn thì tổng các hũ vượt thu nhập.
            allotted: Money.vnd(incomeMinor * jar.percent ~/ 100),
            spent: Money.vnd(-(spentByJar[jar.id] ?? 0)),
            categoryCount: countByJar[jar.id] ?? 0,
          ),
      ];
    });
  }

  Future<Result<void, AppError>> seedDefaultJars(int walletId) async {
    try {
      await _db.transaction(() async {
        final existing = await (_db.select(
          _db.jars,
        )..where((j) => j.walletId.equals(walletId))).get();
        if (existing.isNotEmpty) return;
        for (var i = 0; i < kDefaultJarSeeds.length; i++) {
          final seed = kDefaultJarSeeds[i];
          await _db
              .into(_db.jars)
              .insert(
                JarsCompanion.insert(
                  walletId: walletId,
                  name: seed.name,
                  percent: seed.percent,
                  categoryColorId: seed.colorId,
                  iconCode: seed.iconCode,
                  carryOver: Value(seed.carryOver),
                  sortOrder: Value(i),
                ),
              );
        }
      });
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không tạo được bộ hũ mặc định.', cause: e));
    }
  }

  Future<Result<int, AppError>> insert({
    required int walletId,
    required String name,
    required int percent,
    required int categoryColorId,
    required String iconCode,
    bool carryOver = false,
  }) async {
    try {
      final maxOrder =
          await (_db.selectOnly(_db.jars)
                ..addColumns([_db.jars.sortOrder.max()])
                ..where(_db.jars.walletId.equals(walletId)))
              .map((r) => r.read(_db.jars.sortOrder.max()))
              .getSingle();
      final id = await _db
          .into(_db.jars)
          .insert(
            JarsCompanion.insert(
              walletId: walletId,
              name: name,
              percent: percent,
              categoryColorId: categoryColorId,
              iconCode: iconCode,
              carryOver: Value(carryOver),
              sortOrder: Value((maxOrder ?? -1) + 1),
            ),
          );
      return Ok(id);
    } catch (e) {
      return Err(AppError('Không tạo được hũ.', cause: e));
    }
  }

  Future<Result<void, AppError>> update({
    required int id,
    required String name,
    required int percent,
    required int categoryColorId,
    required String iconCode,
    required bool carryOver,
  }) async {
    try {
      await (_db.update(_db.jars)..where((j) => j.id.equals(id))).write(
        JarsCompanion(
          name: Value(name),
          percent: Value(percent),
          categoryColorId: Value(categoryColorId),
          iconCode: Value(iconCode),
          carryOver: Value(carryOver),
        ),
      );
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không sửa được hũ.', cause: e));
    }
  }

  Future<Result<void, AppError>> archive(int id) async {
    try {
      await _db.transaction(() async {
        // Gỡ danh mục khỏi hũ trước: để lại `jarId` trỏ vào hũ đã lưu trữ
        // thì những danh mục đó biến mất khỏi mọi hũ đang hiện mà vẫn không
        // xếp lại được — kẹt ở trạng thái vô hình.
        await (_db.update(_db.categories)..where((c) => c.jarId.equals(id)))
            .write(const CategoriesCompanion(jarId: Value(null)));
        await (_db.update(_db.jars)..where((j) => j.id.equals(id))).write(
          const JarsCompanion(isArchived: Value(true)),
        );
      });
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không lưu trữ được hũ.', cause: e));
    }
  }

  Future<Result<void, AppError>> setCategoryJar({
    required int categoryId,
    required int? jarId,
  }) async {
    try {
      await (_db.update(_db.categories)..where((c) => c.id.equals(categoryId)))
          .write(CategoriesCompanion(jarId: Value(jarId)));
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không xếp được danh mục vào hũ.', cause: e));
    }
  }
}
