import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_subcategory_parser.dart';

void main() {
  group('parseSubcategoryBackfill', () {
    test(
      'dòng có subcategory_id khớp subcategory.json → StagedSubcategoryBackfill đúng sourceId/tên',
      () {
        final result = parseSubcategoryBackfill(
          [
            {'id': 30048, 'title': 'Gửi xe'},
            {'id': 29564, 'title': 'Xăng'},
          ],
          [
            {'id': 12189685, 'subcategory_id': 30048},
            {'id': 12189686, 'subcategory_id': 29564},
          ],
        );

        expect(result.issues, isEmpty);
        expect(result.entries, hasLength(2));
        expect(result.entries[0].sourceId, 'rolly:12189685');
        expect(result.entries[0].subcategoryTitle, 'Gửi xe');
        expect(result.entries[1].sourceId, 'rolly:12189686');
        expect(result.entries[1].subcategoryTitle, 'Xăng');
      },
    );

    test('subcategory_id null → bỏ qua, không có entry nào', () {
      final result = parseSubcategoryBackfill(
        [
          {'id': 1, 'title': 'A'},
        ],
        [
          {'id': 100, 'subcategory_id': null},
        ],
      );
      expect(result.entries, isEmpty);
      expect(result.issues, isEmpty);
    });

    test(
      'subcategory_id không tìm thấy trong subcategory.json → báo issue, không đoán tên',
      () {
        final result = parseSubcategoryBackfill(
          [
            {'id': 1, 'title': 'A'},
          ],
          [
            {'id': 100, 'subcategory_id': 999},
          ],
        );
        expect(result.entries, isEmpty);
        expect(result.issues.single, contains('999'));
      },
    );

    test(
      'hai cha khác nhau cùng dùng chung MỘT tên danh mục phụ (vd "Phát sinh") vẫn tách theo sourceId riêng',
      () {
        final result = parseSubcategoryBackfill(
          [
            {
              'id': 29567,
              'title': 'Phát sinh',
            }, // dưới Giao thông (dữ liệu thật)
            {
              'id': 29568,
              'title': 'Phát sinh',
            }, // dưới Mua sắm (dữ liệu thật, id khác)
          ],
          [
            {'id': 1, 'subcategory_id': 29567},
            {'id': 2, 'subcategory_id': 29568},
          ],
        );
        expect(result.entries, hasLength(2));
        expect(
          result.entries.every((e) => e.subcategoryTitle == 'Phát sinh'),
          isTrue,
        );
        expect(result.entries.map((e) => e.sourceId), ['rolly:1', 'rolly:2']);
      },
    );
  });
}
