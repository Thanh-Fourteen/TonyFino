import '../../ui/amount_visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/router/app_bottom_nav.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_card.dart';
import '../../ui/budget_ring.dart';
import '../../ui/category_avatar.dart';
import '../../ui/empty_state.dart';
import '../transactions/transactions_providers.dart';
import 'budgets_providers.dart';
import 'domain/budget_pace.dart';
import 'domain/budget_period.dart';
import 'domain/budget_progress.dart';
import 'widgets/budget_edit_sheet.dart';

/// Ngân sách theo danh mục theo tháng — mỗi kỳ là MỘT THÁNG LỊCH (quyết
/// định trước khi code, `docs/decisions.md` § Phase 11), trạng thái LUÔN
/// tính bằng SQL aggregate qua `BudgetRepository.watchBudgetsForPeriod`
/// (D7: không lưu bộ đếm). Danh mục CHƯA có ngân sách của kỳ đang xem hiện
/// riêng bên dưới để Tony đặt mới — sai khác giữa "12 danh mục chi" và
/// "danh mục đã có ngân sách" tính ở TẦNG UI (rẻ, chỉ vài chục danh mục),
/// không phải một truy vấn SQL riêng.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key, this.embedded = false});

  /// `true` khi nằm trong tab "Hạn mức" của `MoneyHubScreen` — bỏ
  /// `SafeArea` trên và không tự chừa đệm đáy hai lần.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(budgetPeriodProvider);
    final progressAsync = ref.watch(budgetProgressProvider);
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final safeToSpendAsync = ref.watch(safeToSpendTodayProvider);
    final now = ref.watch(clockProvider).now();
    final pace = period.paceFraction(now);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final progressList = progressAsync.value ?? const <BudgetProgress>[];
    final budgetedIds = progressList.map((p) => p.categoryId).toSet();
    final allCategories = categoriesAsync.value ?? const <Category>[];
    final categoriesById = {for (final c in allCategories) c.id: c};

    // 🚨 XẾP THEO HAI CẤP, không đổ phẳng.
    //
    // Trước đây đây là một `where(...)` trả về đúng thứ tự bảng: cha và con
    // nằm lẫn lộn, "Tiêu vặt" đứng cạnh "Nhà cửa" mà không cho biết nó thuộc
    // Ăn uống. Tony đã nói rõ hai lần là danh mục không được làm phẳng.
    final unbudgeted = <({Category category, bool isChild})>[];
    for (final parent in allCategories) {
      if (parent.kind != 'expense' || parent.parentCategoryId != null) continue;
      if (!budgetedIds.contains(parent.id)) {
        unbudgeted.add((category: parent, isChild: false));
      }
      for (final child in allCategories) {
        if (child.parentCategoryId != parent.id) continue;
        if (budgetedIds.contains(child.id)) continue;
        unbudgeted.add((category: child, isChild: true));
      }
    }
    final isLoading = progressAsync.isLoading && !progressAsync.hasValue;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // KHÔNG lặp lại tiêu đề màn: `AppShell`'s AppBar đã hiện đúng
            // chữ "Ngân sách" ngay phía trên. Hai dòng chữ y hệt nhau chồng lên
            // nhau vừa thừa vừa ngốn ~120px chiều dọc của màn hình đầu tiên.
            SliverToBoxAdapter(child: SizedBox(height: context.space.sm)),
            if (safeToSpendAsync.value != null)
              SliverToBoxAdapter(
                child: _SafeToSpendCard(amount: safeToSpendAsync.value!),
              ),
            SliverToBoxAdapter(child: _MonthNav(period: period)),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                context.space.screenHorizontal,
                context.space.lg,
                context.space.screenHorizontal,
                unbudgeted.isEmpty ? kBottomNavReservedHeight + bottomInset : 0,
              ),
              sliver: isLoading
                  ? const SliverToBoxAdapter(child: SizedBox.shrink())
                  : SliverList.list(
                      children: [
                        if (progressList.isEmpty && unbudgeted.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: EmptyState(
                              icon: kIconSavings,
                              title: 'Chưa có danh mục chi',
                              message:
                                  'Thêm danh mục chi để bắt đầu đặt ngân sách.',
                            ),
                          ),
                        for (final progress in progressList) ...[
                          _BudgetProgressCard(
                            progress: progress,
                            pace: pace,
                            period: period,
                            parentName:
                                categoriesById[categoriesById[progress
                                            .categoryId]
                                        ?.parentCategoryId]
                                    ?.name,
                          ),
                          SizedBox(height: context.space.betweenCards),
                        ],
                      ],
                    ),
            ),
            // Danh mục CHƯA có ngân sách dựng bằng HÀNG TRÀN VIỀN, không phải
            // card-mỗi-hàng: chúng chỉ có tên + nút thêm, không có gì đáng
            // được một bề mặt nổi riêng. Card-mỗi-hàng ở đây ngốn ~30% chiều
            // dọc vào lề và viền lặp — đúng thứ mà doc của `TransactionRow`
            // đã ghi là phải tránh. Bảy danh mục từng chiếm trọn màn hình.
            if (!isLoading && unbudgeted.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.space.screenHorizontal,
                    progressList.isEmpty ? 0 : context.space.md,
                    context.space.screenHorizontal,
                    context.space.xs,
                  ),
                  child: Text(
                    'Chưa có ngân sách',
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              SliverList.separated(
                itemCount: unbudgeted.length,
                separatorBuilder: (context, _) => Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: context.space.dividerIndent,
                  ),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: context.colors.hairline,
                  ),
                ),
                itemBuilder: (context, index) => _UnbudgetedRow(
                  category: unbudgeted[index].category,
                  isChild: unbudgeted[index].isChild,
                  period: period,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: kBottomNavReservedHeight + bottomInset),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Số "An toàn để tiêu hôm nay" (Phase 15, kiểu PocketGuard) — MỘT con số
/// TOÀN VÍ theo ngày, tách biệt khỏi vòng nhịp TỪNG DANH MỤC bên dưới. Luôn
/// nói về "hôm nay" thật (xem `safeToSpendTodayProvider`), không đổi theo
/// nút trước/sau tháng của `_MonthNav`.
class _SafeToSpendCard extends StatelessWidget {
  const _SafeToSpendCard({required this.amount});

  final Money amount;

  @override
  Widget build(BuildContext context) {
    final isNegative = amount.minorUnits < 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.space.screenHorizontal,
        0,
        context.space.screenHorizontal,
        context.space.md,
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An toàn để tiêu hôm nay',
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: context.space.xxs),
            Text(
              AmountVisibility.mask(
                context,
                isNegative
                    ? '−${Money.vnd(-amount.minorUnits).format()}'
                    : amount.format(),
              ),
              style: context.money.moneyLarge.copyWith(
                color: isNegative
                    ? context.colors.budgetOver
                    : context.colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthNav extends ConsumerWidget {
  const _MonthNav({required this.period});

  final BudgetPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(budgetPeriodProvider.notifier);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.space.screenHorizontal),
      child: Row(
        children: [
          IconButton(
            onPressed: controller.goToPrevious,
            icon: const Icon(kIconChevronLeft),
            tooltip: 'Tháng trước',
          ),
          Expanded(
            child: Center(
              child: Text(period.label, style: context.text.titleMedium),
            ),
          ),
          IconButton(
            onPressed: controller.goToNext,
            icon: const Icon(kIconChevronRight),
            tooltip: 'Tháng sau',
          ),
        ],
      ),
    );
  }
}

class _BudgetProgressCard extends StatelessWidget {
  const _BudgetProgressCard({
    required this.progress,
    required this.pace,
    required this.period,
    this.parentName,
  });

  final BudgetProgress progress;

  /// Tên danh mục CHA khi hạn mức này đặt trên một danh mục con — hiện
  /// "Ăn uống › Tiêu vặt" thay vì mỗi "Tiêu vặt".
  final String? parentName;
  final double pace;
  final BudgetPeriod period;

  @override
  Widget build(BuildContext context) {
    final state = progress.paceState(pace);
    final stateLabel = switch (state) {
      BudgetPaceState.onTrack => 'Đúng nhịp',
      BudgetPaceState.trendingOver => 'Trên nhịp',
      BudgetPaceState.over => 'Đã vượt',
    };
    final stateColor = switch (state) {
      BudgetPaceState.onTrack => context.colors.budgetOk,
      BudgetPaceState.trendingOver => context.colors.budgetWarn,
      BudgetPaceState.over => context.colors.budgetOver,
    };

    // Viền trái đổi màu theo trạng thái (Phase 25, `docs/rolly-uiux-research.md`
    // § F) — tín hiệu thị giác PHỤ, `AppCard` không hỗ trợ viền một cạnh nên
    // bọc thêm một `Container` mỏng ngoài `AppCard` thay vì sửa widget dùng
    // chung (tránh ảnh hưởng mọi card khác trong app).
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: stateColor, width: 4)),
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: AppCard(
        onTap: () => showBudgetEditSheet(
          context: context,
          categoryId: progress.categoryId,
          categoryName: progress.categoryName,
          categoryColorId: progress.categoryColorId,
          iconCode: progress.iconCode,
          period: period,
          existingBudgetId: progress.budgetId,
          existingAmountMinor: progress.budgetAmountMinor,
          existingCarryOver: progress.carryOverEnabled,
        ),
        child: Row(
          children: [
            BudgetRing(
              progress: progress.progressFraction,
              paceFraction: pace,
              size: 64,
              strokeWidth: 7,
            ),
            SizedBox(width: context.space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CategoryAvatar(
                        categoryColorId: progress.categoryColorId,
                        iconCode: progress.iconCode,
                        size: 22,
                      ),
                      SizedBox(width: context.space.xs),
                      Expanded(
                        child: Text(
                          parentName == null
                              ? progress.categoryName
                              : '$parentName › ${progress.categoryName}',
                          style: context.text.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.space.xxs),
                  Text(
                    AmountVisibility.mask(
                      context,
                      'Đã chi ${Money.vnd(progress.spentMinor.abs()).format()} / '
                      '${Money.vnd(progress.effectiveBudgetAmountMinor).format()}',
                    ),
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  if (progress.carryInMinor != 0) ...[
                    SizedBox(height: context.space.xxs),
                    Text(
                      AmountVisibility.mask(
                        context,
                        progress.carryInMinor > 0
                            ? '+${Money.vnd(progress.carryInMinor).format()} cộng dồn từ kỳ trước'
                            : '−${Money.vnd(-progress.carryInMinor).format()} phạt vượt kỳ trước',
                      ),
                      style: context.text.labelMedium?.copyWith(
                        color: progress.carryInMinor > 0
                            ? context.colors.budgetOk
                            : context.colors.budgetOver,
                      ),
                    ),
                  ],
                  SizedBox(height: context.space.xxs),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: stateColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: context.space.xxs),
                      Text(
                        stateLabel,
                        style: context.text.labelMedium?.copyWith(
                          color: stateColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        AmountVisibility.mask(
                          context,
                          progress.remainingMinor >= 0
                              ? 'Còn ${Money.vnd(progress.remainingMinor).format()}'
                              : 'Vượt ${Money.vnd(-progress.remainingMinor).format()}',
                        ),
                        style: context.text.labelMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnbudgetedRow extends StatelessWidget {
  const _UnbudgetedRow({
    required this.category,
    required this.period,
    this.isChild = false,
  });

  final Category category;
  final BudgetPeriod period;

  /// Danh mục CON — thụt vào và avatar nhỏ hơn, để nhìn ra ngay nó nằm dưới
  /// danh mục ngay phía trên. Danh sách xếp cha-rồi-con ở tầng gọi.
  final bool isChild;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showBudgetEditSheet(
          context: context,
          categoryId: category.id,
          categoryName: category.name,
          categoryColorId: category.categoryColorId,
          iconCode: category.iconCode,
          period: period,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left:
                context.space.screenHorizontal +
                (isChild ? context.space.xl : 0),
            right: context.space.screenHorizontal,
            top: context.space.transactionRowVertical,
            bottom: context.space.transactionRowVertical,
          ),
          child: Row(
            children: [
              CategoryAvatar(
                categoryColorId: category.categoryColorId,
                iconCode: category.iconCode,
                size: isChild ? 28 : 36,
              ),
              SizedBox(width: context.space.md),
              Expanded(
                child: Text(
                  category.name,
                  style: isChild
                      ? context.text.bodyMedium
                      : context.text.bodyLarge,
                ),
              ),
              Icon(kIconAddCircle, color: context.colors.brandText),
            ],
          ),
        ),
      ),
    );
  }
}
