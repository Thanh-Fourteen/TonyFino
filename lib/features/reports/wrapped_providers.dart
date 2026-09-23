import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../../data/repositories/reports_repository.dart';
import '../transactions/domain/entry_streak.dart';
import '../transactions/transactions_providers.dart';
import 'domain/category_slice.dart';
import 'domain/report_range.dart';

/// "TonyFino Wrapped" — LUÔN đúng năm hiện tại theo `Clock`, KHÔNG đọc
/// `reportFilterProvider`: đây là thẻ tổng kết năm cố định, không phải một
/// chế độ xem khác của tab Báo cáo đang lọc theo khoảng Tony tự chọn.
final wrappedYearRangeProvider = Provider<ReportRange>((ref) {
  final now = ref.watch(clockProvider).now();
  return ReportRange.preset(ReportRangePreset.thisYear, now);
});

final wrappedCategoryBreakdownProvider =
    StreamProvider<List<CategorySourceAmount>>((ref) {
      final range = ref.watch(wrappedYearRangeProvider);
      return ref
          .watch(reportsRepositoryProvider)
          .watchCategoryBreakdown(range);
    });

final wrappedSummaryProvider = StreamProvider<PeriodSummary>((ref) {
  final range = ref.watch(wrappedYearRangeProvider);
  return ref.watch(reportsRepositoryProvider).watchPeriodSummary(range);
});

/// Chuỗi ngày ghi giao dịch DÀI NHẤT trong năm — TÁI DÙNG
/// [transactionsWithCategoryProvider] (không viết query riêng), lọc xuống
/// đúng năm rồi đưa qua [computeLongestStreakDays]. Cùng cách tiếp cận với
/// `entryStreakProvider` (Phase 22): kéo về Dart chấp nhận được vì đã lọc
/// sẵn xuống một năm, không phải toàn bộ sổ cái.
final wrappedLongestStreakProvider = Provider<int>((ref) {
  final transactions = ref.watch(transactionsWithCategoryProvider).value;
  if (transactions == null) return 0;
  final range = ref.watch(wrappedYearRangeProvider);
  final datesInYear = transactions
      .map((t) => t.transaction.occurredAt)
      .where((d) => !d.isBefore(range.start) && d.isBefore(range.end));
  return computeLongestStreakDays(datesInYear);
});
