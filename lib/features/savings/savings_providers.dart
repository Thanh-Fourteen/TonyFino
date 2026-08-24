import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../data/db/database.dart';
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
