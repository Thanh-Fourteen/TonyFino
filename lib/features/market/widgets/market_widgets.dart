import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/services/market/price_point.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';

final _grouped = NumberFormat('#,##0', 'vi_VN');

/// 143400000 → "143.400.000".
String formatVndFull(num v) => _grouped.format(v.round());

/// Đồng → nghìn đồng, cách bảng giá vàng Việt Nam vẫn in: 143400000 →
/// "143.400".
String formatThousands(num v) => _grouped.format((v / 1000).round());

/// Nhãn gọn cho trục biểu đồ: 143400000 → "143,4tr"; 93600 → "93,6k".
String formatCompactVnd(double v) {
  final abs = v.abs();
  if (abs >= 1e6) {
    return '${NumberFormat('#,##0.#', 'vi_VN').format(v / 1e6)}tr';
  }
  if (abs >= 1e3) {
    return '${NumberFormat('#,##0.#', 'vi_VN').format(v / 1e3)}k';
  }
  return NumberFormat('#,##0', 'vi_VN').format(v);
}

/// Số có phần lẻ theo kiểu Việt Nam: 4182.2 → "4.182,2" ([digits] chữ số lẻ
/// tối đa).
String formatDecimal(num v, {int digits = 2}) => NumberFormat(
  // Mẫu "#,##0." (dấu chấm thập phân trơ trọi) in ra dấu phẩy thừa ở cuối.
  digits == 0 ? '#,##0' : '#,##0.${'#' * digits}',
  'vi_VN',
).format(v);

String formatClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String formatDayTime(DateTime t) => '${formatClock(t)} ${t.day}/${t.month}';

/// ▲ / ▼ / — kèm con số, màu theo chiều. Hình tam giác luôn đi cùng màu —
/// người mù màu đỏ-xanh vẫn đọc được lên hay xuống. Lên: chàm (màu "tiền
/// vào" của app, không dùng xanh lá); xuống: đỏ.
class ChangeLabel extends StatelessWidget {
  const ChangeLabel({
    super.key,
    required this.change,
    required this.text,
    this.style,
  });

  final num change;

  /// Con số đã định dạng, KHÔNG kèm dấu (dấu nằm ở tam giác).
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = change > 0
        ? context.colors.incomeText
        : change < 0
        ? context.colors.budgetOver
        : context.colors.onSurfaceVariant;
    final icon = change > 0
        ? kIconArrowDropUp
        : change < 0
        ? kIconArrowDropDown
        : kIconRemove;
    final base = style ?? context.text.labelMedium;
    // Text.rich (tam giác là WidgetSpan) chứ không phải Row: ô hẹp hay cỡ
    // chữ lớn thì cụm số tự xuống dòng thay vì tràn vạch vàng-đen.
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(icon, size: change == 0 ? 14 : 20, color: color),
          ),
          TextSpan(text: change == 0 ? '0' : text),
        ],
      ),
      style: base?.copyWith(color: color),
    );
  }
}

/// Dòng trạng thái đầu trang: lúc cập nhật, vòng xoay khi đang tải, và lỗi
/// (kèm lời nhắn "đang xem số cũ" khi còn số lần trước để xem).
class MarketStatusLine extends StatelessWidget {
  const MarketStatusLine({
    super.key,
    required this.label,
    required this.updatedAt,
    required this.isLoading,
    required this.error,
    required this.hasData,
    this.dateOnly = false,
  });

  /// Nguồn chỉ công bố theo NGÀY (giá cà phê nhân chốt mỗi sáng) — hiện
  /// "giá ngày 28/9" thay vì một giờ "00:00" không có thật.
  final bool dateOnly;

  /// Tên khối dữ liệu, vd "Giá trong nước".
  final String label;

  /// Giờ NGUỒN công bố (không phải giờ app tải về) — hai con số này lệch
  /// nhau cả giờ đồng hồ là chuyện thường ở giá vàng.
  final DateTime? updatedAt;
  final bool isLoading;
  final String? error;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.labelMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                updatedAt == null
                    ? '$label: đang tải…'
                    : dateOnly
                    ? '$label · giá ngày ${updatedAt!.day}/${updatedAt!.month}'
                    : '$label · cập nhật ${formatDayTime(updatedAt!)}',
                style: muted,
              ),
            ),
            if (isLoading)
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (error != null)
          Padding(
            padding: EdgeInsets.only(top: context.space.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(kIconWarning, size: 16, color: context.colors.budgetOver),
                SizedBox(width: context.space.xxs),
                Expanded(
                  child: Text(
                    hasData ? '$error Đang xem số lần trước.' : error!,
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.budgetOver,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Hàng nút 7N · 1T · 3T · 1N ở đầu biểu đồ.
class ChartSpanSelector extends StatelessWidget {
  const ChartSpanSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ChartSpan value;
  final ValueChanged<ChartSpan> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.space.xs,
      children: [
        for (final span in ChartSpan.values)
          ChoiceChip(
            label: Text(span.label),
            selected: span == value,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => onChanged(span),
          ),
      ],
    );
  }
}

/// Cao nhất / thấp nhất / thay đổi trong khoảng đang xem — đọc được ngay mà
/// không phải rê ngón tay trên biểu đồ.
class SpanSummary extends StatelessWidget {
  const SpanSummary({super.key, required this.points, required this.format});

  final List<PricePoint> points;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    var hi = points.first.value;
    var lo = hi;
    for (final p in points) {
      if (p.value > hi) hi = p.value;
      if (p.value < lo) lo = p.value;
    }
    final delta = points.last.value - points.first.value;
    final pct = points.first.value == 0 ? 0 : delta / points.first.value * 100;
    final muted = context.text.labelSmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    Widget cell(String title, Widget value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: muted),
          value,
        ],
      ),
    );
    return Row(
      children: [
        cell('Cao nhất', Text(format(hi), style: context.text.labelMedium)),
        cell('Thấp nhất', Text(format(lo), style: context.text.labelMedium)),
        cell(
          'Thay đổi',
          ChangeLabel(
            change: delta,
            text:
                '${format(delta.abs())} (${formatDecimal(pct.abs(), digits: 1)}%)',
          ),
        ),
      ],
    );
  }
}
