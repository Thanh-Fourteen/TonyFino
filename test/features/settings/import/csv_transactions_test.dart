import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/settings/import/domain/csv_transactions.dart';

void main() {
  test('encode → decode round-trip khớp đúng từng dòng', () {
    final rows = [
      CsvExportRow(
        occurredAt: DateTime(2026, 5, 10),
        amountMinor: -35000,
        categoryName: 'Ăn uống',
        note: 'cà phê',
        sourceId: 'rolly:1001',
      ),
      CsvExportRow(
        occurredAt: DateTime(2026, 5, 1),
        amountMinor: 15000000,
        categoryName: null,
        note: null,
        sourceId: null,
      ),
    ];

    final csvText = encodeTransactionsCsv(rows);
    final parsed = parseTransactionsCsv(
      csvText,
      categoryIdByName: {'Ăn uống': 7},
    );

    expect(parsed.rows, hasLength(2));
    expect(parsed.rows[0].amountMinor, -35000);
    expect(parsed.rows[0].occurredAt, DateTime(2026, 5, 10));
    expect(parsed.rows[0].note, 'cà phê');
    expect(parsed.rows[0].categoryId, 7);
    expect(parsed.rows[0].sourceId, 'csv:rolly:1001');

    expect(parsed.rows[1].categoryId, isNull);
    expect(parsed.rows[1].note, isNull);
    // Không có source_id gốc → tự sinh từ nội dung, vẫn ổn định/idempotent.
    expect(parsed.rows[1].sourceId, startsWith('csv:'));
    expect(parsed.unmatchedCategoryNames, isEmpty);
  });

  test(
    'tên danh mục không khớp → uncategorized + liệt kê trong unmatchedCategoryNames',
    () {
      final csvText =
          'date,amount_minor,category,note,source_id\n'
          '2026-01-01,-1000,Danh mục lạ,,\n';
      final parsed = parseTransactionsCsv(csvText, categoryIdByName: const {});
      expect(parsed.rows.single.categoryId, isNull);
      expect(parsed.unmatchedCategoryNames, {'Danh mục lạ'});
    },
  );

  test(
    'cùng nội dung sinh CÙNG sourceId khi không có source_id gốc — idempotent theo nội dung',
    () {
      final csvText =
          'date,amount_minor,category,note,source_id\n'
          '2026-01-01,-1000,,ăn trưa,\n';
      final a = parseTransactionsCsv(csvText, categoryIdByName: const {});
      final b = parseTransactionsCsv(csvText, categoryIdByName: const {});
      expect(a.rows.single.sourceId, b.rows.single.sourceId);
    },
  );

  test('thiếu cột bắt buộc → FormatException rõ ràng', () {
    expect(
      () => parseTransactionsCsv(
        'category,note\nx,y\n',
        categoryIdByName: const {},
      ),
      throwsFormatException,
    );
  });
}
