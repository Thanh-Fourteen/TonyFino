import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart';
import '../../data/repositories/jar_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/amount_visibility.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_card.dart';
import '../../ui/category_avatar.dart';
import '../../ui/day_header.dart';
import '../../ui/empty_state.dart';
import '../../ui/money_text.dart';
import '../../ui/transaction_row.dart';
import '../categories/category_detail_screen.dart';
import '../home/home_period_provider.dart';
import '../home/widgets/period_chip.dart';
import '../reports/domain/category_slice.dart';
import '../reports/domain/report_range.dart';
import '../reports/reports_providers.dart';
import '../reports/widgets/category_pie_card.dart';
import '../savings/widgets/savings_contribution_sheet.dart';
import '../transactions/day_label.dart';
import '../transactions/domain/day_groups.dart';
import '../transactions/domain/transaction_row_display.dart';
import '../transactions/transaction_form_sheet.dart';
import '../transactions/transactions_providers.dart';
import 'jars_providers.dart';
import 'jars_screen.dart' show JarProgressBar, JarStat;
import 'widgets/jar_categories_sheet.dart';
import 'widgets/jar_edit_sheet.dart';

void openJarDetailScreen(BuildContext context, int jarId) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => JarDetailScreen(jarId: jarId)),
  );
}

/// Chi tiết MỘT hũ trong kỳ đang xem: con số của hũ, chia theo danh mục
/// (giống thẻ "Theo danh mục" ở Trang chủ), rồi mọi giao dịch làm nên con
/// số đó.
///
/// Tony: *"khi nhấn vô 1 hũ, ở dưới sẽ có tất cả giao dịch theo danh mục
/// danh mục con, như bảng theo danh mục ở trang chủ"*. Trước đây bấm thẻ hũ
/// là mở thẳng sheet SỬA hũ — thứ ít khi cần — còn câu hỏi hay gặp nhất
/// ("hũ này tiêu vào đâu?") thì không có đường trả lời.
///
/// Mọi số ở đây đọc từ cùng nguồn với thẻ hũ (`jarProgressProvider`) và bộ
/// lọc hũ ở tab Giao dịch (`watchJarTransactions`) — ba chỗ nói về một hũ
/// phải ra đúng một con số.
class JarDetailScreen extends ConsumerWidget {
  const JarDetailScreen({super.key, required this.jarId});

  final int jarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(jarOverviewEntryProvider(jarId));
    final period = ref.watch(homePeriodProvider);

    if (progress == null) {
      // Chưa tải xong, hoặc hũ vừa bị xoá (lưu trữ) từ sheet sửa ngay trên
      // màn này — khi đó quay về thay vì treo một màn trống.
      final loaded = ref.watch(jarProgressProvider).hasValue;
      if (loaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final jar = progress.jar;
    final saving = progress.kind == JarKind.saving;
    final remainingOfPeriod = progress.remaining.minorUnits;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryAvatar(
              categoryColorId: jar.categoryColorId,
              iconCode: jar.iconCode,
              size: 32,
            ),
            SizedBox(width: context.space.sm),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jar.name, overflow: TextOverflow.ellipsis),
                  Text(
                    saving
                        ? '${jar.percent}% · Tiết kiệm · '
                              '${progress.goals.length} quỹ'
                        : '${jar.percent}% · ${progress.categoryCount} danh mục',
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!saving)
            IconButton(
              tooltip: 'Chọn danh mục cho hũ',
              icon: const Icon(kIconCategory),
              onPressed: () => showJarCategoriesSheet(context, jar),
            ),
          IconButton(
            tooltip: 'Sửa hũ',
            icon: const Icon(kIconEdit),
            onPressed: () => showJarEditSheet(context: context, existing: jar),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: context.space.xxl),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.space.screenHorizontal,
              context.space.sm,
              context.space.screenHorizontal,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Đổi kỳ ngay tại đây — dùng CHUNG kỳ với Trang chủ/màn Hũ.
                PeriodChip(period: period),
                SizedBox(height: context.space.md),
                _JarSummaryCard(progress: progress),
                if (!saving) ...[
                  SizedBox(height: context.space.betweenCards),
                  _JarCategoryChart(
                    jarId: jarId,
                    range: period.range,
                    rangeLabel: period.label,
                  ),
                ],
                if (saving && progress.goals.isNotEmpty) ...[
                  SizedBox(height: context.space.lg),
                  Text('Quỹ trong hũ', style: context.text.titleMedium),
                  SizedBox(height: context.space.sm),
                  for (final g in progress.goals) ...[
                    _JarGoalCard(goal: g, jarRemainingMinor: remainingOfPeriod),
                    SizedBox(height: context.space.sm),
                  ],
                ],
                SizedBox(height: context.space.lg),
                Text(
                  saving ? 'Các lần nạp/rút quỹ' : 'Giao dịch',
                  style: context.text.titleMedium,
                ),
              ],
            ),
          ),
          _JarTransactionList(jarId: jarId, saving: saving),
        ],
      ),
    );
  }
}

class _JarSummaryCard extends StatelessWidget {
  const _JarSummaryCard({required this.progress});

  final JarProgress progress;

  @override
  Widget build(BuildContext context) {
    final saving = progress.kind == JarKind.saving;
    var remaining = progress.remaining;
    final String remainingLabel;
    Color? remainingColor;
    if (progress.tracksGoalTotal) {
      // Hũ 0%: không có mốc của KỲ, nên ô thứ ba nói về ĐÍCH các quỹ —
      // đúng thứ thanh tiến độ ngay dưới đang đo.
      remaining = progress.goalTarget - progress.savedTotal;
      remainingLabel = remaining.minorUnits <= 0 ? 'Đã đạt đích' : 'Còn thiếu';
      if (remaining.minorUnits <= 0) remainingColor = context.colors.budgetOk;
    } else if (saving) {
      remainingLabel = remaining.minorUnits <= 0 ? 'Đã đủ, dư' : 'Còn cần gửi';
      if (remaining.minorUnits <= 0) remainingColor = context.colors.budgetOk;
    } else if (remaining.minorUnits < 0) {
      remainingLabel = 'Vượt';
      remainingColor = context.colors.budgetOver;
    } else {
      remainingLabel = 'Còn lại';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: context.space.sm,
            children: [
              Expanded(
                child: JarStat(
                  label: 'Hạn mức ${progress.jar.percent}%',
                  amount: progress.allotted,
                ),
              ),
              Expanded(
                child: JarStat(
                  label: saving ? 'Đã gửi kỳ này' : 'Đã tiêu',
                  amount: progress.used,
                ),
              ),
              Expanded(
                child: JarStat(
                  label: remainingLabel,
                  amount: remaining.minorUnits < 0 ? -remaining : remaining,
                  color: remainingColor,
                ),
              ),
            ],
          ),
          SizedBox(height: context.space.md),
          JarProgressBar(progress: progress, height: 8),
          if (saving && progress.goals.isNotEmpty) ...[
            SizedBox(height: context.space.xs),
            // Hai con số khác nhau, Tony muốn thấy cả hai: ô trên là tiền
            // BỎ VÀO trong kỳ, dòng này là tiền ĐANG CÓ trong các quỹ.
            Row(
              children: [
                Text(
                  'Tổng quỹ đang có ',
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                MoneyText(
                  progress.savedTotal,
                  size: MoneySize.small,
                  signed: false,
                ),
                if (progress.goalTarget.minorUnits > 0)
                  Text(
                    AmountVisibility.mask(
                      context,
                      ' / ${progress.goalTarget.format()}',
                    ),
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Biểu đồ "Theo danh mục" của RIÊNG hũ này — cùng widget với Trang chủ,
/// dữ liệu chỉ gồm danh mục thuộc hũ, gộp lên cấp cha.
///
/// Bấm một danh mục cha KHÔNG mở màn Chi tiết danh mục như ở Trang chủ: hũ
/// có thể chỉ chứa vài con của "Ăn uống", màn đó lại cộng MỌI con. Thay vào
/// đó mở bảng các danh mục con thuộc hũ này.
class _JarCategoryChart extends ConsumerWidget {
  const _JarCategoryChart({
    required this.jarId,
    required this.range,
    required this.rangeLabel,
  });

  final int jarId;
  final ReportRange range;
  final String rangeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdown =
        ref.watch(jarCategoryBreakdownProvider(jarId)).value ??
        const <CategorySourceAmount>[];
    if (breakdown.isEmpty) return const SizedBox.shrink();
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final roots = rollupToRootCategories(
      breakdown,
      categoryHierarchyOf(categories),
    );
    final rolled = rolledRootSources(breakdown, categories);

    return CategoryPieCard(
      slices: buildCategorySlices(rolled),
      allSources: rolled,
      range: range,
      rangeLabel: rangeLabel,
      onOpenCategory: (ctx, rootId) {
        final root = roots.where((r) => r.rootCategoryId == rootId).firstOrNull;
        if (root == null) return;
        showAppBottomSheet<void>(
          context: ctx,
          builder: (_) =>
              _RootInJarSheet(root: root, range: range, rangeLabel: rangeLabel),
        );
      },
    );
  }
}

/// Các danh mục con (thuộc hũ này) của một danh mục cha.
class _RootInJarSheet extends StatelessWidget {
  const _RootInJarSheet({
    required this.root,
    required this.range,
    required this.rangeLabel,
  });

  final CategoryRootBreakdown root;
  final ReportRange range;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final totalAbs = root.amountMinor.abs();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.space.screenHorizontal,
          context.space.md,
          context.space.screenHorizontal,
          context.space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(root.label, style: context.text.titleLarge),
            SizedBox(height: context.space.xxs),
            Text(
              'Chỉ phần thuộc hũ này',
              style: context.text.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: context.space.md),
            for (final child in root.children)
              _ChildRow(
                // Hàng mang chính id của cha = khoản ghi THẲNG vào cha,
                // không chọn danh mục con nào.
                label: child.categoryId == root.rootCategoryId
                    ? '${root.label} (không có danh mục con)'
                    : child.label,
                colorId: child.categoryColorId,
                iconCode: child.iconCode,
                amountMinor: child.amountMinor,
                totalAbsMinor: totalAbs,
                // Danh mục CON mở được màn chi tiết của riêng nó — con số ở
                // đó khớp đúng hàng này. Cha thì không: màn của cha cộng cả
                // những con nằm ở hũ khác.
                onTap:
                    child.categoryId == null ||
                        child.categoryId == root.rootCategoryId
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        openCategoryDetailScreen(
                          context,
                          child.categoryId!,
                          range: range,
                          rangeLabel: rangeLabel,
                        );
                      },
              ),
          ],
        ),
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({
    required this.label,
    required this.colorId,
    required this.iconCode,
    required this.amountMinor,
    required this.totalAbsMinor,
    required this.onTap,
  });

  final String label;
  final int colorId;
  final String iconCode;
  final int amountMinor;
  final int totalAbsMinor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pct = totalAbsMinor == 0
        ? 0
        : (amountMinor.abs() * 100 / totalAbsMinor).round();
    return InkWell(
      borderRadius: BorderRadius.circular(context.radii.sm),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.space.xs),
        child: Row(
          children: [
            CategoryAvatar(
              categoryColorId: colorId,
              iconCode: iconCode,
              size: 32,
            ),
            SizedBox(width: context.space.sm),
            Expanded(
              child: Text(
                label,
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
              AmountVisibility.mask(context, Money.vnd(amountMinor).format()),
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
        ),
      ),
    );
  }
}

/// Mọi giao dịch làm nên con số của hũ trong kỳ, nhóm theo ngày.
class _JarTransactionList extends ConsumerWidget {
  const _JarTransactionList({required this.jarId, required this.saving});

  final int jarId;
  final bool saving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(jarTransactionsProvider(jarId)).value ??
        const <TransactionWithCategory>[];
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.space.xl),
        child: EmptyState(
          icon: kIconReceiptLong,
          title: 'Chưa có giao dịch nào trong kỳ này',
          message: saving
              ? 'Mỗi lần nạp vào quỹ gắn với hũ sẽ hiện ở đây.'
              : 'Khoản chi ở các danh mục thuộc hũ sẽ hiện ở đây.',
        ),
      );
    }
    final now = ref.watch(clockProvider).now();
    final categoriesById = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };
    return Column(
      children: [
        for (final group in groupTransactionsByDay(items)) ...[
          DayHeader(
            label: formatDayLabel(group.day, now),
            // Hũ tiết kiệm đọc theo chiều QUỸ TĂNG (nạp = dương), cùng quy
            // ước với màn Lịch sử quỹ.
            netTotal: Money.vnd(saving ? -group.netMinor : group.netMinor),
          ),
          for (final twc in group.items)
            Builder(
              builder: (context) {
                final row = transactionRowDisplay(twc, categoriesById);
                return TransactionRow(
                  categoryColorId: row.categoryColorId,
                  iconCode: row.iconCode,
                  emoji: row.emoji,
                  subcategoryLabel: row.subcategoryLabel,
                  title: row.title,
                  subtitle: twc.transaction.note,
                  amount: Money(
                    minorUnits: twc.transaction.amountMinor,
                    currency: twc.transaction.currency,
                    currencyScale: twc.transaction.currencyScale,
                  ),
                  onTap: () =>
                      showTransactionFormSheet(context: context, existing: twc),
                );
              },
            ),
        ],
      ],
    );
  }
}

/// Một quỹ trong hũ tiết kiệm: tháng này bỏ vào bao nhiêu, đang có bao
/// nhiêu, và nút gửi thêm cho ĐÚNG quỹ đó.
class _JarGoalCard extends StatelessWidget {
  const _JarGoalCard({required this.goal, required this.jarRemainingMinor});

  final JarGoalProgress goal;

  /// Phần còn thiếu của CẢ HŨ trong kỳ — điền sẵn khi hũ chỉ có ích một
  /// chỗ để bỏ tiền vào; nhiều quỹ thì để Tony tự gõ, app không đoán chia.
  final int jarRemainingMinor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.goal.name,
                  style: context.text.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Tỉ lệ chỉ hiện khi KHÁC 100% — "100%" ở mọi hàng là nhiễu.
              if (goal.percent != 100)
                Text(
                  '${goal.percent}% thuộc hũ',
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          SizedBox(height: context.space.xs),
          Row(
            spacing: context.space.sm,
            children: [
              Expanded(
                child: JarStat(
                  label: 'Gửi kỳ này',
                  amount: Money.vnd(goal.depositedMinor),
                ),
              ),
              Expanded(
                child: JarStat(
                  label: 'Đang có',
                  amount: Money.vnd(goal.savedMinor),
                ),
              ),
              Expanded(
                child: JarStat(
                  label: 'Đích',
                  amount: Money.vnd(goal.targetMinor),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showSavingsContributionSheet(
                context: context,
                goalId: goal.goal.id,
                goalName: goal.goal.name,
                move: SavingsMove.deposit,
                savedMinor: goal.savedMinor,
                targetAmountMinor: goal.targetMinor,
                prefillMinor: jarRemainingMinor > 0 ? jarRemainingMinor : null,
              ),
              icon: const Icon(kIconAdd, size: 18),
              label: const Text('Gửi vào quỹ này'),
            ),
          ),
        ],
      ),
    );
  }
}
