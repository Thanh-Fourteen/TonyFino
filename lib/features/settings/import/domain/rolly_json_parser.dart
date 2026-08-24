import 'staged_transaction.dart';

/// Parser THUẦN DART cho bảng `input` của Rolly (Supabase PostgREST) — không
/// chạm `dart:io`/Flutter, nhận thẳng `List<dynamic>` đã `jsonDecode` sẵn để
/// test được trực tiếp trên `raw_rolly/input.json` mà không cần platform
/// channel nào. Đúng schema đã ghi ở `docs/rolly-schema.md` (Phase 2) — xem
/// bảng ánh xạ field đầy đủ ở `docs/decisions.md` § Phase 9, viết TRƯỚC file
/// này.
class RollyParseResult {
  const RollyParseResult({
    required this.rows,
    required this.categoryUsages,
    required this.issues,
  });

  final List<StagedRollyTransaction> rows;

  /// Sắp theo `transactionCount` giảm dần — nguồn cho màn ánh xạ danh mục.
  final List<RollyCategoryUsage> categoryUsages;

  /// Bất thường KHÔNG chặn import (dòng lạ, số không nguyên, cặp transfer
  /// thiếu đôi) nhưng phải hiện cho Tony thấy — không bao giờ nuốt lặng lẽ.
  final List<String> issues;
}

class RollyParseException implements Exception {
  RollyParseException(this.message);
  final String message;

  @override
  String toString() => 'RollyParseException: $message';
}

RollyParseResult parseRollyInputRows(
  List<dynamic> rawRows, {
  Map<int, String> categoryTitleById = const {},
}) {
  final issues = <String>[];
  final staged = <StagedRollyTransaction>[];
  final byId = <int, Map<String, dynamic>>{};
  for (final entry in rawRows) {
    final row = entry as Map<String, dynamic>;
    byId[row['id'] as int] = row;
  }

  final processedSavingsIds = <int>{};
  final categoryCounts = <CategoryBucketKey, _CategoryAccumulator>{};

  void countCategory(CategoryBucketKey bucket, RollySourceType sourceType) {
    final title = switch (bucket) {
      CategoryBucketKey(isSavingsTransferBucket: true) =>
        'Chuyển khoản / Tiết kiệm',
      CategoryBucketKey(rollyCategoryId: null) => 'Không có danh mục Rolly',
      CategoryBucketKey(:final rollyCategoryId) =>
        categoryTitleById[rollyCategoryId] ?? 'Danh mục #$rollyCategoryId',
    };
    final acc = categoryCounts[bucket] ??= _CategoryAccumulator(title);
    acc.count++;
    if (sourceType == RollySourceType.income) acc.incomeCount++;
  }

  for (final row in byId.values) {
    final id = row['id'] as int;
    final type = row['type'] as String;

    if (type == 'Savings') {
      if (processedSavingsIds.contains(id)) continue;
      final linkId = row['linking_transfer_id'] as int?;
      final pair = linkId == null ? null : byId[linkId];
      processedSavingsIds.add(id);
      if (pair == null) {
        issues.add(
          'Dòng Savings id=$id không tìm thấy dòng ghép cặp qua '
          'linking_transfer_id=$linkId — bỏ qua, không import.',
        );
        continue;
      }
      processedSavingsIds.add(pair['id'] as int);

      final walletLeg = row['wallet_id'] != null
          ? row
          : (pair['wallet_id'] != null ? pair : null);
      if (walletLeg == null) {
        issues.add(
          'Cặp Savings id=$id/${pair['id']} không có dòng nào wallet_id '
          'khác null — không xác định được chiều outflow, bỏ qua cả cặp.',
        );
        continue;
      }

      final amount = _requireNonNegativeIntAmount(
        walletLeg['amount'],
        rowId: walletLeg['id'] as int,
        issues: issues,
      );
      if (amount == null) continue;

      const bucket = CategoryBucketKey.savingsTransfer();
      staged.add(
        StagedRollyTransaction(
          sourceId: 'rolly:${walletLeg['id']}',
          amountMinor: -amount,
          occurredAt: _parseVnLocalDate(walletLeg['date'] as String),
          note: _noteFrom(walletLeg['item'] as String?),
          sourceType: RollySourceType.savingsTransfer,
          categoryBucket: bucket,
        ),
      );
      countCategory(bucket, RollySourceType.savingsTransfer);
      continue;
    }

    final RollySourceType sourceType;
    switch (type) {
      case 'Expense':
        sourceType = RollySourceType.expense;
      case 'Income':
        sourceType = RollySourceType.income;
      default:
        issues.add(
          'Dòng id=$id có type lạ "$type" (không phải Expense/Income/'
          'Savings) — bỏ qua, không import.',
        );
        continue;
    }

    final amount = _requireNonNegativeIntAmount(
      row['amount'],
      rowId: id,
      issues: issues,
    );
    if (amount == null) continue;

    final categoryId = row['category_id'] as int?;
    final bucket = categoryId == null
        ? const CategoryBucketKey.uncategorized()
        : CategoryBucketKey.category(categoryId);
    staged.add(
      StagedRollyTransaction(
        sourceId: 'rolly:$id',
        amountMinor: sourceType == RollySourceType.expense ? -amount : amount,
        occurredAt: _parseVnLocalDate(row['date'] as String),
        note: _noteFrom(row['item'] as String?),
        sourceType: sourceType,
        categoryBucket: bucket,
      ),
    );
    countCategory(bucket, sourceType);
  }

  final usages =
      categoryCounts.entries
          .map(
            (e) => RollyCategoryUsage(
              bucket: e.key,
              title: e.value.title,
              transactionCount: e.value.count,
              // Đa số thắng: nhóm nào phần lớn là Income thì danh mục mới
              // tạo ra phải là 'income'. Nhóm chuyển khoản/tiết kiệm không
              // bao giờ tạo danh mục mới nên rơi về 'expense' là vô hại.
              kind: e.value.incomeCount * 2 > e.value.count
                  ? 'income'
                  : 'expense',
            ),
          )
          .toList()
        ..sort((a, b) => b.transactionCount.compareTo(a.transactionCount));

  return RollyParseResult(rows: staged, categoryUsages: usages, issues: issues);
}

/// `amount` của Rolly LUÔN ≥0 và là số nguyên (major unit VND, xem
/// `docs/rolly-schema.md`) — âm hoặc có phần thập phân là dữ liệu bất
/// thường, KHÔNG đoán làm tròn, báo issue và bỏ dòng thay vì import sai.
int? _requireNonNegativeIntAmount(
  Object? raw, {
  required int rowId,
  required List<String> issues,
}) {
  if (raw is! num) {
    issues.add('Dòng id=$rowId có amount không phải số ("$raw") — bỏ qua.');
    return null;
  }
  if (raw < 0) {
    issues.add(
      'Dòng id=$rowId có amount âm ($raw) — trái với bất biến Rolly '
      '"amount luôn ≥0", bỏ qua thay vì đoán dấu.',
    );
    return null;
  }
  final rounded = raw.round();
  if ((raw - rounded).abs() > 1e-9) {
    issues.add(
      'Dòng id=$rowId có amount không nguyên ($raw) — trái với bất biến '
      'Rolly "VND không có xu", bỏ qua thay vì làm tròn đoán.',
    );
    return null;
  }
  return rounded;
}

/// `date` của Rolly đã là ngày lịch giờ Việt Nam (theo `docs/rolly-schema.md`,
/// đối chiếu chéo với `wallet_view`) — parse thủ công 3 phần `YYYY-MM-DD`,
/// KHÔNG dùng `DateTime.parse` (tránh mọi suy diễn múi giờ ngầm của runtime)
/// và TUYỆT ĐỐI không cộng giờ nào từ `created_at`.
DateTime _parseVnLocalDate(String date) {
  final parts = date.split('-');
  if (parts.length != 3) {
    throw RollyParseException(
      'Định dạng date lạ, không phải YYYY-MM-DD: "$date"',
    );
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String? _noteFrom(String? item) {
  final trimmed = item?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

class _CategoryAccumulator {
  _CategoryAccumulator(this.title);
  final String title;
  int count = 0;
  int incomeCount = 0;
}
