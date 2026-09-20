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

/// Một dây nối hũ ↔ quỹ đang được soạn ở UI (chưa ghi xuống DB).
class JarGoalLink {
  const JarGoalLink({required this.goalId, this.percent = 100});

  final int goalId;

  /// Phần của quỹ thuộc về hũ, 1–100. Mặc định 100 = cả quỹ.
  final int percent;

  JarGoalLink copyWith({int? percent}) =>
      JarGoalLink(goalId: goalId, percent: percent ?? this.percent);
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
    this.goals = const [],
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

  /// Các quỹ hũ tiết kiệm này gom (v15) — rỗng với hũ tiêu, hoặc hũ tiết
  /// kiệm chưa gắn quỹ nào.
  final List<JarGoalProgress> goals;

  String? get goalName => goals.length == 1 ? goals.single.goal.name : null;

  /// Tổng tiền ĐANG CÓ trong các quỹ của hũ (mọi thời gian, đã nhân tỉ lệ
  /// từng quỹ) — khác [used] là tiền gửi vào TRONG KỲ. Tony muốn thấy cả
  /// hai: "tháng này bỏ vào bao nhiêu" và "đang để dành được bao nhiêu".
  Money get savedTotal => Money.vnd(goals.fold(0, (s, g) => s + g.savedMinor));

  /// Tổng đích của các quỹ (đã nhân tỉ lệ) — mốc cho thanh tiến độ khi hũ
  /// không lấy phần trăm thu nhập nào trong kỳ. 0 = không quỹ nào đặt đích.
  Money get goalTarget => Money.vnd(goals.fold(0, (s, g) => s + g.targetMinor));

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

  /// Hũ tiết kiệm KHÔNG lấy phần trăm nào của kỳ (0%) thì không có mốc
  /// "kỳ này phải gửi bao nhiêu" — thanh chuyển sang đo tiền đã để dành
  /// được trong các quỹ so với tổng đích của chúng. Tony chốt: hũ 0% vẫn
  /// phải có thanh, đo theo tiền tiết kiệm được.
  bool get tracksGoalTotal =>
      kind == JarKind.saving && allotted.minorUnits == 0 && goals.isNotEmpty;

  double get ratio {
    if (tracksGoalTotal) {
      final target = goalTarget.minorUnits;
      return target == 0 ? 0 : savedTotal.minorUnits / target;
    }
    return allotted.minorUnits == 0 ? 0 : used.minorUnits / allotted.minorUnits;
  }
}

/// Một quỹ trong một hũ tiết kiệm, kèm số liệu đã NHÂN tỉ lệ của dây nối.
class JarGoalProgress {
  const JarGoalProgress({
    required this.goal,
    required this.percent,
    required this.depositedMinor,
    required this.savedMinor,
  });

  final SavingsGoal goal;

  /// Phần của quỹ này thuộc hũ, 0–100 (mặc định 100 = cả quỹ).
  final int percent;

  /// Gửi RÒNG vào quỹ TRONG KỲ (nạp trừ rút), đã nhân [percent].
  final int depositedMinor;

  /// Tiền đang có trong quỹ (mọi thời gian), đã nhân [percent].
  final int savedMinor;

  /// Đích của quỹ, đã nhân [percent]. 0 = quỹ không đặt đích.
  int get targetMinor => goal.targetAmountMinor * percent ~/ 100;
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

  /// Tổng tiền đang có trong mọi quỹ được các hũ tiết kiệm gom.
  Money get totalSaved =>
      Money.vnd(jars.fold(0, (s, p) => s + p.savedTotal.minorUnits));
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

    // Tiền ĐANG CÓ trong từng quỹ — KHÔNG giới hạn kỳ (đó là điểm khác với
    // [savedQuery]). Dùng chung quy ước dấu với `SavingsGoalRepository`.
    final balanceExpr = effAmount.sum();
    final balanceQuery = eff.selectOnly()
      ..addColumns([effGoalId, balanceExpr])
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
            _db.jarGoals,
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
      final balanceByGoal = {
        for (final row in await balanceQuery.get())
          row.read(effGoalId)!: -(row.read(balanceExpr) ?? 0),
      };
      final countByJar = {
        for (final row in await countQuery.get())
          row.read(c.jarId)!: row.read(c.id.count()) ?? 0,
      };
      // Dây nối hũ ↔ quỹ (v15) + bản ghi quỹ, đọc một lần cho cả bộ hũ.
      final links =
          await (_db.select(_db.jarGoals)
                ..where((l) => l.jarId.isIn([for (final j in jars) j.id]))
                ..orderBy([(l) => OrderingTerm.asc(l.goalId)]))
              .get();
      final goalById = links.isEmpty
          ? const <int, SavingsGoal>{}
          : {
              for (final g
                  in await (_db.select(_db.savingsGoals)..where(
                        (g) => g.id.isIn(links.map((l) => l.goalId).toSet()),
                      ))
                      .get())
                g.id: g,
            };
      final goalsByJar = <int, List<JarGoalProgress>>{};
      for (final link in links) {
        final goal = goalById[link.goalId];
        if (goal == null) continue;
        (goalsByJar[link.jarId] ??= []).add(
          JarGoalProgress(
            goal: goal,
            percent: link.percent,
            // Làm tròn XUỐNG như hạn mức hũ, cùng lý do.
            depositedMinor:
                (savedByGoal[link.goalId] ?? 0) * link.percent ~/ 100,
            savedMinor: (balanceByGoal[link.goalId] ?? 0) * link.percent ~/ 100,
          ),
        );
      }

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
                // Hũ tiết kiệm gom NHIỀU quỹ: cộng phần thuộc hũ của từng
                // quỹ (v15).
                JarKind.saving => Money.vnd(
                  (goalsByJar[jar.id] ?? const <JarGoalProgress>[]).fold(
                    0,
                    (sum, g) => sum + g.depositedMinor,
                  ),
                ),
              },
              categoryCount: jar.jarKind == JarKind.spend
                  ? countByJar[jar.id] ?? 0
                  : 0,
              goals: goalsByJar[jar.id] ?? const <JarGoalProgress>[],
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
    List<JarGoalLink> goals = const [],
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
            ),
          );
      // Quỹ chỉ có nghĩa với hũ tiết kiệm — hũ tiêu mà mang theo quỹ "ma"
      // thì sau này đổi loại sẽ tự dưng đếm tiền của quỹ đó.
      if (kind == JarKind.saving) await _writeGoalLinks(id, goals);
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
    List<JarGoalLink> goals = const [],
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
          ),
        );
        await _writeGoalLinks(id, kind == JarKind.saving ? goals : const []);
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

  /// Ghi lại TOÀN BỘ dây nối hũ ↔ quỹ: xoá hết rồi chèn lại đúng danh sách
  /// mới. Gọi trong transaction của caller — nửa chừng mà hỏng thì hũ mất
  /// sạch quỹ mà vẫn còn là hũ tiết kiệm.
  ///
  /// Bỏ qua dây nối tỉ lệ 0 (không đóng góp gì, chỉ làm rối bảng) và kẹp
  /// tỉ lệ vào 1–100.
  Future<void> _writeGoalLinks(int jarId, List<JarGoalLink> goals) async {
    await (_db.delete(_db.jarGoals)..where((l) => l.jarId.equals(jarId))).go();
    final seen = <int>{};
    for (final link in goals) {
      if (!seen.add(link.goalId)) continue;
      final percent = link.percent.clamp(1, 100);
      await _db
          .into(_db.jarGoals)
          .insert(
            JarGoalsCompanion.insert(
              jarId: jarId,
              goalId: link.goalId,
              percent: Value(percent),
            ),
          );
    }
  }

  /// Dây nối hiện có của một hũ — nguồn cho sheet sửa hũ.
  Future<List<JarGoalLink>> goalLinksOf(int jarId) async {
    final rows =
        await (_db.select(_db.jarGoals)
              ..where((l) => l.jarId.equals(jarId))
              ..orderBy([(l) => OrderingTerm.asc(l.goalId)]))
            .get();
    return [
      for (final r in rows) JarGoalLink(goalId: r.goalId, percent: r.percent),
    ];
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
