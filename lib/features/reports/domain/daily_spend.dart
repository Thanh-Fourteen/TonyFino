/// Tổng chi MỘT NGÀY đã gộp SQL theo lịch VN (`occurredAt.modify(localTime())`,
/// cùng lý do timezone ở `monthly_total.dart`).
class DailySpend {
  const DailySpend({required this.date, required this.expenseMinor});

  /// Nửa đêm (00:00) của ngày đó, local — chỉ dùng để so khớp ô lưới.
  final DateTime date;

  /// Luôn ≤ 0.
  final int expenseMinor;
}

/// Một ô trong lưới heatmap 7×N. `date == null` là ô đệm (trước/sau khoảng
/// lọc, cần có để lưới luôn tròn tuần Thứ Hai→Chủ Nhật) — vẽ trống, không
/// tính bậc cường độ.
class HeatmapCell {
  const HeatmapCell({this.date, this.expenseMinor = 0, this.level = 0});

  final DateTime? date;
  final int expenseMinor;

  /// 0–4, chỉ số vào `context.colors.heatmapScale` (5 bậc, xem design system).
  /// 0 vừa là "không chi tiêu" vừa là bậc nhạt nhất — KHÔNG có màu trung tính
  /// riêng cho "0 đồng", đúng ý "5 bậc cường độ VND" của đặc tả (không phải
  /// "4 bậc + 1 màu nền").
  final int level;
}

/// Bậc cường độ TƯƠNG ĐỐI so với ngày chi nhiều nhất trong khoảng đang xem —
/// không phải ngưỡng VND cố định, vì chi tiêu một người dao động quá rộng để
/// một ngưỡng tuyệt đối có nghĩa cho cả tháng ăn uống bình thường lẫn tháng
/// vừa mua xe. Thuần hàm, test được không cần DB.
int spendLevel(int amountMinor, int maxAmountMinor) {
  final amount = amountMinor.abs();
  final max = maxAmountMinor.abs();
  if (amount <= 0 || max <= 0) return 0;
  final ratio = amount / max;
  if (ratio <= 0.25) return 1;
  if (ratio <= 0.5) return 2;
  if (ratio <= 0.75) return 3;
  return 4;
}

/// Xếp [daily] thành lưới tuần Thứ Hai→Chủ Nhật (7 cột), đệm ô trống ở đầu
/// tuần đầu và cuối tuần cuối để lưới luôn tròn — heatmap kiểu "đóng góp"
/// quen mắt (GitHub-style), không phải chỉ liệt kê đúng số ngày trong khoảng.
List<List<HeatmapCell>> buildHeatmapWeeks(
  List<DailySpend> daily, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final byDate = {for (final d in daily) _dayKey(d.date): d};
  final maxAmount = daily.isEmpty
      ? 0
      : daily.map((d) => d.expenseMinor.abs()).reduce((a, b) => a > b ? a : b);

  final firstDay = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
  // rangeEnd là biên loại trừ (nửa khoảng [start, end)) — ngày cuối cùng THẬT
  // sự thuộc khoảng là end trừ 1 ngày.
  final lastDay = DateTime(
    rangeEnd.year,
    rangeEnd.month,
    rangeEnd.day,
  ).subtract(const Duration(days: 1));

  // DateTime.weekday: 1 = Thứ Hai .. 7 = Chủ Nhật — khớp thẳng cột lưới.
  final gridStart = firstDay.subtract(Duration(days: firstDay.weekday - 1));
  final gridEnd = lastDay.add(Duration(days: 7 - lastDay.weekday));

  final weeks = <List<HeatmapCell>>[];
  var cursor = gridStart;
  while (!cursor.isAfter(gridEnd)) {
    final week = <HeatmapCell>[];
    for (var i = 0; i < 7; i++) {
      final inRange = !cursor.isBefore(firstDay) && !cursor.isAfter(lastDay);
      if (!inRange) {
        week.add(const HeatmapCell());
      } else {
        final spend = byDate[_dayKey(cursor)];
        final amount = spend?.expenseMinor ?? 0;
        week.add(
          HeatmapCell(
            date: cursor,
            expenseMinor: amount,
            level: spendLevel(amount, maxAmount),
          ),
        );
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    weeks.add(week);
  }
  return weeks;
}

DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
