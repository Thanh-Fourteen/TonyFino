import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart';
import '../../data/repositories/reports_repository.dart';
import 'domain/category_slice.dart';
import 'domain/daily_spend.dart';
import 'domain/monthly_total.dart';
import '../budgets/domain/budget_period.dart';
import '../settings/settings_controller.dart';
import 'domain/report_filter.dart';
import 'domain/report_range.dart';

/// Trạng thái bộ lọc — Notifier THUẦN UI STATE, không đọc DB trong `build()`
/// nên KHÔNG dính bẫy `ref.watch` phá huỷ notifier (Phase 9 § gotcha):
/// `build()` ở đây chỉ tính khoảng ngày mặc định từ `Clock`, không watch bất
/// cứ `StreamProvider` nào.
class ReportFilterController extends Notifier<ReportFilter> {
  @override
  ReportFilter build() {
    final now = ref.read(clockProvider).now();
    return ReportFilter(
      range: ReportRange.preset(ReportRangePreset.last6Months, now),
      preset: ReportRangePreset.last6Months,
    );
  }

  void setPreset(ReportRangePreset preset) {
    final now = ref.read(clockProvider).now();
    // "Kỳ ngân sách này" đi theo NGÀY NEO trong Cài đặt (vd ngày 5 → kỳ chạy
    // 5/8 → 4/9). Tính ở đây chứ không trong `ReportRange.preset` vì hàm đó
    // là hàm thuần chỉ biết `now`, không đọc được Cài đặt. Dùng lại chính
    // `BudgetPeriod` mà màn Ngân sách và Trang chủ đang dùng — ba màn cùng
    // nói "kỳ này" thì phải ra đúng một khoảng.
    if (preset == ReportRangePreset.budgetPeriod) {
      final period = BudgetPeriod.of(
        now,
        anchorDay: ref.read(appSettingsProvider).budgetAnchorDay,
      );
      state = state.copyWith(
        range: ReportRange(start: period.start, end: period.end),
        preset: preset,
      );
      return;
    }
    state = state.copyWith(
      range: ReportRange.preset(preset, now),
      preset: preset,
    );
  }

  /// Khoảng do Tony tự chọn hai đầu. `end` cộng thêm một ngày để thành nửa
  /// khoảng `[start, end)` — nếu không thì chọn "1/8 đến 31/8" sẽ LOẠI HẾT
  /// giao dịch ngày 31, một lỗi lệch-một-ngày rất khó thấy vì mọi con số
  /// vẫn "trông hợp lý".
  void setCustomRange(DateTime start, DateTime end) {
    state = state.copyWith(
      range: ReportRange(
        start: DateTime(start.year, start.month, start.day),
        end: DateTime(end.year, end.month, end.day + 1),
      ),
      preset: ReportRangePreset.custom,
    );
  }

  void setCategoryIds(Set<int>? categoryIds) {
    state = categoryIds == null || categoryIds.isEmpty
        ? state.copyWith(clearCategoryIds: true)
        : state.copyWith(categoryIds: categoryIds);
  }

  void setTagIds(Set<int>? tagIds) {
    state = tagIds == null || tagIds.isEmpty
        ? state.copyWith(clearTagIds: true)
        : state.copyWith(tagIds: tagIds);
  }
}

final reportFilterProvider =
    NotifierProvider<ReportFilterController, ReportFilter>(
      ReportFilterController.new,
    );

/// Mỗi provider dưới đây `ref.watch(reportFilterProvider)` bên trong một
/// `StreamProvider` (không phải trong `build()` của một `Notifier` giữ state
/// tích luỹ) — đây là chỗ DUY NHẤT `ref.watch` một provider khác là ĐÚNG:
/// `StreamProvider` không có gì để mất khi bị Riverpod huỷ-và-dựng-lại lúc
/// filter đổi, nó chỉ trả về `Stream` mới mỗi lần, đúng ý muốn (khác hẳn
/// `ImportController`/`QuickAddController`, nơi `build()` của một `Notifier`
/// giữ state đang chạy dở — xem `project_tonyfino_gotchas.md`).
final categoryBreakdownProvider = StreamProvider<List<CategorySourceAmount>>((
  ref,
) {
  final filter = ref.watch(reportFilterProvider);
  return ref
      .watch(reportsRepositoryProvider)
      .watchCategoryBreakdown(
        filter.range,
        categoryIds: filter.categoryIds,
        tagIds: filter.tagIds,
      );
});

final monthlyTrendProvider = StreamProvider<List<MonthlyTotal>>((ref) {
  final filter = ref.watch(reportFilterProvider);
  return ref.watch(reportsRepositoryProvider).watchMonthlyTrend(filter.range);
});

final dailySpendProvider = StreamProvider<List<DailySpend>>((ref) {
  final filter = ref.watch(reportFilterProvider);
  return ref
      .watch(reportsRepositoryProvider)
      .watchDailySpend(
        filter.range,
        categoryIds: filter.categoryIds,
        tagIds: filter.tagIds,
      );
});

final periodSummaryProvider = StreamProvider<PeriodSummary>((ref) {
  final filter = ref.watch(reportFilterProvider);
  return ref
      .watch(reportsRepositoryProvider)
      .watchPeriodSummary(
        filter.range,
        categoryIds: filter.categoryIds,
        tagIds: filter.tagIds,
      );
});

/// Nửa "không gắn thẻ" của chế độ gom-theo-thẻ — xem
/// `ReportsRepository.watchCategoryBreakdown(untaggedOnly:)`.
final untaggedCategoryBreakdownProvider =
    StreamProvider<List<CategorySourceAmount>>((ref) {
      final filter = ref.watch(reportFilterProvider);
      return ref
          .watch(reportsRepositoryProvider)
          .watchCategoryBreakdown(
            filter.range,
            categoryIds: filter.categoryIds,
            tagIds: filter.tagIds,
            untaggedOnly: true,
          );
    });

/// Nửa "có thẻ" của chế độ gom-theo-thẻ.
final tagGroupBreakdownProvider = StreamProvider<List<TagGroupAmount>>((ref) {
  final filter = ref.watch(reportFilterProvider);
  return ref
      .watch(reportsRepositoryProvider)
      .watchTagGroupBreakdown(
        filter.range,
        categoryIds: filter.categoryIds,
        tagIds: filter.tagIds,
      );
});

/// Công tắc "Gom theo thẻ" của biểu đồ tròn — DÙNG CHUNG cho Trang chủ và
/// Báo cáo: cùng một biểu đồ ở hai nơi mà bật ở chỗ này, chỗ kia vẫn tắt thì
/// Tony sẽ tưởng hai biểu đồ đang nói hai chuyện khác nhau.
class ChartGroupByTagController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final chartGroupByTagProvider =
    NotifierProvider<ChartGroupByTagController, bool>(
      ChartGroupByTagController.new,
    );

List<CategoryHierarchyEntry> categoryHierarchyOf(List<Category> categories) => [
  for (final c in categories)
    CategoryHierarchyEntry(
      id: c.id,
      parentCategoryId: c.parentCategoryId,
      name: c.name,
      categoryColorId: c.categoryColorId,
      iconCode: c.iconCode,
    ),
];

/// Breakdown phẳng (theo danh mục thật trên giao dịch) → một hàng cho mỗi
/// danh mục CẤP GỐC — đúng thứ biểu đồ tròn vẽ. Dùng chung cho Trang chủ và
/// Báo cáo để hai biểu đồ không bao giờ gộp lát theo hai cách khác nhau.
List<CategorySourceAmount> rolledRootSources(
  List<CategorySourceAmount> sources,
  List<Category> categories,
) => [
  for (final r in rollupToRootCategories(
    sources,
    categoryHierarchyOf(categories),
  ))
    CategorySourceAmount(
      categoryId: r.rootCategoryId,
      label: r.label,
      categoryColorId: r.categoryColorId,
      iconCode: r.iconCode,
      amountMinor: r.amountMinor,
    ),
];

/// Nguồn biểu đồ tròn ở chế độ gom-theo-thẻ, từ hai nửa đã tải.
List<CategorySourceAmount> tagModeRootSources({
  required List<CategorySourceAmount> untagged,
  required List<TagGroupAmount> tagGroups,
  required List<Category> categories,
  required List<Tag> tags,
}) => buildTagModeSources(
  untaggedRootSources: rolledRootSources(untagged, categories),
  tagGroups: tagGroups,
  tagsById: {
    for (final t in tags)
      t.id: TagInfo(id: t.id, name: t.name, colorId: t.categoryColorId),
  },
);
