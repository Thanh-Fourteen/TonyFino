import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/jar_repository.dart';
import '../home/home_period_provider.dart';
import '../wallets/selected_wallet_provider.dart';

/// Hũ của ví đang chọn (v13) — cùng phạm vi "một ví" với danh mục.
final jarsProvider = StreamProvider<List<Jar>>((ref) {
  final walletId = ref.watch(selectedWalletIdProvider);
  if (walletId == null) return Stream.value(const <Jar>[]);
  return ref.watch(jarRepositoryProvider).watchActive(walletId);
});

/// Hũ + số liệu của KỲ ĐANG XEM ở Trang chủ.
///
/// Cố ý dùng chung `homePeriodProvider` thay vì một bộ chọn kỳ riêng: hũ
/// chia thu nhập THEO KỲ, nên nếu Trang chủ đang xem "05/08 – 04/09" mà màn
/// Hũ lại tính theo tháng lịch thì hai màn ra hai con số và không ai biết
/// cái nào đúng.
final jarProgressProvider = StreamProvider<List<JarProgress>>((ref) {
  final walletId = ref.watch(selectedWalletIdProvider);
  if (walletId == null) return Stream.value(const <JarProgress>[]);
  final period = ref.watch(homePeriodProvider);
  return ref
      .watch(jarRepositoryProvider)
      .watchProgress(
        walletId: walletId,
        start: period.range.start,
        end: period.range.end,
      );
});
