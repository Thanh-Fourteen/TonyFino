import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../data/db/database.dart';

final activeRecurringTransactionsProvider =
    StreamProvider<List<RecurringTransaction>>((ref) {
      return ref.watch(recurringTransactionRepositoryProvider).watchActive();
    });
