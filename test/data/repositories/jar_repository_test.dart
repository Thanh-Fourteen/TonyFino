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

  test('hũ TIẾT KIỆM đếm tiền gửi RÒNG vào quỹ gắn kèm trong kỳ', () async {
    final quy = await goal('Quỹ ngắn hạn');
    final quyKhac = await goal('Quỹ khác');
    await repo.insert(
      walletId: walletId,
      name: 'Tiết kiệm ngắn hạn',
      percent: 10,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      goalId: quy,
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
    expect(p.used.minorUnits, 400000, reason: 'nạp 100k + 500k, rút 200k');
    expect(p.remaining.minorUnits, 600000);
    expect(p.isOverspent, isFalse);
    expect(overview.totalUsed.minorUnits, 400000);
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
      goalId: quy,
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
      goalId: quy,
    );

    final after = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(cat.id))).getSingle();
    expect(after.jarId, null);
    final saved = await (db.select(
      db.jars,
    )..where((j) => j.id.equals(jar.id))).getSingle();
    expect(saved.jarKind, JarKind.saving);
    expect(saved.goalId, quy);
  });

  test('hũ tiêu không giữ quỹ "ma" dù được truyền goalId', () async {
    final quy = await goal('Quỹ');
    final id = (await repo.insert(
      walletId: walletId,
      name: 'Tiêu',
      percent: 10,
      categoryColorId: 0,
      iconCode: 'home',
      goalId: quy,
    )).when(ok: (id) => id, err: (e) => throw e);
    final jar = await (db.select(
      db.jars,
    )..where((j) => j.id.equals(id))).getSingle();
    expect(jar.goalId, null);
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
}
