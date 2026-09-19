import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/transaction_repository.dart';
import 'domain/debt_progress.dart';
import 'domain/savings_goal_progress.dart';

final activeSavingsGoalsProvider = StreamProvider<List<SavingsGoal>>((ref) {
  return ref.watch(savingsGoalRepositoryProvider).watchActive();
});

final archivedSavingsGoalsProvider = StreamProvider<List<SavingsGoal>>((ref) {
  return ref.watch(savingsGoalRepositoryProvider).watchArchived();
});

final activeSavingsGoalsWithProgressProvider =
    StreamProvider<List<SavingsGoalProgress>>((ref) {
      return ref.watch(savingsGoalRepositoryProvider).watchActiveWithProgress();
    });

final activeDebtsProvider = StreamProvider<List<Debt>>((ref) {
  return ref.watch(debtRepositoryProvider).watchActive();
});

final archivedDebtsProvider = StreamProvider<List<Debt>>((ref) {
  return ref.watch(debtRepositoryProvider).watchArchived();
});

final activeDebtsWithProgressProvider = StreamProvider<List<DebtProgress>>((
  ref,
) {
  return ref.watch(debtRepositoryProvider).watchActiveWithProgress();
});

/// Tiến độ của MỘT quỹ — lọc ra từ chính stream `watchActiveWithProgress`
/// đang chạy cho danh sách, KHÔNG mở thêm một query riêng: hai nguồn cho cùng
/// một con số là hai chỗ để nó trôi khỏi nhau. `null` khi quỹ vừa bị lưu trữ
/// hoặc không còn (màn chi tiết tự hiện trạng thái rỗng).
final savingsGoalProgressProvider =
    StreamProvider.family<SavingsGoalProgress?, int>((ref, goalId) {
      return ref
          .watch(savingsGoalRepositoryProvider)
          .watchActiveWithProgress()
          .map((all) {
            for (final progress in all) {
              if (progress.goal.id == goalId) return progress;
            }
            return null;
          });
    });

/// Lịch sử nạp/rút của MỘT quỹ, mới nhất trước — nguồn cho màn
/// `SavingsGoalDetailScreen`.
final savingsGoalHistoryProvider =
    StreamProvider.family<List<TransactionWithCategory>, int>((ref, goalId) {
      return ref
          .watch(transactionRepositoryProvider)
          .watchAllWithCategory(goalId: goalId);
    });
