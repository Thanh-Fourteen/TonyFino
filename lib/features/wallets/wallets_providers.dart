import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/wallet_repository.dart';

final activeWalletsProvider = StreamProvider<List<Wallet>>((ref) {
  return ref.watch(walletRepositoryProvider).watchActive();
});

final archivedWalletsProvider = StreamProvider<List<Wallet>>((ref) {
  return ref.watch(walletRepositoryProvider).watchArchived();
});

final activeWalletBalancesProvider = StreamProvider<List<WalletBalance>>((ref) {
  return ref.watch(walletRepositoryProvider).watchActiveBalances();
});
