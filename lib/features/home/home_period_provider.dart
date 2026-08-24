import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/clock_provider.dart';
import '../budgets/domain/budget_period.dart';
import '../reports/domain/report_range.dart';
import '../settings/settings_controller.dart';

/// Kỳ đang xem ở Trang chủ. Mặc định "Tháng này".
enum HomePeriodPreset {
  today('Hôm nay'),
  thisMonth('Tháng này'),
  thisYear('Năm nay'),
  // Bắt buộc phải có kể từ khi tab Giao dịch lọc theo kỳ: không có mốc này
  // thì muốn xem một khoản của năm ngoái phải tự bấm ra đúng hai ngày trong
  // lịch. Rolly cũng có ("Mọi thời gian").
  allTime('Mọi thời gian'),
  custom('Khoảng tuỳ chọn…');

  const HomePeriodPreset(this.label);
  final String label;
}

class HomePeriod {
  const HomePeriod({
    required this.preset,
    required this.range,
    required this.label,
  });

  final HomePeriodPreset preset;
  final ReportRange range;

  /// Nhãn hiện trên chip — KHÁC `preset.label` ở hai ca: kỳ tháng có ngày
  /// neo (hiện "5/8 – 4/9" thay vì "Tháng này", vì "tháng" lúc đó không
  /// trùng tháng lịch) và khoảng tuỳ chọn (hiện chính hai ngày).
  final String label;
}

/// Kỳ của Trang chủ.
///
/// "Tháng này" ĐI THEO NGÀY NEO trong Cài đặt (`budgetAnchorDay`): đặt ngày
/// 5 thì kỳ chạy 5/8 → 4/9, không phải 1/8 → 31/8. Dùng lại đúng
/// [BudgetPeriod] mà màn Ngân sách đã dùng — hai chỗ cùng nói "tháng" mà
/// hiểu khác nhau là cách chắc chắn nhất để hai màn ra hai con số khác nhau
/// rồi không ai biết cái nào đúng.
class HomePeriodController extends Notifier<HomePeriod> {
  @override
  HomePeriod build() {
    final now = ref.watch(clockProvider).now();
    final anchorDay = ref.watch(appSettingsProvider).budgetAnchorDay;
    return _forPreset(HomePeriodPreset.thisMonth, now, anchorDay);
  }

  void setPreset(HomePeriodPreset preset) {
    final now = ref.read(clockProvider).now();
    final anchorDay = ref.read(appSettingsProvider).budgetAnchorDay;
    state = _forPreset(preset, now, anchorDay);
  }

  /// `end` cộng thêm một ngày để thành nửa khoảng `[start, end)` — chọn
  /// "1/8 đến 31/8" mà không cộng sẽ LOẠI HẾT giao dịch ngày 31.
  void setCustomRange(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day + 1);
    state = HomePeriod(
      preset: HomePeriodPreset.custom,
      range: ReportRange(start: s, end: e),
      label: _formatRange(s, e),
    );
  }

  static HomePeriod _forPreset(
    HomePeriodPreset preset,
    DateTime now,
    int anchorDay,
  ) {
    switch (preset) {
      case HomePeriodPreset.today:
        final start = DateTime(now.year, now.month, now.day);
        return HomePeriod(
          preset: preset,
          range: ReportRange(
            start: start,
            end: start.add(const Duration(days: 1)),
          ),
          label: preset.label,
        );
      case HomePeriodPreset.thisMonth:
        final period = BudgetPeriod.of(now, anchorDay: anchorDay);
        return HomePeriod(
          preset: preset,
          range: ReportRange(start: period.start, end: period.end),
          label: anchorDay == 1 ? preset.label : period.label,
        );
      case HomePeriodPreset.thisYear:
        return HomePeriod(
          preset: preset,
          range: ReportRange(
            start: DateTime(now.year),
            end: DateTime(now.year + 1),
          ),
          label: preset.label,
        );
      case HomePeriodPreset.allTime:
        // Cùng biên với `ReportRange.preset(allTime)`: mốc 2000 làm đáy
        // (không giao dịch nào cũ hơn) và HẾT hôm nay làm đỉnh — không lấy
        // `now` trần, nếu không thì mọi khoản ghi cho hôm nay nhưng giờ
        // muộn hơn thời điểm dựng provider sẽ rơi ra ngoài.
        return HomePeriod(
          preset: preset,
          range: ReportRange(
            start: DateTime(2000),
            end: DateTime(now.year, now.month, now.day + 1),
          ),
          label: preset.label,
        );
      case HomePeriodPreset.custom:
        // Không có khoảng cố định — giữ nguyên tháng này cho tới khi Tony
        // chọn hai đầu qua `setCustomRange`.
        return _forPreset(HomePeriodPreset.thisMonth, now, anchorDay);
    }
  }

  static String _formatRange(DateTime start, DateTime endExclusive) {
    final last = endExclusive.subtract(const Duration(days: 1));
    final sameYear = start.year == last.year;
    final s = sameYear
        ? '${start.day}/${start.month}'
        : '${start.day}/${start.month}/${start.year}';
    return '$s – ${last.day}/${last.month}/${last.year}';
  }
}

final homePeriodProvider = NotifierProvider<HomePeriodController, HomePeriod>(
  HomePeriodController.new,
);
