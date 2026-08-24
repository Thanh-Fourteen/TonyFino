import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../data/db/database.dart';

final transactionTemplatesProvider = StreamProvider<List<TransactionTemplate>>((
  ref,
) {
  return ref.watch(transactionTemplateRepositoryProvider).watchAll();
});
