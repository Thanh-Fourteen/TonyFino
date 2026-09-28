import 'package:flutter/foundation.dart';

/// Một điểm trên đường giá — [value] ở ĐÚNG đơn vị của nguồn (đồng/lượng,
/// USD/ounce, USD/tấn…), đơn vị do nơi gọi mang theo.
///
/// `double` có chủ đích: đây là giá THỊ TRƯỜNG để xem, không phải tiền trong
/// sổ của Tony — luật "tiền là int minor units" áp cho số dư/giao dịch lưu
/// trong DB, còn giá thế giới vốn có phần lẻ (4182.2 USD/oz, 3.9 US cent).
/// Không bao giờ ghi xuống DB.
@immutable
class PricePoint {
  const PricePoint(this.time, this.value);

  final DateTime time;
  final double value;
}

/// Khoảng thời gian của biểu đồ — nút chọn ở đầu mọi biểu đồ giá.
enum ChartSpan {
  week('7N', 7),
  month('1T', 30),
  quarter('3T', 90),
  year('1N', 365);

  const ChartSpan(this.label, this.days);
  final String label;
  final int days;
}

/// Giữ điểm trong [span] ngày tính NGƯỢC từ điểm mới nhất (không từ "hôm
/// nay" — thứ Bảy/Chủ nhật sàn đóng, neo vào hôm nay thì 7N chỉ còn 5 điểm
/// mà trông như thiếu dữ liệu).
List<PricePoint> pointsInSpan(List<PricePoint> points, ChartSpan span) {
  if (points.isEmpty) return points;
  final latest = points.last.time;
  final cutoff = latest.subtract(Duration(days: span.days));
  return [
    for (final p in points)
      if (!p.time.isBefore(cutoff)) p,
  ];
}

/// Khoảng đang xem trên biểu đồ: một nút có sẵn ([preset]) HOẶC một khoảng
/// ngày Tony tự chọn ([from]–[to], tính cả hai đầu).
@immutable
class ChartWindow {
  const ChartWindow.preset(ChartSpan this.preset) : from = null, to = null;
  const ChartWindow.custom(DateTime this.from, DateTime this.to)
    : preset = null;

  final ChartSpan? preset;
  final DateTime? from;
  final DateTime? to;

  bool get isCustom => preset == null;

  @override
  bool operator ==(Object other) =>
      other is ChartWindow &&
      other.preset == preset &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(preset, from, to);
}

/// Lọc điểm theo [window]. Khoảng tự chọn so theo NGÀY (bỏ giờ): chọn
/// "tới 25/9" thì điểm lúc 00:00 hay 23:38 ngày 25/9 đều được tính.
List<PricePoint> pointsInWindow(List<PricePoint> points, ChartWindow window) {
  final preset = window.preset;
  if (preset != null) return pointsInSpan(points, preset);
  final from = _day(window.from!);
  final to = _day(window.to!);
  return [
    for (final p in points)
      if (!_day(p.time).isBefore(from) && !_day(p.time).isAfter(to)) p,
  ];
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
