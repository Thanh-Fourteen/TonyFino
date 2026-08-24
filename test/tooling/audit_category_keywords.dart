// Công cụ soi lỗ hổng từ khoá danh mục (KHÔNG phải test hồi quy) — chạy bộ
// khớp thật lên chính 209 ghi chú Tony đã gõ trong Rolly, đối chiếu với
// danh mục Tony đã chọn cho từng ghi chú. In ra những câu bộ khớp đoán SAI
// hoặc KHÔNG đoán được.
//
//   flutter test test/tooling/audit_category_keywords.dart
//
// Nguồn dữ liệu là file rescue ngoài repo (dữ liệu thật của Tony, không
// commit) — thiếu file thì tự bỏ qua.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/seed/category_seed.dart';
import 'package:tonyfino/features/quick_add/domain/parser/category_matcher.dart';
import 'package:tonyfino/features/quick_add/domain/parser/normalizer.dart';
import 'package:tonyfino/features/quick_add/domain/parser/parse_result.dart';

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

void main() {
  test('soi từ khoá', () {
    final file = File(
      '/tmp/claude-1000/-home-tony-Tony-TonyFino/'
      '063fdd3b-b03b-4063-99fa-3ad51e0d7cc1/scratchpad/notes.tsv',
    );
    if (!file.existsSync()) {
      // ignore: avoid_print
      print('BỎ QUA — không có file dữ liệu thật.');
      return;
    }
    // 🚨 Phải nạp CẢ từ khoá của danh mục CON, quy về khoá của cha.
    //
    // Bản đầu chỉ nạp danh mục gốc, nên báo "cafe" là THIẾU trong khi nó đã
    // nằm sẵn ở danh mục con "Tiêu vặt" — suýt nữa thêm một bộ từ khoá
    // trùng lặp ở cấp gốc để chữa một lỗi không tồn tại.
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

    var miss = 0, wrong = 0, ok = 0;
    final report = <String>[];
    for (final line in const LineSplitter().convert(file.readAsStringSync())) {
      final parts = line.split('\t');
      if (parts.length < 3) continue;
      final note = parts[0];
      final expected = _rollyToSeed[parts[1]];
      if (expected == null) continue; // "Chưa được phân loại" — bỏ
      final count = int.parse(parts[2]);
      final match = matchCategory(note, keywords);
      if (match == null) {
        miss++;
        report.add('THIẾU  x$count  "$note"  → cần: $expected');
      } else if (match.categoryKey != expected) {
        wrong++;
        report.add(
          'SAI    x$count  "$note"  → đoán ${match.categoryKey}, cần $expected',
        );
      } else {
        ok++;
      }
    }
    report.sort();
    // ignore: avoid_print
    print('ĐÚNG=$ok  THIẾU=$miss  SAI=$wrong\n${report.join('\n')}');
  });
}
