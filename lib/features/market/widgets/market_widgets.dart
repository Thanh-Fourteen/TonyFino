import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/services/market/price_point.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/segment_track.dart';

export '../../../ui/segment_track.dart';

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

/// Viên ▲/▼ trên nền nhạt cùng màu chiều — con số tăng/giảm nổi lên được
/// ở hero và ở từng dòng mà không cần cả một cột riêng.
class ChangePill extends StatelessWidget {
  const ChangePill({super.key, required this.change, required this.text});

  final num change;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = change > 0
        ? context.colors.incomeText
        : change < 0
        ? context.colors.budgetOver
        : context.colors.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.sm,
        vertical: context.space.xxs,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(context.radii.full),
      ),
      child: ChangeLabel(
        change: change,
        text: text,
        style: context.money.moneySmall,
      ),
    );
  }
}

/// Chọn khoảng của biểu đồ: rãnh 7N · 1T · 3T · 1N + nút lịch "Tuỳ chọn"
/// (Tony: "vẽ biểu đồ phải cho chọn khoảng"). Nút lịch mở bộ chọn khoảng
/// ngày, giới hạn trong những ngày thật sự có dữ liệu; đang xem khoảng tự
/// chọn thì nút hiện luôn khoảng đó ("12/8–20/9") và rãnh không viên nào
/// sáng.
class ChartRangeBar extends StatelessWidget {
  const ChartRangeBar({
    super.key,
    required this.value,
    required this.onChanged,
    required this.available,
  });

  final ChartWindow value;
  final ValueChanged<ChartWindow> onChanged;

  /// Toàn bộ điểm đang có — biên của bộ chọn ngày. Ít hơn 2 điểm thì nút
  /// lịch tắt.
  final List<PricePoint> available;

  Future<void> _pickCustom(BuildContext context) async {
    final first = DateUtils.dateOnly(available.first.time);
    final last = DateUtils.dateOnly(available.last.time);
    DateTime clamp(DateTime d) {
      final day = DateUtils.dateOnly(d);
      return day.isBefore(first) ? first : (day.isAfter(last) ? last : day);
    }

    final shown = pointsInWindow(available, value);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: DateTimeRange(
        start: clamp(value.from ?? shown.firstOrNull?.time ?? first),
        end: clamp(value.to ?? last),
      ),
      helpText: 'Chọn khoảng ngày',
      saveText: 'Xem',
    );
    if (picked == null) return;
    onChanged(ChartWindow.custom(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context) {
    String dm(DateTime d) => '${d.day}/${d.month}';
    final enabled = available.length >= 2;
    final custom = value.isCustom;
    return Row(
      children: [
        Expanded(
          child: SegmentTrack<ChartSpan>(
            options: [for (final s in ChartSpan.values) (s, s.label)],
            value: value.preset,
            onChanged: (s) => onChanged(ChartWindow.preset(s)),
          ),
        ),
        SizedBox(width: context.space.xs),
        custom
            ? TextButton.icon(
                onPressed: enabled ? () => _pickCustom(context) : null,
                icon: const Icon(kIconCalendarToday, size: 16),
                label: Text('${dm(value.from!)}–${dm(value.to!)}'),
              )
            : IconButton(
                tooltip: 'Chọn khoảng ngày',
                onPressed: enabled ? () => _pickCustom(context) : null,
                icon: const Icon(kIconCalendarToday, size: 20),
              ),
      ],
    );
  }
}

/// Tiêu đề một mục trên nền trang (không bọc thẻ): tên mục bên trái, đơn
/// vị/ghi chú mờ bên phải.
class MarketSectionHeader extends StatelessWidget {
  const MarketSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: context.text.titleMedium)),
          if (trailing != null)
            Text(
              trailing!,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Nút chọn đối tượng của hero ("SJC · Vàng miếng SJC ▾") — chữ mờ + mũi
/// tên, bấm mở danh sách.
class HeroPicker extends StatelessWidget {
  const HeroPicker({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(context.radii.full),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.space.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            if (onTap != null)
              Icon(
                kIconExpandMore,
                size: 18,
                color: context.colors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// Số to của hero: con số + đơn vị nhỏ đứng sau, xuống dòng được ở cỡ chữ
/// lớn (không `FittedBox` — thu nhỏ số tiền là giấu nó đi).
class HeroNumber extends StatelessWidget {
  const HeroNumber({super.key, required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: value, style: context.money.moneyHero),
          TextSpan(
            text: ' $unit',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung xương khi CHƯA có số lần nào — giữ đúng hình dáng trang thay vì một
/// vòng xoay giữa màn trắng.
class MarketSkeleton extends StatelessWidget {
  const MarketSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      margin: EdgeInsets.only(bottom: context.space.sm),
      decoration: BoxDecoration(
        color: context.colors.skeletonBase,
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
    );
    return Semantics(
      label: 'Đang tải giá',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(140, 14),
          bar(220, 40),
          bar(160, 18),
          SizedBox(height: context.space.lg),
          bar(double.infinity, 200),
          SizedBox(height: context.space.lg),
          for (var i = 0; i < 4; i++) bar(double.infinity, 48),
        ],
      ),
    );
  }
}

/// Biểu đồ + nhãn ô bảng chỉ tải khi tab ĐANG HIỆN. Tab ở thanh dưới
/// (`StatefulShellRoute.indexedStack`) vẫn được giữ trong cây khi đổi sang
/// tab khác — chỉ bị tắt `TickerMode`. Nếu vẫn `watch` provider giá thì hẹn
/// giờ tự tải lại cứ gọi mạng ngầm khi Tony đang ở Trang chủ.
bool marketTabVisible(BuildContext context) =>
    TickerMode.valuesOf(context).enabled;

/// Cao nhất / thấp nhất / thay đổi trong khoảng đang xem — đọc được ngay mà
/// không phải rê ngón tay trên biểu đồ.
class SpanSummary extends StatelessWidget {
  const SpanSummary({
    super.key,
    required this.points,
    required this.format,
    this.title,
  });

  final List<PricePoint> points;
  final String Function(double) format;

  /// Tên đường khi biểu đồ có nhiều đường (vd "Bán ra").
  final String? title;

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
    final row = Row(
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
    if (title == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title!, style: context.text.labelMedium),
        row,
      ],
    );
  }
}
