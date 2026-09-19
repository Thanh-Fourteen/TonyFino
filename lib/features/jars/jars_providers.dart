import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/jar_repository.dart';
import '../home/home_period_provider.dart';
import '../wallets/selected_wallet_provider.dart';
import '../../data/repositories/transaction_repository.dart';
import '../reports/domain/category_slice.dart';
import '../reports/domain/report_range.dart';
import '../transactions/transactions_providers.dart';
import 'domain/jar_membership.dart';

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
final jarProgressProvider = StreamProvider<JarsOverview>((ref) {
  final walletId = ref.watch(selectedWalletIdProvider);
  if (walletId == null) return Stream.value(JarsOverview.empty);
  final period = ref.watch(homePeriodProvider);
  return ref
      .watch(jarRepositoryProvider)
      .watchProgress(
        walletId: walletId,
        start: period.range.start,
        end: period.range.end,
      );
});

/// Danh mục có hũ HIỆU LỰC là [jarId] — đúng tập `JarRepository` cộng chi.
Set<int> jarCategoryIds(Ref ref, int jarId) => categoryIdsInJar([
  for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
    (id: c.id, parentCategoryId: c.parentCategoryId, jarId: c.jarId),
], jarId);

/// Những giao dịch làm nên con số "đã dùng" của [jar] trong [range] — MỘT
/// định nghĩa cho cả bộ lọc hũ ở tab Giao dịch lẫn màn Chi tiết hũ.
///
/// Hũ TIẾT KIỆM: đúng những lần nạp/rút quỹ gắn kèm. Hũ TIÊU: mọi danh mục
/// có hũ hiệu lực là hũ này, trừ dòng gắn quỹ (nạp quỹ không phải chi).
Stream<List<TransactionWithCategory>> watchJarTransactions(
  Ref ref,
  Jar jar,
  ReportRange range, {
  Set<int>? tagIds,
}) {
  final repo = ref.watch(transactionRepositoryProvider);
  if (jar.jarKind == JarKind.saving) {
    if (jar.goalId == null) return Stream.value(const []);
    return repo.watchAllWithCategory(
      tagIds: tagIds,
      from: range.start,
      to: range.end,
      goalId: jar.goalId,
    );
  }
  final categoryIds = jarCategoryIds(ref, jar.id);
  // Hũ chưa có danh mục nào: lọc bằng tập rỗng. KHÔNG được rơi về "không
  // lọc" (`categoryIds: null`) — thế là hiện CẢ sổ dưới nhãn một hũ rỗng.
  if (categoryIds.isEmpty) return Stream.value(const []);
  return repo.watchAllWithCategory(
    tagIds: tagIds,
    from: range.start,
    to: range.end,
    categoryIds: categoryIds,
    excludeGoalLinked: true,
  );
}

/// Một hũ + số liệu của nó trong kỳ đang xem — lọc ra từ chính
/// [jarProgressProvider], không mở truy vấn thứ hai cho cùng con số.
final jarOverviewEntryProvider = Provider.family<JarProgress?, int>((
  ref,
  jarId,
) {
  final overview = ref.watch(jarProgressProvider).value;
  return overview?.jars.where((p) => p.jar.id == jarId).firstOrNull;
});

/// Giao dịch của một hũ trong kỳ đang xem — nguồn cho màn Chi tiết hũ.
final jarTransactionsProvider =
    StreamProvider.family<List<TransactionWithCategory>, int>((ref, jarId) {
      final jar = (ref.watch(jarsProvider).value ?? const <Jar>[])
          .where((j) => j.id == jarId)
          .firstOrNull;
      if (jar == null) return Stream.value(const []);
      return watchJarTransactions(
        ref,
        jar,
        ref.watch(homePeriodProvider).range,
      );
    });

/// Chi theo từng danh mục THẬT (cha hoặc con) của một hũ tiêu trong kỳ —
/// nguồn cho biểu đồ ở màn Chi tiết hũ. Cùng truy vấn với biểu đồ Trang
/// chủ, chỉ giới hạn trong các danh mục của hũ.
final jarCategoryBreakdownProvider =
    StreamProvider.family<List<CategorySourceAmount>, int>((ref, jarId) {
      final categoryIds = jarCategoryIds(ref, jarId);
      if (categoryIds.isEmpty) return Stream.value(const []);
      return ref
          .watch(reportsRepositoryProvider)
          .watchCategoryBreakdown(
            ref.watch(homePeriodProvider).range,
            categoryIds: categoryIds,
          );
    });
