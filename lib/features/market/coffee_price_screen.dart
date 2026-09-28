import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/market/coffee_prices.dart';
import '../../data/services/market/market_repository.dart';
import '../../data/services/market/price_point.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_card.dart';
import 'market_providers.dart';
import 'widgets/market_widgets.dart';
import 'widgets/price_line_chart.dart';

/// 1 kg = 2,20462 lb.
const _lbPerKg = 2.20462;

/// Trang Giá cà phê — Tony 2026-09-28.
///
/// Hai thị trường, đúng cách người trồng/buôn cà phê Tây Nguyên theo dõi
/// (khảo sát giacaphe.com, webgia, vietnambiz — docs/decisions.md
/// § 2026-09-28 (4)):
/// 1. Giá cà phê nhân xô TRONG NƯỚC theo tỉnh (đ/kg), chốt mỗi sáng.
/// 2. Giá sàn THẾ GIỚI: Robusta London (USD/tấn) — thứ Việt Nam chủ yếu
///    trồng, kéo giá trong nước; Arabica New York (US cent/lb). Nhảy liên
///    tục trong phiên — trang tự tải lại 30 giây/lần khi đang mở.
/// Kèm quy đổi giá sàn ra đ/kg theo tỷ giá Vietcombank, và biểu đồ.
class CoffeePriceScreen extends ConsumerStatefulWidget {
  const CoffeePriceScreen({super.key});

  @override
  ConsumerState<CoffeePriceScreen> createState() => _CoffeePriceScreenState();
}

class _CoffeePriceScreenState extends ConsumerState<CoffeePriceScreen> {
  CoffeeProvince _province = CoffeeProvince.dakLak;
  CoffeeExchange _exchange = CoffeeExchange.robusta;
  ChartSpan _domesticSpan = ChartSpan.month;
  ChartSpan _worldSpan = ChartSpan.quarter;

  Future<void> _refreshAll() async {
    ref.invalidate(coffeeHistoryProvider);
    ref.invalidate(usdVndProvider);
    await Future.wait([
      ref.read(domesticCoffeeProvider.notifier).refresh(),
      ref.read(coffeeFuturesProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final domestic = ref.watch(domesticCoffeeProvider);
    final futures = ref.watch(coffeeFuturesProvider);
    final rate = ref.watch(usdVndProvider).value?.sell;
    final busy = domestic.isLoading || futures.isLoading;
    final provinces = domestic.data ?? const <ProvinceCoffee>[];
    final selected =
        provinces.where((p) => p.province == _province).firstOrNull ??
        provinces.firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giá cà phê'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(kIconRefresh),
            onPressed: busy ? null : _refreshAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.space.screenHorizontal,
            context.space.sm,
            context.space.screenHorizontal,
            context.space.xxl,
          ),
          children: [
            // ── Trong nước ──
            MarketStatusLine(
              label: 'Trong nước',
              updatedAt: selected?.latest.date,
              dateOnly: true,
              isLoading: domestic.isLoading,
              error: domestic.error,
              hasData: provinces.isNotEmpty,
            ),
            SizedBox(height: context.space.sm),
            if (provinces.isNotEmpty) ...[
              _DomesticCard(
                provinces: provinces,
                selected: selected!.province,
                onSelect: (p) => setState(() => _province = p),
              ),
              SizedBox(height: context.space.md),
              _DomesticChartCard(
                data: selected,
                span: _domesticSpan,
                onSpanChanged: (s) => setState(() => _domesticSpan = s),
              ),
            ] else if (!domestic.isLoading)
              const _NoData(),
            SizedBox(height: context.space.xl),
            // ── Thế giới ──
            MarketStatusLine(
              label: 'Sàn thế giới',
              updatedAt: futures.data?.robusta.firstOrNull?.time,
              isLoading: futures.isLoading,
              error: futures.error,
              hasData: futures.data != null,
            ),
            SizedBox(height: context.space.sm),
            if (futures.data != null) ...[
              _FuturesCard(
                title: 'Robusta London',
                unit: 'USD/tấn',
                contracts: futures.data!.robusta,
                digits: 0,
                // USD/tấn → đ/kg.
                vndPerKg: rate == null ? null : (usd) => usd * rate / 1000,
                selected: _exchange == CoffeeExchange.robusta,
                onTap: () => setState(() => _exchange = CoffeeExchange.robusta),
              ),
              SizedBox(height: context.space.md),
              _FuturesCard(
                title: 'Arabica New York',
                unit: 'US cent/lb',
                contracts: futures.data!.arabica,
                digits: 2,
                // cent/lb → USD/lb → USD/kg → đ/kg.
                vndPerKg: rate == null
                    ? null
                    : (cents) => cents / 100 * _lbPerKg * rate,
                selected: _exchange == CoffeeExchange.arabica,
                onTap: () => setState(() => _exchange = CoffeeExchange.arabica),
              ),
              SizedBox(height: context.space.md),
            ] else if (!futures.isLoading)
              const _NoData(),
            _WorldChartCard(
              exchange: _exchange,
              span: _worldSpan,
              onExchangeChanged: (e) => setState(() => _exchange = e),
              onSpanChanged: (s) => setState(() => _worldSpan = s),
            ),
            SizedBox(height: context.space.lg),
            Text(
              'Nguồn: giacaphe.com (giá nhân xô theo tỉnh, giá khớp lệnh '
              'sàn), ICE Futures (lịch sử giá chốt), tỷ giá USD bán ra của '
              'Vietcombank. Giá sàn trễ khoảng 10 phút; quy đổi ra đ/kg chỉ '
              'để so sánh, chưa trừ chi phí và chênh lệch chất lượng.',
              style: context.text.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.space.lg),
      child: Row(
        children: [
          Icon(kIconCoffee, color: context.colors.onSurfaceVariant),
          SizedBox(width: context.space.sm),
          Expanded(
            child: Text(
              'Chưa có số — cần mạng để tải lần đầu.',
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DomesticCard extends StatelessWidget {
  const _DomesticCard({
    required this.provinces,
    required this.selected,
    required this.onSelect,
  });

  final List<ProvinceCoffee> provinces;
  final CoffeeProvince selected;
  final ValueChanged<CoffeeProvince> onSelect;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.labelSmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cà phê nhân xô', style: context.text.titleMedium),
          Text('Đồng/kg · chạm một tỉnh để xem biểu đồ', style: muted),
          SizedBox(height: context.space.sm),
          for (final p in provinces)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelect(p.province),
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: context.space.sm,
                  horizontal: context.space.xxs,
                ),
                decoration: p.province == selected
                    ? BoxDecoration(
                        color: context.colors.brandText.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.province.label,
                        style: context.text.bodyLarge,
                      ),
                    ),
                    Text(
                      formatVndFull(p.latest.price),
                      style: context.text.titleSmall,
                    ),
                    SizedBox(
                      width: 88,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ChangeLabel(
                          change: p.latest.change,
                          text: formatVndFull(p.latest.change.abs()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DomesticChartCard extends StatelessWidget {
  const _DomesticChartCard({
    required this.data,
    required this.span,
    required this.onSpanChanged,
  });

  final ProvinceCoffee data;
  final ChartSpan span;
  final ValueChanged<ChartSpan> onSpanChanged;

  @override
  Widget build(BuildContext context) {
    final points = pointsInSpan(data.history, span);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Giá nhân xô ${data.province.label}',
            style: context.text.titleMedium,
          ),
          SizedBox(height: context.space.sm),
          ChartSpanSelector(value: span, onChanged: onSpanChanged),
          SizedBox(height: context.space.md),
          PriceLineChart(
            points: points,
            formatValue: (v) => '${formatVndFull(v)} đ/kg',
            formatAxis: formatCompactVnd,
          ),
          SizedBox(height: context.space.sm),
          SpanSummary(points: points, format: formatVndFull),
          // Nguồn chỉ công bố 7 ngày gần nhất — lịch sử dài hơn là do app
          // tự ghi lại, nói rõ để Tony không tưởng biểu đồ bị thiếu.
          if (data.history.length < 30)
            Padding(
              padding: EdgeInsets.only(top: context.space.sm),
              child: Text(
                'Nguồn chỉ công bố 7 ngày gần nhất; app tự lưu thêm mỗi lần '
                'mở trang này, biểu đồ sẽ dài dần.',
                style: context.text.labelSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FuturesCard extends StatelessWidget {
  const _FuturesCard({
    required this.title,
    required this.unit,
    required this.contracts,
    required this.digits,
    required this.vndPerKg,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String unit;

  /// Kỳ hạn gần nhất trước.
  final List<CoffeeFuture> contracts;
  final int digits;
  final double Function(double price)? vndPerKg;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (contracts.isEmpty) return const SizedBox.shrink();
    final front = contracts.first;
    final muted = context.text.labelSmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    String fmt(double v) => formatDecimal(v, digits: digits);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.text.titleMedium)),
              if (selected)
                Icon(kIconShowChart, size: 18, color: context.colors.brandText),
            ],
          ),
          Text('$unit · kỳ hạn ${front.month}', style: muted),
          SizedBox(height: context.space.xs),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(fmt(front.last), style: context.text.headlineSmall),
              SizedBox(width: context.space.sm),
              ChangeLabel(
                change: front.change,
                text:
                    '${fmt(front.change.abs())} '
                    '(${formatDecimal(front.changePercent.abs(), digits: 2)}%)',
              ),
            ],
          ),
          Text(
            'Cao ${fmt(front.high)} · Thấp ${fmt(front.low)} · '
            'Khớp lúc ${formatDayTime(front.time)}',
            style: muted,
          ),
          if (vndPerKg != null)
            Text(
              '≈ ${formatVndFull(vndPerKg!(front.last))} đ/kg quy đổi',
              style: muted,
            ),
          if (contracts.length > 1) ...[
            SizedBox(height: context.space.sm),
            for (final c in contracts.skip(1))
              Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kỳ hạn ${c.month}',
                        style: context.text.labelMedium,
                      ),
                    ),
                    Text(fmt(c.last), style: context.text.labelMedium),
                    SizedBox(
                      width: 80,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ChangeLabel(
                          change: c.change,
                          text: fmt(c.change.abs()),
                          style: context.text.labelSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _WorldChartCard extends ConsumerWidget {
  const _WorldChartCard({
    required this.exchange,
    required this.span,
    required this.onExchangeChanged,
    required this.onSpanChanged,
  });

  final CoffeeExchange exchange;
  final ChartSpan span;
  final ValueChanged<CoffeeExchange> onExchangeChanged;
  final ValueChanged<ChartSpan> onSpanChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(coffeeHistoryProvider(exchange));
    final isRobusta = exchange == CoffeeExchange.robusta;
    final digits = isRobusta ? 0 : 2;
    final unit = isRobusta ? 'USD/tấn' : 'cent/lb';
    final data = history.value;
    final points = pointsInSpan(data?.points ?? const [], span);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Biểu đồ giá sàn', style: context.text.titleMedium),
          if (data != null)
            Text(
              'Giá chốt ngày, hợp đồng kỳ hạn ${_stripLabel(data.strip)} · $unit',
              style: context.text.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          SizedBox(height: context.space.sm),
          SegmentedButton<CoffeeExchange>(
            segments: const [
              ButtonSegment(
                value: CoffeeExchange.robusta,
                label: Text('Robusta'),
              ),
              ButtonSegment(
                value: CoffeeExchange.arabica,
                label: Text('Arabica'),
              ),
            ],
            selected: {exchange},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onExchangeChanged(s.first),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          SizedBox(height: context.space.xs),
          ChartSpanSelector(value: span, onChanged: onSpanChanged),
          SizedBox(height: context.space.md),
          if (history.isLoading && !history.hasValue)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (history.hasError && !history.hasValue)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Chưa tải được lịch sử giá sàn.',
                  style: context.text.bodyMedium,
                ),
              ),
            )
          else ...[
            PriceLineChart(
              points: points,
              formatValue: (v) => '${formatDecimal(v, digits: digits)} $unit',
              formatAxis: (v) => formatDecimal(v, digits: 0),
            ),
            SizedBox(height: context.space.sm),
            SpanSummary(
              points: points,
              format: (v) => formatDecimal(v, digits: digits),
            ),
          ],
        ],
      ),
    );
  }
}

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Kỳ hạn kiểu sàn ICE "Nov26" → "11/26", cùng cách viết với thẻ giá ở trên.
String _stripLabel(String strip) {
  if (strip.length < 5) return strip;
  final m = _monthAbbr.indexOf(strip.substring(0, 3));
  if (m < 0) return strip;
  return '${(m + 1).toString().padLeft(2, '0')}/${strip.substring(3)}';
}
