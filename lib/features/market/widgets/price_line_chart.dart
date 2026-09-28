import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../data/services/market/price_point.dart';
import '../../../theme/context_ext.dart';

/// Đường giá theo thời gian — dùng chung cho trang Giá vàng và Giá cà phê.
///
/// MỘT chuỗi, MỘT trục (không bao giờ hai thang đo trên một khung — giá
/// trong nước và thế giới khác đơn vị thì là hai biểu đồ). Nét 2px, lưới
/// ngang mờ, nhãn trục bằng màu chữ phụ; chạm/kéo ngón tay hiện đường dóng
/// + ô giá trị của ngày đó. Màu nét là `brandText` (petrol) — mảng lớn/nhạt
/// dùng petrol, cam chỉ cho mảng nhỏ đậm (luật màu của dự án).
class PriceLineChart extends StatelessWidget {
  const PriceLineChart({
    super.key,
    required this.points,
    required this.formatValue,
    this.formatAxis,
    this.height = 200,
  });

  /// Đã sắp tăng dần theo thời gian.
  final List<PricePoint> points;

  /// Nhãn đầy đủ trong ô giá trị khi chạm (vd "143.400.000 ₫").
  final String Function(double value) formatValue;

  /// Nhãn gọn cho trục dọc (vd "143,4tr"); mặc định dùng [formatValue].
  final String Function(double value)? formatAxis;

  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Chưa đủ dữ liệu để vẽ',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final color = context.colors.brandText;
    var minY = points.first.value;
    var maxY = minY;
    for (final p in points) {
      if (p.value < minY) minY = p.value;
      if (p.value > maxY) maxY = p.value;
    }
    // Đệm 10% trên/dưới — đường không dính mép, và giá đi ngang tuyệt đối
    // (min == max) vẫn có khoảng để vẽ.
    final pad = maxY == minY ? (maxY.abs() * 0.01 + 1) : (maxY - minY) * 0.1;
    final axisLabel = formatAxis ?? formatValue;
    final labelStyle = context.text.labelSmall?.copyWith(
      color: context.colors.chartAxisLabel,
    );
    final firstX = points.first.time.millisecondsSinceEpoch.toDouble();

    double xOf(PricePoint p) =>
        (p.time.millisecondsSinceEpoch - firstX) / Duration.millisecondsPerDay;

    return SizedBox(
      height: height,
      child: LineChart(
        duration: Duration.zero,
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          minX: 0,
          maxX: xOf(points.last),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: context.colors.chartGrid, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, meta) {
                  // Bỏ nhãn đúng mép trên/dưới (giá trị lẻ do đệm) — chỉ
                  // giữ các vạch lưới tròn fl_chart tự chọn.
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(axisLabel(value), style: labelStyle),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: _dayInterval(xOf(points.last)),
                getTitlesWidget: (value, meta) {
                  // fl_chart luôn vẽ thêm nhãn ở mép phải (maxX) dù nó
                  // không rơi đúng bước — sát nhãn bước trước thì hai ngày
                  // dính vào nhau ("27/928/9", đo trên máy ảo). Bỏ nhãn
                  // mép khi nó cách nhãn trước chưa tới nửa bước.
                  if (value == meta.max) {
                    final rest = value % meta.appliedInterval;
                    if (rest > 0 && rest < meta.appliedInterval * 0.6) {
                      return const SizedBox.shrink();
                    }
                  }
                  final t = DateTime.fromMillisecondsSinceEpoch(
                    (firstX + value * Duration.millisecondsPerDay).round(),
                  );
                  return SideTitleWidget(
                    meta: meta,
                    fitInside: SideTitleFitInsideData.fromTitleMeta(
                      meta,
                      distanceFromEdge: 0,
                    ),
                    child: Text('${t.day}/${t.month}', style: labelStyle),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            getTouchedSpotIndicator: (bar, indexes) => [
              for (final _ in indexes)
                TouchedSpotIndicatorData(
                  FlLine(
                    color: context.colors.onSurfaceVariant,
                    strokeWidth: 1,
                  ),
                  FlDotData(
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                          radius: 4,
                          color: color,
                          strokeWidth: 2,
                          strokeColor: context.colors.card,
                        ),
                  ),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => context.colors.surfaceContainer,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${_dateOf(firstX, s.x)}\n${formatValue(s.y)}',
                    context.text.labelMedium!.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (final p in points) FlSpot(xOf(p), p.value)],
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _dateOf(double firstX, double x) {
    final t = DateTime.fromMillisecondsSinceEpoch(
      (firstX + x * Duration.millisecondsPerDay).round(),
    );
    return '${t.day}/${t.month}/${t.year}';
  }

  /// Khoảng giữa hai nhãn ngày — tối đa ~5 nhãn trên trục: nhãn "28/9"
  /// rộng ~45px, màn điện thoại chỉ đủ chỗ cho chừng đó. (Bản đầu để mỗi
  /// ngày một nhãn khi ≤ 8 ngày — chồng chữ ngay trên máy ảo.)
  static double _dayInterval(double spanDays) =>
      (spanDays / 4).ceilToDouble().clamp(1, double.infinity);
}
