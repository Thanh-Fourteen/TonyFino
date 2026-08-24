// Bù từ khoá seed vào sổ ĐÃ TỒN TẠI — thêm từ khoá vào `category_seed.dart`
// mà không có bước này thì chỉ người cài mới được hưởng, máy đang dùng vẫn
// y nguyên (đúng lỗi "hủ tíu chưa nhận ra là đồ ăn" Tony báo).
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<int> tieuVatId() async {
    final rows = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Tiêu vặt'))).get();
    return rows.first.id;
  }

  Future<int> anUongId() async {
    final rows = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Ăn uống'))).get();
    return rows.first.id;
  }

  Future<Set<String>> keywordsOf(int categoryId) async {
    final rows = await (db.select(
      db.categoryKeywords,
    )..where((k) => k.categoryId.equals(categoryId))).get();
    return rows.map((k) => k.keyword).toSet();
  }

  test(
    '🚨 sổ cũ THIẾU từ khoá mới → backfill chèn vào, không đụng từ đã có',
    () async {
      final categoryId = await anUongId();

      // Giả lập sổ cũ: xoá đúng những từ khoá đợt này mới thêm, và mốc đã
      // chạy (openTestDatabase gọi onCreate nên mốc đã có sẵn).
      await (db.delete(db.categoryKeywords)..where(
            (k) =>
                k.categoryId.equals(categoryId) &
                k.keyword.isIn(['hủ tíu', 'bò kho', 'trái cây']),
          ))
          .go();
      await (db.delete(
        db.appEvents,
      )..where((e) => e.message.equals(kSeedKeywordBackfillMarker))).go();

      // Trọng số do người dùng chỉnh phải được GIỮ NGUYÊN, không bị ghi đè.
      await (db.update(db.categoryKeywords)..where(
            (k) => k.categoryId.equals(categoryId) & k.keyword.equals('phở'),
          ))
          .write(const CategoryKeywordsCompanion(weight: Value(9.9)));

      await backfillSeedKeywords(db);

      final after = await keywordsOf(categoryId);
      expect(after, containsAll(['hủ tíu', 'bò kho', 'trái cây']));

      final pho =
          await (db.select(db.categoryKeywords)..where(
                (k) =>
                    k.categoryId.equals(categoryId) & k.keyword.equals('phở'),
              ))
              .getSingle();
      expect(pho.weight, 9.9, reason: 'không được ghi đè trọng số người dùng');
    },
  );

  test(
    'chạy MỘT LẦN — gọi lại không mọc lại từ khoá người dùng đã xoá',
    () async {
      final categoryId = await anUongId();
      await backfillSeedKeywords(db); // lần đầu (mốc đã có từ onCreate)

      // Người dùng chủ động xoá một từ khoá.
      await (db.delete(db.categoryKeywords)..where(
            (k) => k.categoryId.equals(categoryId) & k.keyword.equals('phở'),
          ))
          .go();

      await backfillSeedKeywords(db);
      expect(await keywordsOf(categoryId), isNot(contains('phở')));
    },
  );

  test('🚨 bù cả danh mục CON — từ khoá cà phê nằm ở "Tiêu vặt", bỏ sót vế này '
      'thì đợt bổ sung không tới được sổ đang dùng', () async {
    final subId = await tieuVatId();
    await (db.delete(db.categoryKeywords)..where(
          (k) =>
              k.categoryId.equals(subId) &
              k.keyword.isIn(['caphe', 'coffee', 'highlands']),
        ))
        .go();
    await (db.delete(
      db.appEvents,
    )..where((e) => e.message.equals(kSeedKeywordBackfillMarker))).go();

    await backfillSeedKeywords(db);

    expect(
      await keywordsOf(subId),
      containsAll(['caphe', 'coffee', 'highlands', 'cafe']),
    );
  });
}
