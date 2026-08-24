import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/settings/import/domain/category_mapping.dart';
import 'package:tonyfino/features/settings/import/domain/staged_transaction.dart';

void main() {
  final tonyfinoCategories = [
    (id: 1, name: 'Ăn uống'),
    (id: 2, name: 'Di chuyển'),
    (id: 3, name: 'Gia đình'),
  ];

  group('suggestDefaultMapping', () {
    test('tên trùng TUYỆT ĐỐI (sau fold dấu) → gợi ý category đó', () {
      const usage = RollyCategoryUsage(
        bucket: CategoryBucketKey.category(999),
        title: 'Gia đình',
        transactionCount: 5,
        kind: 'expense',
      );
      final choice = suggestDefaultMapping(usage, tonyfinoCategories);
      expect(choice, isA<MappingToCategory>());
      expect((choice as MappingToCategory).categoryId, 3);
    });

    test(
      'tên gần giống ngữ nghĩa nhưng KHÔNG trùng tuyệt đối → không gợi ý',
      () {
        const usage = RollyCategoryUsage(
          bucket: CategoryBucketKey.category(999),
          title: 'Thức ăn & Đồ uống',
          transactionCount: 5,
          kind: 'expense',
        );
        final choice = suggestDefaultMapping(usage, tonyfinoCategories);
        expect(choice, isA<MappingUndecided>());
      },
    );

    test('bucket Savings gợi ý sẵn "Chưa phân loại", bucket uncategorized thì '
        'không gợi ý gì', () {
      const savings = RollyCategoryUsage(
        bucket: CategoryBucketKey.savingsTransfer(),
        title: 'Chuyển khoản / Tiết kiệm',
        transactionCount: 4,
        kind: 'expense',
      );
      // Tiền chuyển vào/ra tiết kiệm KHÔNG phải khoản chi nên không có danh
      // mục nào đúng cho nó. Trước đây nó nằm ở "Chưa chọn" và chặn nút
      // Tiếp tục mà không nói vì sao — Tony báo đúng câu "chưa biết nhập vô
      // đâu". Các dòng này gắn vào mục tiêu tiết kiệm qua `goalId` ở bước
      // sau, không qua danh mục.
      expect(
        suggestDefaultMapping(savings, tonyfinoCategories),
        isA<MappingUncategorized>(),
      );

      const uncategorized = RollyCategoryUsage(
        bucket: CategoryBucketKey.uncategorized(),
        title: 'Không có danh mục Rolly',
        transactionCount: 1,
        kind: 'expense',
      );
      expect(
        suggestDefaultMapping(uncategorized, tonyfinoCategories),
        isA<MappingUndecided>(),
      );
    });
  });

  group('allCategoriesDecided', () {
    const usages = [
      RollyCategoryUsage(
        bucket: CategoryBucketKey.category(1),
        title: 'A',
        transactionCount: 1,
        kind: 'expense',
      ),
      RollyCategoryUsage(
        bucket: CategoryBucketKey.category(2),
        title: 'B',
        transactionCount: 1,
        kind: 'expense',
      ),
    ];

    test('còn MappingUndecided → false', () {
      final mapping = <CategoryBucketKey, MappingChoice>{
        const CategoryBucketKey.category(1): const MappingToCategory(1),
        const CategoryBucketKey.category(2): const MappingUndecided(),
      };
      expect(allCategoriesDecided(usages, mapping), isFalse);
    });

    test(
      'mọi usage đều MappingToCategory hoặc MappingUncategorized → true',
      () {
        final mapping = <CategoryBucketKey, MappingChoice>{
          const CategoryBucketKey.category(1): const MappingToCategory(1),
          const CategoryBucketKey.category(2): const MappingUncategorized(),
        };
        expect(allCategoriesDecided(usages, mapping), isTrue);
      },
    );

    test('thiếu hẳn key trong map (chưa từng set) → false', () {
      final mapping = <CategoryBucketKey, MappingChoice>{
        const CategoryBucketKey.category(1): const MappingToCategory(1),
      };
      expect(allCategoriesDecided(usages, mapping), isFalse);
    });
  });

  group('resolveRollyRows', () {
    test('MappingToCategory → categoryId; MappingUncategorized → null', () {
      final rows = [
        StagedRollyTransaction(
          sourceId: 'rolly:1',
          amountMinor: -1000,
          occurredAt: DateTime(2026, 1, 1),
          note: 'x',
          sourceType: RollySourceType.expense,
          categoryBucket: const CategoryBucketKey.category(1),
        ),
        StagedRollyTransaction(
          sourceId: 'rolly:2',
          amountMinor: -2000,
          occurredAt: DateTime(2026, 1, 2),
          note: 'y',
          sourceType: RollySourceType.savingsTransfer,
          categoryBucket: const CategoryBucketKey.savingsTransfer(),
        ),
      ];
      final mapping = <CategoryBucketKey, MappingChoice>{
        const CategoryBucketKey.category(1): const MappingToCategory(7),
        const CategoryBucketKey.savingsTransfer(): const MappingUncategorized(),
      };
      final resolved = resolveRollyRows(rows, mapping);
      expect(resolved[0].categoryId, 7);
      expect(resolved[1].categoryId, isNull);
    });

    test(
      'gọi khi chưa quyết định hết → ném StateError, không âm thầm import sai',
      () {
        final rows = [
          StagedRollyTransaction(
            sourceId: 'rolly:1',
            amountMinor: -1000,
            occurredAt: DateTime(2026, 1, 1),
            note: 'x',
            sourceType: RollySourceType.expense,
            categoryBucket: const CategoryBucketKey.category(1),
          ),
        ];
        expect(() => resolveRollyRows(rows, const {}), throwsStateError);
      },
    );
  });
}
