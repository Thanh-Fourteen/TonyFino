import 'report_range.dart';

/// Bộ lọc chung cho mọi widget ở màn Báo cáo — một nguồn sự thật duy nhất,
/// đổi filter là mọi biểu đồ tự cập nhật qua provider (không animate lại,
/// animation vào-tab chỉ chạy một lần — xem `reports_screen.dart`).
class ReportFilter {
  const ReportFilter({
    required this.range,
    required this.preset,
    this.categoryIds,
    this.tagIds,
  });

  final ReportRange range;
  final ReportRangePreset preset;

  /// `null` = tất cả danh mục (không lọc). Rỗng không phải trạng thái hợp lệ
  /// ở UI — sheet chọn danh mục luôn map "bỏ chọn hết" về lại `null`.
  final Set<int>? categoryIds;

  /// Cùng quy ước `null`/rỗng như [categoryIds] (Phase 17) — độc lập với
  /// danh mục, một giao dịch khớp filter nếu gắn ÍT NHẤT MỘT thẻ trong tập
  /// này (xem `ReportsRepository._taggedWith`).
  final Set<int>? tagIds;

  ReportFilter copyWith({
    ReportRange? range,
    ReportRangePreset? preset,
    Set<int>? categoryIds,
    bool clearCategoryIds = false,
    Set<int>? tagIds,
    bool clearTagIds = false,
  }) {
    return ReportFilter(
      range: range ?? this.range,
      preset: preset ?? this.preset,
      categoryIds: clearCategoryIds ? null : (categoryIds ?? this.categoryIds),
      tagIds: clearTagIds ? null : (tagIds ?? this.tagIds),
    );
  }
}
