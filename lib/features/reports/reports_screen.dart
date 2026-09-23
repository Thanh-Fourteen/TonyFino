import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/router/app_bottom_nav.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../tags/tags_providers.dart';
import '../transactions/transactions_providers.dart';
import 'domain/category_slice.dart';
import 'reports_providers.dart';
import 'widgets/category_pie_card.dart';
import 'widgets/income_expense_bar_card.dart';
import 'widgets/monthly_trend_card.dart';
import 'widgets/report_filter_bar.dart';
import 'widgets/report_stat_tile.dart';
import 'widgets/spending_heatmap_card.dart';
import 'widgets/wrapped_banner_card.dart';

/// Bento grid: ô thống kê 2 cột + tròn theo danh mục + đường xu hướng + cột
/// thu-vs-chi + lịch heatmap, tất cả full-width trừ hàng thống kê đầu. Mỗi
/// card tự quản lý animation "vẽ vào" của riêng nó (xem từng widget con) —
/// màn hình này chỉ ghép bố cục + đưa dữ liệu đã lọc xuống, KHÔNG có
/// animation controller dùng chung (mỗi biểu đồ chạy MỘT LẦN lúc chính nó
/// được tạo, tự nhiên khớp "một lần khi vào tab" vì `StatefulShellRoute`
/// giữ nguyên state của nhánh Báo cáo khi chuyển tab qua lại — xem
/// `app_router.dart`).
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportFilterProvider);
    final breakdownAsync = ref.watch(categoryBreakdownProvider);
    final monthlyAsync = ref.watch(monthlyTrendProvider);
    final dailyAsync = ref.watch(dailySpendProvider);
    final summaryAsync = ref.watch(periodSummaryProvider);
    // `categoriesProvider` (KHÔNG phải `activeCategoriesProvider`) — lịch sử
    // báo cáo phải hiện đúng danh mục ĐÃ LƯU TRỮ, cùng lý do
    // `watchCategoryBreakdown`'s JOIN không lọc `isArchived` (xem
    // docs/decisions.md § Phase 20 câu hỏi 3).
    final categoriesAsync = ref.watch(categoriesProvider);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final categories = categoriesAsync.value ?? const <Category>[];
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    // Công tắc dùng chung với Trang chủ; sổ chưa có thẻ thì coi như tắt.
    final byTag = ref.watch(chartGroupByTagProvider) && tags.isNotEmpty;
    // Rollup CHỦ ĐÍCH ở tầng Dart (không phải SQL) — xem docs/decisions.md
    // § Phase 20 câu hỏi 3 để hiểu vì sao đây không phải rủi ro Cartesian
    // fan-out: nguồn đã ĐÚNG TỪNG SỐ từ SQL, hàm này chỉ cộng lại.
    final rolledSources = byTag
        ? tagModeRootSources(
            untagged:
                ref.watch(untaggedCategoryBreakdownProvider).value ??
                const <CategorySourceAmount>[],
            tagGroups:
                ref.watch(tagGroupBreakdownProvider).value ??
                const <TagGroupAmount>[],
            categories: categories,
            tags: tags,
          )
        : rolledRootSources(
            breakdownAsync.value ?? const <CategorySourceAmount>[],
            categories,
          );
    final slices = buildCategorySlices(rolledSources);
    final months = monthlyAsync.value ?? const [];
    final daily = dailyAsync.value ?? const [];
    final summary = summaryAsync.value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // KHÔNG lặp lại tiêu đề màn: `AppShell`'s AppBar đã hiện đúng
            // chữ "Báo cáo" ngay phía trên. Hai dòng chữ y hệt nhau chồng lên
            // nhau vừa thừa vừa ngốn ~120px chiều dọc của màn hình đầu tiên.
            SliverToBoxAdapter(child: SizedBox(height: context.space.sm)),
            SliverToBoxAdapter(child: ReportFilterBar()),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                context.space.screenHorizontal,
                context.space.lg,
                context.space.screenHorizontal,
                kBottomNavReservedHeight + bottomInset,
              ),
              sliver: SliverList.list(
                children: [
                  WrappedBannerCard(year: ref.watch(clockProvider).now().year),
                  SizedBox(height: context.space.betweenCards),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ReportStatTile(
                          label: 'Tổng chi',
                          icon: kIconTrendingUp,
                          amount: summary == null
                              ? null
                              : Money.vnd(summary.expenseMinor),
                        ),
                      ),
                      SizedBox(width: context.space.betweenCards),
                      Expanded(
                        child: ReportStatTile(
                          label: 'Tổng thu',
                          icon: kIconSavings,
                          amount: summary == null
                              ? null
                              : Money.vnd(summary.incomeMinor),
                        ),
                      ),
                    ],
                  ),
                  // 🚨 Biểu đồ KHÔNG ĐỦ DỮ LIỆU thì không vẽ ra.
                  //
                  // Một biểu đồ tròn rỗng, một đường xu hướng nối đúng MỘT
                  // điểm, một lịch không ô nào — không cái nào nói được điều
                  // gì, chỉ chiếm chỗ và làm người xem tưởng app hỏng. Ngưỡng
                  // đặt theo thứ mỗi biểu đồ CẦN để có nghĩa: tròn cần ≥1
                  // lát, đường/cột cần ≥2 mốc (một điểm không thành xu
                  // hướng), lịch cần ≥1 ngày có chi.
                  ...[
                    if (slices.isNotEmpty)
                      CategoryPieCard(
                        slices: slices,
                        allSources: rolledSources,
                        range: filter.range,
                        rangeLabel: filter.preset.label,
                        groupByTag: byTag,
                        onGroupByTagChanged: tags.isEmpty
                            ? null
                            : ref.read(chartGroupByTagProvider.notifier).set,
                      ),
                    if (months.length >= 2) MonthlyTrendCard(months: months),
                    if (months.length >= 2)
                      IncomeExpenseBarCard(months: months),
                    if (daily.any((d) => d.expenseMinor != 0))
                      SpendingHeatmapCard(
                        daily: daily,
                        rangeStart: filter.range.start,
                        rangeEnd: filter.range.end,
                      ),
                  ].expand((card) sync* {
                    yield SizedBox(height: context.space.betweenCards);
                    yield card;
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
