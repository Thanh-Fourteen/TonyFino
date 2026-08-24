import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/context_ext.dart';
import '../../../theme/tokens/curves.dart';
import '../../../theme/tokens/durations.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_card.dart';
import '../../../ui/empty_state.dart';
import '../domain/monthly_total.dart';

/// Cột thu-vs-chi theo tháng. Animation #2 bản "cột": chiều cao MỖI cột
/// animate LỆCH PHA 30ms so với cột trước (`AppDurations.chartBarStep`) — tự
/// tính hệ số 0→1 cho từng cột từ MỘT `AnimationController` duy nhất (không
/// phải một controller/cột) bằng cách chia tổng thời lượng thành các đoạn
/// chồng lấn `[i·30ms, i·30ms + 450ms]`, rồi áp `easeOutCubic` cục bộ trong
/// đoạn đó — `BarChart(duration: Duration.zero)` tắt animation nội bộ của
/// fl_chart để không animate hai lớp chồng nhau.
class IncomeExpenseBarCard extends StatefulWidget {
  const IncomeExpenseBarCard({super.key, required this.months});

  final List<MonthlyTotal> months;

  @override
  State<IncomeExpenseBarCard> createState() => _IncomeExpenseBarCardState();
}

class _IncomeExpenseBarCardState extends State<IncomeExpenseBarCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final int _drawMs;
  late final int _stepMs;
  late final int _totalMs;

  @override
  void initState() {
    super.initState();
    _drawMs = appDurations.chartDraw.inMilliseconds;
    _stepMs = appDurations.chartBarStep.inMilliseconds;
    final n = widget.months.length;
    _totalMs = _drawMs + (n > 0 ? (n - 1) * _stepMs : 0);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Hệ số tăng trưởng 0→1 của cột thứ [index] tại thời điểm hiện tại của
  /// `_controller` — thuần toán, không tạo `Animation` phụ mỗi khung hình.
  double _growthFactor(int index) {
    if (_totalMs <= 0) return 1.0;
    final elapsedMs = _controller.value * _totalMs;
    final startMs = index * _stepMs;
    final endMs = startMs + _drawMs;
    if (elapsedMs <= startMs) return 0.0;
    if (elapsedMs >= endMs) return 1.0;
    final localT = (elapsedMs - startMs) / (endMs - startMs);
    return appCurves.chartDraw.transform(localT);
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thu và chi theo tháng', style: context.text.titleMedium),
          SizedBox(height: context.space.md),
          if (months.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(
                icon: kIconBarChart,
                title: 'Chưa có dữ liệu',
                message: 'Không có giao dịch nào trong khoảng đang lọc.',
              ),
            )
          else
            SizedBox(
              height: 160,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => BarChart(
                  duration: Duration.zero,
                  _buildData(context, months),
                ),
              ),
            ),
        ],
      ),
    );
  }

  BarChartData _buildData(BuildContext context, List<MonthlyTotal> months) {
    final incomeColor = context.colors.incomeFill;
    final expenseColor = context.colors.onSurfaceVariant;
    final maxY = months
        .map(
          (m) =>
              m.incomeMinor > -m.expenseMinor ? m.incomeMinor : -m.expenseMinor,
        )
        .fold<int>(0, (a, b) => a > b ? a : b);
    final ceiling = maxY <= 0 ? 1.0 : maxY.toDouble() * 1.15;

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      minY: 0,
      maxY: ceiling,
      groupsSpace: 12,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barTouchData: const BarTouchData(enabled: false),
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
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= months.length) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
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
      barGroups: [
        for (var i = 0; i < months.length; i++)
          BarChartGroupData(
            x: i,
            barsSpace: 4,
            barRods: [
              BarChartRodData(
                toY: months[i].incomeMinor * _growthFactor(i),
                color: incomeColor,
                width: 8,
                borderRadius: BorderRadius.circular(3),
              ),
              BarChartRodData(
                toY: -months[i].expenseMinor * _growthFactor(i),
                color: expenseColor,
                width: 8,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
      ],
    );
  }
}
