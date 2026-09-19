import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/amount_visibility.dart';
import '../../ui/app_card.dart';
import '../../ui/day_header.dart';
import '../../ui/empty_state.dart';
import '../../ui/progress_ring.dart';
import '../../ui/transaction_row.dart';
import '../transactions/day_label.dart';
import '../transactions/domain/day_groups.dart';
import '../transactions/domain/transaction_row_display.dart';
import '../transactions/transaction_form_sheet.dart';
import '../transactions/transactions_providers.dart';
import 'domain/savings_goal_progress.dart';
import 'savings_providers.dart';
import 'widgets/savings_contribution_sheet.dart';
import 'widgets/savings_goal_edit_sheet.dart';

/// Cửa duy nhất để mở [SavingsGoalDetailScreen].
void openSavingsGoalDetailScreen(BuildContext context, int goalId) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => SavingsGoalDetailScreen(goalId: goalId),
    ),
  );
}

/// Một quỹ: tiến độ ở trên, LỊCH SỬ nạp/rút ở dưới.
///
/// 🚨 Trước bản này không có màn nào như thế, và đó là lỗ hổng Tony chỉ ra:
/// *"lịch sử cũng khó xem"*. Bấm vào thẻ quỹ chỉ mở sheet sửa tên/số tiền cần
/// đạt — không có đường nào xem một quỹ đã nạp/rút những gì, cũng không có
/// đường nào sửa một lần nạp sai ngoài việc mò trong danh sách giao dịch
/// chung, nơi mọi khoản quỹ khi ấy đều đội lốt "Chưa phân loại".
///
/// Tiến độ vẫn là `SavingsGoalProgress` (SQL aggregate, D7) chứ không cộng
/// tay từ danh sách bên dưới: hai con số phải là CÙNG một nguồn, nếu không
/// thì đúng một chỗ sẽ trôi và không ai biết chỗ nào đúng.
class SavingsGoalDetailScreen extends ConsumerWidget {
  const SavingsGoalDetailScreen({super.key, required this.goalId});

  final int goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(savingsGoalProgressProvider(goalId));
    final progress = progressAsync.value;
    final goal = progress?.goal;

    return Scaffold(
      appBar: AppBar(
        title: Text(goal?.name ?? 'Quỹ'),
        actions: [
          if (goal != null)
            PopupMenuButton<_GoalAction>(
              onSelected: (action) => switch (action) {
                _GoalAction.edit => showSavingsGoalEditSheet(
                  context: context,
                  existingId: goal.id,
                  existingName: goal.name,
                  existingTargetAmountMinor: goal.targetAmountMinor,
                  existingTargetDate: goal.targetDate,
                ),
                _GoalAction.archive => _archive(context, ref, goal.id),
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _GoalAction.edit,
                  child: Text('Sửa mục tiêu'),
                ),
                PopupMenuItem(
                  value: _GoalAction.archive,
                  child: Text('Lưu trữ'),
                ),
              ],
            ),
        ],
      ),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Lỗi: $error')),
        data: (progress) {
          if (progress == null) {
            return const Center(
              child: EmptyState(
                icon: kIconFlag,
                title: 'Không tìm thấy quỹ này',
                message: 'Có thể nó vừa bị lưu trữ ở màn khác.',
              ),
            );
          }
          return _Body(progress: progress);
        },
      ),
    );
  }

  void _archive(BuildContext context, WidgetRef ref, int id) {
    ref.read(savingsGoalRepositoryProvider).setArchived(id, true);
    Navigator.of(context).pop();
  }
}

enum _GoalAction { edit, archive }

class _Body extends ConsumerWidget {
  const _Body({required this.progress});

  final SavingsGoalProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = progress.goal;
    final historyAsync = ref.watch(savingsGoalHistoryProvider(goal.id));
    final categories =
        ref.watch(activeCategoriesProvider).value ?? const <Category>[];
    final categoriesById = {for (final c in categories) c.id: c};
    final now = ref.watch(clockProvider).now();

    return ListView(
      padding: EdgeInsets.only(bottom: context.space.xxl),
      children: [
        Padding(
          padding: EdgeInsets.all(context.space.screenHorizontal),
          child: _ProgressCard(progress: progress),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.screenHorizontal,
          ),
          child: Row(
            spacing: context.space.sm,
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showSavingsContributionSheet(
                    context: context,
                    goalId: goal.id,
                    goalName: goal.name,
                    move: SavingsMove.deposit,
                    savedMinor: progress.savedMinor,
                    targetAmountMinor: goal.targetAmountMinor,
                  ),
                  icon: const Icon(kIconAddCircle),
                  label: const Text('Nạp tiền'),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showSavingsContributionSheet(
                    context: context,
                    goalId: goal.id,
                    goalName: goal.name,
                    move: SavingsMove.withdraw,
                    savedMinor: progress.savedMinor,
                    targetAmountMinor: goal.targetAmountMinor,
                  ),
                  icon: const Icon(kIconUndo),
                  label: const Text('Rút về ví'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.space.lg),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.screenHorizontal,
          ),
          child: Text('Lịch sử', style: context.text.titleMedium),
        ),
        SizedBox(height: context.space.xs),
        historyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: EdgeInsets.all(context.space.screenHorizontal),
            child: Text('Lỗi: $error'),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: kIconSavings,
                  title: 'Quỹ này chưa có lần nạp nào',
                  message: 'Bấm "Nạp tiền" để bắt đầu.',
                ),
              );
            }
            return Column(
              children: [
                for (final group in groupTransactionsByDay(items)) ...[
                  // Hiện `-netMinor`: một ngày nạp 2tr đọc ra "+2.000.000"
                  // theo hướng QUỸ TĂNG, không phải theo hướng ví giảm.
                  DayHeader(
                    label: formatDayLabel(group.day, now),
                    netTotal: Money.vnd(-group.netMinor),
                  ),
                  for (final twc in group.items)
                    _HistoryRow(twc: twc, categoriesById: categoriesById),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.twc, required this.categoriesById});

  final TransactionWithCategory twc;
  final Map<int, Category> categoriesById;

  @override
  Widget build(BuildContext context) {
    final row = transactionRowDisplay(twc, categoriesById);
    return TransactionRow(
      categoryColorId: row.categoryColorId,
      iconCode: row.iconCode,
      emoji: row.emoji,
      // Trong CHÍNH màn của một quỹ thì lặp lại tên quỹ ở mọi dòng là thừa —
      // ghi chú của lần nạp đó mới là thứ phân biệt các dòng với nhau.
      title: row.title,
      subtitle: twc.transaction.note,
      amount: Money(
        minorUnits: twc.transaction.amountMinor,
        currency: twc.transaction.currency,
        currencyScale: twc.transaction.currencyScale,
      ),
      // Sửa/xoá một lần nạp đi qua ĐÚNG form giao dịch như mọi khoản khác —
      // form đó nay giữ nguyên `goalId` và hiện rõ "Gắn với quỹ: …".
      onTap: () => showTransactionFormSheet(context: context, existing: twc),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final SavingsGoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    final saved = Money(
      minorUnits: progress.savedMinor,
      currency: goal.currency,
      currencyScale: goal.currencyScale,
    );
    final target = Money(
      minorUnits: goal.targetAmountMinor,
      currency: goal.currency,
      currencyScale: goal.currencyScale,
    );
    final remaining = Money(
      minorUnits: progress.remainingMinor,
      currency: goal.currency,
      currencyScale: goal.currencyScale,
    );
    final percent = (progress.progressFraction * 100).round();

    return AppCard(
      child: Row(
        children: [
          ProgressRing(
            progress: progress.progressFraction,
            ringColor: progress.isAchieved
                ? context.colors.budgetOk
                : context.scheme.primary,
            trackColor: context.colors.hairline,
            size: 72,
            strokeWidth: 8,
          ),
          SizedBox(width: context.space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AmountVisibility.mask(
                    context,
                    '${saved.format()} / ${target.format()}',
                  ),
                  style: context.text.titleMedium,
                ),
                SizedBox(height: context.space.xxs),
                Text(
                  progress.isAchieved
                      ? 'Đã đạt mục tiêu · $percent%'
                      : AmountVisibility.mask(
                          context,
                          'Còn thiếu ${remaining.format()} · $percent%',
                        ),
                  style: context.text.bodyMedium?.copyWith(
                    color: progress.isAchieved
                        ? context.colors.budgetOk
                        : context.colors.onSurfaceVariant,
                  ),
                ),
                if (goal.targetDate != null) ...[
                  SizedBox(height: context.space.xxs),
                  Text(
                    'Hạn: ${_formatDate(goal.targetDate!)}',
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
