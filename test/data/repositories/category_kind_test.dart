// Chiều tiền (`Categories.kind`) — ba lỗ hổng làm "thưởng 1tr" gõ ở màn chat
// ghi ra −1.000.000 dù Tony đã tạo "Thưởng" là danh mục THU.
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/result/result.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/category_repository.dart';

import '../../support/open_test_database.dart';

int _unwrap(Result<int, AppError> result) =>
    result.when(ok: (v) => v, err: (e) => throw Exception('$e'));

Future<int> _defaultWalletId(AppDatabase db) async =>
    (await db.select(db.wallets).get()).first.id;

Future<Category> _byId(AppDatabase db, int id) =>
    (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle();

void main() {
  test('🚨 update() GHI được kind — nút gạt Chi/Thu ở sheet sửa không nói dối', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = CategoryRepository(db);
    final id = _unwrap(
      await repo.insert(
        name: 'Thưởng',
        kind: 'expense',
        categoryColorId: 3,
        iconCode: 'payments',
        walletId: await _defaultWalletId(db),
      ),
    );

    final result = await repo.update(
      id: id,
      name: 'Thưởng',
      kind: 'income',
      categoryColorId: 3,
      iconCode: 'payments',
    );

    expect(result.isOk, isTrue, reason: '$result');
    expect((await _byId(db, id)).kind, 'income');
  });

  test('danh mục CON thừa hưởng kind của cha lúc TẠO, bỏ qua kind truyền vào', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = CategoryRepository(db);
    final parentId = _unwrap(
      await repo.insert(
        name: 'Thu nhập phụ',
        kind: 'income',
        categoryColorId: 3,
        iconCode: 'payments',
        walletId: await _defaultWalletId(db),
      ),
    );

    final childId = _unwrap(
      await repo.insert(
        name: 'Thưởng',
        // Đúng thứ sheet gửi lên khi Tony quên bấm "Thu" — phải bị bỏ qua.
        kind: 'expense',
        categoryColorId: 3,
        iconCode: 'payments',
        parentCategoryId: parentId,
      ),
    );

    expect((await _byId(db, childId)).kind, 'income');
  });

  test('đổi kind của danh mục GỐC kéo theo mọi danh mục con', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = CategoryRepository(db);
    final parentId = _unwrap(
      await repo.insert(
        name: 'Việc phụ',
        kind: 'expense',
        categoryColorId: 3,
        iconCode: 'payments',
        walletId: await _defaultWalletId(db),
      ),
    );
    final childId = _unwrap(
      await repo.insert(
        name: 'Thưởng',
        kind: 'expense',
        categoryColorId: 3,
        iconCode: 'payments',
        parentCategoryId: parentId,
      ),
    );

    await repo.update(
      id: parentId,
      name: 'Việc phụ',
      kind: 'income',
      categoryColorId: 3,
      iconCode: 'payments',
    );

    expect((await _byId(db, parentId)).kind, 'income');
    expect(
      (await _byId(db, childId)).kind,
      'income',
      reason: 'con còn kẹt expense thì màn chat vẫn ghi ra khoản CHI',
    );
  });

  test('chuyển một danh mục sang làm CON thì nhận kind của cha mới', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = CategoryRepository(db);
    final walletId = await _defaultWalletId(db);
    final parentId = _unwrap(
      await repo.insert(
        name: 'Thu nhập phụ',
        kind: 'income',
        categoryColorId: 3,
        iconCode: 'payments',
        walletId: walletId,
      ),
    );
    final orphanId = _unwrap(
      await repo.insert(
        name: 'Thưởng',
        kind: 'expense',
        categoryColorId: 3,
        iconCode: 'payments',
        walletId: walletId,
      ),
    );

    await repo.update(
      id: orphanId,
      name: 'Thưởng',
      kind: 'expense',
      categoryColorId: 3,
      iconCode: 'payments',
      parentCategoryId: parentId,
    );

    expect((await _byId(db, orphanId)).kind, 'income');
  });

  test('repairSubcategoryKinds sửa hàng đã lỡ sai trong sổ CŨ', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final walletId = await _defaultWalletId(db);
    // Ghi thẳng vào bảng, không qua repository — mô phỏng đúng hàng đã nằm
    // sẵn trong sổ Tony từ trước bản sửa này.
    final parentId = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Thu nhập phụ',
            kind: 'income',
            categoryColorId: 3,
            iconCode: 'payments',
            walletId: walletId,
          ),
        );
    final childId = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Thưởng',
            kind: 'expense',
            categoryColorId: 3,
            iconCode: 'payments',
            parentCategoryId: Value(parentId),
            walletId: walletId,
          ),
        );

    await repairSubcategoryKinds(db);

    expect((await _byId(db, childId)).kind, 'income');
    expect(
      (await _byId(db, parentId)).kind,
      'income',
      reason: 'danh mục gốc không bị đụng tới',
    );
  });
}
