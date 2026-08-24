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
          ),
        );
  }

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
    final p = {for (final x in progress) x.jar.name: x};

    // 55% × 20.000.000 = 11.000.000
    expect(p['Thiết yếu']!.allotted.minorUnits, 11000000);
    expect(p['Thiết yếu']!.spent.minorUnits, 3000000);
    expect(p['Thiết yếu']!.remaining.minorUnits, 8000000);

    // 10% × 20.000.000 = 2.000.000
    expect(p['Hưởng thụ']!.allotted.minorUnits, 2000000);
    expect(p['Hưởng thụ']!.spent.minorUnits, 500000);

    // Hũ chưa có danh mục nào: có hạn mức nhưng chưa chi đồng nào.
    expect(p['Cho đi']!.allotted.minorUnits, 1000000); // 5%
    expect(p['Cho đi']!.spent.minorUnits, 0);
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
      progress.firstWhere((p) => p.jar.id == jar.id).categoryCount,
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
    final p = progress.firstWhere((x) => x.jar.id == jar.id);
    expect(
      p.spent.minorUnits,
      700000,
      reason: 'chi ở danh mục con phải cộng vào hũ của cha',
    );
  });
}
