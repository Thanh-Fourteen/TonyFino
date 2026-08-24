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

  test('chuỗi rỗng → null, không ném lỗi', () {
    expect(matchCategory('', keywords), isNull);
    expect(matchCategory('   ', keywords), isNull);
  });
}
