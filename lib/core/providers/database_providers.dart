import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/recurring_transaction_repository.dart';
import '../../data/repositories/debt_repository.dart';
import '../../data/repositories/reports_repository.dart';
import '../../data/repositories/safe_to_spend_repository.dart';
import '../../data/repositories/savings_goal_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/transaction_template_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/repositories/jar_repository.dart';
import '../../data/repositories/note_repository.dart';

/// Mở DB thật xong (async, cần secure storage cho khoá mã hoá — Phase 4) rồi
/// override provider này bằng giá trị đã sẵn TRƯỚC `runApp()` (`bootstrap.dart`).
/// Nhờ vậy mọi provider phía dưới là đồng bộ, không cần `AsyncValue` rải khắp
/// màn hình chỉ vì DB mở bất đồng bộ — và test override thẳng bằng DB bộ nhớ,
/// không đụng `flutter_secure_storage`/platform channel.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider phải được override ở bootstrap.dart trước runApp().',
  );
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(appDatabaseProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(appDatabaseProvider));
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(appDatabaseProvider));
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(appDatabaseProvider));
});

final safeToSpendRepositoryProvider = Provider<SafeToSpendRepository>((ref) {
  return SafeToSpendRepository(ref.watch(appDatabaseProvider));
});

final recurringTransactionRepositoryProvider =
    Provider<RecurringTransactionRepository>((ref) {
      return RecurringTransactionRepository(ref.watch(appDatabaseProvider));
    });

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(appDatabaseProvider));
});

final transactionTemplateRepositoryProvider =
    Provider<TransactionTemplateRepository>((ref) {
      return TransactionTemplateRepository(ref.watch(appDatabaseProvider));
    });

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  return SavingsGoalRepository(ref.watch(appDatabaseProvider));
});

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepository(ref.watch(appDatabaseProvider));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(ref.watch(appDatabaseProvider));
});

final jarRepositoryProvider = Provider<JarRepository>((ref) {
  return JarRepository(ref.watch(appDatabaseProvider));
});

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(ref.watch(appDatabaseProvider));
});
