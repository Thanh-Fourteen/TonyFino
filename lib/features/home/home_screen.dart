import '../../ui/amount_visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money/money.dart';
import '../../core/router/app_bottom_nav.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_card.dart';
import '../../ui/money_text.dart';
import '../reports/domain/category_slice.dart';
import '../reports/widgets/category_pie_card.dart';
import '../settings/settings_controller.dart';
import '../../data/repositories/reports_repository.dart';
import 'home_period_provider.dart';
import 'home_providers.dart';
import '../wallets/selected_wallet_provider.dart';
import '../wallets/wallets_providers.dart';
import 'widgets/wallet_switcher_sheet.dart';
import '../transactions/transactions_providers.dart';
import '../transactions/domain/transaction_row_display.dart';
import '../savings/savings_providers.dart';
import '../money_hub/money_hub_tab_provider.dart';
import '../jars/jars_providers.dart';
import '../jars/jar_detail_screen.dart';
import '../jars/jars_screen.dart' show JarProgressBar, JarStat;
import '../../ui/category_avatar.dart';
import '../../ui/transaction_row.dart';
import '../../data/repositories/jar_repository.dart';
import '../savings/domain/savings_goal_progress.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/db/database.dart' show Category, Tag;
import '../reports/reports_providers.dart';
import '../tags/tags_providers.dart';
import 'widgets/period_chip.dart';

/// Trang chủ — tab đầu tiên kể từ khi màn "Nhập" thôi làm tab.
///
/// Vì sao đổi: nhập liệu là một HÀNH ĐỘNG, không phải một nơi để ở. Đặt nó
/// làm tab đầu nghĩa là mỗi lần mở app đều rơi vào một ô nhập trống rỗng
/// thay vì thấy tình hình tiền nong. Giờ nhập nằm sau đúng một nút cộng, và
/// tab đầu trả lời câu hỏi thật sự đầu tiên: "ví này còn bao nhiêu, tháng
/// này tiêu thế nào".
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final walletId = ref.watch(selectedWalletIdProvider);
    final balances = ref.watch(activeWalletBalancesProvider).value;
    final period = ref.watch(homePeriodProvider);
    final summary = ref.watch(homeSummaryProvider).value;
    final sections = ref.watch(appSettingsProvider).homeSections;
    // Thẻ nào có gì để hiện — quyết định ở đây để [_spaced] không chừa
    // khoảng cách cho thẻ vắng mặt.
    final hasJars = !(ref.watch(jarProgressProvider).value?.isEmpty ?? true);
    final hasGoals =
        (ref.watch(activeSavingsGoalsWithProgressProvider).value ?? const [])
            .isNotEmpty;
    final hasRecent =
        (ref.watch(homeRecentTransactionsProvider).value ?? const [])
            .isNotEmpty;

    final current = balances?.where((b) => b.wallet.id == walletId).firstOrNull;

    return Scaffold(
      extendBody: true,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: kBottomNavReservedHeight + bottomInset,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/quick-add'),
          icon: const Icon(kIconAdd),
          label: const Text('Ghi một khoản'),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.space.screenHorizontal,
          context.space.sm,
          context.space.screenHorizontal,
          kBottomNavReservedHeight + bottomInset,
        ),
        // Các thẻ tổng quan tự ẩn khi chưa có dữ liệu (mục tiêu, giao dịch)
        // — nhưng KHÔNG được để lại khoảng hở. Trước đây mỗi thẻ kèm sẵn một
        // `SizedBox` phía sau nên thẻ ẩn đi vẫn chừa nguyên khoảng cách:
        // trang chủ máy Tony hiện một mảng trống giữa thẻ tháng và "Gần đây",
        // trông như thẻ lỗi không vẽ ra. Giờ chèn khoảng cách GIỮA các thẻ
        // THẬT SỰ hiện, xem [_spaced].
        children: _spaced(context, [
          _BalanceHeader(balance: current, period: period, summary: summary),
          if (sections.contains(HomeSection.jars) && hasJars)
            const _JarsOverviewCard(),
          if (sections.contains(HomeSection.goals) && hasGoals)
            const _GoalsOverviewCard(),
          if (sections.contains(HomeSection.chart)) const _SpendingChartCard(),
          if (sections.contains(HomeSection.recent) && hasRecent)
            const _RecentTransactionsCard(),
        ]),
      ),
    );
  }
}

/// Chèn `betweenCards` GIỮA các thẻ, bỏ qua thẻ `null` (không hiện).
///
/// Thẻ nào ẩn phải được quyết định ở ĐÂY, tại chỗ dựng danh sách — không
/// phải bên trong `build()` của chính thẻ đó. Lần đầu sửa lỗi khoảng-hở tôi
/// lọc `SizedBox.shrink()` ngay trong danh sách, nhưng phần tử trong danh
/// sách là `_JarsOverviewCard`, cái `shrink()` chỉ xuất hiện sau khi nó
/// build — bộ lọc không bao giờ khớp và khoảng hở vẫn còn nguyên trên máy.
List<Widget> _spaced(BuildContext context, List<Widget?> cards) {
  final visible = cards.nonNulls.toList();
  return [
    for (var i = 0; i < visible.length; i++) ...[
      if (i > 0) SizedBox(height: context.space.betweenCards),
      visible[i],
    ],
  ];
}

/// Đầu trang: tên ví + số dư + kỳ + thu/chi/còn lại — MỘT khối duy nhất.
///
/// Trước đây là hai thẻ lớn chồng nhau, mỗi thẻ một con số cỡ hero: gần hai
/// phần ba màn hình đầu tiên chỉ để hiện hai con số, phần còn lại của app
/// bị đẩy xuống dưới nếp gấp. Tony gọi đúng tên vấn đề — "thiết kế trang chủ
/// thanh mảnh, sang trọng hơn".
///
/// Cách gộp: MỘT số lớn duy nhất (số dư ví — thứ người ta mở app ra để
/// xem), còn thu/chi/còn lại của kỳ xuống hàng thống kê nhỏ bên dưới, ngăn
/// bằng một đường kẻ mảnh thay vì viền thẻ thứ hai.
class _BalanceHeader extends ConsumerWidget {
  const _BalanceHeader({
    required this.balance,
    required this.period,
    required this.summary,
  });

  final WalletBalance? balance;
  final HomePeriod period;
  final PeriodSummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // "Còn lại" = thu − chi − phần đã cất vào tiết kiệm (xem
    // `PeriodSummary.netMinor`). Tony có tiết kiệm nên công thức cũ
    // (thu − chi) báo dư nhiều hơn số thật sự tiêu được.
    final net = summary == null ? null : Money.vnd(summary!.netMinor);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(context.radii.sm),
            onTap: () => showWalletSwitcherSheet(context),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    balance?.wallet.name ?? 'Đang tải ví…',
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  kIconExpandMore,
                  size: 18,
                  color: context.colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
          SizedBox(height: context.space.xxs),
          if (balance != null)
            MoneyText(balance!.balance, size: MoneySize.hero)
          else
            const SizedBox(height: 38),
          SizedBox(height: context.space.md),
          Divider(height: 1, color: context.colors.hairline),
          SizedBox(height: context.space.md),
          PeriodChip(period: period),
          SizedBox(height: context.space.sm),
          // HAI HÀNG, mỗi hàng hai ô — số tiền VND thật dài tới
          // "+29.533.000 đ"; bốn ô trên một hàng ở máy 360dp là mỗi ô còn
          // ~78px, chữ vỡ dòng và bốn cột lệch nhau.
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Thu',
                  amount: summary == null
                      ? null
                      : Money.vnd(summary!.incomeMinor),
                  size: MoneySize.small,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Chi',
                  amount: summary == null
                      ? null
                      : Money.vnd(summary!.expenseMinor),
                  size: MoneySize.small,
                ),
              ),
            ],
          ),
          SizedBox(height: context.space.sm),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  // Hiện ngay cả khi bằng 0: thấy dòng "Tiết kiệm 0 đ" thì
                  // mới biết "Còn lại" đã trừ phần này, chứ ẩn đi thì con số
                  // "Còn lại" lại thành khó hiểu theo kiểu khác.
                  label: 'Tiết kiệm',
                  amount: summary == null
                      ? null
                      : Money.vnd(summary!.savingsMinor),
                  size: MoneySize.small,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Còn lại',
                  amount: net,
                  size: MoneySize.small,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.amount,
    this.size = MoneySize.medium,
  });

  final String label;
  final Money? amount;
  final MoneySize size;

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
        // Số CO LẠI cho vừa một dòng, không xuống dòng.
        //
        // Ở cỡ chữ hệ thống 2.0× (Cài đặt trợ năng), "+29.533.000 đ" không
        // đủ chỗ trong nửa bề ngang thẻ nên nó gãy dòng, đẩy ô bên cạnh lệch
        // hẳn và làm hàng thống kê trông vỡ. `scaleDown` chỉ thu nhỏ khi
        // THIẾU chỗ — ở cỡ chữ thường không đổi một pixel nào.
        amount == null
            ? SizedBox(height: size == MoneySize.hero ? 44 : 24)
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: MoneyText(amount!, size: size),
              ),
      ],
    );
  }
}

/// Mở tab "Túi tiền" ở đúng trang con.
void _openHub(BuildContext context, WidgetRef ref, int tab) {
  ref.read(moneyHubTabProvider.notifier).select(tab);
  // `goBranch` của StatefulShellRoute — đổi nhánh mà GIỮ state từng nhánh.
  StatefulNavigationShell.of(context).goBranch(3);
}

/// Tổng quan HŨ của kỳ đang xem — ĐỦ mọi hũ, mỗi hũ đủ ba con số.
///
/// Bản cũ chỉ vẽ 4 hũ đầu, mỗi hũ một thanh + phần trăm: nhìn thấy "hũ nào
/// sắp đầy" nhưng không biết hũ đó được bao nhiêu, đã tiêu bao nhiêu, còn
/// bao nhiêu — ba thứ Tony mở Trang chủ ra để hỏi. Giờ hiện hết, kèm dòng
/// tổng của cả bộ hũ ở cuối.
class _JarsOverviewCard extends ConsumerWidget {
  const _JarsOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(jarProgressProvider).value;
    if (overview == null || overview.isEmpty) return const SizedBox.shrink();
    final remaining = overview.totalRemaining;

    return AppCard(
      onTap: () => _openHub(context, ref, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Hũ kỳ này',
            trailing: '${overview.jars.length} hũ',
          ),
          SizedBox(height: context.space.xxs),
          Text(
            AmountVisibility.mask(
              context,
              'Chia từ tổng thu ${overview.income.format()}',
            ),
            style: context.text.labelSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.space.md),
          for (final p in overview.jars) ...[
            // Mỗi hũ bấm riêng được → màn Chi tiết hũ (tiêu vào danh mục
            // nào, những giao dịch nào). Bấm phần còn lại của thẻ vẫn sang
            // tab Hũ như cũ.
            InkWell(
              borderRadius: BorderRadius.circular(context.radii.sm),
              onTap: () => openJarDetailScreen(context, p.jar.id),
              child: _HomeJarRow(progress: p),
            ),
            SizedBox(height: context.space.md),
          ],
          Divider(height: 1, color: context.colors.hairline),
          SizedBox(height: context.space.md),
          Row(
            spacing: context.space.sm,
            children: [
              Expanded(
                child: JarStat(
                  label: 'Tổng hũ ${overview.totalPercent}%',
                  amount: overview.totalAllotted,
                ),
              ),
              // "Đã tiêu" chỉ còn là tiền TIÊU; tiền để dành có dòng riêng
              // bên dưới — xem `JarsTotalsCard`, cùng lý do.
              Expanded(
                child: JarStat(label: 'Đã tiêu', amount: overview.totalSpent),
              ),
              Expanded(child: JarStat(label: 'Còn lại', amount: remaining)),
            ],
          ),
          if (overview.totalOverspent.minorUnits > 0)
            _JarsTotalsNote(
              label: 'Vượt hũ',
              amount: overview.totalOverspent,
              color: context.colors.budgetOver,
            ),
          // Hai dòng phụ, cùng nội dung với `JarsTotalsCard` ở màn Hũ —
          // tiền để dành và tiền rút từ quỹ đứng RIÊNG, không lẫn vào "đã
          // tiêu" và không trừ vào "còn lại" của kỳ.
          if (overview.totalSaved.minorUnits > 0)
            _JarsTotalsNote(
              label: 'Đã nạp vào quỹ',
              amount: overview.totalSaved,
              color: context.colors.incomeText,
            ),
          if (overview.totalDrawnFromGoals.minorUnits > 0)
            _JarsTotalsNote(
              label: 'Đã rút từ quỹ ra tiêu',
              amount: overview.totalDrawnFromGoals,
              color: context.colors.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

/// Dòng phụ của thẻ tổng hũ ở Trang chủ — nhãn trái, số tiền phải.
class _JarsTotalsNote extends StatelessWidget {
  const _JarsTotalsNote({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final Money amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.space.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(color: color),
            ),
          ),
          MoneyText(amount, size: MoneySize.small, signed: false),
        ],
      ),
    );
  }
}

/// Một hũ trên Trang chủ: tên + phần còn lại, thanh tiến độ, "đã dùng / hạn
/// mức". Hũ tiết kiệm nói bằng chữ của nó ("đã gửi", "còn cần gửi").
String _usedLabel(JarProgress p) {
  if (p.kind == JarKind.spend) return 'Đã tiêu';
  return p.spendsFromGoals ? 'Đã rút' : 'Đã nạp';
}

class _HomeJarRow extends StatelessWidget {
  const _HomeJarRow({required this.progress});

  final JarProgress progress;

  @override
  Widget build(BuildContext context) {
    final saving = progress.kind == JarKind.saving;
    final remaining = progress.remaining;
    final muted = context.text.labelSmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );

    String remainingLabel;
    Color remainingColor;
    // Số hiện ở góc phải: mặc định là phần CÒN LẠI của kỳ; hũ tiêu-từ-quỹ
    // không trần thì là tiền CÒN TRONG QUỸ.
    var remainingAmount = remaining;
    if (progress.tracksGoalDrawdown) {
      remainingAmount = progress.goalBalance;
      remainingLabel = 'Còn trong quỹ';
      remainingColor = remainingAmount.minorUnits > 0
          ? context.colors.onSurfaceVariant
          : context.colors.budgetOver;
    } else if (progress.tracksGoalTotal) {
      // Hũ tiết kiệm "nạp vào quỹ" đo theo ĐÍCH của quỹ, không theo mốc của
      // kỳ — cùng con số thanh tiến độ ngay dưới đang vẽ.
      final left = progress.goalTarget - progress.savedTotal;
      remainingAmount = left;
      remainingLabel = left.minorUnits <= 0 ? 'Đã đạt đích' : 'Còn thiếu';
      remainingColor = left.minorUnits <= 0
          ? context.colors.budgetOk
          : context.colors.onSurfaceVariant;
    } else if (saving) {
      remainingLabel = remaining.minorUnits <= 0 ? 'Đã đủ' : 'Còn cần nạp';
      remainingColor = remaining.minorUnits <= 0
          ? context.colors.budgetOk
          : context.colors.onSurfaceVariant;
    } else if (remaining.minorUnits < 0) {
      remainingLabel = 'Vượt';
      remainingColor = context.colors.budgetOver;
    } else {
      remainingLabel = 'Còn';
      remainingColor = context.colors.onSurfaceVariant;
    }
    final showAmount = progress.tracksGoalDrawdown
        ? true
        : progress.tracksGoalTotal
        ? remainingAmount.minorUnits > 0
        : !(saving && remaining.minorUnits <= 0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryAvatar(
          categoryColorId: progress.jar.categoryColorId,
          iconCode: progress.jar.iconCode,
          size: 32,
        ),
        SizedBox(width: context.space.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${progress.jar.name} · ${progress.jar.percent}%',
                      style: context.text.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    showAmount ? '$remainingLabel ' : remainingLabel,
                    style: context.text.labelSmall?.copyWith(
                      color: remainingColor,
                    ),
                  ),
                  if (showAmount)
                    MoneyText(
                      remainingAmount.minorUnits < 0
                          ? -remainingAmount
                          : remainingAmount,
                      size: MoneySize.small,
                      signed: false,
                    ),
                ],
              ),
              SizedBox(height: context.space.xxs),
              JarProgressBar(progress: progress),
              SizedBox(height: context.space.xxs),
              // Dòng số dưới thanh: con số của KỲ theo đúng chiều của hũ,
              // rồi mới tới tiền đang có trong quỹ làm bối cảnh. Tiền trong
              // quỹ là số của QUỸ (một quỹ nằm trong hai hũ thì hai hũ cùng
              // trỏ vào nó), nên nó không được đứng đầu dòng.
              Text(
                AmountVisibility.mask(
                  context,
                  '${_usedLabel(progress)} ${progress.used.format()}'
                  // Hũ 0% không có mức của kỳ — "/ 0 ₫" chỉ làm nhiễu.
                  '${progress.allotted.minorUnits > 0 ? ' / ${progress.allotted.format()}' : ''}'
                  '${saving && progress.goals.isNotEmpty ? ' · quỹ đang có ${progress.savedTotal.format()}' : ''}',
                ),
                style: muted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tổng quan QUỸ (mục tiêu tiết kiệm) — tổng đã để dành / tổng mục tiêu.
class _GoalsOverviewCard extends ConsumerWidget {
  const _GoalsOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals =
        ref.watch(activeSavingsGoalsWithProgressProvider).value ??
        const <SavingsGoalProgress>[];
    if (goals.isEmpty) return const SizedBox.shrink();

    final saved = goals.fold(0, (s, g) => s + g.savedMinor);
    final target = goals.fold(0, (s, g) => s + g.goal.targetAmountMinor);

    return AppCard(
      onTap: () => _openHub(context, ref, 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: 'Quỹ', trailing: '${goals.length} mục tiêu'),
          SizedBox(height: context.space.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(Money.vnd(saved), size: MoneySize.large, signed: false),
              SizedBox(width: context.space.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  AmountVisibility.mask(
                    context,
                    '/ ${Money.vnd(target).format()}',
                  ),
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Vài giao dịch gần nhất — trả lời "vừa rồi tiêu gì" ngay trên Trang chủ,
/// không phải sang tab khác mới biết.
class _RecentTransactionsCard extends ConsumerWidget {
  const _RecentTransactionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(homeRecentTransactionsProvider).value ?? const [];
    if (recent.isEmpty) return const SizedBox.shrink();
    final categoriesById = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };

    return AppCard(
      onTap: () => StatefulNavigationShell.of(context).goBranch(1),
      padding: EdgeInsets.symmetric(vertical: context.space.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.space.cardPadding,
            ),
            child: const _CardHeader(title: 'Gần đây', trailing: 'Xem tất cả'),
          ),
          SizedBox(height: context.space.xs),
          // Hiện DANH MỤC CHA + chip danh mục con, y hệt tab Giao dịch —
          // cùng một giao dịch mà hai màn gọi tên khác nhau thì người dùng
          // tưởng là hai thứ.
          for (final twc in recent)
            _RecentRow(twc: twc, categoriesById: categoriesById),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: context.text.titleMedium)),
        Text(
          trailing,
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        Icon(
          kIconChevronRight,
          size: 18,
          color: context.colors.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// Một hàng của thẻ "Gần đây" — đi qua `transactionRowDisplay` dùng chung
/// với tab Giao dịch, chứ không tự dựng lại màu/icon/tên nữa. Trước đây hai
/// màn tự tính riêng và đã lệch thật (Trang chủ thiếu `emoji`, và cả hai đều
/// gọi một khoản nạp quỹ là "Chưa phân loại").
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.twc, required this.categoriesById});

  final TransactionWithCategory twc;
  final Map<int, Category> categoriesById;

  @override
  Widget build(BuildContext context) {
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
    );
  }
}

/// Thẻ biểu đồ chi theo danh mục ở Trang chủ (tuỳ chọn, bật/tắt ở Cài đặt).
///
/// Tái dùng thẳng [CategoryPieCard] của màn Báo cáo thay vì vẽ một biểu đồ
/// thứ hai: cùng cách gộp lát, cùng cách rollup danh mục con vào cha, cùng
/// hành vi bấm-vào-mở-chi-tiết. Hai biểu đồ tròn viết riêng cho cùng một câu
/// hỏi là cách chắc chắn để chúng ra hai con số khác nhau.
class _SpendingChartCard extends ConsumerWidget {
  const _SpendingChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    // Sổ chưa có thẻ nào thì bật "gom theo thẻ" cũng ra y hệt — không hiện
    // công tắc, và coi như đang tắt dù lần trước để bật.
    final byTag = ref.watch(chartGroupByTagProvider) && tags.isNotEmpty;

    final List<CategorySourceAmount> rolled;
    if (byTag) {
      rolled = tagModeRootSources(
        untagged:
            ref.watch(homeUntaggedBreakdownProvider).value ??
            const <CategorySourceAmount>[],
        tagGroups:
            ref.watch(homeTagGroupBreakdownProvider).value ??
            const <TagGroupAmount>[],
        categories: categories,
        tags: tags,
      );
    } else {
      rolled = rolledRootSources(
        ref.watch(homeCategoryBreakdownProvider).value ??
            const <CategorySourceAmount>[],
        categories,
      );
    }
    if (rolled.isEmpty) return const SizedBox.shrink();

    final period = ref.watch(homePeriodProvider);
    return CategoryPieCard(
      slices: buildCategorySlices(rolled),
      allSources: rolled,
      range: period.range,
      rangeLabel: period.label,
      groupByTag: byTag,
      onGroupByTagChanged: tags.isEmpty
          ? null
          : ref.read(chartGroupByTagProvider.notifier).set,
    );
  }
}
