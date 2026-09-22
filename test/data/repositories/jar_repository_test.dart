import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/jar_repository.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late JarRepository repo;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    repo = JarRepository(db);
    walletId = await defaultWalletId(db);
  });
  tearDown(() => db.close());

  Future<void> tx({
    required int amountMinor,
    required DateTime at,
    int? categoryId,
    int? goalId,
  }) async {
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: amountMinor,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: at,
            walletId: walletId,
            categoryId: Value(categoryId),
            goalId: Value(goalId),
          ),
        );
  }

  Future<int> goal(String name) => db
      .into(db.savingsGoals)
      .insert(
        SavingsGoalsCompanion.insert(
          name: name,
          targetAmountMinor: 50000000,
          currency: 'VND',
          currencyScale: 0,
        ),
      );

  Future<JarsOverview> august() => repo
      .watchProgress(
        walletId: walletId,
        start: DateTime(2026, 8),
        end: DateTime(2026, 9),
      )
      .first;

  test('bộ 6 hũ mặc định cộng đúng 100%', () {
    final total = kDefaultJarSeeds.fold(0, (s, j) => s + j.percent);
    expect(total, 100, reason: 'JARS 55/10/10/10/10/5');
  });

  test('seed 2 lần không tạo trùng', () async {
    await repo.seedDefaultJars(walletId);
    await repo.seedDefaultJars(walletId);
    expect(await repo.watchActive(walletId).first, hasLength(6));
  });

  test('hạn mức hũ = phần trăm của TỔNG THU kỳ; chi trừ đúng vào hũ của danh '
      'mục, không lẫn sang hũ khác', () async {
    await repo.seedDefaultJars(walletId);
    final jars = await repo.watchActive(walletId).first;
    final thietYeu = jars.firstWhere((j) => j.name == 'Thiết yếu');
    final huongThu = jars.firstWhere((j) => j.name == 'Hưởng thụ');

    final cats = await db.select(db.categories).get();
    final anUong = cats.firstWhere((c) => c.name == 'Ăn uống');
    final giaiTri = cats.firstWhere((c) => c.name == 'Giải trí');
    await repo.setCategoryJar(categoryId: anUong.id, jarId: thietYeu.id);
    await repo.setCategoryJar(categoryId: giaiTri.id, jarId: huongThu.id);

    final start = DateTime(2026, 8);
    final end = DateTime(2026, 9);
    await tx(amountMinor: 20000000, at: DateTime(2026, 8, 1)); // thu
    await tx(
      amountMinor: -3000000,
      at: DateTime(2026, 8, 5),
      categoryId: anUong.id,
    );
    await tx(
      amountMinor: -500000,
      at: DateTime(2026, 8, 6),
      categoryId: giaiTri.id,
    );
    // NGOÀI kỳ — không được tính vào đâu cả.
    await tx(
      amountMinor: -9000000,
      at: DateTime(2026, 7, 20),
      categoryId: anUong.id,
    );

    final progress = await repo
        .watchProgress(walletId: walletId, start: start, end: end)
        .first;
    final p = {for (final x in progress.jars) x.jar.name: x};

    // 55% × 20.000.000 = 11.000.000
    expect(p['Thiết yếu']!.allotted.minorUnits, 11000000);
    expect(p['Thiết yếu']!.used.minorUnits, 3000000);
    expect(p['Thiết yếu']!.remaining.minorUnits, 8000000);

    // 10% × 20.000.000 = 2.000.000
    expect(p['Hưởng thụ']!.allotted.minorUnits, 2000000);
    expect(p['Hưởng thụ']!.used.minorUnits, 500000);

    // Hũ chưa có danh mục nào: có hạn mức nhưng chưa chi đồng nào.
    expect(p['Cho đi']!.allotted.minorUnits, 1000000); // 5%
    expect(p['Cho đi']!.used.minorUnits, 0);
    expect(p['Cho đi']!.categoryCount, 0);
  });

  test('lưu trữ hũ thì GỠ danh mục ra khỏi nó, không để mồ côi', () async {
    await repo.seedDefaultJars(walletId);
    final jar = (await repo.watchActive(walletId).first).first;
    final cat = (await db.select(db.categories).get()).first;
    await repo.setCategoryJar(categoryId: cat.id, jarId: jar.id);

    await repo.archive(jar.id);

    final after = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(cat.id))).getSingle();
    expect(
      after.jarId,
      isNull,
      reason: 'danh mục phải quay về "chưa xếp hũ", không trỏ vào hũ đã ẩn',
    );
    expect(await repo.watchActive(walletId).first, hasLength(5));
  });

  test('xếp danh mục vào hũ thì stream tiến độ PHÁT LẠI ngay — không phải mở '
      'lại app mới thấy', () async {
    await repo.seedDefaultJars(walletId);
    final jar = (await repo.watchActive(walletId).first).first;
    final cat = (await db.select(db.categories).get()).firstWhere(
      (c) => c.parentCategoryId == null,
    );

    final stream = repo.watchProgress(
      walletId: walletId,
      start: DateTime(2026, 8),
      end: DateTime(2026, 9),
    );
    // Chờ đúng lần phát THỨ HAI: lần đầu là ảnh chụp hiện trạng (0 danh
    // mục), lần hai phải đến từ việc `categories.jar_id` vừa đổi.
    final second = stream.skip(1).first;
    await repo.setCategoryJar(categoryId: cat.id, jarId: jar.id);

    final progress = await second.timeout(const Duration(seconds: 5));
    expect(
      progress.jars.firstWhere((p) => p.jar.id == jar.id).categoryCount,
      1,
      reason: 'stream phải phản ánh danh mục vừa xếp vào hũ',
    );
  });

  test('chi ở DANH MỤC CON tính vào hũ của danh mục CHA — không rơi ra ngoài '
      'mọi hũ', () async {
    await repo.seedDefaultJars(walletId);
    final jar = (await repo.watchActive(walletId).first).first;
    final cats = await db.select(db.categories).get();
    final anUong = cats.firstWhere(
      (c) => c.name == 'Ăn uống' && c.parentCategoryId == null,
    );
    final tieuVat = cats.firstWhere((c) => c.parentCategoryId == anUong.id);

    // CHỈ xếp danh mục CHA vào hũ — đúng cách bảng chọn cho phép.
    await repo.setCategoryJar(categoryId: anUong.id, jarId: jar.id);

    await tx(amountMinor: 10000000, at: DateTime(2026, 8, 1));
    // Giao dịch ghi vào danh mục CON, giống hệt dữ liệu Rolly thật sau
    // khi khôi phục danh mục phụ (324/358 giao dịch nằm ở danh mục con).
    await tx(
      amountMinor: -700000,
      at: DateTime(2026, 8, 6),
      categoryId: tieuVat.id,
    );

    final progress = await repo
        .watchProgress(
          walletId: walletId,
          start: DateTime(2026, 8),
          end: DateTime(2026, 9),
        )
        .first;
    final p = progress.jars.firstWhere((x) => x.jar.id == jar.id);
    expect(
      p.used.minorUnits,
      700000,
      reason: 'chi ở danh mục con phải cộng vào hũ của cha',
    );
  });

  test('🚨 % hũ tính trên đúng con số "Thu" của Trang chủ: RÚT tiền từ quỹ về '
      'ví không phải thu nhập', () async {
    final jarId = (await repo.insert(
      walletId: walletId,
      name: 'Thiết yếu',
      percent: 50,
      categoryColorId: 0,
      iconCode: 'home',
    )).when(ok: (id) => id, err: (e) => throw e);
    final quy = await goal('Quỹ ngắn hạn');

    await tx(amountMinor: 20000000, at: DateTime(2026, 8, 5)); // lương
    // Rút 6tr từ quỹ về ví — dòng DƯƠNG gắn quỹ. Bản cũ cộng nó vào thu
    // nhập, hạn mức hũ phình thành 50% × 26tr = 13tr.
    await tx(amountMinor: 6000000, at: DateTime(2026, 8, 10), goalId: quy);

    final overview = await august();
    expect(overview.income.minorUnits, 20000000);
    expect(
      overview.jars.single.allotted.minorUnits,
      10000000,
      reason: '50% của 20tr thu nhập thật, không phải của 26tr',
    );
    expect(overview.jars.single.jar.id, jarId);
  });

  test('nạp quỹ KHÔNG phải chi của hũ tiêu, dù dòng đó mang một danh mục '
      'thuộc hũ', () async {
    await repo.seedDefaultJars(walletId);
    final thietYeu = (await repo.watchActive(walletId).first).firstWhere(
      (j) => j.name == 'Thiết yếu',
    );
    final phatSinh = (await db.select(db.categories).get()).firstWhere(
      (c) => c.parentCategoryId == null && c.kind == 'expense',
    );
    await repo.setCategoryJar(categoryId: phatSinh.id, jarId: thietYeu.id);
    final quy = await goal('CCTG');

    await tx(amountMinor: 20000000, at: DateTime(2026, 8, 1));
    await tx(
      amountMinor: -300000,
      at: DateTime(2026, 8, 2),
      categoryId: phatSinh.id,
    );
    // Dữ liệu Rolly thật: khoản nạp quỹ mang danh mục "Phát sinh".
    await tx(
      amountMinor: -10000000,
      at: DateTime(2026, 8, 15),
      categoryId: phatSinh.id,
      goalId: quy,
    );

    final p = (await august()).jars.firstWhere((j) => j.jar.id == thietYeu.id);
    expect(p.used.minorUnits, 300000);
  });

  test('danh mục CON xếp riêng sang hũ khác thì theo hũ đó; con chưa xếp vẫn '
      'theo cha', () async {
    await repo.seedDefaultJars(walletId);
    final jars = await repo.watchActive(walletId).first;
    final thietYeu = jars.firstWhere((j) => j.name == 'Thiết yếu');
    final huongThu = jars.firstWhere((j) => j.name == 'Hưởng thụ');
    final cats = await db.select(db.categories).get();
    final anUong = cats.firstWhere(
      (c) => c.name == 'Ăn uống' && c.parentCategoryId == null,
    );
    final tieuVat = cats.firstWhere((c) => c.parentCategoryId == anUong.id);
    final giaoLuu = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Giao lưu',
            kind: 'expense',
            categoryColorId: 0,
            iconCode: 'restaurant',
            walletId: walletId,
            parentCategoryId: Value(anUong.id),
          ),
        );

    await repo.setCategoryJar(categoryId: anUong.id, jarId: thietYeu.id);
    await repo.setCategoryJar(categoryId: giaoLuu, jarId: huongThu.id);

    await tx(amountMinor: 10000000, at: DateTime(2026, 8, 1));
    await tx(
      amountMinor: -40000,
      at: DateTime(2026, 8, 3),
      categoryId: tieuVat.id,
    );
    await tx(
      amountMinor: -250000,
      at: DateTime(2026, 8, 4),
      categoryId: giaoLuu,
    );
    await tx(
      amountMinor: -60000,
      at: DateTime(2026, 8, 5),
      categoryId: anUong.id,
    );

    final byId = {for (final p in (await august()).jars) p.jar.id: p};
    expect(byId[thietYeu.id]!.used.minorUnits, 100000, reason: '40k + 60k');
    expect(byId[huongThu.id]!.used.minorUnits, 250000);
    // Đếm cả con đã tách ra: Hưởng thụ có đúng 1 ("Giao lưu").
    expect(byId[huongThu.id]!.categoryCount, 1);
  });

  test('hũ TIẾT KIỆM đếm TỔNG tiền nạp vào quỹ gắn kèm trong kỳ', () async {
    final quy = await goal('Quỹ ngắn hạn');
    final quyKhac = await goal('Quỹ khác');
    await repo.insert(
      walletId: walletId,
      name: 'Tiết kiệm ngắn hạn',
      percent: 10,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      goals: [JarGoalLink(goalId: quy)],
    );

    await tx(amountMinor: 10000000, at: DateTime(2026, 8, 1));
    await tx(amountMinor: -100000, at: DateTime(2026, 8, 3), goalId: quy);
    await tx(amountMinor: -500000, at: DateTime(2026, 8, 9), goalId: quy);
    await tx(amountMinor: 200000, at: DateTime(2026, 8, 20), goalId: quy);
    // Không tính: quỹ khác, và ngoài kỳ.
    await tx(amountMinor: -900000, at: DateTime(2026, 8, 9), goalId: quyKhac);
    await tx(amountMinor: -700000, at: DateTime(2026, 7, 30), goalId: quy);

    final overview = await august();
    final p = overview.jars.single;
    expect(p.kind, JarKind.saving);
    expect(p.goalName, 'Quỹ ngắn hạn');
    expect(p.allotted.minorUnits, 1000000);
    expect(
      p.used.minorUnits,
      600000,
      reason: 'nhiệm vụ của hũ là NẠP: 100k + 500k. Rút 200k là chiều kia.',
    );
    expect(p.periodNet.minorUnits, 400000, reason: 'quỹ phình ra 400k');
    expect(p.remaining.minorUnits, 400000);
    expect(p.isOverspent, isFalse);
    // Tiền gửi quỹ KHÔNG còn nằm trong "đã tiêu" — nó là tiền để dành, có
    // ô riêng (đổi 2026-09-22, xem `JarsOverview.totalSpent`).
    expect(overview.totalSpent.minorUnits, 0);
    expect(overview.totalSaved.minorUnits, 600000);
  });

  test('hũ tiết kiệm gửi VƯỢT mức là đạt, không phải vượt chi', () async {
    final quy = await goal('Quỹ');
    await repo.insert(
      walletId: walletId,
      name: 'Tiết kiệm',
      percent: 10,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      goals: [JarGoalLink(goalId: quy)],
    );
    await tx(amountMinor: 1000000, at: DateTime(2026, 8, 1));
    await tx(amountMinor: -300000, at: DateTime(2026, 8, 2), goalId: quy);

    final p = (await august()).jars.single;
    expect(p.isSavingReached, isTrue);
    expect(p.isOverspent, isFalse);
  });

  test('đổi hũ tiêu thành hũ tiết kiệm thì gỡ danh mục khỏi nó — không để '
      'danh mục kẹt ở một hũ không hiện bảng chọn danh mục', () async {
    await repo.seedDefaultJars(walletId);
    final jar = (await repo.watchActive(walletId).first).first;
    final cat = (await db.select(db.categories).get()).first;
    await repo.setCategoryJar(categoryId: cat.id, jarId: jar.id);
    final quy = await goal('Quỹ');

    await repo.update(
      id: jar.id,
      name: jar.name,
      percent: jar.percent,
      categoryColorId: jar.categoryColorId,
      iconCode: jar.iconCode,
      carryOver: jar.carryOver,
      kind: JarKind.saving,
      goals: [JarGoalLink(goalId: quy)],
    );

    final after = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(cat.id))).getSingle();
    expect(after.jarId, null);
    final saved = await (db.select(
      db.jars,
    )..where((j) => j.id.equals(jar.id))).getSingle();
    expect(saved.jarKind, JarKind.saving);
    expect(await repo.goalLinksOf(jar.id), hasLength(1));
  });

  test('hũ tiêu không giữ quỹ "ma" dù được truyền goalId', () async {
    final quy = await goal('Quỹ');
    final id = (await repo.insert(
      walletId: walletId,
      name: 'Tiêu',
      percent: 10,
      categoryColorId: 0,
      iconCode: 'home',
      goals: [JarGoalLink(goalId: quy)],
    )).when(ok: (id) => id, err: (e) => throw e);
    expect(
      await repo.goalLinksOf(id),
      isEmpty,
      reason: 'hũ TIÊU không giữ dây nối quỹ',
    );
  });

  test(
    'kéo thả: reorder ghi đúng thứ tự mới, mọi màn đọc theo thứ tự đó',
    () async {
      await repo.seedDefaultJars(walletId);
      final before = await repo.watchActive(walletId).first;
      final ids = [for (final j in before) j.id];
      // Đưa hũ cuối ("Cho đi") lên đầu.
      final next = [ids.last, ...ids.take(ids.length - 1)];
      await repo.reorder(next);

      final after = await repo.watchActive(walletId).first;
      expect([for (final j in after) j.id], next);
      expect(after.first.name, 'Cho đi');
      final overview = await august();
      expect([for (final p in overview.jars) p.jar.id], next);
    },
  );

  test('hũ tiết kiệm gom NHIỀU quỹ: đã gửi = tổng tiền vào các quỹ trong kỳ; '
      'tổng quỹ đang có = số dư mọi thời gian', () async {
    final khamBenh = await goal('Khám bệnh');
    final baoHiem = await goal('Bảo hiểm');
    final khac = await goal('Quỹ khác');
    await repo.insert(
      walletId: walletId,
      name: 'Sức khoẻ',
      percent: 10,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      goals: [
        JarGoalLink(goalId: khamBenh),
        JarGoalLink(goalId: baoHiem),
      ],
    );

    await tx(amountMinor: 10000000, at: DateTime(2026, 8, 1));
    // Kỳ TRƯỚC — vào "đang có", không vào "gửi kỳ này".
    await tx(
      amountMinor: -2000000,
      at: DateTime(2026, 7, 10),
      goalId: khamBenh,
    );
    await tx(amountMinor: -300000, at: DateTime(2026, 8, 5), goalId: khamBenh);
    await tx(amountMinor: -200000, at: DateTime(2026, 8, 6), goalId: baoHiem);
    // Quỹ KHÔNG thuộc hũ.
    await tx(amountMinor: -900000, at: DateTime(2026, 8, 7), goalId: khac);

    final p = (await august()).jars.single;
    expect(p.goals, hasLength(2));
    expect(p.used.minorUnits, 500000, reason: '300k + 200k trong kỳ');
    expect(p.savedTotal.minorUnits, 2500000, reason: '2tr kỳ trước + 500k');
    expect(p.allotted.minorUnits, 1000000);
    // Hũ CÓ đặt phần trăm thì nhiệm vụ của nó là mốc của KỲ, không phải
    // đích của quỹ — thanh đo `used / allotted`.
    expect(p.tracksGoalTotal, isFalse);
    expect(p.depositsToGoals, isTrue);
    expect(p.goalTarget.minorUnits, 100000000, reason: '2 quỹ × 50tr');
    expect(p.periodNet.minorUnits, 500000);
  });

  test('tỉ lệ từng quỹ: 50% thì chỉ nửa số tiền của quỹ đó thuộc hũ', () async {
    final chung = await goal('Quỹ chung');
    await repo.insert(
      walletId: walletId,
      name: 'Hũ A',
      percent: 10,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      goals: [JarGoalLink(goalId: chung, percent: 50)],
    );
    await tx(amountMinor: 10000000, at: DateTime(2026, 8, 1));
    await tx(amountMinor: -400000, at: DateTime(2026, 8, 4), goalId: chung);

    final p = (await august()).jars.single;
    expect(p.used.minorUnits, 200000);
    expect(p.savedTotal.minorUnits, 200000);
    expect(p.goals.single.percent, 50);
  });

  test('hũ tiết kiệm 0%: không có hạn mức kỳ, thanh đo theo tiền đã để dành '
      'so với đích các quỹ', () async {
    final quy = await goal('Khám bệnh'); // đích 50tr (xem helper `goal`)
    await repo.insert(
      walletId: walletId,
      name: 'Sức khoẻ',
      percent: 0,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      goals: [JarGoalLink(goalId: quy)],
    );
    await tx(amountMinor: 10000000, at: DateTime(2026, 8, 1));
    await tx(amountMinor: -5000000, at: DateTime(2026, 8, 3), goalId: quy);

    final p = (await august()).jars.single;
    expect(p.allotted.minorUnits, 0);
    expect(p.used.minorUnits, 5000000);
    expect(p.tracksGoalTotal, isTrue);
    expect(p.goalTarget.minorUnits, 50000000);
    expect(p.ratio, closeTo(0.1, 0.0001));
    expect(p.isOverspent, isFalse);
  });

  test(
    'sửa hũ: danh sách quỹ ghi đè hoàn toàn, không để lại dây nối cũ',
    () async {
      final a = await goal('A');
      final b = await goal('B');
      final id = (await repo.insert(
        walletId: walletId,
        name: 'Hũ',
        percent: 10,
        categoryColorId: 4,
        iconCode: 'savings',
        kind: JarKind.saving,
        goals: [JarGoalLink(goalId: a)],
      )).when(ok: (id) => id, err: (e) => throw e);

      await repo.update(
        id: id,
        name: 'Hũ',
        percent: 10,
        categoryColorId: 4,
        iconCode: 'savings',
        carryOver: false,
        kind: JarKind.saving,
        goals: [JarGoalLink(goalId: b, percent: 25)],
      );

      final links = await repo.goalLinksOf(id);
      expect(links, hasLength(1));
      expect(links.single.goalId, b);
      expect(links.single.percent, 25);
    },
  );

  test(
    'hũ "TIÊU TỪ QUỸ": đếm tiền RÚT ra trong kỳ, mốc là tiền còn trong quỹ',
    () async {
      final quy = await goal('Khám bệnh');
      await repo.insert(
        walletId: walletId,
        name: 'Khám bệnh',
        percent: 0,
        categoryColorId: 4,
        iconCode: 'savings',
        kind: JarKind.saving,
        flow: JarGoalFlow.spend,
        goals: [JarGoalLink(goalId: quy)],
      );
      await tx(amountMinor: 10000000, at: DateTime(2026, 8, 1));
      // Kỳ trước nạp 3tr vào quỹ.
      await tx(amountMinor: -3000000, at: DateTime(2026, 7, 5), goalId: quy);
      // Kỳ này rút 800k ra tiêu, và nạp thêm 200k.
      await tx(amountMinor: 800000, at: DateTime(2026, 8, 10), goalId: quy);
      await tx(amountMinor: -200000, at: DateTime(2026, 8, 12), goalId: quy);

      final p = (await august()).jars.single;
      expect(p.spendsFromGoals, isTrue);
      expect(
        p.used.minorUnits,
        800000,
        reason: 'TỔNG tiền rút ra, KHÔNG trừ phần nạp thêm trong kỳ',
      );
      expect(p.savedTotal.minorUnits, 2400000, reason: '3tr − 800k + 200k');
      expect(p.tracksGoalDrawdown, isTrue);
      // Thanh đo phần quỹ đã tiêu trong kỳ: 800k / (2,4tr + 800k) = 25%.
      expect(p.ratio, closeTo(0.25, 0.0001));
      expect(p.isOverspent, isFalse);
      expect(p.goals.single.inMinor, 200000);
      expect(p.goals.single.outMinor, 800000);
    },
  );

  test('hũ "tiêu từ quỹ" CÓ đặt trần: vượt trần là vượt', () async {
    final quy = await goal('Khám bệnh');
    await repo.insert(
      walletId: walletId,
      name: 'Khám bệnh',
      percent: 5,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      flow: JarGoalFlow.spend,
      goals: [JarGoalLink(goalId: quy)],
    );
    await tx(amountMinor: 10000000, at: DateTime(2026, 8, 1));
    await tx(amountMinor: -3000000, at: DateTime(2026, 7, 5), goalId: quy);
    await tx(amountMinor: 700000, at: DateTime(2026, 8, 10), goalId: quy);

    final p = (await august()).jars.single;
    expect(p.allotted.minorUnits, 500000, reason: 'trần 5% của 10tr');
    expect(p.used.minorUnits, 700000);
    expect(p.isOverspent, isTrue);
    expect(p.tracksGoalDrawdown, isFalse);
  });

  test('hũ "nạp vào quỹ" KHÔNG đếm nhầm tiền rút thành tiền tiêu', () async {
    final quy = await goal('Dài hạn');
    await repo.insert(
      walletId: walletId,
      name: 'Tiết kiệm',
      percent: 10,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      goals: [JarGoalLink(goalId: quy)],
    );
    await tx(amountMinor: 10000000, at: DateTime(2026, 8, 1));
    await tx(amountMinor: -1000000, at: DateTime(2026, 8, 3), goalId: quy);
    await tx(amountMinor: 400000, at: DateTime(2026, 8, 20), goalId: quy);

    final p = (await august()).jars.single;
    expect(p.spendsFromGoals, isFalse);
    expect(
      p.used.minorUnits,
      1000000,
      reason: 'chiều NẠP chỉ đếm tiền nạp, TỔNG — không trừ 400k rút ra',
    );
    expect(p.goals.single.outMinor, 400000, reason: 'phần rút vẫn đọc được');
    expect(p.periodNet.minorUnits, 600000);
  });

  test('hũ tiết kiệm: kỳ RÚT RÒNG không kéo hũ xuống số âm — con số của hũ '
      'là tiền ĐANG CÓ trong quỹ', () async {
    final quy = await goal('CCTG');
    await repo.insert(
      walletId: walletId,
      name: 'Tiết kiệm dài hạn',
      percent: 10,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      goals: [JarGoalLink(goalId: quy)],
    );

    await tx(amountMinor: 10000000, at: DateTime(2026, 8, 1));
    // Kỳ TRƯỚC nạp 3tr.
    await tx(amountMinor: -3000000, at: DateTime(2026, 7, 5), goalId: quy);
    // Kỳ NÀY nạp 200k rồi rút 500k → ròng −300k.
    await tx(amountMinor: -200000, at: DateTime(2026, 8, 4), goalId: quy);
    await tx(amountMinor: 500000, at: DateTime(2026, 8, 20), goalId: quy);

    final overview = await august();
    final p = overview.jars.single;

    // Nhiệm vụ của hũ này là NẠP — nó chỉ đếm tiền nạp, số TỔNG. Việc hũ
    // khác (hoặc chính Tony) rút 500k ra là dòng tiền của CHIỀU KIA.
    expect(p.used.minorUnits, 200000, reason: 'chỉ đếm tiền NẠP trong kỳ');
    expect(p.periodNet.minorUnits, -300000, reason: 'quỹ hụt đi 300k');
    expect(p.savedTotal.minorUnits, 2700000, reason: '3tr − 300k vẫn DƯƠNG');
    expect(p.depositsToGoals, isTrue);
    expect(p.tracksGoalTotal, isFalse, reason: 'hũ có 10% thì đo mốc của kỳ');
    expect(p.ratio, closeTo(200000 / 1000000, 1e-9));
    expect(p.isOverspent, isFalse);

    // Tổng của bộ hũ: "đã nạp vào quỹ" là số tổng, không bao giờ âm; tiền
    // quỹ không lẫn vào "đã tiêu".
    expect(overview.totalSaved.minorUnits, 200000);
    expect(overview.totalSpent.minorUnits, 0);
    expect(overview.totalInGoals.minorUnits, 2700000);
  });

  // 🚨 Ca dùng THẬT của Tony (2026-09-22): tám quỹ, hai hũ — "Tiết kiệm"
  // chuyên NẠP vào quỹ, "Phát sinh trong quỹ dự phòng" chuyên RÚT từ quỹ —
  // và CÙNG một quỹ nằm trong CẢ HAI hũ. Trước bản này hũ nạp đọc phần
  // RÒNG, nên mỗi lần hũ kia làm đúng việc của mình (rút tiền) thì con số
  // của hũ nạp tụt xuống: "trừ tiền và cộng tiền lộn xộn lên".
  test('một quỹ nằm trong CẢ HAI hũ ngược chiều: hai hũ không giẫm chân nhau',
      () async {
    final khamBenh = await goal('Khám bệnh');
    final duLich = await goal('Du lịch');

    await repo.insert(
      walletId: walletId,
      name: 'Tiết kiệm',
      percent: 10,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      flow: JarGoalFlow.deposit,
      goals: [JarGoalLink(goalId: khamBenh), JarGoalLink(goalId: duLich)],
    );
    await repo.insert(
      walletId: walletId,
      name: 'Phát sinh trong quỹ dự phòng',
      percent: 0,
      categoryColorId: 3,
      iconCode: 'handshake',
      kind: JarKind.saving,
      flow: JarGoalFlow.spend,
      // ĐÚNG hai quỹ đó, cũng 100% — không chia tỉ lệ, vì hai hũ lo hai
      // NHIỆM VỤ khác nhau chứ không chia nhau quyền sở hữu túi tiền.
      goals: [JarGoalLink(goalId: khamBenh), JarGoalLink(goalId: duLich)],
    );

    await tx(amountMinor: 10000000, at: DateTime(2026, 8, 1));
    // Kỳ này: nạp 800k vào Khám bệnh, rồi rút 300k ra đi khám.
    await tx(amountMinor: -800000, at: DateTime(2026, 8, 5), goalId: khamBenh);
    await tx(amountMinor: 300000, at: DateTime(2026, 8, 18), goalId: khamBenh);
    // Du lịch chỉ nạp.
    await tx(amountMinor: -500000, at: DateTime(2026, 8, 6), goalId: duLich);

    final overview = await august();
    final nap = overview.jars.firstWhere((j) => j.jar.name == 'Tiết kiệm');
    final rut = overview.jars.firstWhere(
      (j) => j.jar.name == 'Phát sinh trong quỹ dự phòng',
    );

    // Hũ NẠP chỉ thấy tiền nạp: 800k + 500k. Việc rút 300k không đụng tới.
    expect(nap.used.minorUnits, 1300000);
    expect(nap.depositsToGoals, isTrue);
    expect(
      nap.remaining.minorUnits,
      -300000,
      reason: 'hạn mức 1tr, đã nạp 1,3tr → đã đủ và dư 300k',
    );

    // Hũ RÚT chỉ thấy tiền rút: 300k. Việc nạp 1,3tr không đụng tới.
    expect(rut.used.minorUnits, 300000);
    expect(rut.spendsFromGoals, isTrue);

    // Tổng bộ hũ: hai dòng riêng, và tiền trong quỹ đếm MỘT lần dù hai hũ
    // cùng trỏ vào đúng hai quỹ đó.
    expect(overview.totalSaved.minorUnits, 1300000);
    expect(overview.totalDrawnFromGoals.minorUnits, 300000);
    expect(overview.distinctGoalCount, 2);
    expect(
      overview.totalInGoals.minorUnits,
      1000000,
      reason: '800k − 300k + 500k, đếm mỗi quỹ đúng một lần',
    );
    // Tiền quỹ không lẫn vào "đã tiêu" của kỳ.
    expect(overview.totalSpent.minorUnits, 0);

    // 🚨 Nạp VƯỢT hạn mức không được kéo tổng bộ hũ xuống "Vượt". Thu nhập
    // kỳ này 10tr → hạn mức hũ nạp là 1tr, mà Tony nạp 1,3tr (phần dôi ra
    // là tiền của kỳ trước đang nằm trong ví). Bắt được lỗi này khi bấm
    // thật: bộ hũ từng báo "Vượt 6.050.000".
    expect(nap.remaining.minorUnits, -300000);
    expect(overview.totalOverspent.minorUnits, 0, reason: 'nạp dư là TỐT');
    expect(
      overview.totalRemaining.minorUnits,
      0,
      reason: 'hũ nạp đã dùng hết hạn mức, hũ rút không có hạn mức nào',
    );
  });

  test('vai trò của từng quỹ đọc được để sheet sửa hũ cảnh báo trùng chiều',
      () async {
    final quy = await goal('Khám bệnh');
    await repo.insert(
      walletId: walletId,
      name: 'Tiết kiệm',
      percent: 10,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      flow: JarGoalFlow.deposit,
      goals: [JarGoalLink(goalId: quy)],
    );
    await repo.insert(
      walletId: walletId,
      name: 'Phát sinh',
      percent: 0,
      categoryColorId: 3,
      iconCode: 'handshake',
      kind: JarKind.saving,
      flow: JarGoalFlow.spend,
      goals: [JarGoalLink(goalId: quy)],
    );

    final roles = await repo.goalJarRoles(walletId);
    final forGoal = roles[quy]!..sort((a, b) => a.jarName.compareTo(b.jarName));
    expect(forGoal, hasLength(2));
    expect(forGoal[0].jarName, 'Phát sinh');
    expect(forGoal[0].flow, JarGoalFlow.spend);
    expect(forGoal[1].jarName, 'Tiết kiệm');
    expect(forGoal[1].flow, JarGoalFlow.deposit);
  });
}
