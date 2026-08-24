// Bộ từ khoá SEED THẬT phải xếp đúng những câu Tony gõ hằng ngày.
//
// Khác `category_matcher_test.dart` (kiểm THUẬT TOÁN chấm điểm bằng 3 từ
// khoá giả), file này kiểm chính `defaultCategorySeeds` — thứ quyết định
// app có nhận ra "hủ tíu" là đồ ăn hay không. Danh sách câu lấy từ sổ thật
// của Tony (`test/tooling/audit_category_keywords.dart` soi 209 ghi chú).
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/seed/category_seed.dart';
import 'package:tonyfino/features/quick_add/domain/parser/category_matcher.dart';
import 'package:tonyfino/features/quick_add/domain/parser/normalizer.dart';
import 'package:tonyfino/features/quick_add/domain/parser/parse_result.dart';

void main() {
  // Nạp cả từ khoá danh mục CON, quy về khoá CHA — đó đúng là cách app
  // rollup khi hiển thị. Thiếu vế này thì "cafe" trông như chưa có từ khoá
  // nào trong khi nó nằm ở danh mục con "Tiêu vặt".
  final keywords = [
    for (final seed in defaultCategorySeeds)
      for (final k in seed.keywords)
        CategoryKeywordEntry(
          categoryKey: seed.key,
          keyword: k.keyword,
          keywordAscii: normalize(k.keyword).ascii,
          weight: k.weight,
        ),
    for (final sub in defaultSubcategorySeeds)
      for (final k in sub.keywords)
        CategoryKeywordEntry(
          categoryKey: sub.parentKey,
          keyword: k.keyword,
          keywordAscii: normalize(k.keyword).ascii,
          weight: k.weight,
        ),
  ];

  void expectsCategory(String note, String key) {
    final match = matchCategory(note, keywords);
    expect(
      match?.categoryKey,
      key,
      reason: '"$note" phải vào $key, nhận được ${match?.categoryKey}',
    );
  }

  group('🚨 món ăn Tony gõ thường xuyên nhất', () {
    const dishes = [
      'hủ tíu', // 8 lần trong sổ — chính câu Tony báo
      'hủ tíu gà',
      'ăn hủ tíu',
      'hủ tiếu', // cách viết còn lại
      'bánh mì',
      'bún riêu',
      'bò kho',
      'bánh bao',
      'mì cay',
      'cháo hàu',
      'chân gà',
      'tàu hủ',
      'trái cây',
      'buffet',
      'cơm trưa',
    ];
    for (final note in dishes) {
      test('"$note" → Ăn uống', () => expectsCategory(note, 'an_uong'));
    }
  });

  group(
    '🚨 cà phê — trước đây KHÔNG có từ khoá nào, mọi cách viết đều trượt',
    () {
      for (final note in ['cafe', 'cà phê', 'caphe', 'coffee', 'cf']) {
        test('"$note" → Ăn uống', () => expectsCategory(note, 'an_uong'));
      }
    },
  );

  group('🚨 "nước" là ĐỒ UỐNG, không phải hoá đơn nhà', () {
    for (final note in [
      'nước lọc',
      'nước mía',
      'nước dừa',
      'nước highlands coffee',
    ]) {
      test('"$note" → Ăn uống', () => expectsCategory(note, 'an_uong'));
    }

    // Nhưng hoá đơn nước thì vẫn phải về Nhà cửa — từ khoá dài hơn, điểm
    // cao hơn. Đây là ràng buộc giữ cho việc gỡ `nước` trần không phá thứ
    // khác.
    test(
      '"tiền nước" → Nhà cửa',
      () => expectsCategory('tiền nước', 'nha_cua'),
    );
    test(
      '"hoá đơn nước tháng 8" → Nhà cửa',
      () => expectsCategory('hoá đơn nước tháng 8', 'nha_cua'),
    );
    test(
      '"sửa ống nước" → Nhà cửa',
      () => expectsCategory('sửa ống nước', 'nha_cua'),
    );
  });

  test('🚨 KHÔNG có từ khoá "ăn" trần — "an" là âm tiết quá phổ biến', () {
    // "bình an"/"an toàn"/"an kỳ" không được rơi vào Ăn uống.
    expect(matchCategory('an kỳ', keywords)?.categoryKey, isNot('an_uong'));
    expect(matchCategory('bình an', keywords)?.categoryKey, isNot('an_uong'));
  });
}
