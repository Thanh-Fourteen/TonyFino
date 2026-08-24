/// Khôi phục danh mục PHỤ (subcategory) cho lịch sử giao dịch Rolly đã nhập
/// từ Phase 9 — Phase 9 chỉ đọc `category_id` của `input.json`, hoàn toàn bỏ
/// qua `subcategory_id` (324/362 giao dịch thật của Tony — 90% — có gắn
/// subcategory ở Rolly, vd "Giao thông → Xăng/Gửi xe", "Thức ăn & Đồ uống →
/// Ăn sáng/trưa/tối thiết yếu"). File này nhận `subcategory.json` (bảng tra
/// id→tên) + `input.json` (đã có sẵn từ Phase 2/9), sinh ra danh sách
/// "gán lại danh mục phụ" theo `sourceId` — KHỚP ĐÚNG `sourceId` Phase 9 đã
/// ghi (`'rolly:$id'`), không tính lại từ đầu.
class StagedSubcategoryBackfill {
  const StagedSubcategoryBackfill({
    required this.sourceId,
    required this.subcategoryTitle,
  });

  final String sourceId;
  final String subcategoryTitle;
}

/// [subcategoryRows] = `subcategory.json` (field `id`, `title`), [inputRows]
/// = `input.json` (field `id`, `subcategory_id`). Bỏ qua dòng không có
/// `subcategory_id`, hoặc có `subcategory_id` nhưng KHÔNG tìm thấy trong
/// `subcategory.json` (báo issue, không đoán tên).
class SubcategoryBackfillParseResult {
  const SubcategoryBackfillParseResult({
    required this.entries,
    required this.issues,
  });
  final List<StagedSubcategoryBackfill> entries;
  final List<String> issues;
}

SubcategoryBackfillParseResult parseSubcategoryBackfill(
  List<dynamic> subcategoryRows,
  List<dynamic> inputRows,
) {
  final titleById = <int, String>{};
  for (final entry in subcategoryRows) {
    final row = entry as Map<String, dynamic>;
    titleById[row['id'] as int] = row['title'] as String;
  }

  final issues = <String>[];
  final entries = <StagedSubcategoryBackfill>[];
  for (final entry in inputRows) {
    final row = entry as Map<String, dynamic>;
    final subcategoryId = row['subcategory_id'] as int?;
    if (subcategoryId == null) continue;

    final title = titleById[subcategoryId];
    final id = row['id'] as int;
    if (title == null) {
      issues.add(
        'Dòng id=$id có subcategory_id=$subcategoryId không tìm thấy trong '
        'subcategory.json — bỏ qua, không đoán tên.',
      );
      continue;
    }
    entries.add(
      StagedSubcategoryBackfill(sourceId: 'rolly:$id', subcategoryTitle: title),
    );
  }

  return SubcategoryBackfillParseResult(entries: entries, issues: issues);
}
