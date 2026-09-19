import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../data/repositories/reports_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../reports/domain/category_slice.dart';
import 'home_period_provider.dart';

/// Tổng Thu/Chi của KỲ ĐANG CHỌN ở Trang chủ.
///
/// Dùng `watchPeriodSummary` (đã có sẵn cho màn Báo cáo) thay vì
/// `monthSummaryProvider` cũ — cái đó khoá cứng vào "từ đầu tháng LỊCH tới
/// giờ", không hiểu ngày neo lẫn khoảng tuỳ chọn.
final homeSummaryProvider = StreamProvider<PeriodSummary>((ref) {
  final period = ref.watch(homePeriodProvider);
  return ref.watch(reportsRepositoryProvider).watchPeriodSummary(period.range);
});

/// Chi theo danh mục của KỲ ĐANG CHỌN — nguồn cho thẻ biểu đồ ở Trang chủ.
///
/// Dùng chung `watchCategoryBreakdown` với màn Báo cáo, chỉ khác ở chỗ lấy
/// kỳ từ `homePeriodProvider` thay vì bộ lọc riêng của Báo cáo: hai màn phải
/// ra cùng một con số khi đang cùng một kỳ.
final homeCategoryBreakdownProvider =
    StreamProvider<List<CategorySourceAmount>>((ref) {
      final period = ref.watch(homePeriodProvider);
      return ref
          .watch(reportsRepositoryProvider)
          .watchCategoryBreakdown(period.range);
    });

/// Giao dịch gần nhất TRONG KỲ ĐANG CHỌN — nguồn cho thẻ "Gần đây".
///
/// 🚨 Phải theo kỳ, không lấy "mới nhất mọi thời gian".
///
/// Trước đây thẻ này đọc `transactionsWithCategoryProvider` (không lọc gì
/// cả) trong khi mọi con số khác trên Trang chủ đều theo chip kỳ. Chọn "Hôm
/// nay" thì phần đầu trang nói về hôm nay còn "Gần đây" vẫn liệt kê giao
/// dịch tháng trước — hai thứ cạnh nhau nói về hai khoảng thời gian khác
/// nhau mà không có gì báo, đúng kiểu "nhìn sai sai" mà không chỉ ra được.
final homeRecentTransactionsProvider =
    StreamProvider<List<TransactionWithCategory>>((ref) {
      final period = ref.watch(homePeriodProvider);
      return ref
          .watch(transactionRepositoryProvider)
          .watchAllWithCategory(
            from: period.range.start,
            to: period.range.end,
            limit: 4,
          );
    });

/// Hai nửa của chế độ "gom theo thẻ" cho biểu đồ Trang chủ — cùng kỳ với
/// [homeCategoryBreakdownProvider]. Chỉ được watch khi công tắc đang bật.
final homeUntaggedBreakdownProvider =
    StreamProvider<List<CategorySourceAmount>>((ref) {
      final period = ref.watch(homePeriodProvider);
      return ref
          .watch(reportsRepositoryProvider)
          .watchCategoryBreakdown(period.range, untaggedOnly: true);
    });

final homeTagGroupBreakdownProvider = StreamProvider<List<TagGroupAmount>>((
  ref,
) {
  final period = ref.watch(homePeriodProvider);
  return ref
      .watch(reportsRepositoryProvider)
      .watchTagGroupBreakdown(period.range);
});
