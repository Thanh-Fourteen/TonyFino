import 'package:tonyfino/core/text/ascii_fold.dart';
import 'package:tonyfino/data/db/seed/category_seed.dart';
import 'package:tonyfino/features/quick_add/domain/parser/parser.dart';

/// Chuyển `defaultCategorySeeds` (Phase 4, ~300 từ khoá thật) sang
/// `CategoryKeywordEntry` — dùng làm fixture test cho `category_matcher`
/// (Phase 7) mà không cần dựng DB. Sản phẩm thật (Phase 8) sẽ nạp từ
/// `category_keywords` sống trong DB (đã lớn dần qua vòng lặp học), không
/// phải từ bảng seed tĩnh này — hàm này CHỈ phục vụ test.
/// Danh mục CON mặc định (`defaultSubcategorySeeds`, Phase 22 addendum)
/// dùng `categoryKey: parentKey` ở fixture này CÓ CHỦ ĐÍCH — tầng
/// parser/matcher thuần (`category_matcher.dart`) không có khái niệm
/// "danh mục con" (đó là chi tiết của DB thật, xem `categoryKeywordEntriesProvider`
/// khoá theo id thật), fixture test chỉ cần biết "câu này khớp vào NHÓM
/// nào" để kiểm amount/segmenter — dùng key của cha giữ đúng kỳ vọng cũ
/// của corpus (`test/fixtures/parser/corpus.jsonl`) mà không phải sinh lại
/// corpus chỉ vì một từ khoá đổi danh mục con.
List<CategoryKeywordEntry> testCategoryKeywords() => [
  for (final category in defaultCategorySeeds)
    for (final keyword in category.keywords)
      CategoryKeywordEntry(
        categoryKey: category.key,
        keyword: keyword.keyword,
        keywordAscii: foldToAscii(keyword.keyword),
        weight: keyword.weight,
      ),
  for (final subCategory in defaultSubcategorySeeds)
    for (final keyword in subCategory.keywords)
      CategoryKeywordEntry(
        categoryKey: subCategory.parentKey,
        keyword: keyword.keyword,
        keywordAscii: foldToAscii(keyword.keyword),
        weight: keyword.weight,
      ),
];
