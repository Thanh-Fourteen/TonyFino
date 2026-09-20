import '../../../ui/amount_visibility.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/durations.dart';
import '../../../theme/tokens/curves.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../../../ui/app_card.dart';
import '../../../ui/empty_state.dart';
import '../../categories/category_detail_screen.dart';
import '../domain/category_slice.dart';
import '../domain/report_range.dart';
import 'report_category_color.dart';

/// Handler chạm cho MỘT hàng chú thích (Phase 20) — dùng chung giữa
/// [CategoryPieCard]'s legend chính và [_FullBreakdownSheet], tránh viết
/// trùng logic ở hai nơi. Lát "Khác" (isOther) mở LẠI danh sách đầy đủ cấp
/// gốc — nó không phải một danh mục thật nên không có "con" riêng. Lát
/// "Chưa phân loại" (categoryId null, isOther false) không bấm được. Một
/// danh mục gốc thật chỉ bấm được khi THẬT SỰ có nhiều hơn một nguồn đóng
/// góp ([CategoryRootBreakdown.hasBreakdown]) — nếu chưa dùng danh mục con
/// nào thì bấm vào cũng chỉ thấy lại đúng một hàng đã hiện sẵn.
VoidCallback? categorySliceTapHandler({
  required CategorySlice slice,
  required VoidCallback openFullBreakdown,
  required void Function(int rootCategoryId) openCategoryDetail,
}) {
  if (slice.isOther) return openFullBreakdown;
  // Nhóm thẻ không phải một danh mục — không có màn chi tiết nào để mở.
  if (slice.isTagGroup) return null;
  final id = slice.categoryId;
  // `null` = "Chưa phân loại" — không có danh mục nào để mở ra.
  if (id == null) return null;
  return () => openCategoryDetail(id);
}

/// Biểu đồ tròn theo danh mục — giới hạn 6 lát + "Khác" ([buildCategorySlices],
/// đã gộp SQL ở tầng gọi). Ba quyết định thiết kế bắt buộc của Phase 10:
/// 1. Mỗi lát LUÔN kèm icon qua `badgeWidget` (không chỉ chấm màu).
/// 2. Animate BÁN KÍNH (0→56), KHÔNG phải góc quét — quét trông như spinner
///    loading. `PieChart(duration: Duration.zero)` tắt hẳn animation nội bộ
///    của fl_chart (nó tự tween MỌI thay đổi `PieChartData`, kể cả animate
///    lại từ đầu mỗi khi filter đổi radius nếu không tắt) — bán kính hoàn
///    toàn do `AnimationController` của widget này điều khiển, chạy MỘT LẦN
///    lúc `initState`.
/// 3. Chạm vào biểu đồ mở sheet xem đầy đủ (không giới hạn 6 lát).
class CategoryPieCard extends StatefulWidget {
  const CategoryPieCard({
    super.key,
    required this.slices,
    required this.allSources,
    required this.range,
    required this.rangeLabel,
    this.groupByTag = false,
    this.onGroupByTagChanged,
    this.onOpenCategory,
  });

  /// Thay cho hành vi mặc định "bấm một danh mục → mở màn Chi tiết danh
  /// mục". Màn Chi tiết hũ cần: một hũ có thể chỉ chứa VÀI danh mục con của
  /// "Ăn uống", nên mở nguyên màn "Ăn uống" (mọi con) sẽ ra con số khác hẳn.
  final void Function(BuildContext context, int rootCategoryId)? onOpenCategory;

  /// Đang ở chế độ "gom theo thẻ" — [slices]/[allSources] khi đó đã là
  /// nhóm thẻ + danh mục của phần không gắn thẻ (xem `buildTagModeSources`).
  final bool groupByTag;

  /// `null` = không hiện công tắc (sổ chưa có thẻ nào — bật lên cũng không
  /// đổi được gì).
  final ValueChanged<bool>? onGroupByTagChanged;

  /// ≤ 7 lát (6 danh mục CẤP GỐC lớn nhất + "Khác" nếu có), đã sắp giảm dần
  /// — đã rollup con vào cha (Phase 20), xem `reports_screen.dart`.
  final List<CategorySlice> slices;

  /// Toàn bộ danh mục CẤP GỐC đã rollup, CHƯA gộp "Khác" — nguồn cho sheet
  /// "xem đầy đủ".
  final List<CategorySourceAmount> allSources;

  /// Kỳ đang lọc — truyền thẳng sang màn "Chi tiết danh mục" để hai màn nói
  /// về cùng một tập giao dịch (xem [CategoryDetailScreen.range]).
  final ReportRange range;
  final String rangeLabel;

  /// Một hàng cho MỖI danh mục cấp gốc — nguồn để bấm vào một hàng chú
  /// thích và mở sheet xem breakdown danh mục con của riêng nó (Phase 20).

  @override
  State<CategoryPieCard> createState() => _CategoryPieCardState();
}

class _CategoryPieCardState extends State<CategoryPieCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _radius;

  static const _maxRadius = 56.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: appDurations.chartDraw,
    );
    _radius = CurvedAnimation(parent: _controller, curve: appCurves.chartDraw);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullBreakdown(BuildContext context) {
    showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) => _FullBreakdownSheet(
        sources: widget.allSources,
        range: widget.range,
        rangeLabel: widget.rangeLabel,
        onOpenCategory: widget.onOpenCategory,
      ),
    );
  }

  VoidCallback? _tapHandlerFor(BuildContext context, CategorySlice slice) {
    return categorySliceTapHandler(
      slice: slice,
      openFullBreakdown: () => _openFullBreakdown(context),
      openCategoryDetail: (id) {
        final custom = widget.onOpenCategory;
        if (custom != null) return custom(context, id);
        openCategoryDetailScreen(
          context,
          id,
          range: widget.range,
          rangeLabel: widget.rangeLabel,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAbs = widget.slices.fold<int>(
      0,
      (sum, s) => sum + s.amountMinor.abs(),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.groupByTag ? 'Theo thẻ & danh mục' : 'Theo danh mục',
                  style: context.text.titleMedium,
                ),
              ),
              if (widget.onGroupByTagChanged != null)
                FilterChip(
                  label: const Text('Gom theo thẻ'),
                  avatar: const Icon(kIconSell, size: 16),
                  showCheckmark: false,
                  selected: widget.groupByTag,
                  onSelected: widget.onGroupByTagChanged,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (widget.groupByTag) ...[
            SizedBox(height: context.space.xxs),
            Text(
              'Khoản có thẻ gom theo thẻ; khoản không thẻ vẫn theo danh mục.',
              style: context.text.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: context.space.md),
          if (widget.slices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(
                icon: kIconCategory,
                title: 'Chưa có chi tiêu',
                message: 'Không có giao dịch chi nào trong khoảng đang lọc.',
              ),
            )
          else ...[
            GestureDetector(
              onTap: () => _openFullBreakdown(context),
              child: AnimatedBuilder(
                animation: _radius,
                builder: (context, _) {
                  final radius = _maxRadius * _radius.value;
                  return SizedBox(
                    height: 200,
                    child: PieChart(
                      duration: Duration.zero,
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        pieTouchData: PieTouchData(enabled: false),
                        sections: [
                          for (final slice in widget.slices)
                            PieChartSectionData(
                              value: slice.amountMinor.abs().toDouble(),
                              color: reportCategoryColor(
                                context,
                                slice.categoryColorId,
                              ),
                              radius: radius,
                              showTitle: false,
                              badgeWidget: _radius.value < 0.7
                                  ? null
                                  : _RingBadge(
                                      iconCode: slice.iconCode,
                                      isTag: slice.isTagGroup,
                                    ),
                              badgePositionPercentageOffset: 0.62,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: context.space.md),
            for (final slice in widget.slices)
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.space.xxs),
                child: _LegendRow(
                  slice: slice,
                  totalAbsMinor: totalAbs,
                  onTap: _tapHandlerFor(context, slice),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.slice,
    required this.totalAbsMinor,
    this.onTap,
  });

  final CategorySlice slice;
  final int totalAbsMinor;

  /// `null` = hàng không bấm được (đúng hành vi cũ trước Phase 20) — chỉ
  /// khác `null` khi có gì đó để mở ra (xem `_tapHandlerFor`).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pct = totalAbsMinor == 0
        ? 0
        : (slice.amountMinor.abs() * 100 / totalAbsMinor).round();
    final row = Row(
      children: [
        // Chấm chú giải dùng ĐÚNG icon 3D như vành biểu đồ và như danh sách
        // giao dịch — cùng một danh mục phải nhận ra được ngay ở cả ba chỗ.
        // Nền vẫn là màu đặc của lát cắt để chú giải khớp màu với biểu đồ.
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: reportCategoryColor(context, slice.categoryColorId),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: slice.isTagGroup
              ? const Icon(kIconSell, size: 14, color: Colors.white, fill: 1)
              : Image.asset(
                  resolveCategoryIcon3d(slice.iconCode),
                  width: 16,
                  height: 16,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, _, _) => Icon(
                    resolveCategoryIcon(slice.iconCode),
                    size: 13,
                    color: Colors.white,
                    fill: 1,
                  ),
                ),
        ),
        SizedBox(width: context.space.sm),
        Expanded(
          child: Text(
            slice.label,
            style: context.text.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$pct%',
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SizedBox(width: context.space.sm),
        Text(
          AmountVisibility.mask(context, Money.vnd(slice.amountMinor).format()),
          style: context.text.labelMedium,
        ),
        if (onTap != null) ...[
          SizedBox(width: context.space.xxs),
          Icon(
            kIconChevronRight,
            size: 16,
            color: context.colors.onSurfaceVariant,
          ),
        ],
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: row,
    );
  }
}

class _FullBreakdownSheet extends StatelessWidget {
  const _FullBreakdownSheet({
    required this.sources,
    required this.range,
    required this.rangeLabel,
    this.onOpenCategory,
  });

  final List<CategorySourceAmount> sources;
  final ReportRange range;
  final String rangeLabel;
  final void Function(BuildContext context, int rootCategoryId)? onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final sorted = sources.where((s) => s.amountMinor != 0).toList()
      ..sort((a, b) => b.amountMinor.abs().compareTo(a.amountMinor.abs()));
    final totalAbs = sorted.fold<int>(0, (sum, s) => sum + s.amountMinor.abs());

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.space.lg,
          context.space.md,
          context.space.lg,
          context.space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.only(bottom: context.space.md),
                decoration: BoxDecoration(
                  color: context.colors.hairline,
                  borderRadius: BorderRadius.circular(context.radii.full),
                ),
              ),
            ),
            Text(
              sorted.any((s) => s.tagIds != null)
                  ? 'Toàn bộ thẻ & danh mục'
                  : 'Toàn bộ danh mục',
              style: context.text.titleLarge,
            ),
            SizedBox(height: context.space.md),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sorted.length,
                separatorBuilder: (_, _) => SizedBox(height: context.space.sm),
                itemBuilder: (context, index) {
                  final s = sorted[index];
                  final slice = CategorySlice(
                    categoryId: s.categoryId,
                    label: s.label,
                    categoryColorId: s.categoryColorId,
                    iconCode: s.iconCode,
                    amountMinor: s.amountMinor,
                    isOther: false,
                    tagIds: s.tagIds,
                  );
                  return _LegendRow(
                    slice: slice,
                    totalAbsMinor: totalAbs,
                    // Không có "Khác" nào ở đây (danh sách ĐÃ đầy đủ) —
                    // `openFullBreakdown` không bao giờ thật sự được gọi,
                    // chỉ cần khớp chữ ký hàm dùng chung.
                    onTap: categorySliceTapHandler(
                      slice: slice,
                      openFullBreakdown: () {},
                      openCategoryDetail: (id) {
                        // Đóng sheet "xem đầy đủ" trước rồi mới đẩy màn chi
                        // tiết — nếu không, quay lại từ màn chi tiết sẽ rơi
                        // vào một sheet vẫn đang mở, người dùng phải vuốt
                        // thêm một nhịp nữa mới về được Báo cáo.
                        Navigator.of(context).pop();
                        final custom = onOpenCategory;
                        if (custom != null) return custom(context, id);
                        openCategoryDetailScreen(
                          context,
                          id,
                          range: range,
                          rangeLabel: rangeLabel,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon danh mục nổi TRÊN vành biểu đồ tròn — đúng nét đặc trưng của Rolly
/// (`rolly.mp4`): một đĩa trắng nhỏ có bóng nhẹ ôm lấy icon 3D, đặt lên mép
/// lát cắt. Đĩa trắng là thứ bắt buộc: icon 3D nhiều màu đặt thẳng lên lát
/// cắt cũng nhiều màu thì cả hai cùng chìm.
class _RingBadge extends StatelessWidget {
  const _RingBadge({required this.iconCode, this.isTag = false});

  final String iconCode;

  /// Lát nhóm THẺ — vẽ glyph thẻ thay vì icon danh mục 3D (thẻ không có
  /// icon riêng, và mượn icon danh mục thì trông như một danh mục thật).
  final bool isTag;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: context.colors.card,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: isTag
          ? Icon(kIconSell, size: 15, color: context.colors.brandText, fill: 1)
          : Image.asset(
              resolveCategoryIcon3d(iconCode),
              width: 17,
              height: 17,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, _, _) => Icon(
                resolveCategoryIcon(iconCode),
                size: 14,
                color: context.colors.onSurfaceVariant,
                fill: 1,
              ),
            ),
    );
  }
}
