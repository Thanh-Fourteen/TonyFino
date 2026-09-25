import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/context_ext.dart';
import '../../../theme/tokens/curves.dart';
import '../../../theme/tokens/durations.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_card.dart';
import '../../../ui/empty_state.dart';
import '../domain/monthly_total.dart';

/// Đường xu hướng thu/chi theo tháng. Animation #2 bản "đường": vẽ TĨNH toàn
/// bộ dữ liệu (`LineChart(duration: Duration.zero)` — tắt animation nội bộ
/// của fl_chart, nó tự tween mọi lần `LineChartData` đổi), rồi lộ dần
/// trái→phải bằng `ClipRect` có bề rộng animate qua `AnimationController`
/// riêng của widget này, chạy MỘT LẦN lúc `initState`.
class MonthlyTrendCard extends StatefulWidget {
  const MonthlyTrendCard({super.key, required this.months});

  final List<MonthlyTotal> months;

  @override
  State<MonthlyTrendCard> createState() => _MonthlyTrendCardState();
}

class _MonthlyTrendCardState extends State<MonthlyTrendCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _reveal;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: appDurations.chartDraw,
    );
    _reveal = CurvedAnimation(parent: _controller, curve: appCurves.chartDraw);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Xu hướng theo tháng',
                  style: context.text.titleMedium,
                ),
              ),
              _LegendDot(color: context.colors.incomeFill, label: 'Thu'),
              SizedBox(width: context.space.md),
              _LegendDot(color: context.colors.onSurfaceVariant, label: 'Chi'),
            ],
          ),
          SizedBox(height: context.space.md),
          if (months.length < 2)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(
                icon: kIconTrendingUp,
                title: 'Chưa đủ dữ liệu',
                message:
                    'Cần ít nhất 2 tháng có giao dịch để vẽ đường xu hướng.',
              ),
            )
          else
            SizedBox(
              height: 160,
              child: AnimatedBuilder(
                animation: _reveal,
                builder: (context, _) {
                  return ClipRect(
                    clipper: _LeftRevealClipper(_reveal.value),
                    child: LineChart(
                      duration: Duration.zero,
                      _buildData(context, months),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  LineChartData _buildData(BuildContext context, List<MonthlyTotal> months) {
    final maxY = months
        .map(
          (m) =>
              m.incomeMinor > -m.expenseMinor ? m.incomeMinor : -m.expenseMinor,
        )
        .fold<int>(0, (a, b) => a > b ? a : b);
    final ceiling = maxY <= 0 ? 1.0 : maxY.toDouble() * 1.15;

    return LineChartData(
      minX: 0,
      maxX: (months.length - 1).toDouble(),
      minY: 0,
      maxY: ceiling,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 || index >= months.length) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                // Nhãn tháng đầu/cuối căn giữa đúng MÉP biểu đồ (minX/maxX
                // trùng index đầu/cuối) — không có `fitInside` thì fl_chart
                // vẽ nhãn tràn ra ngoài khung và bị cắt (chụp thật: "Th5"
                // chỉ còn "5", "Th9" chỉ còn "Th"). `fitInside` tự đẩy nhãn
                // vào trong khi nó sắp tràn.
                fitInside: SideTitleFitInsideData.fromTitleMeta(
                  meta,
                  distanceFromEdge: 0,
                ),
                child: Text(
                  months[index].shortLabel,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        _line(
          months,
          context.colors.incomeFill,
          (m) => m.incomeMinor.toDouble(),
        ),
        _line(
          months,
          context.colors.onSurfaceVariant,
          (m) => -m.expenseMinor.toDouble(),
        ),
      ],
    );
  }

  LineChartBarData _line(
    List<MonthlyTotal> months,
    Color color,
    double Function(MonthlyTotal) valueOf,
  ) {
    return LineChartBarData(
      isCurved: true,
      curveSmoothness: 0.25,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: false),
      spots: [
        for (var i = 0; i < months.length; i++)
          FlSpot(i.toDouble(), valueOf(months[i])),
      ],
    );
  }
}

class _LeftRevealClipper extends CustomClipper<Rect> {
  _LeftRevealClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant _LeftRevealClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: context.space.xxs),
        Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
