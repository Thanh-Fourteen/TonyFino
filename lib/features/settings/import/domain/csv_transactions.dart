import 'package:csv/csv.dart';

import 'staged_transaction.dart';

/// Cột CSV: `date,amount_minor,category,note,source_id` — định dạng RIÊNG
/// của TonyFino (không phải cố parse một CSV Rolly nào đó — Rolly khoá tính
/// năng export CSV sau Premium nên Tony chưa từng có file đó, xem
/// `docs/rolly-schema.md`). Mục tiêu ở đây là một lối thoát/di động chung
/// (Rolly tính phí cả nhập lẫn xuất CSV — TonyFino cho miễn phí cả hai),
/// tự round-trip được với chính `encodeTransactionsCsv` bên dưới.
const csvHeader = ['date', 'amount_minor', 'category', 'note', 'source_id'];

class CsvExportRow {
  const CsvExportRow({
    required this.occurredAt,
    required this.amountMinor,
    required this.categoryName,
    required this.note,
    required this.sourceId,
  });

  final DateTime occurredAt;
  final int amountMinor;
  final String? categoryName;
  final String? note;
  final String? sourceId;
}

String encodeTransactionsCsv(List<CsvExportRow> rows) {
  final table = [
    csvHeader,
    for (final row in rows)
      [
        _formatDate(row.occurredAt),
        row.amountMinor,
        row.categoryName ?? '',
        row.note ?? '',
        row.sourceId ?? '',
      ],
  ];
  return csv.encode(table);
}

class CsvParseResult {
  const CsvParseResult({
    required this.rows,
    required this.unmatchedCategoryNames,
  });

  /// Đã có `categoryId` (từ [categoryIdByName]) hoặc `null` nếu tên không
  /// khớp danh mục TonyFino nào — KHÔNG có bước ánh xạ riêng như Rolly, đây
  /// là phạm vi có chủ đích nhỏ hơn cho lối thoát CSV chung (xem
  /// `docs/decisions.md` § Phase 9).
  final List<ResolvedImportRow> rows;

  /// Tên danh mục xuất hiện trong CSV nhưng không khớp danh mục TonyFino nào
  /// — hiện cho Tony biết trước khi commit, dòng liên quan vẫn import với
  /// `categoryId: null` (Chưa phân loại), không bị bỏ qua.
  final Set<String> unmatchedCategoryNames;
}

CsvParseResult parseTransactionsCsv(
  String csvString, {
  required Map<String, int> categoryIdByName,
}) {
  final table = csv.decode(csvString);
  if (table.isEmpty)
    return const CsvParseResult(rows: [], unmatchedCategoryNames: {});

  final header = table.first.map((c) => c.toString().trim()).toList();
  final dateIdx = header.indexOf('date');
  final amountIdx = header.indexOf('amount_minor');
  final categoryIdx = header.indexOf('category');
  final noteIdx = header.indexOf('note');
  final sourceIdIdx = header.indexOf('source_id');
  if (dateIdx == -1 || amountIdx == -1) {
    throw const FormatException(
      'CSV thiếu cột bắt buộc "date" hoặc "amount_minor".',
    );
  }

  final rows = <ResolvedImportRow>[];
  final unmatched = <String>{};

  for (final record in table.skip(1)) {
    if (record.length == 1 && record.first.toString().trim().isEmpty) continue;
    final dateStr = record[dateIdx].toString();
    final amountMinor = int.parse(record[amountIdx].toString());
    final categoryName = categoryIdx == -1
        ? ''
        : record[categoryIdx].toString().trim();
    final note = noteIdx == -1 ? '' : record[noteIdx].toString().trim();
    final explicitSourceId = sourceIdIdx == -1
        ? ''
        : record[sourceIdIdx].toString().trim();

    int? categoryId;
    if (categoryName.isNotEmpty) {
      categoryId = categoryIdByName[categoryName];
      if (categoryId == null) unmatched.add(categoryName);
    }

    final sourceId = explicitSourceId.isNotEmpty
        ? 'csv:$explicitSourceId'
        : 'csv:$dateStr|$amountMinor|$note';

    rows.add(
      ResolvedImportRow(
        sourceId: sourceId,
        amountMinor: amountMinor,
        occurredAt: _parseDate(dateStr),
        note: note.isEmpty ? null : note,
        categoryId: categoryId,
      ),
    );
  }

  return CsvParseResult(rows: rows, unmatchedCategoryNames: unmatched);
}

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _parseDate(String date) {
  final parts = date.split('-');
  if (parts.length != 3) {
    throw FormatException('Cột "date" phải dạng YYYY-MM-DD, gặp "$date".');
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
