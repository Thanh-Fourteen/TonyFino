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

/// Hai loại hũ — đo NGƯỢC CHIỀU nhau (xem `Jars.kind`).
enum JarKind {
  /// Hũ TIÊU: gom một số danh mục chi; đo tiền RA, vượt hạn mức là xấu.
  spend('spend'),

  /// Hũ TIẾT KIỆM: gắn một quỹ; đo tiền GỬI VÀO quỹ trong kỳ, gửi vượt
  /// mức là tốt. Không có danh mục nào — tiền vào quỹ không phải chi tiêu.
  saving('saving');

  const JarKind(this.dbValue);
  final String dbValue;

  /// Giá trị lạ (sổ ghi từ bản tương lai) rơi về hũ tiêu — loại mặc định,
  /// đúng với mọi hũ có trước khi có khái niệm này.
  static JarKind parse(String raw) =>
      raw == saving.dbValue ? JarKind.saving : JarKind.spend;
}

extension JarKindX on Jar {
  JarKind get jarKind => JarKind.parse(kind);
}

/// Một hũ kèm số liệu của kỳ đang xem.
class JarProgress {
  const JarProgress({
    required this.jar,
    required this.allotted,
    required this.used,
    required this.categoryCount,
    this.goalName,
  });

  final Jar jar;

  JarKind get kind => jar.jarKind;

  /// Hạn mức kỳ này = `percent%` × TỔNG THU của kỳ. Không phải số cố định —
  /// đó chính là điểm khác giữa hũ và ngân sách.
  final Money allotted;

  /// Số DƯƠNG. Hũ tiêu: đã CHI trong các danh mục của hũ. Hũ tiết kiệm: đã
  /// GỬI RÒNG vào quỹ gắn kèm trong kỳ (nạp trừ rút).
  final Money used;

  final int categoryCount;

  /// Tên quỹ mà hũ tiết kiệm đổ vào — `null` khi chưa gắn quỹ nào (hoặc hũ
  /// tiêu).
  final String? goalName;

  Money get remaining => allotted - used;

  /// Chỉ hũ TIÊU mới "vượt" theo nghĩa xấu. Hũ tiết kiệm gửi quá mức là
  /// đạt mục tiêu, không phải lỗi — đừng tô đỏ nó.
  bool get isOverspent =>
      kind == JarKind.spend && used.minorUnits > allotted.minorUnits;

  /// Hũ tiết kiệm đã gửi đủ phần của kỳ.
  bool get isSavingReached =>
      kind == JarKind.saving &&
      allotted.minorUnits > 0 &&
      used.minorUnits >= allotted.minorUnits;

  double get ratio =>
      allotted.minorUnits == 0 ? 0 : used.minorUnits / allotted.minorUnits;
}

/// Bộ hũ của một kỳ + nguồn chia của nó.
///
/// [income] đi kèm danh sách chứ không để màn tự lấy từ chỗ khác: màn Hũ
/// phải cho thấy "10% của CÁI GÌ" — con số đó mà không hiện ra thì không ai
/// kiểm được hạn mức từng hũ có đúng không.
class JarsOverview {
  const JarsOverview({required this.income, required this.jars});

  static const empty = JarsOverview(income: Money.vnd(0), jars: []);

  /// Tổng THU của kỳ — cùng định nghĩa với ô "Thu" ở Trang chủ.
  final Money income;
  final List<JarProgress> jars;

  bool get isEmpty => jars.isEmpty;

  int get totalPercent => jars.fold(0, (s, p) => s + p.jar.percent);

  Money get totalAllotted =>
      Money.vnd(jars.fold(0, (s, p) => s + p.allotted.minorUnits));

  /// Đã dùng = đã chi (hũ tiêu) + đã gửi (hũ tiết kiệm) — cả hai đều là
  /// tiền đã rời khỏi phần "còn tiêu được".
  Money get totalUsed =>
      Money.vnd(jars.fold(0, (s, p) => s + p.used.minorUnits));

  Money get totalRemaining => totalAllotted - totalUsed;
}

class JarRepository {
  JarRepository(this._db);
  final AppDatabase _db;

  Stream<List<Jar>> watchActive(int walletId) => _activeQuery(walletId).watch();

  SimpleSelectStatement<$JarsTable, Jar> _activeQuery(int walletId) {
    return _db.select(_db.jars)
      ..where((j) => j.walletId.equals(walletId) & j.isArchived.equals(false))
      ..orderBy([
        (j) => OrderingTerm.asc(j.sortOrder),
        (j) => OrderingTerm.asc(j.id),
      ]);
  }

  /// Hũ + số liệu kỳ `[start, end)`.
  ///
  /// Thu nhập của kỳ tính MỘT LẦN cho cả bộ hũ (mọi hũ chia từ cùng một
  /// nguồn), rồi mỗi hũ lấy `percent%` của nó. Chi tính qua
  /// [effectiveCategoryAmounts] để giao dịch TÁCH DÒNG (Phase 14) rơi đúng
  /// vào danh mục của từng dòng con chứ không dồn hết vào danh mục cha.
  Stream<JarsOverview> watchProgress({
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
    final effGoalId = eff.ref(_db.transactions.goalId);

    final inWindow =
        effOccurredAt.isBiggerOrEqualValue(start) &
        effOccurredAt.isSmallerThanValue(end) &
        effIsTransfer.equals(false) &
        effWalletId.equals(walletId);

    // Tổng THU của kỳ — nguồn chia cho mọi hũ.
    //
    // 🚨 PHẢI loại dòng gắn quỹ (`goal_id`), y hệt ô "Thu" ở Trang chủ
    // (`ReportsRepository.watchPeriodSummary`). Trước đây chỗ này đếm mọi
    // dòng dương, nên RÚT tiền từ quỹ về ví bị coi là thu nhập: hạn mức mọi
    // hũ phình theo, và "10%" của hũ không còn là 10% của con số "Thu" Tony
    // nhìn thấy ngay trên cùng màn hình.
    final incomeExpr = effAmount.sum(
      filter: inWindow & effAmount.isBiggerThanValue(0) & effGoalId.isNull(),
    );
    final incomeQuery = eff.selectOnly()..addColumns([incomeExpr]);

    // Chi theo hũ. 🚨 Phần lớn giao dịch thật ghi vào danh mục CON ("Ăn
    // uống → Ăn trưa thiết yếu"). Hũ hiệu lực = `COALESCE(của chính nó, của
    // cha)`: danh mục con xếp riêng vào một hũ thì theo hũ đó (cùng một "Ăn
    // uống" có con ở hũ Thiết yếu, con ở hũ Hưởng thụ), chưa xếp thì thừa
    // hưởng hũ của cha.
    final c = _db.categories;
    final parent = _db.categories.createAlias('parent_category');
    final effectiveJarId = coalesce([c.jarId, parent.jarId]);

    // Dòng gắn quỹ KHÔNG phải chi tiêu — nó là tiền chuyển sang túi tiết
    // kiệm, và được tính ở hũ tiết kiệm bên dưới. Để nó lọt vào đây thì một
    // lần nạp quỹ (thường mang danh mục "Phát sinh") bị đếm HAI lần: vừa là
    // chi của hũ tiêu, vừa là tiền gửi của hũ tiết kiệm.
    final spentExpr = effAmount.sum(
      filter: inWindow & effAmount.isSmallerThanValue(0) & effGoalId.isNull(),
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

    // Gửi RÒNG vào từng quỹ trong kỳ: nạp là dòng ÂM gắn quỹ, rút là dòng
    // DƯƠNG — `-SUM` ra số tiền quỹ thực sự tăng thêm (cùng quy ước với
    // `SavingsGoalRepository`).
    final savedExpr = effAmount.sum(filter: inWindow);
    final savedQuery = eff.selectOnly()
      ..addColumns([effGoalId, savedExpr])
      ..where(effGoalId.isNotNull())
      ..groupBy([effGoalId]);

    // Đếm mọi danh mục ĐƯỢC XẾP TƯỜNG MINH vào hũ, cả cha lẫn con — từ khi
    // danh mục con xếp riêng được, "3 danh mục" phải gồm cả con đã tách ra.
    // Con chỉ THỪA HƯỞNG hũ của cha thì không đếm thêm: đếm vậy ra những con
    // số vô nghĩa như "9 danh mục" cho hũ có đúng một danh mục cha.
    final countQuery = _db.selectOnly(c)
      ..addColumns([c.jarId, c.id.count()])
      ..where(c.jarId.isNotNull() & c.isArchived.equals(false))
      ..groupBy([c.jarId]);

    // 🚨 Nguồn phát PHẢI theo dõi MỌI bảng các truy vấn bên dưới đọc.
    //
    // Các truy vấn gộp trong `asyncMap` là đọc MỘT LẦN; nếu stream chỉ
    // theo dõi `jars` thì xếp danh mục hay ghi giao dịch mới không làm nó
    // phát lại — màn Hũ đứng im cho tới khi mở lại app (đã bắt tận tay trên
    // máy). `customSelect(readsFrom:)` khai báo phụ thuộc tường minh.
    final tick = _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.jars,
            _db.categories,
            _db.transactions,
            _db.transactionLines,
            _db.savingsGoals,
          },
        )
        .watch();

    return tick.asyncMap((_) async {
      // `.get()`, KHÔNG `watchActive(...).first`: mở một stream phụ rồi lấy
      // phần tử đầu bên trong `asyncMap` làm `pumpAndSettle` treo vô hạn ở
      // widget test (bẫy đã ghi ở project_tonyfino_gotchas — bắt lại lần
      // này khi màn Giao dịch bắt đầu hiện dải "Chi theo hũ").
      final jars = await _activeQuery(walletId).get();
      final incomeMinor = (await incomeQuery.getSingle()).read(incomeExpr) ?? 0;
      if (jars.isEmpty) {
        return JarsOverview(income: Money.vnd(incomeMinor), jars: const []);
      }
      final spentByJar = {
        for (final row in await spentQuery.get())
          row.read(effectiveJarId)!: row.read(spentExpr) ?? 0,
      };
      final savedByGoal = {
        for (final row in await savedQuery.get())
          row.read(effGoalId)!: -(row.read(savedExpr) ?? 0),
      };
      final countByJar = {
        for (final row in await countQuery.get())
          row.read(c.jarId)!: row.read(c.id.count()) ?? 0,
      };
      final goalIds = jars.map((j) => j.goalId).nonNulls.toSet();
      final goalNames = goalIds.isEmpty
          ? const <int, String>{}
          : {
              for (final g in await (_db.select(
                _db.savingsGoals,
              )..where((g) => g.id.isIn(goalIds))).get())
                g.id: g.name,
            };

      return JarsOverview(
        income: Money.vnd(incomeMinor),
        jars: [
          for (final jar in jars)
            JarProgress(
              jar: jar,
              // Làm tròn XUỐNG: hũ hứa ít hơn thực tế một đồng thì vô hại,
              // hứa nhiều hơn thì tổng các hũ vượt thu nhập.
              allotted: Money.vnd(incomeMinor * jar.percent ~/ 100),
              used: switch (jar.jarKind) {
                JarKind.spend => Money.vnd(-(spentByJar[jar.id] ?? 0)),
                JarKind.saving => Money.vnd(
                  jar.goalId == null ? 0 : (savedByGoal[jar.goalId] ?? 0),
                ),
              },
              categoryCount: jar.jarKind == JarKind.spend
                  ? countByJar[jar.id] ?? 0
                  : 0,
              goalName: jar.goalId == null ? null : goalNames[jar.goalId],
            ),
        ],
      );
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
    JarKind kind = JarKind.spend,
    int? goalId,
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
              kind: Value(kind.dbValue),
              // Quỹ chỉ có nghĩa với hũ tiết kiệm — hũ tiêu mà mang theo một
              // quỹ "ma" thì sau này đổi loại sẽ tự dưng đếm tiền của quỹ đó.
              goalId: Value(kind == JarKind.saving ? goalId : null),
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
    JarKind kind = JarKind.spend,
    int? goalId,
  }) async {
    try {
      await _db.transaction(() async {
        await (_db.update(_db.jars)..where((j) => j.id.equals(id))).write(
          JarsCompanion(
            name: Value(name),
            percent: Value(percent),
            categoryColorId: Value(categoryColorId),
            iconCode: Value(iconCode),
            carryOver: Value(carryOver),
            kind: Value(kind.dbValue),
            goalId: Value(kind == JarKind.saving ? goalId : null),
          ),
        );
        // Hũ tiết kiệm không gom danh mục. Đổi một hũ tiêu thành hũ tiết
        // kiệm mà để nguyên dây nối thì các danh mục đó KẸT: chi của chúng
        // không còn tính vào hũ nào, và bảng chọn danh mục của hũ tiết kiệm
        // lại không hiện để gỡ ra được.
        if (kind == JarKind.saving) {
          await (_db.update(_db.categories)..where((c) => c.jarId.equals(id)))
              .write(const CategoriesCompanion(jarId: Value(null)));
        }
      });
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không sửa được hũ.', cause: e));
    }
  }

  /// Ghi thứ tự mới sau khi Tony kéo thả: [jarIdsInOrder] là TOÀN BỘ hũ
  /// đang hiện, đúng thứ tự mới. Ghi lại `sortOrder = vị trí` cho mọi hũ
  /// trong MỘT transaction — đổi chỗ từng cặp thì giữa chừng có hai hũ trùng
  /// `sortOrder` và stream phát ra một thứ tự nửa vời.
  Future<Result<void, AppError>> reorder(List<int> jarIdsInOrder) async {
    try {
      await _db.transaction(() async {
        for (var i = 0; i < jarIdsInOrder.length; i++) {
          await (_db.update(_db.jars)
                ..where((j) => j.id.equals(jarIdsInOrder[i])))
              .write(JarsCompanion(sortOrder: Value(i)));
        }
      });
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không đổi được thứ tự hũ.', cause: e));
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
