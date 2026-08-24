import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_subcategory_parser.dart';

/// Xác minh bằng dữ liệu THẬT (`raw_rolly/subcategory.json` +
/// `raw_rolly/input.json`, gitignored) — phát hiện dẫn tới việc khôi phục
/// này: 90% giao dịch thật của Tony (324/362) có gắn danh mục phụ ở Rolly
/// mà Phase 9 đã bỏ qua. Test SKIP nếu file không tồn tại.
void main() {
  final subcategoryFile = File('raw_rolly/subcategory.json');
  final inputFile = File('raw_rolly/input.json');

  test(
    'parse dữ liệu thật → đúng 324 giao dịch có danh mục phụ, không dòng nào bị bỏ qua vì thiếu tên',
    () {
      if (!subcategoryFile.existsSync() || !inputFile.existsSync()) {
        markTestSkipped('raw_rolly/ không tồn tại trên máy này — bỏ qua.');
        return;
      }

      final subcategoryRows =
          jsonDecode(subcategoryFile.readAsStringSync()) as List<dynamic>;
      final inputRows =
          jsonDecode(inputFile.readAsStringSync()) as List<dynamic>;

      final result = parseSubcategoryBackfill(subcategoryRows, inputRows);

      expect(
        result.issues,
        isEmpty,
        reason: 'Có subcategory_id không khớp được tên: ${result.issues}',
      );
      expect(result.entries, hasLength(324));

      // Khớp đúng vài ca thật đã xác nhận tay (xem docs/decisions.md).
      final byTitle = <String, int>{};
      for (final e in result.entries) {
        byTitle[e.subcategoryTitle] = (byTitle[e.subcategoryTitle] ?? 0) + 1;
      }
      expect(byTitle.containsKey('Xăng'), isTrue);
      expect(byTitle.containsKey('Gửi xe'), isTrue);
      expect(byTitle.containsKey('Ăn sáng thiết yếu'), isTrue);
      expect(byTitle.containsKey('Ăn trưa thiết yếu'), isTrue);
      expect(byTitle.containsKey('Ăn tối thiết yếu'), isTrue);
    },
  );
}
