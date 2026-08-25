import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/quick_add/domain/parser/category_matcher.dart';
import 'package:tonyfino/features/quick_add/domain/parser/parse_result.dart';

void main() {
  const List<CategoryKeywordEntry> keywords = [
    CategoryKeywordEntry(
      categoryKey: 'an_uong',
      keyword: 'cà phê',
      keywordAscii: 'ca phe',
      weight: 1.3,
    ),
    CategoryKeywordEntry(
      categoryKey: 'di_chuyen',
      keyword: 'xe',
      keywordAscii: 'xe',
      weight: 1.0,
    ),
    CategoryKeywordEntry(
      categoryKey: 'giao_duc',
      keyword: 'học phí',
      keywordAscii: 'hoc phi',
      weight: 1.2,
    ),
  ];

  test('không có từ khoá nào khớp → null', () {
    expect(matchCategory('lan man không liên quan gì', keywords), isNull);
  });

  test('khớp cơ bản, không phân biệt dấu', () {
    final match = matchCategory('cà phê sáng nay', keywords);
    expect(match?.categoryKey, 'an_uong');
  });

  test('điểm = weight × độ dài khớp (ký tự ascii)', () {
    // "ca phe" dài 6 ký tự, weight 1.3 → điểm 7.8.
    final match = matchCategory('cà phê', keywords);
    expect(match?.score, closeTo(7.8, 0.001));
  });

  test('ràng buộc biên từ — không khớp nhầm giữa từ khác', () {
    // "xe" không được khớp bên trong "hoc phi xem" (dù "xe" là substring).
    final match = matchCategory('học phí xem online', keywords);
    expect(match?.categoryKey, 'giao_duc');
  });

  test('nhiều từ khoá cùng danh mục cộng dồn điểm', () {
    const List<CategoryKeywordEntry> kw = [
      CategoryKeywordEntry(
        categoryKey: 'an_uong',
        keyword: 'cà phê',
        keywordAscii: 'ca phe',
        weight: 1.0,
      ),
      CategoryKeywordEntry(
        categoryKey: 'an_uong',
        keyword: 'ăn sáng',
        keywordAscii: 'an sang',
        weight: 1.0,
      ),
    ];
    final match = matchCategory('cà phê ăn sáng luôn', kw);
    // "ca phe"(6) + "an sang"(7) = 13.
    expect(match?.score, closeTo(13.0, 0.001));
  });

  group('hai tầng — chấm điểm theo NHÁNH, chọn con khi con có bằng chứng', () {
    // "Ăn uống" (gốc) có con "Ăn trưa"; con mang tín hiệu buổi `trưa` do
    // `categoryKeywordEntriesProvider` sinh ra từ chính tên nó.
    const List<CategoryKeywordEntry> tree = [
      CategoryKeywordEntry(
        categoryKey: 'an_uong',
        keyword: 'hủ tíu',
        keywordAscii: 'hu tiu',
        weight: 1.0,
      ),
      CategoryKeywordEntry(
        categoryKey: 'an_trua',
        parentKey: 'an_uong',
        keyword: 'trưa',
        keywordAscii: 'trua',
        weight: 1.2,
      ),
      CategoryKeywordEntry(
        categoryKey: 'di_chuyen',
        keyword: 'gửi xe',
        keywordAscii: 'gui xe',
        weight: 1.2,
      ),
    ];

    test('🚨 "hủ tíu trưa" → danh mục CON, không dừng ở cha', () {
      // Trước bản sửa: argmax phẳng thấy cha 6.0 > con 4.8 nên luôn trả cha,
      // và Tony không bao giờ nhận được danh mục con dù đã viết rõ "trưa".
      expect(matchCategory('hủ tíu trưa', tree)?.categoryKey, 'an_trua');
    });

    test('không có tín hiệu con → vẫn là cha', () {
      expect(matchCategory('hủ tíu', tree)?.categoryKey, 'an_uong');
    });

    test('điểm trả về là điểm CẢ NHÁNH (cha + con)', () {
      // "hu tiu" 1.0×6 = 6.0, "trua" 1.2×4 = 4.8.
      expect(matchCategory('hủ tíu trưa', tree)?.score, closeTo(10.8, 0.001));
    });

    test('con của nhánh THUA không cướp được nhánh khác', () {
      // "gui xe" 1.2×6 = 7.2 cho Di chuyển; con "Ăn trưa" chỉ có 4.8 và
      // nhánh Ăn uống không có gì khác → không được nhảy vào bữa trưa.
      expect(matchCategory('gửi xe trưa', tree)?.categoryKey, 'di_chuyen');
    });

    test('điểm con ĐẨY nhánh cha thắng nhánh khác', () {
      // Cha Ăn uống không khớp gì; chỉ mình con khớp "trưa" (4.8) vẫn phải
      // đủ để nhánh này thắng một nhánh khớp yếu hơn.
      const List<CategoryKeywordEntry> kw = [
        CategoryKeywordEntry(
          categoryKey: 'an_uong',
          keyword: 'ăn uống',
          keywordAscii: 'an uong',
          weight: 2.0,
        ),
        CategoryKeywordEntry(
          categoryKey: 'an_trua',
          parentKey: 'an_uong',
          keyword: 'trưa',
          keywordAscii: 'trua',
          weight: 1.2,
        ),
        CategoryKeywordEntry(
          categoryKey: 'khac',
          keyword: 'mì',
          keywordAscii: 'mi',
          weight: 1.0,
        ),
      ];
      expect(matchCategory('mì trưa', kw)?.categoryKey, 'an_trua');
    });
  });

  group('khớp mờ — tên riêng gõ sai một ký tự', () {
    const List<CategoryKeywordEntry> kw = [
      CategoryKeywordEntry(
        categoryKey: 'an_uong',
        keyword: 'oxytocin',
        keywordAscii: 'oxytocin',
        weight: 1.2,
      ),
      CategoryKeywordEntry(
        categoryKey: 'di_chuyen',
        keyword: 'xăng',
        keywordAscii: 'xang',
        weight: 1.3,
      ),
    ];

    test('sai một ký tự ở từ dài → vẫn khớp', () {
      expect(matchCategory('oxytoxin', kw)?.categoryKey, 'an_uong');
    });

    test('thiếu/thừa một ký tự cũng khớp', () {
      expect(matchCategory('oxytocn', kw)?.categoryKey, 'an_uong');
      expect(matchCategory('oxytocinn', kw)?.categoryKey, 'an_uong');
    });

    test('sai HAI ký tự → không khớp', () {
      expect(matchCategory('oxytoxim', kw), isNull);
    });

    test('🚨 từ NGẮN không bao giờ khớp mờ', () {
      // "xong" cách "xang" đúng một ký tự — cho phép mờ ở từ 4 ký tự là mời
      // gọi khớp bậy trên khắp tiếng Việt bỏ dấu.
      expect(matchCategory('xong viec roi', kw), isNull);
    });

    test('khớp mờ ăn điểm THẤP HƠN khớp đúng', () {
      final exact = matchCategory('oxytocin', kw)!.score;
      final fuzzy = matchCategory('oxytoxin', kw)!.score;
      expect(fuzzy, lessThan(exact));
    });

    test('từ khoá NHIỀU TỪ phải liên tiếp, một từ trong đó được mờ', () {
      const List<CategoryKeywordEntry> phrase = [
        CategoryKeywordEntry(
          categoryKey: 'an_chung',
          keyword: 'chung oxytocin',
          keywordAscii: 'chung oxytocin',
          weight: 1.2,
        ),
      ];
      expect(
        matchCategory('oc chung oxytoxin', phrase)?.categoryKey,
        'an_chung',
      );
      // Không liên tiếp → không phải cụm đó.
      expect(matchCategory('chung voi oxytocin', phrase), isNull);
    });
  });

  test('chuỗi rỗng → null, không ném lỗi', () {
    expect(matchCategory('', keywords), isNull);
    expect(matchCategory('   ', keywords), isNull);
  });
}
