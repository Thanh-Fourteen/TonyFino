import '../../ui/amount_visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/providers/database_providers.dart';
import '../../data/db/database.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_card.dart';
import '../../ui/empty_state.dart';
import '../../ui/mascot/app_mascot.dart';
import '../../ui/mascot/mascot_mood.dart';
import '../../ui/progress_ring.dart';
import '../transactions/transaction_form_sheet.dart';
import 'domain/debt_kind.dart';
import 'domain/debt_progress.dart';
import 'domain/savings_goal_progress.dart';
import 'savings_providers.dart';
import 'widgets/debt_edit_sheet.dart';
import 'widgets/savings_goal_edit_sheet.dart';

/// Mục tiêu tiết kiệm & nợ vay (Phase 16) — MỘT màn, hai tab, vì cả hai đều
/// "một danh sách mục có vòng tiến độ" cùng khuôn hình, không đáng hai màn
/// riêng + hai lối vào Settings riêng. Tiến độ LUÔN dẫn xuất bằng SQL (D7) —
/// xem `SavingsGoalRepository`/`DebtRepository`.
class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key, this.embedded = false});

  /// `true` khi màn này nằm TRONG một tab của `MoneyHubScreen` —
  /// bỏ AppBar riêng vì hub đã có tiêu đề + thanh tab. FAB giữ
  /// nguyên: nó là hành động của riêng tab này.
  final bool embedded;

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mục tiêu & Nợ vay'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mục tiêu tiết kiệm'),
            Tab(text: 'Nợ vay'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _tabController.index == 0
            ? showSavingsGoalEditSheet(context: context)
            : showDebtEditSheet(context: context),
        child: const Icon(kIconAdd),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [SavingsGoalsTab(), _DebtsTab()],
      ),
    );
  }
}

/// Danh sách MỤC TIÊU TIẾT KIỆM (các "quỹ").
///
/// Public để tab "Quỹ" của `MoneyHubScreen` dùng lại ĐÚNG phần này — hub
/// đã có thanh tab riêng (Ví/Quỹ/Hũ) nên không lồng thêm thanh tab
/// Mục tiêu/Nợ vay vào trong nữa. Màn `SavingsScreen` đầy đủ (kèm Nợ vay)
/// vẫn giữ nguyên, vào từ Cài đặt.
class SavingsGoalsTab extends ConsumerWidget {
  const SavingsGoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(activeSavingsGoalsWithProgressProvider);
    final archivedAsync = ref.watch(archivedSavingsGoalsProvider);

    return progressAsync.when(
      data: (goals) {
        final archived = archivedAsync.value ?? const <SavingsGoal>[];
        if (goals.isEmpty && archived.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: kIconFlag,
              title: 'Chưa có mục tiêu tiết kiệm nào',
              message: 'Bấm "+" để đặt mục tiêu đầu tiên.',
              mascotMood: MascotMood.idle,
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.all(context.space.screenHorizontal),
          children: [
            for (final progress in goals) _SavingsGoalTile(progress: progress),
            if (archived.isNotEmpty) ...[
              SizedBox(height: context.space.lg),
              Text('Đã lưu trữ', style: context.text.titleMedium),
              SizedBox(height: context.space.sm),
              for (final goal in archived)
                _ArchivedTile(
                  title: goal.name,
                  onRestore: () => ref
                      .read(savingsGoalRepositoryProvider)
                      .setArchived(goal.id, false),
                ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Lỗi: $error')),
    );
  }
}

/// 🎨 Phase 22 — phát hiện khoảnh khắc VỪA ĐẠT mục tiêu (chuyển trạng thái,
/// không phải trạng thái tĩnh, xem `docs/decisions.md` § Phase 22):
/// `SavingsGoalProgress.isAchieved` (Phase 16) chỉ là boolean tính lại mỗi
/// build, không tự phân biệt "đã đạt từ trước" với "vừa đạt xong" — phải tự
/// so sánh TRƯỚC/SAU bằng state cục bộ (`_wasAchieved`), ghi nhận từ lần
/// build ĐẦU TIÊN (mở màn khi goal đã đạt từ trước không ăn mừng lại).
class _SavingsGoalTile extends ConsumerStatefulWidget {
  const _SavingsGoalTile({required this.progress});

  final SavingsGoalProgress progress;

  @override
  ConsumerState<_SavingsGoalTile> createState() => _SavingsGoalTileState();
}

class _SavingsGoalTileState extends ConsumerState<_SavingsGoalTile> {
  // 🚨 KHÔNG được viết `late bool _wasAchieved = widget.progress.isAchieved;`
  // (field initializer) — `late` là LAZY, chỉ chạy ở lần ĐỌC ĐẦU TIÊN, và
  // lần đọc đầu tiên thực tế xảy ra bên TRONG `didUpdateWidget` (dòng dưới),
  // nơi `widget` ĐÃ LÀ widget MỚI (Flutter gán lại `widget` trước khi gọi
  // `didUpdateWidget`) — nghĩa là "giá trị cũ" vô tình đọc ra CHÍNH giá trị
  // MỚI, khiến điều kiện "vừa đạt" không bao giờ đúng. Phải gán TRỰC TIẾP
  // trong `initState()` để chốt đúng giá trị TẠI THỜI ĐIỂM khởi tạo.
  late bool _wasAchieved;

  @override
  void initState() {
    super.initState();
    _wasAchieved = widget.progress.isAchieved;
  }

  @override
  void didUpdateWidget(covariant _SavingsGoalTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final justAchieved = !_wasAchieved && widget.progress.isAchieved;
    _wasAchieved = widget.progress.isAchieved;
    if (justAchieved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCelebration(widget.progress.goal.name);
      });
    }
  }

  void _showCelebration(String goalName) {
    showDialog<void>(
      context: context,
      builder: (context) => _GoalCelebrationDialog(goalName: goalName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final goal = progress.goal;
    final target = Money(
      minorUnits: goal.targetAmountMinor,
      currency: goal.currency,
      currencyScale: goal.currencyScale,
    );
    final saved = Money(
      minorUnits: progress.savedMinor,
      currency: goal.currency,
      currencyScale: goal.currencyScale,
    );

    return AppCard(
      onTap: () => showSavingsGoalEditSheet(
        context: context,
        existingId: goal.id,
        existingName: goal.name,
        existingTargetAmountMinor: goal.targetAmountMinor,
        existingTargetDate: goal.targetDate,
      ),
      child: Row(
        children: [
          ProgressRing(
            progress: progress.progressFraction,
            ringColor: progress.isAchieved
                ? context.colors.budgetOk
                : context.scheme.primary,
            trackColor: context.colors.hairline,
            size: 64,
            strokeWidth: 7,
          ),
          SizedBox(width: context.space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.name, style: context.text.titleMedium),
                SizedBox(height: context.space.xxs),
                Text(
                  AmountVisibility.mask(
                    context,
                    '${saved.format()} / ${target.format()}',
                  ),
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                if (progress.isAchieved) ...[
                  SizedBox(height: context.space.xxs),
                  Text(
                    'Đã đạt mục tiêu',
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.budgetOk,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Nạp vào mục tiêu (ví trừ tiền)',
            icon: const Icon(kIconAddCircle),
            onPressed: () => showTransactionFormSheet(
              context: context,
              prefill: TransactionFormPrefill.forGoalContribution(
                goalId: goal.id,
                goalName: goal.name,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Rút về ví (mục tiêu giảm)',
            icon: const Icon(kIconUndo),
            onPressed: () => showTransactionFormSheet(
              context: context,
              prefill: TransactionFormPrefill.forGoalWithdrawal(
                goalId: goal.id,
                goalName: goal.name,
              ),
            ),
          ),
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => ref
                    .read(savingsGoalRepositoryProvider)
                    .setArchived(goal.id, true),
                child: const Text('Lưu trữ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Khoảnh khắc ăn mừng (Phase 22, Hướng 3 một phần) — mascot `celebrate` +
/// icon 3D chọn lọc (🎉🏆, MIT — xem `assets/icons3d/NOTICE.md`). Chỉ hiện
/// MỘT LẦN đúng lúc chuyển sang đạt mục tiêu (xem `_SavingsGoalTileState`),
/// không phải mỗi lần mở màn.
class _GoalCelebrationDialog extends StatelessWidget {
  const _GoalCelebrationDialog({required this.goalName});

  final String goalName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.xl),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppMascot(mood: MascotMood.celebrate, size: 96),
            SizedBox(height: context.space.lg),
            Text(
              'Đã đạt mục tiêu!',
              style: context.text.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.space.xs),
            Text(
              goalName,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.space.xl),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tuyệt vời'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtsTab extends ConsumerWidget {
  const _DebtsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(activeDebtsWithProgressProvider);
    final archivedAsync = ref.watch(archivedDebtsProvider);

    return progressAsync.when(
      data: (debts) {
        final archived = archivedAsync.value ?? const <Debt>[];
        if (debts.isEmpty && archived.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: kIconHandshake,
              title: 'Chưa có khoản vay/cho vay nào',
              message: 'Bấm "+" để thêm khoản đầu tiên.',
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.all(context.space.screenHorizontal),
          children: [
            for (final progress in debts) _DebtTile(progress: progress),
            if (archived.isNotEmpty) ...[
              SizedBox(height: context.space.lg),
              Text('Đã lưu trữ', style: context.text.titleMedium),
              SizedBox(height: context.space.sm),
              for (final debt in archived)
                _ArchivedTile(
                  title: debt.counterpartyName,
                  onRestore: () => ref
                      .read(debtRepositoryProvider)
                      .setArchived(debt.id, false),
                ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Lỗi: $error')),
    );
  }
}

class _DebtTile extends ConsumerWidget {
  const _DebtTile({required this.progress});

  final DebtProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debt = progress.debt;
    final principal = Money(
      minorUnits: debt.principalMinor,
      currency: debt.currency,
      currencyScale: debt.currencyScale,
    );
    final remaining = Money(
      minorUnits: progress.remainingMinor,
      currency: debt.currency,
      currencyScale: debt.currencyScale,
    );
    final isDebtIOwe = progress.kind == DebtKind.debt;

    return AppCard(
      onTap: () => showDebtEditSheet(
        context: context,
        existingId: debt.id,
        existingCounterpartyName: debt.counterpartyName,
        existingKind: progress.kind,
        existingPrincipalMinor: debt.principalMinor,
        existingStartDate: debt.startDate,
      ),
      child: Row(
        children: [
          ProgressRing(
            progress: progress.progressFraction,
            ringColor: progress.isSettled
                ? context.colors.budgetOk
                : context.scheme.primary,
            trackColor: context.colors.hairline,
            size: 64,
            strokeWidth: 7,
          ),
          SizedBox(width: context.space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(debt.counterpartyName, style: context.text.titleMedium),
                SizedBox(height: context.space.xxs),
                Text(
                  progress.kind.label,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: context.space.xxs),
                Text(
                  AmountVisibility.mask(
                    context,
                    progress.isSettled
                        ? 'Đã tất toán / ${principal.format()}'
                        : 'Còn ${remaining.format()} / ${principal.format()}',
                  ),
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isDebtIOwe ? 'Trả nợ' : 'Thu nợ',
            icon: const Icon(kIconAddCircle),
            onPressed: () => showTransactionFormSheet(
              context: context,
              prefill: TransactionFormPrefill.forDebtContribution(
                debtId: debt.id,
                debtName: debt.counterpartyName,
                isDebtIOwe: isDebtIOwe,
              ),
            ),
          ),
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () =>
                    ref.read(debtRepositoryProvider).setArchived(debt.id, true),
                child: const Text('Lưu trữ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArchivedTile extends StatelessWidget {
  const _ArchivedTile({required this.title, required this.onRestore});

  final String title;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: context.colors.onSurfaceVariant),
      ),
      trailing: TextButton(
        onPressed: onRestore,
        child: const Text('Khôi phục'),
      ),
    );
  }
}
