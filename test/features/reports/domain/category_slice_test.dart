import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/reports/domain/category_slice.dart';

CategorySourceAmount _amount(String label, int amountMinor, {int? categoryId}) {
  return CategorySourceAmount(
    categoryId: categoryId,
    label: label,
    categoryColorId: 0,
    iconCode: 'restaurant',
    amountMinor: amountMinor,
  );
}

void main() {
  group('buildCategorySlices', () {
    test(
      '≤ 6 danh mục: không gộp "Khác", giữ nguyên thứ tự giảm dần |amount|',
      () {
        final slices = buildCategorySlices([
          _amount('B', -50000),
          _amount('A', -100000),
          _amount('C', -10000),
        ]);

        expect(slices.map((s) => s.label), ['A', 'B', 'C']);
        expect(slices.every((s) => !s.isOther), isTrue);
      },
    );

    test(
      '> 6 danh mục: giữ 6 lớn nhất, gộp phần còn lại thành MỘT lát "Khác"',
      () {
        final sources = [
          for (var i = 1; i <= 8; i++) _amount('Cat$i', -i * 1000),
        ]; // Cat8 lớn nhất … Cat1 nhỏ nhất

        final slices = buildCategorySlices(sources);

        expect(slices, hasLength(7)); // 6 + 1 "Khác"
        expect(slices.take(6).map((s) => s.label), [
          'Cat8',
          'Cat7',
          'Cat6',
          'Cat5',
          'Cat4',
          'Cat3',
        ]);
        final other = slices.last;
        expect(other.isOther, isTrue);
        expect(other.label, 'Khác');
        // Cat2 (-2000) + Cat1 (-1000) gộp vào "Khác".
        expect(other.amountMinor, -3000);
      },
    );

    test('bỏ qua danh mục 0 đồng — không tạo lát rỗng', () {
      final slices = buildCategorySlices([
        _amount('Zero', 0),
        _amount('Real', -5000),
      ]);
      expect(slices, hasLength(1));
      expect(slices.single.label, 'Real');
    });

    test(
      'danh mục chưa gán (categoryId null) là một lát bình thường, KHÔNG tự gộp vào "Khác"',
      () {
        final sources = [
          for (var i = 1; i <= 6; i++)
            _amount('Cat$i', -i * 1000, categoryId: i),
          _amount('Chưa phân loại', -500000, categoryId: null),
        ];
        final slices = buildCategorySlices(sources);

        // "Chưa phân loại" có |amount| lớn nhất nên đứng ĐẦU danh sách hiển
        // thị, không bị đẩy vào lát "Khác" chỉ vì categoryId null — hai khái
        // niệm khác nhau (bài học Phase 9 § CategoryBucketKey).
        expect(slices.first.label, 'Chưa phân loại');
        expect(slices.first.isOther, isFalse);
      },
    );
  });

  group('rollupToRootCategories (Phase 20)', () {
    const hierarchy = [
      CategoryHierarchyEntry(
        id: 1,
        parentCategoryId: null,
        name: 'Thức ăn & Đồ uống',
        categoryColorId: 0,
        iconCode: 'restaurant',
      ),
      CategoryHierarchyEntry(
        id: 11,
        parentCategoryId: 1,
        name: 'Ăn trưa thiết yếu',
        categoryColorId: 0,
        iconCode: 'restaurant',
      ),
      CategoryHierarchyEntry(
        id: 12,
        parentCategoryId: 1,
        name: 'Tiêu vặt',
        categoryColorId: 0,
        iconCode: 'restaurant',
      ),
      CategoryHierarchyEntry(
        id: 2,
        parentCategoryId: null,
        name: 'Giao thông',
        categoryColorId: 1,
        iconCode: 'directions_car',
      ),
    ];

    test(
      '🚨 giao dịch gán THẲNG vào cha + gán vào NHIỀU con khác nhau của cùng cha → tổng đúng, không thiếu không đôi',
      () {
        final sources = [
          _amount('Thức ăn & Đồ uống', -500000, categoryId: 1), // thẳng vào cha
          _amount('Ăn trưa thiết yếu', -480000, categoryId: 11),
          _amount('Tiêu vặt', -268000, categoryId: 12),
          _amount(
            'Giao thông',
            -100000,
            categoryId: 2,
          ), // cha khác, không con nào
        ];

        final rollup = rollupToRootCategories(sources, hierarchy);

        expect(rollup, hasLength(2));
        final food = rollup.firstWhere((r) => r.rootCategoryId == 1);
        // -500.000 + -480.000 + -268.000 = -1.248.000 — đúng CHÍNH XÁC, không
        // thiếu (không bỏ sót hàng nào) không đôi (không hàng nào bị cộng 2 lần).
        expect(food.amountMinor, -1248000);
        expect(food.label, 'Thức ăn & Đồ uống');
        expect(food.hasBreakdown, isTrue);
        expect(food.children, hasLength(3));
        expect(
          food.children.map((c) => c.amountMinor),
          [-500000, -480000, -268000], // sắp giảm dần |amount|
        );

        final transport = rollup.firstWhere((r) => r.rootCategoryId == 2);
        expect(transport.amountMinor, -100000);
        // Cha không có con nào dùng thật — chỉ 1 nguồn, không đáng bấm xem
        // breakdown (sẽ chỉ thấy lại đúng 1 hàng đã hiện sẵn).
        expect(transport.hasBreakdown, isFalse);
      },
    );

    test(
      'cha KHÔNG có giao dịch trực tiếp nào, chỉ con có → vẫn cộng đúng, tên/màu/icon mượn từ hierarchy',
      () {
        final sources = [
          _amount('Ăn trưa thiết yếu', -480000, categoryId: 11),
          _amount('Tiêu vặt', -268000, categoryId: 12),
        ];

        final rollup = rollupToRootCategories(sources, hierarchy);

        expect(rollup, hasLength(1));
        final food = rollup.single;
        expect(food.rootCategoryId, 1);
        expect(
          food.label,
          'Thức ăn & Đồ uống',
        ); // tên CHA, không phải tên con nào
        expect(food.amountMinor, -748000);
        expect(food.hasBreakdown, isTrue);
      },
    );

    test(
      '"Chưa phân loại" (categoryId null) giữ nguyên, KHÔNG rollup vào đâu, không có breakdown',
      () {
        final sources = [
          _amount('Ăn trưa thiết yếu', -480000, categoryId: 11),
          _amount('Chưa phân loại', -50000, categoryId: null),
        ];

        final rollup = rollupToRootCategories(sources, hierarchy);

        final uncategorized = rollup.firstWhere(
          (r) => r.rootCategoryId == null,
        );
        expect(uncategorized.amountMinor, -50000);
        expect(uncategorized.label, 'Chưa phân loại');
        expect(uncategorized.children, isEmpty);
        expect(uncategorized.hasBreakdown, isFalse);
      },
    );

    test(
      'danh mục CẤP GỐC không có con nào trong hierarchy vẫn tự làm root của chính nó',
      () {
        final sources = [_amount('Giao thông', -100000, categoryId: 2)];

        final rollup = rollupToRootCategories(sources, hierarchy);

        expect(rollup.single.rootCategoryId, 2);
        expect(rollup.single.amountMinor, -100000);
      },
    );
  });
}
