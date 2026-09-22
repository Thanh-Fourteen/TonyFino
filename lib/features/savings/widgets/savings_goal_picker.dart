import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../data/db/database.dart';
import '../../../theme/context_ext.dart';
import '../../../ui/amount_visibility.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../../../ui/category_avatar.dart';
import '../domain/savings_goal_progress.dart';
import '../savings_providers.dart';
import 'savings_contribution_sheet.dart';

/// Mở luồng "nạp tiền vào quỹ" từ một chỗ KHÔNG biết trước quỹ nào (chip ở
/// màn chat).
///
/// Không quỹ nào → không làm gì (chip gọi hàm này đã tự ẩn khi sổ chưa có
/// quỹ). ĐÚNG MỘT quỹ → vào thẳng sheet nạp, không bắt chọn giữa một lựa
/// chọn. Từ hai trở lên → hỏi quỹ nào trước. Cùng nguyên tắc "một lựa chọn
/// thì đừng hỏi" mà bộ chọn ví trong form ghi khoản đang dùng.
Future<void> openSavingsDepositFlow(BuildContext context, WidgetRef ref) async {
  final goals =
      ref.read(activeSavingsGoalsWithProgressProvider).value ??
      const <SavingsGoalProgress>[];
  if (goals.isEmpty) return;

  var picked = goals.first;
  if (goals.length > 1) {
    final chosen = await showAppBottomSheet<SavingsGoalProgress>(
      context: context,
      builder: (sheetContext) => _GoalPickerSheet(goals: goals),
    );
    if (chosen == null || !context.mounted) return;
    picked = chosen;
  }

  if (!context.mounted) return;
  await showSavingsContributionSheet(
    context: context,
    goalId: picked.goal.id,
    goalName: picked.goal.name,
    move: SavingsMove.deposit,
    savedMinor: picked.savedMinor,
    targetAmountMinor: picked.goal.targetAmountMinor,
  );
}

class _GoalPickerSheet extends StatelessWidget {
  const _GoalPickerSheet({required this.goals});

  final List<SavingsGoalProgress> goals;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.space.screenHorizontal,
              context.space.lg,
              context.space.screenHorizontal,
              context.space.sm,
            ),
            child: Text('Nạp vào quỹ nào?', style: context.text.titleLarge),
          ),
          // 🚨 Danh sách quỹ PHẢI cuộn được, và sheet phải được phép cao
          // quá 9/16 màn hình.
          //
          // Trước đây đây là một `Column` thẳng đuột trong một sheet mở với
          // `isScrollControlled: false`: Material kẹp chiều cao ở 9/16 màn
          // hình, nên từ hũ thứ bảy trở đi danh sách tràn ra ngoài và
          // KHÔNG vuốt được — đúng lỗi Tony báo ("nhiều hơn 6 quỹ không
          // vuốt chọn được"). `Flexible` + `ListView` để sheet vừa cao hết
          // mức `showAppBottomSheet` cho phép (92% màn hình), vừa cuộn khi
          // còn thiếu chỗ; `shrinkWrap` giữ sheet ÔM SÁT danh sách khi chỉ
          // có vài quỹ, không kéo dài ra chiếm cả màn hình.
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.only(bottom: context.space.sm),
              itemCount: goals.length,
              itemBuilder: (context, i) {
                final progress = goals[i];
                return ListTile(
                  leading: const CategoryAvatar(
                    categoryColorId: 11,
                    iconCode: 'savings',
                    size: 36,
                  ),
                  title: Text(progress.goal.name),
                  subtitle: Text(
                    AmountVisibility.mask(
                      context,
                      '${_money(progress.goal, progress.savedMinor).format()} / '
                      '${_money(progress.goal, progress.goal.targetAmountMinor).format()}',
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(progress),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Money _money(SavingsGoal goal, int minorUnits) => Money(
    minorUnits: minorUnits,
    currency: goal.currency,
    currencyScale: goal.currencyScale,
  );
}
