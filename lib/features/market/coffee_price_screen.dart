import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_bottom_nav.dart';
import '../../data/services/market/coffee_prices.dart';
import '../../data/services/market/market_repository.dart';
import '../../data/services/market/price_point.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_card.dart';
import 'market_providers.dart';
import 'widgets/market_widgets.dart';
import 'widgets/price_line_chart.dart';

/// 1 kg = 2,20462 lb.
const _lbPerKg = 2.20462;

/// Tải lại mọi số của trang Cà phê.
Future<void> refreshCoffeePrices(WidgetRef ref) async {
  ref.invalidate(coffeeHistoryProvider);
  ref.invalidate(usdVndProvider);
  await Future.wait([
    ref.read(domesticCoffeeProvider.notifier).refresh(),
    ref.read(coffeeFuturesProvider.notifier).refresh(),
  ]);
}

/// Trang Cà phê trong tab Thị trường — cùng bố cục với trang Vàng (xem doc
/// của `GoldPriceScreen`): hero phẳng → biểu đồ + thanh chọn khoảng → bảng
/// trong nước một thẻ → mục sàn kỳ hạn.
///
/// Hai thị trường, đúng cách người trồng/buôn cà phê Tây Nguyên theo dõi:
/// 1. Giá cà phê nhân xô TRONG NƯỚC theo tỉnh (đ/kg), chốt mỗi sáng.
/// 2. Sàn THẾ GIỚI: Robusta London (USD/tấn) — thứ Việt Nam chủ yếu trồng,
///    kéo giá trong nước; Arabica New York (US cent/lb). Nhảy liên tục
///    trong phiên — tự tải lại 30 giây/lần khi đang xem.
class CoffeePriceScreen extends ConsumerStatefulWidget {
  const CoffeePriceScreen({super.key});

  @override
  ConsumerState<CoffeePriceScreen> createState() => _CoffeePriceScreenState();
}

class _CoffeePriceScreenState extends ConsumerState<CoffeePriceScreen> {
  CoffeeProvince _province = CoffeeProvince.dakLak;
  CoffeeExchange _exchange = CoffeeExchange.robusta;
  ChartWindow _domesticWindow = const ChartWindow.preset(ChartSpan.month);
  ChartWindow _worldWindow = const ChartWindow.preset(ChartSpan.quarter);

  @override
  Widget build(BuildContext context) {
    // Xem `marketTabVisible` — tab ẩn thì thôi theo dõi, hẹn giờ dừng.
    if (!marketTabVisible(context)) return const SizedBox.shrink();

    final domestic = ref.watch(domesticCoffeeProvider);
    final futures = ref.watch(coffeeFuturesProvider);
    final rate = ref.watch(usdVndProvider).value?.sell;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final provinces = domestic.data ?? const <ProvinceCoffee>[];
    final selected =
        provinces.where((p) => p.province == _province).firstOrNull ??
        provinces.firstOrNull;
    final contracts = switch (_exchange) {
      CoffeeExchange.robusta => futures.data?.robusta,
      CoffeeExchange.arabica => futures.data?.arabica,
    };
    final isRobusta = _exchange == CoffeeExchange.robusta;

    return RefreshIndicator(
      onRefresh: () => refreshCoffeePrices(ref),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          context.space.screenHorizontal,
          context.space.sm,
          context.space.screenHorizontal,
          kBottomNavReservedHeight + bottomInset + context.space.xxl,
        ),
        children: [
          // ── Trong nước ──
          MarketStatusLine(
            label: 'Trong nước',
            updatedAt: selected?.latest.date,
            isLoading: domestic.isLoading,
            error: domestic.error,
            hasData: provinces.isNotEmpty,
            dateOnly: true,
          ),
          SizedBox(height: context.space.lg),
          if (selected == null)
            domestic.isLoading ? const MarketSkeleton() : const _NoData()
          else ...[
            _DomesticHero(
              data: selected,
              onPick: () => _pickProvince(provinces),
            ),
            SizedBox(height: context.space.lg),
            _DomesticChart(
              data: selected,
              window: _domesticWindow,
              onWindowChanged: (w) => setState(() => _domesticWindow = w),
            ),
            SizedBox(height: context.space.xxxl),
            const MarketSectionHeader(title: 'Các tỉnh', trailing: 'đ/kg'),
            _ProvinceCard(
              provinces: provinces,
              selected: selected.province,
              onSelect: (p) => setState(() => _province = p),
            ),
          ],
          // ── Sàn kỳ hạn ──
          SizedBox(height: context.space.xxxl),
          MarketSectionHeader(
            title: 'Sàn kỳ hạn',
            trailing: isRobusta ? 'USD/tấn' : 'US cent/lb',
          ),
          SegmentTrack<CoffeeExchange>(
            options: const [
              (CoffeeExchange.robusta, 'Robusta London'),
              (CoffeeExchange.arabica, 'Arabica New York'),
            ],
            value: _exchange,
            onChanged: (e) => setState(() => _exchange = e),
          ),
          SizedBox(height: context.space.md),
          MarketStatusLine(
            label: 'Sàn thế giới',
            updatedAt: contracts?.firstOrNull?.time,
            isLoading: futures.isLoading,
            error: futures.error,
            hasData: futures.data != null,
          ),
          SizedBox(height: context.space.md),
          if (contracts == null || contracts.isEmpty)
            futures.isLoading ? const MarketSkeleton() : const _NoData()
          else ...[
            _FuturesHero(
              front: contracts.first,
              isRobusta: isRobusta,
              vndPerKg: rate == null
                  ? null
                  : isRobusta
                  // USD/tấn → đ/kg.
                  ? (usd) => usd * rate / 1000
                  // cent/lb → USD/lb → USD/kg → đ/kg.
                  : (cents) => cents / 100 * _lbPerKg * rate,
            ),
            SizedBox(height: context.space.lg),
            _WorldChart(
              exchange: _exchange,
              window: _worldWindow,
              onWindowChanged: (w) => setState(() => _worldWindow = w),
            ),
            SizedBox(height: context.space.betweenSections),
            _ContractsCard(contracts: contracts, digits: isRobusta ? 0 : 2),
          ],
          SizedBox(height: context.space.xxl),
          Text(
            'Nguồn: giacaphe.com (giá nhân xô theo tỉnh, giá khớp lệnh '
            'sàn), ICE Futures (lịch sử giá chốt), tỷ giá USD bán ra của '
            'Vietcombank. Giá sàn trễ khoảng 10 phút; quy đổi ra đ/kg chỉ '
            'để so sánh, chưa trừ chi phí và chênh lệch chất lượng.',
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProvince(List<ProvinceCoffee> provinces) async {
    final picked = await showAppBottomSheet<CoffeeProvince>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                sheetContext.space.lg,
                sheetContext.space.lg,
                sheetContext.space.lg,
                sheetContext.space.sm,
              ),
              child: Text('Xem giá tỉnh', style: sheetContext.text.titleMedium),
            ),
            for (final p in provinces)
              ListTile(
                title: Text(p.province.label),
                trailing: Text(
                  '${formatVndFull(p.latest.price)} đ/kg',
                  style: sheetContext.money.moneySmall,
                ),
                selected: p.province == _province,
                onTap: () => Navigator.of(sheetContext).pop(p.province),
              ),
            SizedBox(height: sheetContext.space.md),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _province = picked);
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

class _DomesticHero extends StatelessWidget {
  const _DomesticHero({required this.data, required this.onPick});

  final ProvinceCoffee data;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroPicker(
          label: 'Cà phê nhân xô · ${data.province.label}',
          onTap: onPick,
        ),
        SizedBox(height: context.space.xxs),
        HeroNumber(value: formatVndFull(data.latest.price), unit: 'đ/kg'),
        SizedBox(height: context.space.xs),
        Wrap(
          spacing: context.space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChangePill(
              change: data.latest.change,
              text: formatVndFull(data.latest.change.abs()),
            ),
            Text(
              'so với phiên trước',
              style: context.money.moneySmall.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DomesticChart extends StatelessWidget {
  const _DomesticChart({
    required this.data,
    required this.window,
    required this.onWindowChanged,
  });

  final ProvinceCoffee data;
  final ChartWindow window;
  final ValueChanged<ChartWindow> onWindowChanged;

  @override
  Widget build(BuildContext context) {
    final points = pointsInWindow(data.history, window);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PriceLineChart(
          series: [ChartSeries(label: data.province.label, points: points)],
          formatValue: (v) => '${formatVndFull(v)} đ/kg',
          formatAxis: formatCompactVnd,
        ),
        SizedBox(height: context.space.md),
        ChartRangeBar(
          value: window,
          onChanged: onWindowChanged,
          available: data.history,
        ),
        SizedBox(height: context.space.md),
        SpanSummary(points: points, format: formatVndFull),
        // Nguồn chỉ công bố 7 ngày gần nhất — lịch sử dài hơn là do app
        // tự ghi lại, nói rõ để Tony không tưởng biểu đồ bị thiếu.
        if (data.history.length < 30)
          Padding(
            padding: EdgeInsets.only(top: context.space.sm),
            child: Text(
              'Nguồn chỉ công bố 7 ngày gần nhất; app tự lưu thêm mỗi lần '
              'mở trang này, biểu đồ sẽ dài dần.',
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProvinceCard extends StatelessWidget {
  const _ProvinceCard({
    required this.provinces,
    required this.selected,
    required this.onSelect,
  });

  final List<ProvinceCoffee> provinces;
  final CoffeeProvince selected;
  final ValueChanged<CoffeeProvince> onSelect;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.symmetric(vertical: context.space.xs),
      child: Column(
        children: [
          for (var i = 0; i < provinces.length; i++) ...[
            Material(
              color: provinces[i].province == selected
                  ? context.colors.surfaceContainer
                  : Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(provinces[i].province),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.space.lg,
                    vertical: context.space.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          provinces[i].province.label,
                          style: context.text.bodyLarge,
                        ),
                      ),
                      Text(
                        formatVndFull(provinces[i].latest.price),
                        style: context.money.moneyMedium,
                      ),
                      SizedBox(width: context.space.md),
                      SizedBox(
                        width: 72,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ChangeLabel(
                            change: provinces[i].latest.change,
                            text: formatVndFull(
                              provinces[i].latest.change.abs(),
                            ),
                            style: context.money.moneySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (i < provinces.length - 1)
              Divider(
                height: 1,
                indent: context.space.lg,
                endIndent: context.space.lg,
                color: context.colors.hairline,
              ),
          ],
        ],
      ),
    );
  }
}

/// Hero nhỏ của mục sàn: hợp đồng kỳ hạn GẦN NHẤT (thứ báo chí gọi là "giá
/// Robusta hôm nay").
class _FuturesHero extends StatelessWidget {
  const _FuturesHero({
    required this.front,
    required this.isRobusta,
    required this.vndPerKg,
  });

  final CoffeeFuture front;
  final bool isRobusta;
  final double Function(double price)? vndPerKg;

  @override
  Widget build(BuildContext context) {
    final digits = isRobusta ? 0 : 2;
    final muted = context.money.moneySmall.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kỳ hạn ${front.month} · gần nhất',
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.space.xxs),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: formatDecimal(front.last, digits: digits),
                style: context.money.moneyLarge,
              ),
              TextSpan(
                text: isRobusta ? ' USD/tấn' : ' cent/lb',
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.space.xs),
        Wrap(
          spacing: context.space.sm,
          runSpacing: context.space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChangePill(
              change: front.change,
              text:
                  '${formatDecimal(front.change.abs(), digits: digits)} '
                  '(${formatDecimal(front.changePercent.abs(), digits: 2)}%)',
            ),
            if (vndPerKg != null)
              Text(
                '≈ ${formatVndFull(vndPerKg!(front.last))} đ/kg',
                style: muted,
              ),
          ],
        ),
        SizedBox(height: context.space.xxs),
        Text('Khớp lúc ${formatDayTime(front.time)}', style: muted),
      ],
    );
  }
}

class _WorldChart extends ConsumerWidget {
  const _WorldChart({
    required this.exchange,
    required this.window,
    required this.onWindowChanged,
  });

  final CoffeeExchange exchange;
  final ChartWindow window;
  final ValueChanged<ChartWindow> onWindowChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(coffeeHistoryProvider(exchange));
    final isRobusta = exchange == CoffeeExchange.robusta;
    final digits = isRobusta ? 0 : 2;
    final unit = isRobusta ? 'USD/tấn' : 'cent/lb';
    final all = history.value?.points ?? const <PricePoint>[];
    final points = pointsInWindow(all, window);

    final Widget chart;
    if (history.isLoading && !history.hasValue) {
      chart = const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (history.hasError && !history.hasValue) {
      chart = SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Chưa tải được lịch sử giá sàn.',
            style: context.text.bodyMedium,
          ),
        ),
      );
    } else {
      chart = PriceLineChart(
        series: [
          ChartSeries(label: isRobusta ? 'Robusta' : 'Arabica', points: points),
        ],
        formatValue: (v) => '${formatDecimal(v, digits: digits)} $unit',
        formatAxis: (v) => formatDecimal(v, digits: 0),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chart,
        SizedBox(height: context.space.md),
        ChartRangeBar(
          value: window,
          onChanged: onWindowChanged,
          available: all,
        ),
        SizedBox(height: context.space.md),
        SpanSummary(
          points: points,
          format: (v) => formatDecimal(v, digits: digits),
          title: history.value == null
              ? null
              : 'Giá chốt ngày, hợp đồng kỳ hạn '
                    '${iceStripLabel(history.value!.strip)}',
        ),
      ],
    );
  }
}

/// Các kỳ hạn hợp đồng — mỗi kỳ một dòng gọn; chạm để mở chi tiết phiên
/// (cao/thấp/mở cửa/khối lượng/hợp đồng mở). Không dùng bảng cuộn ngang.
class _ContractsCard extends StatefulWidget {
  const _ContractsCard({required this.contracts, required this.digits});

  final List<CoffeeFuture> contracts;
  final int digits;

  @override
  State<_ContractsCard> createState() => _ContractsCardState();
}

class _ContractsCardState extends State<_ContractsCard> {
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    String fmt(double v) => formatDecimal(v, digits: widget.digits);
    final muted = context.text.labelMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final contracts = widget.contracts;
    return AppCard(
      padding: EdgeInsets.symmetric(vertical: context.space.xs),
      child: Column(
        children: [
          for (var i = 0; i < contracts.length; i++) ...[
            InkWell(
              onTap: () => setState(
                () => _expanded = _expanded == contracts[i].code
                    ? null
                    : contracts[i].code,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.space.lg,
                  vertical: context.space.md,
                ),
                child: AnimatedSize(
                  duration: context.durations.sheet,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            contracts[i].month,
                            style: context.text.bodyLarge,
                          ),
                          if (i == 0) ...[
                            SizedBox(width: context.space.sm),
                            Text(
                              'gần nhất',
                              style: context.text.labelSmall?.copyWith(
                                color: context.colors.brandText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            fmt(contracts[i].last),
                            style: context.money.moneyMedium,
                          ),
                          SizedBox(width: context.space.md),
                          SizedBox(
                            width: 64,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ChangeLabel(
                                change: contracts[i].change,
                                text: fmt(contracts[i].change.abs()),
                                style: context.money.moneySmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_expanded == contracts[i].code) ...[
                        SizedBox(height: context.space.xs),
                        Text(
                          'Cao ${fmt(contracts[i].high)} · '
                          'Thấp ${fmt(contracts[i].low)} · '
                          'Mở cửa ${fmt(contracts[i].open)}',
                          style: muted,
                        ),
                        Text(
                          'Khối lượng ${formatVndFull(contracts[i].volume)} · '
                          'Hợp đồng mở '
                          '${formatVndFull(contracts[i].openInterest)}',
                          style: muted,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (i < contracts.length - 1)
              Divider(
                height: 1,
                indent: context.space.lg,
                endIndent: context.space.lg,
                color: context.colors.hairline,
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

/// Kỳ hạn kiểu sàn ICE "Nov26" → "11/26", cùng cách viết với các dòng kỳ
/// hạn ở trên.
String iceStripLabel(String strip) {
  if (strip.length < 5) return strip;
  final m = _monthAbbr.indexOf(strip.substring(0, 3));
  if (m < 0) return strip;
  return '${(m + 1).toString().padLeft(2, '0')}/${strip.substring(3)}';
}
