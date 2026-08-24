/// Khoảng ngày lọc cho toàn màn Báo cáo — kiểu thuần Dart, KHÔNG dùng
/// `DateTimeRange` của `material.dart` để domain không phụ thuộc UI framework
/// (cùng triết lý với `lib/features/settings/import/domain/`).
class ReportRange {
  const ReportRange({required this.start, required this.end});

  /// Bao gồm — nửa khoảng `[start, end)` khi lọc SQL (khớp cách
  /// `TransactionRepository.watchMonthToDateSummary` đã dùng).
  final DateTime start;
  final DateTime end;

  static const _presetDays = {
    ReportRangePreset.last7Days: 7,
    ReportRangePreset.last30Days: 30,
    ReportRangePreset.last3Months: 90,
    ReportRangePreset.last6Months: 182,
  };

  /// `now` luôn đến từ `Clock` inject ở tầng gọi (provider), KHÔNG BAO GIỜ
  /// `DateTime.now()` ở đây (Luật #3).
  ///
  /// [ReportRangePreset.custom] KHÔNG tự tính được khoảng nào — nó chỉ là
  /// nhãn cho khoảng Tony tự chọn, nên gọi vào đây với nó là lỗi lập trình
  /// (call site phải dùng `setCustomRange`).
  factory ReportRange.preset(ReportRangePreset preset, DateTime now) {
    final end = DateTime(now.year, now.month, now.day + 1); // hết hôm nay
    switch (preset) {
      case ReportRangePreset.budgetPeriod:
        throw ArgumentError(
          'ReportRangePreset.budgetPeriod cần NGÀY NEO trong Cài đặt, không '
          'tính được từ mỗi `now` — xem ReportFilterController.setPreset.',
        );
      case ReportRangePreset.custom:
        throw ArgumentError(
          'ReportRangePreset.custom không có khoảng cố định — dùng '
          'ReportFilterController.setCustomRange.',
        );
      case ReportRangePreset.allTime:
        return ReportRange(start: DateTime(2000), end: end);
      // Ba mốc dưới đây neo theo LỊCH, không phải "N ngày qua": "tháng này"
      // là từ ngày 1 tới hết hôm nay, không phải 30 ngày gần nhất. Hai thứ
      // đó khác hẳn nhau vào giữa tháng, và người dùng hỏi "tháng này" là
      // hỏi theo lịch.
      case ReportRangePreset.today:
        return ReportRange(
          start: DateTime(now.year, now.month, now.day),
          end: end,
        );
      case ReportRangePreset.thisMonth:
        return ReportRange(start: DateTime(now.year, now.month), end: end);
      case ReportRangePreset.thisYear:
        return ReportRange(start: DateTime(now.year), end: end);
      case ReportRangePreset.last7Days:
      case ReportRangePreset.last30Days:
      case ReportRangePreset.last3Months:
      case ReportRangePreset.last6Months:
        return ReportRange(
          start: end.subtract(Duration(days: _presetDays[preset]!)),
          end: end,
        );
    }
  }

  ReportRange copyWith({DateTime? start, DateTime? end}) {
    return ReportRange(start: start ?? this.start, end: end ?? this.end);
  }

  @override
  bool operator ==(Object other) =>
      other is ReportRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

enum ReportRangePreset {
  today('Hôm nay'),
  last7Days('7 ngày qua'),
  last30Days('30 ngày qua'),
  thisMonth('Tháng này'),

  /// Kỳ ngân sách hiện tại — chạy theo NGÀY NEO trong Cài đặt (vd đặt ngày 5
  /// thì kỳ là 5/8 → 4/9), khác hẳn [thisMonth] là tháng lịch.
  ///
  /// Khoảng của mốc này KHÔNG tính được ở đây: `ReportRange.preset` là hàm
  /// thuần chỉ biết `now`, còn ngày neo nằm trong Cài đặt.
  /// `ReportFilterController.setPreset` xử lý riêng mốc này — xem chỗ đó.
  budgetPeriod('Kỳ ngân sách này'),
  last3Months('3 tháng qua'),
  last6Months('6 tháng qua'),
  thisYear('Năm nay'),
  allTime('Tất cả'),

  /// Khoảng do Tony tự chọn hai đầu — nhãn hiển thị được thay bằng chính
  /// hai ngày đó ở thanh lọc, nên chữ này chỉ xuất hiện trong menu.
  custom('Khoảng tuỳ chọn…');

  const ReportRangePreset(this.label);
  final String label;
}
