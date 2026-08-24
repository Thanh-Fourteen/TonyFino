import '../../../ui/amount_visibility.dart';
import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/curves.dart';
import '../../../theme/tokens/durations.dart';
import '../../../ui/app_card.dart';
import '../domain/daily_spend.dart';

const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const _maxRenderedWeeks = 53; // đủ một năm

/// Ô heatmap cỡ CỐ ĐỊNH (không co theo bề rộng màn nữa): bố cục giờ cuộn
/// ngang nên bề rộng không còn là ràng buộc, và ô cố định giữ mọi khoảng
/// thời gian trông giống nhau.
const _cell = 16.0;
const _gap = 4.0;

/// Lịch heatmap chi tiêu theo ngày — Rolly khoá tính năng này sau paywall,
/// ở đây miễn phí. `CustomPainter` tự viết (không package heatmap có sẵn,
/// TODOS.md § Package UI: "ì và cứng nhắc, không theo được theme") — 5 bậc
/// cường độ đọc thẳng từ `context.colors.heatmapScale`, nên đổi theme là
/// heatmap tự đổi màu, không cần sửa file này.
class SpendingHeatmapCard extends StatefulWidget {
  const SpendingHeatmapCard({
    super.key,
    required this.daily,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final List<DailySpend> daily;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<SpendingHeatmapCard> createState() => _SpendingHeatmapCardState();
}

class _SpendingHeatmapCardState extends State<SpendingHeatmapCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _fade;
  int? _selectedRow;
  int? _selectedCol;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: appDurations.chartDraw,
    );
    _fade = CurvedAnimation(parent: _controller, curve: appCurves.chartDraw);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allWeeks = buildHeatmapWeeks(
      widget.daily,
      rangeStart: widget.rangeStart,
      rangeEnd: widget.rangeEnd,
    );
    final truncated = allWeeks.length > _maxRenderedWeeks;
    final weeks = truncated
        ? allWeeks.sublist(allWeeks.length - _maxRenderedWeeks)
        : allWeeks;

    HeatmapCell? selected;
    if (_selectedRow != null &&
        _selectedRow! < weeks.length &&
        _selectedCol != null) {
      final cell = weeks[_selectedRow!][_selectedCol!];
      if (cell.date != null) selected = cell;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lịch chi tiêu', style: context.text.titleMedium),
          if (truncated) ...[
            SizedBox(height: context.space.xxs),
            Text(
              'Hiển thị $_maxRenderedWeeks tuần gần nhất',
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: context.space.md),
          // 🚨 MỘT TUẦN = MỘT CỘT, không phải một hàng.
          //
          // Trước đây mỗi tuần là một HÀNG nên xem 6 tháng là 26 hàng chồng
          // xuống — thẻ dài lê thê, đúng chỗ Tony kêu "kéo dài xuống làm
          // xấu". Xoay 90°: chiều cao CỐ ĐỊNH đúng 7 ô (7 thứ trong tuần),
          // còn dài ra thì dài NGANG và cuộn ngang — đúng cách heatmap đóng
          // góp của GitHub làm, và là lý do nó chịu được cả năm dữ liệu.
          FadeTransition(
            opacity: _fade,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nhãn thứ nằm DỌC bên trái, mỗi nhãn cao đúng một ô — thứ
                // giờ là HÀNG chứ không còn là cột. Để nguyên hàng nhãn
                // ngang phía trên là nói sai trục (đã thấy ở golden).
                Padding(
                  padding: EdgeInsets.only(right: context.space.xs),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final label in _weekdayLabels)
                        SizedBox(
                          height: _cell + _gap,
                          child: Text(
                            label,
                            style: context.text.labelSmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: _cell * 7 + _gap * 6,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true, // mở ra ở tuần MỚI NHẤT
                      child: GestureDetector(
                        onTapUp: (details) {
                          final week =
                              (details.localPosition.dx / (_cell + _gap))
                                  .floor()
                                  .clamp(0, weeks.length - 1);
                          final day =
                              (details.localPosition.dy / (_cell + _gap))
                                  .floor()
                                  .clamp(0, 6);
                          setState(() {
                            _selectedRow = week;
                            _selectedCol = day;
                          });
                        },
                        child: CustomPaint(
                          size: Size(
                            weeks.length * (_cell + _gap) - _gap,
                            _cell * 7 + _gap * 6,
                          ),
                          painter: _HeatmapPainter(
                            weeks: weeks,
                            scale: context.colors.heatmapScale,
                            selectedRow: _selectedRow,
                            selectedCol: _selectedCol,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.space.sm),
          _Legend(scale: context.colors.heatmapScale),
          if (selected != null) ...[
            SizedBox(height: context.space.xs),
            Text(
              AmountVisibility.mask(
                context,
                '${_formatDate(selected.date!)} · ${Money.vnd(selected.expenseMinor).format()}',
              ),
              style: context.text.labelMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.weeks,
    required this.scale,
    required this.selectedRow,
    required this.selectedCol,
  });

  final List<List<HeatmapCell>> weeks;
  final List<Color> scale;
  final int? selectedRow;
  final int? selectedCol;

  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty) return;
    final paint = Paint();
    final selectPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.8);

    // `row` = tuần → trục NGANG; `col` = thứ trong tuần → trục DỌC.
    for (var row = 0; row < weeks.length; row++) {
      for (var col = 0; col < 7; col++) {
        final cell = weeks[row][col];
        final rect = Rect.fromLTWH(
          row * (_cell + _gap),
          col * (_cell + _gap),
          _cell,
          _cell,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        if (cell.date == null) continue; // ô đệm — để trống, không vẽ
        paint.color = scale[cell.level.clamp(0, scale.length - 1)];
        canvas.drawRRect(rrect, paint);
        if (row == selectedRow && col == selectedCol) {
          canvas.drawRRect(rrect.deflate(0.75), selectPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.weeks != weeks ||
        oldDelegate.selectedRow != selectedRow ||
        oldDelegate.selectedCol != selectedCol;
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.scale});

  final List<Color> scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Ít',
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SizedBox(width: context.space.xxs),
        for (final color in scale)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        SizedBox(width: context.space.xxs),
        Text(
          'Nhiều',
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}
