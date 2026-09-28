import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../data/services/market/price_point.dart';
import '../../../theme/context_ext.dart';

/// Vai trò của một đường — quyết định màu + kiểu nét, không để nơi gọi tự
/// chọn màu (hai trang phải vẽ cùng một kiểu).
enum ChartSeriesStyle {
  /// Đường chính: petrol, nét liền, tô nhạt phía dưới.
  primary,

  /// Đường thứ hai: xám chữ phụ, NÉT ĐỨT, mảnh hơn, không tô. Kiểu nét
  /// gánh việc phân biệt hai đường, không để màu gánh một mình. (Bản đầu
  /// dùng cam: validate_palette.js đo cam trên nền trắng chỉ 2,93:1, và cam
  /// là màu của mảng nhỏ đậm chứ không phải một đường dài cả biểu đồ.)
  secondary,
}

/// Một đường trên [PriceLineChart].
class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.points,
    this.style = ChartSeriesStyle.primary,
  });

  /// Tên hiện ở chú thích và trong ô giá trị (vd "Bán ra").
  final String label;

  /// Đã sắp tăng dần theo thời gian.
  final List<PricePoint> points;
  final ChartSeriesStyle style;
}

/// Đường giá theo thời gian — dùng chung cho trang Giá vàng và Giá cà phê.
///
/// MỘT trục (không bao giờ hai thang đo trên một khung — giá trong nước và
/// thế giới khác đơn vị thì là hai biểu đồ); nhiều đường chỉ khi CÙNG đơn
/// vị (giá mua vào và bán ra của cùng một loại vàng). Nét 2px, lưới ngang
/// mờ, nhãn trục bằng màu chữ phụ; chạm/kéo ngón tay hiện đường dóng + ô
/// giá trị ghi TÊN từng đường. Từ hai đường trở lên có chú thích phía trên.
class PriceLineChart extends StatelessWidget {
  const PriceLineChart({
    super.key,
    required this.series,
    required this.formatValue,
    this.formatAxis,
    this.height = 200,
  });

  final List<ChartSeries> series;

  /// Nhãn đầy đủ trong ô giá trị khi chạm (vd "143.400.000 ₫").
  final String Function(double value) formatValue;

  /// Nhãn gọn cho trục dọc (vd "143,4tr"); mặc định dùng [formatValue].
  final String Function(double value)? formatAxis;

  final double height;

  Color _colorOf(BuildContext context, ChartSeriesStyle style) =>
      switch (style) {
        ChartSeriesStyle.primary => context.colors.brandText,
        ChartSeriesStyle.secondary => context.colors.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final drawn = [
      for (final s in series)
        if (s.points.length >= 2) s,
    ];
    if (drawn.isEmpty) {
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
    var minY = drawn.first.points.first.value;
    var maxY = minY;
    var firstMs = drawn.first.points.first.time.millisecondsSinceEpoch;
    var lastMs = firstMs;
    for (final s in drawn) {
      for (final p in s.points) {
        if (p.value < minY) minY = p.value;
        if (p.value > maxY) maxY = p.value;
        final ms = p.time.millisecondsSinceEpoch;
        if (ms < firstMs) firstMs = ms;
        if (ms > lastMs) lastMs = ms;
      }
    }
    // Đệm 10% trên/dưới — đường không dính mép, và giá đi ngang tuyệt đối
    // (min == max) vẫn có khoảng để vẽ.
    final pad = maxY == minY ? (maxY.abs() * 0.01 + 1) : (maxY - minY) * 0.1;
    final axisLabel = formatAxis ?? formatValue;
    final labelStyle = context.text.labelSmall?.copyWith(
      color: context.colors.chartAxisLabel,
    );
    final firstX = firstMs.toDouble();

    double xOf(PricePoint p) =>
        (p.time.millisecondsSinceEpoch - firstX) / Duration.millisecondsPerDay;
    final maxX = (lastMs - firstX) / Duration.millisecondsPerDay;

    final chart = SizedBox(
      height: height,
      child: LineChart(
        duration: Duration.zero,
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          minX: 0,
          maxX: maxX,
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
                interval: _dayInterval(maxX),
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
                          color: bar.color ?? context.colors.brandText,
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
              getTooltipItems: (spots) {
                final style = context.text.labelMedium!.copyWith(
                  color: context.colors.onSurface,
                );
                return [
                  for (var i = 0; i < spots.length; i++)
                    LineTooltipItem(
                      // Ngày ghi MỘT lần ở dòng đầu; mỗi dòng sau ghi tên
                      // đường khi có từ hai đường (ô giá trị không được
                      // dựa vào màu chữ để nói đây là đường nào).
                      [
                        if (i == 0) _dateOf(firstX, spots[i].x),
                        drawn.length > 1
                            ? '${drawn[spots[i].barIndex].label}: '
                                  '${formatValue(spots[i].y)}'
                            : formatValue(spots[i].y),
                      ].join('\n'),
                      style,
                    ),
                ];
              },
            ),
          ),
          lineBarsData: [
            for (final s in drawn)
              LineChartBarData(
                spots: [for (final p in s.points) FlSpot(xOf(p), p.value)],
                color: _colorOf(context, s.style),
                barWidth: s.style == ChartSeriesStyle.primary ? 2 : 1.5,
                isStrokeCapRound: true,
                dashArray: s.style == ChartSeriesStyle.secondary
                    ? const [6, 4]
                    : null,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: s.style == ChartSeriesStyle.primary,
                  color: _colorOf(context, s.style).withValues(alpha: 0.08),
                ),
              ),
          ],
        ),
      ),
    );

    if (drawn.length < 2) return chart;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: context.space.md,
          children: [
            for (final s in drawn)
              _LegendItem(
                label: s.label,
                color: _colorOf(context, s.style),
                dashed: s.style == ChartSeriesStyle.secondary,
              ),
          ],
        ),
        SizedBox(height: context.space.sm),
        chart,
      ],
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

/// Mẫu nét (liền/đứt) + tên — chú thích vẽ ĐÚNG kiểu nét của đường, không
/// chỉ một chấm màu.
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.color,
    required this.dashed,
  });

  final String label;
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22,
          height: 10,
          child: CustomPaint(
            painter: _LegendStrokePainter(color: color, dashed: dashed),
          ),
        ),
        SizedBox(width: context.space.xxs),
        Text(label, style: context.text.labelMedium),
      ],
    );
  }
}

class _LegendStrokePainter extends CustomPainter {
  const _LegendStrokePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    // Cùng nhịp nét đứt với đường trên biểu đồ (6 vẽ, 4 trống).
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + 6).clamp(0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LegendStrokePainter old) =>
      old.color != color || old.dashed != dashed;
}
