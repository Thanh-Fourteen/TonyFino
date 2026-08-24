import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_json_parser.dart';
import 'package:tonyfino/features/settings/import/domain/staged_transaction.dart';

void main() {
  late List<dynamic> sampleRows;
  late Map<int, String> categoryTitles;

  setUpAll(() {
    sampleRows =
        jsonDecode(File('test/fixtures/rolly/sample.json').readAsStringSync())
            as List<dynamic>;
    final categoryRows =
        jsonDecode(
              File(
                'test/fixtures/rolly/category_view.sample.json',
              ).readAsStringSync(),
            )
            as List<dynamic>;
    categoryTitles = {
      for (final row in categoryRows.cast<Map<String, dynamic>>())
        row['id'] as int: row['title'] as String,
    };
  });

  test('parse sample.json → đúng 5 dòng sau khử trùng lặp transfer (6 raw)', () {
    final result = parseRollyInputRows(
      sampleRows,
      categoryTitleById: categoryTitles,
    );

    expect(result.issues, isEmpty);
    expect(result.rows, hasLength(5));

    final byId = {for (final r in result.rows) r.sourceId: r};

    expect(byId['rolly:1001']!.amountMinor, -35000);
    expect(byId['rolly:1001']!.sourceType, RollySourceType.expense);
    expect(byId['rolly:1001']!.occurredAt, DateTime(2026, 5, 10));
    expect(byId['rolly:1001']!.note, 'cà phê');

    expect(byId['rolly:1002']!.amountMinor, -120000);
    // "date" (2026-05-11) phải thắng, KHÔNG dùng "created_at" (2026-05-10
    // giờ UTC) — đây chính xác là cạm bẫy múi giờ TODOS.md cảnh báo.
    expect(byId['rolly:1002']!.occurredAt, DateTime(2026, 5, 11));

    expect(byId['rolly:1003']!.amountMinor, 15000000);
    expect(byId['rolly:1003']!.sourceType, RollySourceType.income);

    // Cặp Savings 1004/1005: CHỈ 1004 (wallet_id != null) sống sót, âm (outflow).
    expect(byId.containsKey('rolly:1005'), isFalse);
    expect(byId['rolly:1004']!.amountMinor, -5000000);
    expect(byId['rolly:1004']!.sourceType, RollySourceType.savingsTransfer);
    expect(byId['rolly:1004']!.categoryBucket.isSavingsTransferBucket, isTrue);

    // category_id null trên MỘT dòng Expense thật (không phải Savings) —
    // phải rơi vào bucket "uncategorized", KHÔNG lẫn vào bucket Savings.
    expect(byId['rolly:1006']!.categoryBucket.isSavingsTransferBucket, isFalse);
    expect(byId['rolly:1006']!.categoryBucket.rollyCategoryId, isNull);
  });

  test(
    'categoryUsages tách RIÊNG bucket Savings và bucket "không có danh mục"',
    () {
      final result = parseRollyInputRows(
        sampleRows,
        categoryTitleById: categoryTitles,
      );

      final savingsUsage = result.categoryUsages.firstWhere(
        (u) => u.bucket.isSavingsTransferBucket,
      );
      expect(savingsUsage.transactionCount, 1);
      expect(savingsUsage.title, contains('Tiết kiệm'));

      final uncategorizedUsage = result.categoryUsages.firstWhere(
        (u) =>
            !u.bucket.isSavingsTransferBucket &&
            u.bucket.rollyCategoryId == null,
      );
      expect(uncategorizedUsage.transactionCount, 1);

      // Hai bucket này PHẢI là hai usage riêng biệt, không gộp count.
      expect(savingsUsage.bucket, isNot(equals(uncategorizedUsage.bucket)));
    },
  );

  test('categoryUsages dùng tên thật từ category_view khi có', () {
    final result = parseRollyInputRows(
      sampleRows,
      categoryTitleById: categoryTitles,
    );
    final usage501 = result.categoryUsages.firstWhere(
      (u) => u.bucket.rollyCategoryId == 501,
    );
    expect(usage501.title, 'Ăn uống');
  });

  test('không có category_view thì hiện "Danh mục #id" thay vì crash', () {
    final result = parseRollyInputRows(sampleRows);
    final usage501 = result.categoryUsages.firstWhere(
      (u) => u.bucket.rollyCategoryId == 501,
    );
    expect(usage501.title, 'Danh mục #501');
  });

  test('dòng amount âm bị báo issue và bỏ qua, không import sai dấu', () {
    final rows = [
      {
        'id': 1,
        'type': 'Expense',
        'amount': -1000.0,
        'date': '2026-01-01',
        'item': 'lỗi',
        'category_id': 1,
      },
    ];
    final result = parseRollyInputRows(rows);
    expect(result.rows, isEmpty);
    expect(result.issues, hasLength(1));
    expect(result.issues.first, contains('âm'));
  });

  test(
    'dòng amount không nguyên bị báo issue và bỏ qua, không làm tròn đoán',
    () {
      final rows = [
        {
          'id': 1,
          'type': 'Expense',
          'amount': 1000.5,
          'date': '2026-01-01',
          'item': 'lỗi',
          'category_id': 1,
        },
      ];
      final result = parseRollyInputRows(rows);
      expect(result.rows, isEmpty);
      expect(result.issues, hasLength(1));
      expect(result.issues.first, contains('không nguyên'));
    },
  );

  test('dòng type lạ bị báo issue và bỏ qua', () {
    final rows = [
      {
        'id': 1,
        'type': 'Refund',
        'amount': 1000.0,
        'date': '2026-01-01',
        'item': 'lạ',
        'category_id': 1,
      },
    ];
    final result = parseRollyInputRows(rows);
    expect(result.rows, isEmpty);
    expect(result.issues, hasLength(1));
    expect(result.issues.first, contains('type lạ'));
  });

  test('Savings thiếu dòng ghép cặp bị báo issue và bỏ qua', () {
    final rows = [
      {
        'id': 1,
        'type': 'Savings',
        'amount': 1000.0,
        'date': '2026-01-01',
        'item': 'tiết kiệm',
        'linking_transfer_id': 999,
        'wallet_id': 1,
      },
    ];
    final result = parseRollyInputRows(rows);
    expect(result.rows, isEmpty);
    expect(result.issues, hasLength(1));
    expect(result.issues.first, contains('không tìm thấy dòng ghép cặp'));
  });
}
