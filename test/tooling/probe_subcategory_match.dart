// Công cụ SOI (không phải test hồi quy): chạy bộ khớp thật lên SỔ THẬT của
// Tony — 12 danh mục gốc seed + 30 danh mục con nhập từ Rolly — rồi in ra
// câu nào rơi vào đâu. Dùng để ĐO trước khi sửa, không phải để chốt hành vi.
//
//   flutter test test/tooling/probe_subcategory_match.dart
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/db/seed/category_seed.dart';
import 'package:tonyfino/features/quick_add/domain/category_keyword_entries.dart';
import 'package:tonyfino/features/quick_add/domain/parser/parser.dart';
import 'package:tonyfino/core/text/ascii_fold.dart';

// Danh mục Rolly → khoá danh mục seed, y hệt bảng trong
// `audit_category_keywords.dart` (chính là ánh xạ importer Phase 9 dùng).
const _rollyToSeed = {
  'Thức ăn & Đồ uống': 'an_uong',
  'Thực phẩm': 'an_uong',
  'Giao thông': 'di_chuyen',
  'Du lịch': 'di_chuyen',
  'Tiền nhà': 'nha_cua',
  'Giặt đồ': 'nha_cua',
  'Gia đình': 'gia_dinh',
  'Mua sắm': 'mua_sam',
  'Điện tử': 'dien_tu',
  'Sức khỏe': 'suc_khoe',
  'Thể thao': 'suc_khoe',
  'Làm đẹp': 'lam_dep',
  'Giáo dục': 'giao_duc',
  'Giải trí': 'giai_tri',
  'Phát sinh': 'phat_sinh',
};

/// 30 danh mục con THẬT (dist/tonyfino_subcategory_bundle.json).
const _realSubcategories = <String, List<String>>{
  'Thức ăn & Đồ uống': [
    'Giao lưu',
    'Tiêu vặt',
    'Ăn chung oxytocin',
    'Ăn sáng thiết yếu',
    'Ăn trưa thiết yếu',
    'Ăn tối thiết yếu',
  ],
  'Gia đình': ['Mẹ', 'Oxytocin', 'Người thân'],
  'Giao thông': [
    'Bảo dưỡng',
    'Công an',
    'Gửi xe',
    'Phát sinh',
    'Sửa chữa',
    'Xăng',
  ],
  'Làm đẹp': ['Cắt tóc'],
  'Mua sắm': ['Ngẫu hứng', 'Phát sinh', 'Thiết yếu', 'Tiện nghi'],
  'Phát sinh': ['Dài hạn', 'Ngắn hạn'],
  'Sức khỏe': ['Ốm'],
  'Thực phẩm': ['Thiết yếu'],
  'Tiền nhà': ['Trọ'],
  'Điện tử': ['Khác', 'Tool công việc', 'card điện thoại'],
};

void main() {
  test('soi danh mục cha/con trên sổ thật', () {
    var nextId = 1;
    final categories = <Category>[];
    final idByKey = <String, int>{};

    Category make(String name, String kind, {int? parentId}) => Category(
      id: nextId++,
      name: name,
      kind: kind,
      categoryColorId: 0,
      iconCode: 'x',
      isArchived: false,
      createdAt: DateTime(2026),
      sortOrder: 0,
      walletId: 1,
      parentCategoryId: parentId,
    );

    for (final seed in defaultCategorySeeds) {
      final c = make(seed.name, seed.kind);
      idByKey[seed.key] = c.id;
      categories.add(c);
    }
    for (final entry in _realSubcategories.entries) {
      final parentId = idByKey[_rollyToSeed[entry.key]]!;
      for (final name in entry.value) {
        categories.add(make(name, 'expense', parentId: parentId));
      }
    }
    // Danh mục con mặc định (Tiêu vặt) đã có trong danh sách thật ở trên.

    final rows = <CategoryKeyword>[
      for (final seed in defaultCategorySeeds)
        for (final kw in seed.keywords)
          CategoryKeyword(
            id: nextId++,
            categoryId: idByKey[seed.key]!,
            keyword: kw.keyword,
            keywordAscii: foldToAscii(kw.keyword),
            weight: kw.weight,
            createdAt: DateTime(2026),
          ),
    ];

    for (final sub in defaultSubcategorySeeds) {
      final subId = categories
          .firstWhere(
            (c) =>
                c.name == sub.name &&
                c.parentCategoryId == idByKey[sub.parentKey],
          )
          .id;
      for (final kw in sub.keywords) {
        rows.add(
          CategoryKeyword(
            id: nextId++,
            categoryId: subId,
            keyword: kw.keyword,
            keywordAscii: foldToAscii(kw.keyword),
            weight: kw.weight,
            createdAt: DateTime(2026),
          ),
        );
      }
    }

    final entries = buildCategoryKeywordEntries(
      categories: categories,
      keywordRows: rows,
    );
    final byId = {for (final c in categories) c.id: c};
    String label(int? id) {
      if (id == null) return '— chưa phân loại';
      final c = byId[id]!;
      final p = c.parentCategoryId;
      return p == null ? c.name : '${byId[p]!.name} › ${c.name}';
    }

    const cases = [
      'bún chả ăn sáng 40k',
      'Ốc chung Oxytoxin 120k',
      'hủ tíu trưa 30k',
      'cơm tối 45k',
      'cà phê 35k',
      'ăn sáng 25k',
      'ăn tối với mẹ 200k',
      'quà cho mẹ 500k',
      'đổ xăng 60k',
      'gửi xe 5k',
      'rửa xe 40k',
      'cắt tóc 100k',
      'mua đồ thiết yếu 200k',
      'tiền trọ 3tr',
      'card điện thoại 50k',
      'mua thuốc 35k',
      'ốm nghỉ mua thuốc 120k',
      'ăn chung oxytocin 150k',
      'giao lưu bạn bè 300k',
      'bún chả 40k',
      'ăn trưa thiết yếu 35k',
      'tool công việc 200k',
      // — ca khó: cùng tên riêng ở hai nhánh, gõ sai chính tả, từ chung —
      'Oxytocin 500k',
      'oxytoxin 500k',
      'ăn chung oxytoxin 150k',
      'mua sắm ngẫu hứng 300k',
      'phát sinh ngắn hạn 1tr',
      'xăng xe 60k',
      'công an phạt 200k',
      'tiền điện 300k',
      'internet 200k',
      'trà sữa 45k',
      'katinnat 55k',
      'nhậu với người thân 400k',
      'ăn sáng thiết yếu 25k',
      'sửa chữa xe 500k',
      'bảo dưỡng xe 800k',
      'ốc 120k',
      'chung 50k',
      'thiết yếu 100k',
    ];

    final clock = Clock.fixed(DateTime(2026, 8, 25, 12));
    for (final text in cases) {
      final drafts = parseMessage(
        text,
        clock: clock,
        categoryKeywords: entries,
      );
      final d = drafts.first;
      final id = d.category == null
          ? null
          : int.tryParse(d.category!.categoryKey);
      // ignore: avoid_print
      print('${text.padRight(30)} → ${label(id)}');
    }
  });
}
