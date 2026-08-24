import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/router/app_bottom_nav.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart' show Category;
import '../../data/repositories/transaction_repository.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/count_up_text.dart';
import '../../ui/day_header.dart';
import '../../ui/empty_state.dart';
import '../../ui/app_chip.dart';
import '../../ui/hero_gradient_background.dart';
import '../../ui/mascot/mascot_mood.dart';
import '../../ui/money_text.dart';
import '../../ui/transaction_row.dart';
import '../home/home_period_provider.dart';
import '../home/widgets/period_chip.dart';
import '../tags/tags_providers.dart';
import 'day_label.dart';
import 'transaction_form_sheet.dart';
import 'transaction_templates_screen.dart';
import 'transactions_providers.dart';

/// 🔥 Danh sách hàng tràn viền dưới header ngày dính + hero card (chi tiêu
/// từ đầu tháng, KHÔNG PHẢI số dư — số dư của app nhập tay là hư cấu). FAB
/// `Thêm` thu về icon-only khi cuộn xuống. `extendBody: true` + đệm đáy thủ
/// công trên chính sliver này — không `SafeArea` bao trùm (edge-to-edge).
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _scrollController = ScrollController();
  bool _fabExtended = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final direction = _scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.reverse && _fabExtended) {
      setState(() => _fabExtended = false);
    } else if (direction == ScrollDirection.forward && !_fabExtended) {
      setState(() => _fabExtended = true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openAddSheet() {
    showTransactionFormSheet(context: context);
  }

  /// Nhấn giữ FAB → sheet "Thêm nhanh" (Phase 14 "Áp dụng mẫu", Phase 18
  /// thêm "Quét hoá đơn") — tái dùng đúng nút Thêm hiện có thay vì thêm một
  /// nút mới trên màn (đã không còn `AppBar` để đặt icon action từ Phase 6),
  /// khớp khuôn "nhấn giữ để có hành động phụ" đã dùng ở hàng giao dịch
  /// (Phase 8).
  void _openTemplatePicker() {
    showApplyTemplateSheet(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final summaryAsync = ref.watch(monthSummaryProvider);
    final now = ref.watch(clockProvider).now();

    return Scaffold(
      extendBody: true,
      // Đệm đáy = chiều cao thanh nav nổi + gesture inset — nếu không FAB
      // của Scaffold LỒNG BÊN TRONG này nằm ngay dưới `AppShell`'s bottom
      // nav (che khuất một phần/toàn phần). Bắt bằng ảnh chụp thật trên
      // emulator tonyfino36, không phải đoán — đúng loại lỗi mà edge-to-edge
      // của Android 15+ gây ra (TODOS.md § Nghiên cứu trước, Phase 6).
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom:
              kBottomNavReservedHeight +
              MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: GestureDetector(
          onLongPress: _openTemplatePicker,
          child: _fabExtended
              ? FloatingActionButton.extended(
                  onPressed: _openAddSheet,
                  icon: const Icon(kIconAdd),
                  label: const Text('Thêm'),
                )
              : FloatingActionButton(
                  onPressed: _openAddSheet,
                  child: const Icon(kIconAdd),
                ),
        ),
      ),
      body: transactionsAsync.when(
        data: (items) => _TransactionList(
          items: items,
          summaryAsync: summaryAsync,
          now: now,
          scrollController: _scrollController,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Không tải được giao dịch: $error')),
      ),
    );
  }
}

class _TransactionList extends ConsumerWidget {
  const _TransactionList({
    required this.items,
    required this.summaryAsync,
    required this.now,
    required this.scrollController,
  });

  final List<TransactionWithCategory> items;
  final AsyncValue<MonthSummary> summaryAsync;
  final DateTime now;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    if (items.isEmpty) {
      return CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(child: _HeroCard(summaryAsync: summaryAsync)),
          // Bộ chọn kỳ: ngày / tháng (neo theo ngày bắt đầu kỳ ngân sách) /
          // năm / khoảng tuỳ chọn. DÙNG CHUNG `PeriodChip` + provider với
          // Trang chủ — xem `filteredTransactionsProvider`.
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.space.screenHorizontal,
                context.space.sm,
                context.space.screenHorizontal,
                0,
              ),
              child: PeriodChip(period: ref.watch(homePeriodProvider)),
            ),
          ),
          const SliverToBoxAdapter(child: _TagFilterRow()),
          SliverFillRemaining(
            hasScrollBody: false,
            child: const EmptyState(
              icon: kIconReceiptLong,
              title: 'Không có giao dịch trong kỳ này',
              // Nói rõ "trong kỳ này": từ khi màn này lọc theo kỳ, một sổ
              // đầy ắp vẫn có thể hiện rỗng chỉ vì đang chọn "Hôm nay" —
              // câu cũ ("ghi khoản đầu tiên") lúc đó là sai sự thật.
              message:
                  'Đổi kỳ ở chip phía trên, hoặc bấm "Thêm" để ghi một khoản.',
              mascotMood: MascotMood.idle,
            ),
          ),
        ],
      );
    }

    final groups = _groupByDay(items);

    // Tra cứu danh mục CHA cho giao dịch gắn vào danh mục phụ. Cố ý dựng ở
    // UI từ `categoriesProvider` (vốn đã sống sẵn cho cả app) thay vì nối
    // thêm một JOIN nữa vào truy vấn danh sách: bảng danh mục nhỏ và đã nằm
    // trong bộ nhớ, còn thêm JOIN thứ hai vào cùng truy vấn là đúng cái bẫy
    // fan-out Cartesian đã dính một lần ở dự án này.
    final categoriesById = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(child: _HeroCard(summaryAsync: summaryAsync)),
        // Bộ chọn kỳ: ngày / tháng (neo theo ngày bắt đầu kỳ ngân sách) /
        // năm / khoảng tuỳ chọn. DÙNG CHUNG `PeriodChip` + provider với
        // Trang chủ — xem `filteredTransactionsProvider`.
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.space.screenHorizontal,
              context.space.sm,
              context.space.screenHorizontal,
              0,
            ),
            child: PeriodChip(period: ref.watch(homePeriodProvider)),
          ),
        ),
        const SliverToBoxAdapter(child: _TagFilterRow()),
        // 🚨 MỖI NGÀY LÀ MỘT `SliverMainAxisGroup` — header pinned nằm BÊN
        // TRONG nhóm của nó.
        //
        // Trước đây các `SliverPersistentHeader(pinned: true)` xếp TUẦN TỰ
        // thẳng vào `slivers`. Cách đó chỉ đúng khi mỗi nhóm cao hơn header:
        // header sau đẩy header trước đi. Với sổ thật (358 giao dịch trải
        // trên ~100 ngày, phần lớn 1–2 giao dịch/ngày) chúng KHÔNG đẩy được
        // nhau nên tích lại và NUỐT SẠCH viewport — cuộn xuống chỉ còn một
        // chồng header ngày, mất hết dòng giao dịch. Tony báo đúng chuyện
        // này; chụp màn hình xác nhận.
        //
        // `SliverMainAxisGroup` giới hạn tầm dính của header trong đúng
        // nhóm — header tự trôi đi khi nhóm của nó cuộn hết. Comment cũ ở
        // đây từng loại trừ nó vì lỗi "layoutExtent exceeds paintExtent"
        // trên bản Flutter cũ; đã kiểm lại trên Flutter 3.44 (test danh
        // sách ngắn hơn viewport bên dưới) — không còn tái hiện.
        for (final group in groups)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _DayHeaderDelegate(
                  label: formatDayLabel(group.day, now),
                  netTotal: group.netTotal,
                ),
              ),
              SliverList.separated(
                itemCount: group.items.length,
                separatorBuilder: (context, _) =>
                    TransactionRow.divider(context),
                itemBuilder: (context, index) {
                  final twc = group.items[index];
                  // Giao dịch gắn vào danh mục phụ hiện theo kiểu Rolly: avatar
                  // + tên là của danh mục CHA (nên mọi bữa ăn cùng một icon,
                  // nhận ra ngay khi lướt), tên danh mục phụ tách ra thành chip.
                  final category = twc.category;
                  final parent = category?.parentCategoryId == null
                      ? null
                      : categoriesById[category!.parentCategoryId];
                  final display = parent ?? category;
                  return Dismissible(
                    key: ValueKey(twc.transaction.id),
                    direction: DismissDirection.endToStart,
                    background: _DeleteBackground(),
                    onDismissed: (_) => deleteTransactionWithUndo(
                      context,
                      ref,
                      twc.transaction,
                    ),
                    child: TransactionRow(
                      categoryColorId: display?.categoryColorId ?? 10,
                      iconCode: display?.iconCode ?? 'more_horiz',
                      emoji: display?.emoji,
                      subcategoryLabel: parent == null ? null : category!.name,
                      // Tách dòng (Phase 14) và "chưa phân loại" (Phase 8) đều
                      // có `category == null` nhưng là hai khái niệm khác nhau
                      // — phân biệt qua `isSplit`, không thể suy ra từ category.
                      title: twc.isSplit
                          ? 'Nhiều danh mục'
                          : (display?.name ?? 'Chưa phân loại'),
                      subtitle: twc.transaction.note,
                      amount: Money(
                        minorUnits: twc.transaction.amountMinor,
                        currency: twc.transaction.currency,
                        currencyScale: twc.transaction.currencyScale,
                      ),
                      onTap: () => showTransactionFormSheet(
                        context: context,
                        existing: twc,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: kBottomNavReservedHeight + bottomInset),
        ),
      ],
    );
  }
}

/// 🎨 Phase 22, Hướng 1 "phong phú có giới hạn": nền gradient động CHỈ ở
/// đây (không phải `AppCard` dùng chung — cố tình KHÔNG sửa `AppCard` để
/// không ảnh hưởng mọi card khác trong app). Dựng lại đúng khung viền/bóng
/// của `AppCard` (không đổi được từ bên ngoài) rồi chèn
/// `HeroGradientBackground` phía sau nội dung, clip theo cùng bo góc.
class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.summaryAsync});

  final AsyncValue<MonthSummary> summaryAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = summaryAsync.value;
    final streak = ref.watch(entryStreakProvider);
    final radius = BorderRadius.circular(context.radii.xl);
    return Padding(
      padding: EdgeInsets.all(context.space.screenHorizontal),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: radius,
          border: Border.all(color: context.shadows.level1Border, width: 1),
          boxShadow: context.shadows.level1Shadow,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Positioned.fill(
                child: HeroGradientBackground(
                  // Ba mốc cùng họ LẠNH (petrol), không phải họ ấm.
                  //
                  // Bản cũ là cam 12% → bột gạch 10% → cam 5%. Trên nền tối,
                  // cam pha loãng ra nâu đục — cùng đúng vấn đề với vòng
                  // tròn icon và quầng nền. Petrol thì tối đi vẫn là xanh.
                  // Giữ ba mốc lệch alpha để vẫn ra một khối ánh sáng có
                  // chiều, không phải một mảng phẳng.
                  colors: [
                    context.colors.brandText.withValues(alpha: 0.14),
                    context.colors.brandText.withValues(alpha: 0.08),
                    context.colors.brandText.withValues(alpha: 0.04),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(context.space.heroCardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            // Không ghi cứng "từ đầu tháng" nữa: thẻ này
                            // giờ đi theo kỳ đang chọn ở chip ngay bên
                            // dưới, có thể là hôm nay/năm nay/khoảng tự
                            // chọn.
                            'Chi tiêu trong kỳ',
                            style: context.text.labelMedium?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        // Chuỗi ngày ghi giao dịch — chỉ hiện khi có ý nghĩa
                        // (≥3 ngày liên tiếp), tính theo NGÀY GIAO DỊCH THẬT
                        // (`entryStreakProvider`), không phải ngày nhập.
                        if (streak >= 3) ...[
                          Image.asset(
                            'assets/icons3d/fire_3d.png',
                            width: 18,
                            height: 18,
                          ),
                          SizedBox(width: context.space.xs),
                          Text(
                            '$streak ngày',
                            style: context.text.labelMedium?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: context.space.xs),
                    summary == null
                        ? SizedBox(height: 48, child: _HeroSkeleton())
                        : CountUpText(summary.expense, size: MoneySize.hero),
                    SizedBox(height: context.space.lg),
                    // BA cột: Thu · Tiết kiệm · Còn lại. KHÔNG lặp lại số Chi
                    // — nó đã là con số lớn ngay phía trên.
                    //
                    // "Tiết kiệm" phải có mặt: nếu không, "Còn lại" = Thu −
                    // Chi và nó coi tiền đã cất vào mục tiêu là vẫn tiêu
                    // được. Cùng một lỗi đã sửa ở Trang chủ; hai màn phải
                    // ra đúng một con số (`MonthSummary.net`).
                    // `spacing` chứ không phải ba `Expanded` sát nhau: không
                    // có khe thì "+29.533.000 đ" của cột này chạm ngay vào
                    // "0 đ" của cột kia, đọc thành một chuỗi số liền — Tony
                    // gọi đúng là "chữ bị đè".
                    Row(
                      spacing: context.space.sm,
                      children: [
                        Expanded(
                          child: _SummaryColumn(
                            label: 'Thu',
                            amount: summary?.income,
                          ),
                        ),
                        Expanded(
                          child: _SummaryColumn(
                            label: 'Tiết kiệm',
                            amount: summary?.savings,
                          ),
                        ),
                        Expanded(
                          child: _SummaryColumn(
                            label: 'Còn lại',
                            amount: summary?.net,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 40,
      decoration: BoxDecoration(
        color: context.colors.skeletonBase,
        borderRadius: BorderRadius.circular(context.radii.sm),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({required this.label, required this.amount});

  final String label;
  final Money? amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.space.xxs),
        // Cỡ `small` (13px), KHÔNG phải `medium` (17px).
        //
        // Ba số tiền VND thật đều dài cỡ "+29.533.000 đ". Ở 17px chúng
        // không vừa một phần ba bề ngang thẻ: số gãy thành "+29.533.00" /
        // "0 đ" — chữ số bị cắt ngang, đọc ra một con số KHÁC. Kiểu hỏng
        // này tệ hơn tràn viền vì nó không TRÔNG như lỗi. Trang chủ đã hạ
        // xuống `small` vì đúng lý do đó; ở đây cũng vậy.
        //
        // `FittedBox` là lưới an toàn cuối cho cỡ chữ hệ thống 2.0×.
        amount == null
            ? const SizedBox(height: 24)
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: MoneyText(amount!, size: MoneySize.small),
              ),
      ],
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.expenseFill,
      alignment: AlignmentDirectional.centerEnd,
      padding: EdgeInsets.symmetric(horizontal: context.space.lg),
      child: const Icon(kIconDelete, color: Colors.white),
    );
  }
}

class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DayHeaderDelegate({required this.label, required this.netTotal});

  final String label;
  final Money netTotal;

  static const _height = 44.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // BẮT BUỘC ép đúng `_height` — nếu không, `RenderSliverPinnedPersistentHeader`
    // đo `childExtent` theo chiều cao THẬT của `DayHeader` (nhỏ hơn `maxExtent`
    // khai báo), lệch với `layoutExtent` (luôn dùng `maxExtent`) → ném
    // "layoutExtent exceeds paintExtent" mỗi khi danh sách ngắn hơn viewport.
    // Bắt được bằng widget test, không phải đoán.
    return SizedBox(
      height: _height,
      child: DayHeader(label: label, netTotal: netTotal),
    );
  }

  @override
  bool shouldRebuild(covariant _DayHeaderDelegate oldDelegate) {
    return oldDelegate.label != label || oldDelegate.netTotal != netTotal;
  }
}

class _DayGroup {
  _DayGroup(this.day) : items = [], netTotalMinor = 0;

  final DateTime day;
  final List<TransactionWithCategory> items;
  int netTotalMinor;

  Money get netTotal => Money.vnd(netTotalMinor);
}

/// Lọc theo thẻ (Phase 17) — chỉ hiện khi có ít nhất một thẻ (cùng quy ước
/// ẩn/hiện với chip thẻ ở `ReportFilterBar`, tránh một hàng UI trống nghĩa
/// khi Tony chưa tạo thẻ nào). Đọc/ghi [transactionsTagFilterProvider] —
/// TÁCH khỏi [reportFilterProvider] (Phase 17 "Bàn giao" yêu cầu lọc được ở
/// CẢ Giao dịch LẪN Báo cáo, nhưng đây là hai bộ lọc độc lập, đổi lọc ở tab
/// Giao dịch không ảnh hưởng bộ lọc đang đặt ở tab Báo cáo và ngược lại).
class _TagFilterRow extends ConsumerWidget {
  const _TagFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider).value ?? const [];
    if (tags.isEmpty) return const SizedBox.shrink();

    final selected = ref.watch(transactionsTagFilterProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: context.space.sm),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(
            horizontal: context.space.screenHorizontal,
          ),
          children: [
            for (final tag in tags) ...[
              AppChip(
                label: tag.name,
                editable: false,
                selected: selected.contains(tag.id),
                icon: CircleAvatar(
                  radius: 6,
                  backgroundColor:
                      context.colors.categoryFills[tag.categoryColorId %
                          context.colors.categoryFills.length],
                ),
                onTap: () {
                  final next = {...selected};
                  if (!next.add(tag.id)) next.remove(tag.id);
                  ref
                      .read(transactionsTagFilterProvider.notifier)
                      .setTagIds(next);
                },
              ),
              SizedBox(width: context.space.xs),
            ],
          ],
        ),
      ),
    );
  }
}

List<_DayGroup> _groupByDay(List<TransactionWithCategory> items) {
  final groups = <DateTime, _DayGroup>{};
  final order = <DateTime>[];
  for (final item in items) {
    final key = dayKey(item.transaction.occurredAt);
    final group = groups.putIfAbsent(key, () {
      order.add(key);
      return _DayGroup(key);
    });
    group.items.add(item);
    group.netTotalMinor += item.transaction.amountMinor;
  }
  return [for (final key in order) groups[key]!];
}
