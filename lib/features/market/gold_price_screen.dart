import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_bottom_nav.dart';
import '../../data/services/market/gold_prices.dart';
import '../../data/services/market/price_point.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_card.dart';
import 'market_providers.dart';
import 'widgets/market_widgets.dart';
import 'widgets/price_line_chart.dart';

/// Mã dòng "vàng thế giới" — cùng mã của vang.today.
const _worldCode = 'XAUUSD';

/// Tải lại mọi số của trang Vàng — dùng cho nút tải lại ở hàng tab con và
/// cho kéo-xuống-để-tải-lại.
Future<void> refreshGoldPrices(WidgetRef ref) async {
  ref.invalidate(goldHistoryProvider);
  ref.invalidate(usdVndProvider);
  await ref.read(goldBoardProvider.notifier).refresh();
}

/// Trang Vàng trong tab Thị trường.
///
/// Bố cục (nghiên cứu 2026-09-28 — Robinhood/Apple Stocks/Coinbase, các
/// trang giá vàng Việt Nam, và bài học từ bản thiết kế lại Google Finance
/// 2026 bị chê vì biến bảng số thành thẻ thưa thớt; xem docs/decisions.md
/// § 2026-09-28 (5)):
/// 1. **Hero PHẲNG** trên nền trang, không thẻ: giá BÁN RA của dòng đang
///    chọn thật to, dưới là viên ▲▼ + giá mua vào + chênh lệch.
/// 2. **Biểu đồ ngay dưới hero**, hai đường Mua vào / Bán ra, rồi thanh chọn
///    khoảng (7N · 1T · 3T · 1N · lịch).
/// 3. **Bảng trong nước** là MỘT thẻ, nhóm theo doanh nghiệp, số canh phải
///    — bảng giá phải đặc, không tách mỗi dòng một thẻ.
/// 4. Thế giới một thẻ nhỏ; máy tính cất vào một dòng mở sheet.
///
/// Cần mạng; mất mạng thì hiện số lần trước kèm lời báo.
class GoldPriceScreen extends ConsumerStatefulWidget {
  const GoldPriceScreen({super.key});

  @override
  ConsumerState<GoldPriceScreen> createState() => _GoldPriceScreenState();
}

class _GoldPriceScreenState extends ConsumerState<GoldPriceScreen> {
  String _code = 'SJL1L10';
  ChartWindow _window = const ChartWindow.preset(ChartSpan.month);

  @override
  Widget build(BuildContext context) {
    // Tab bị ẩn (đang ở tab khác của thanh dưới) → thôi theo dõi provider
    // giá, hẹn giờ tự tải lại dừng theo. State (dòng đang chọn, khoảng)
    // vẫn giữ nguyên cho lần quay lại.
    if (!marketTabVisible(context)) return const SizedBox.shrink();

    final snapshot = ref.watch(goldBoardProvider);
    final board = snapshot.data;
    final rate = ref.watch(usdVndProvider).value?.sell;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // Dòng đang chọn không có trong bảng (vd đang dùng bảng dự phòng của
    // PNJ — mã khác hẳn) → rơi về dòng đầu tiên, không để hero trống.
    final quote =
        board?.quotes.where((q) => q.code == _code).firstOrNull ??
        board?.quotes.firstOrNull;
    final showingWorld = _code == _worldCode && board?.world != null;

    return RefreshIndicator(
      onRefresh: () => refreshGoldPrices(ref),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          context.space.screenHorizontal,
          context.space.sm,
          context.space.screenHorizontal,
          kBottomNavReservedHeight + bottomInset + context.space.xxl,
        ),
        children: [
          MarketStatusLine(
            label: 'Giá vàng',
            updatedAt: board?.updatedAt,
            isLoading: snapshot.isLoading,
            error: snapshot.error,
            hasData: board != null,
          ),
          SizedBox(height: context.space.lg),
          if (board == null)
            snapshot.isLoading ? const MarketSkeleton() : const _EmptyBoard()
          else ...[
            if (showingWorld)
              _WorldHero(
                world: board.world!,
                vndPerUsd: rate,
                onPick: () => _pick(board),
              )
            else if (quote != null)
              _QuoteHero(quote: quote, onPick: () => _pick(board)),
            SizedBox(height: context.space.lg),
            _GoldChart(
              code: showingWorld ? _worldCode : (quote?.code ?? _code),
              window: _window,
              onWindowChanged: (w) => setState(() => _window = w),
            ),
            SizedBox(height: context.space.xxxl),
            const MarketSectionHeader(
              title: 'Trong nước',
              trailing: 'nghìn đ/lượng',
            ),
            _BoardCard(
              quotes: board.quotes,
              selectedCode: showingWorld ? _worldCode : (quote?.code ?? _code),
              onSelect: (code) => setState(() => _code = code),
            ),
            if (board.world != null) ...[
              SizedBox(height: context.space.betweenSections),
              const MarketSectionHeader(title: 'Thế giới'),
              _WorldCard(
                world: board.world!,
                vndPerUsd: rate,
                sjc: board.quotes.where((q) => q.code == 'SJL1L10').firstOrNull,
                selected: showingWorld,
                onTap: () => setState(() => _code = _worldCode),
              ),
            ],
            SizedBox(height: context.space.betweenSections),
            _CalculatorEntry(quotes: board.quotes),
          ],
          SizedBox(height: context.space.xxl),
          Text(
            'Nguồn: vang.today (tổng hợp giá niêm yết của các doanh '
            'nghiệp), dự phòng PNJ; tỷ giá USD bán ra của Vietcombank. '
            'Giá tham khảo — giá tại quầy có thể khác.',
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(GoldBoard board) async {
    final picked = await showAppBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: sheetContext.space.md),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: sheetContext.space.lg,
                vertical: sheetContext.space.sm,
              ),
              child: Text('Xem giá của', style: sheetContext.text.titleMedium),
            ),
            for (final q in board.quotes)
              ListTile(
                title: Text(q.brand),
                subtitle: q.product.isEmpty ? null : Text(q.product),
                selected: q.code == _code,
                onTap: () => Navigator.of(sheetContext).pop(q.code),
              ),
            if (board.world != null)
              ListTile(
                title: const Text('Vàng thế giới'),
                subtitle: const Text('XAU/USD'),
                selected: _code == _worldCode,
                onTap: () => Navigator.of(sheetContext).pop(_worldCode),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _code = picked);
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.space.xxl),
      child: Column(
        children: [
          Icon(
            kIconWorkspacePremium,
            size: 48,
            color: context.colors.onSurfaceVariant,
          ),
          SizedBox(height: context.space.sm),
          Text(
            'Chưa có bảng giá — cần mạng để tải lần đầu.',
            style: context.text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QuoteHero extends StatelessWidget {
  const _QuoteHero({required this.quote, required this.onPick});

  final GoldQuote quote;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroPicker(
          label: quote.product.isEmpty
              ? '${quote.brand} · bán ra'
              : '${quote.brand} · ${quote.product} · bán ra',
          onTap: onPick,
        ),
        SizedBox(height: context.space.xxs),
        HeroNumber(value: formatVndFull(quote.sell), unit: 'đ/lượng'),
        SizedBox(height: context.space.xs),
        Wrap(
          spacing: context.space.sm,
          runSpacing: context.space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChangePill(
              change: quote.changeSell,
              text: formatVndFull(quote.changeSell.abs()),
            ),
            Text(
              'Mua vào ${formatVndFull(quote.buy)} · '
              'chênh ${formatVndFull(quote.spread)}',
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

class _WorldHero extends StatelessWidget {
  const _WorldHero({
    required this.world,
    required this.vndPerUsd,
    required this.onPick,
  });

  final WorldGoldQuote world;
  final double? vndPerUsd;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final converted = vndPerUsd == null
        ? null
        : worldGoldVndPerLuong(
            usdPerOunce: world.usdPerOunce,
            vndPerUsd: vndPerUsd!,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroPicker(label: 'Vàng thế giới · XAU/USD', onTap: onPick),
        SizedBox(height: context.space.xxs),
        HeroNumber(
          value: formatDecimal(world.usdPerOunce, digits: 1),
          unit: 'USD/oz',
        ),
        SizedBox(height: context.space.xs),
        Wrap(
          spacing: context.space.sm,
          runSpacing: context.space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChangePill(
              change: world.change,
              text: formatDecimal(world.change.abs(), digits: 1),
            ),
            if (converted != null)
              Text(
                '≈ ${formatVndFull(converted)} đ/lượng',
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

class _GoldChart extends ConsumerWidget {
  const _GoldChart({
    required this.code,
    required this.window,
    required this.onWindowChanged,
  });

  final String code;
  final ChartWindow window;
  final ValueChanged<ChartWindow> onWindowChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (code.startsWith('PNJ:')) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.space.lg),
        child: Text(
          'Nguồn dự phòng không có lịch sử giá để vẽ.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }
    final isWorld = code == _worldCode;
    final history = ref.watch(goldHistoryProvider(code));
    final data = history.value;
    // Thế giới chỉ có MỘT giá (nằm ở `buy`); trong nước vẽ cả hai đường.
    final all = (isWorld ? data?.buy : data?.sell) ?? const <PricePoint>[];
    final main = pointsInWindow(all, window);
    final buy = isWorld
        ? const <PricePoint>[]
        : pointsInWindow(data?.buy ?? const [], window);

    String full(double v) => isWorld
        ? '${formatDecimal(v, digits: 1)} USD'
        : '${formatVndFull(v)} đ';
    String axis(double v) =>
        isWorld ? formatDecimal(v, digits: 0) : formatCompactVnd(v);

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
            'Chưa tải được lịch sử giá.',
            style: context.text.bodyMedium,
          ),
        ),
      );
    } else {
      chart = PriceLineChart(
        series: [
          ChartSeries(label: isWorld ? 'XAU/USD' : 'Bán ra', points: main),
          if (!isWorld)
            ChartSeries(
              label: 'Mua vào',
              points: buy,
              style: ChartSeriesStyle.secondary,
            ),
        ],
        formatValue: full,
        formatAxis: axis,
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
          points: main,
          format: (v) =>
              isWorld ? formatDecimal(v, digits: 1) : formatThousands(v),
          title: isWorld ? null : 'Giá bán ra trong khoảng · nghìn đ/lượng',
        ),
      ],
    );
  }
}

/// "Tốt nhất" chỉ so trong CÙNG một sản phẩm (vàng miếng SJC ở mọi nơi bán)
/// — so nhẫn với miếng là so hai thứ khác nhau. Ai cũng bằng nhau thì không
/// ai "tốt nhất" — không gắn nhãn.
({String? bestBuy, String? bestSell}) bestSjcBar(List<GoldQuote> quotes) {
  final bars = quotes.where((q) => q.product == 'Vàng miếng SJC').toList();
  if (bars.length < 2) return (bestBuy: null, bestSell: null);
  final maxBuy = bars.map((q) => q.buy).reduce((a, b) => a > b ? a : b);
  final minSell = bars.map((q) => q.sell).reduce((a, b) => a < b ? a : b);
  final topBuyers = bars.where((q) => q.buy == maxBuy).toList();
  final topSellers = bars.where((q) => q.sell == minSell).toList();
  return (
    bestBuy: topBuyers.length == 1 ? topBuyers.single.code : null,
    bestSell: topSellers.length == 1 ? topSellers.single.code : null,
  );
}

/// Tên hiển thị trong bảng khi đã có tiêu đề nhóm doanh nghiệp phía trên:
/// chỉ còn tên sản phẩm; hai chi nhánh DOJI thì kèm nơi bán.
String _rowName(GoldQuote q) {
  if (q.product.isEmpty) return q.brand;
  if (q.brand.startsWith('DOJI ')) {
    return '${q.product} · ${q.brand.substring(5)}';
  }
  return q.product;
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.quotes,
    required this.selectedCode,
    required this.onSelect,
  });

  final List<GoldQuote> quotes;
  final String selectedCode;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final head = context.text.labelMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final best = bestSjcBar(quotes);
    // Nhóm theo doanh nghiệp, giữ thứ tự đã sắp (SJC → DOJI → PNJ → …).
    final groups = <String, List<GoldQuote>>{};
    for (final q in quotes) {
      final brand = q.brand.startsWith('DOJI') ? 'DOJI' : q.brand;
      (groups[brand] ??= []).add(q);
    }
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 14 * 1.3;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!stacked)
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.space.lg,
                context.space.md,
                context.space.lg,
                0,
              ),
              child: Row(
                children: [
                  const Spacer(),
                  SizedBox(
                    width: _priceColumnWidth,
                    child: Text(
                      'Mua vào',
                      style: head,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  SizedBox(
                    width: _priceColumnWidth,
                    child: Text(
                      'Bán ra',
                      style: head,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          for (final entry in groups.entries) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.space.lg,
                context.space.md,
                context.space.lg,
                context.space.xxs,
              ),
              child: Text(
                entry.key,
                style: head?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            for (var i = 0; i < entry.value.length; i++) ...[
              _QuoteRow(
                quote: entry.value[i],
                selected: entry.value[i].code == selectedCode,
                stacked: stacked,
                bestBuy: entry.value[i].code == best.bestBuy,
                bestSell: entry.value[i].code == best.bestSell,
                onTap: () => onSelect(entry.value[i].code),
              ),
              if (i < entry.value.length - 1)
                Divider(
                  height: 1,
                  indent: context.space.lg,
                  endIndent: context.space.lg,
                  color: context.colors.hairline,
                ),
            ],
          ],
          SizedBox(height: context.space.sm),
        ],
      ),
    );
  }
}

const _priceColumnWidth = 92.0;

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({
    required this.quote,
    required this.selected,
    required this.stacked,
    required this.bestBuy,
    required this.bestSell,
    required this.onTap,
  });

  final GoldQuote quote;
  final bool selected;

  /// Cỡ chữ lớn: hai cột giá không còn vừa một hàng → xếp dưới tên.
  final bool stacked;
  final bool bestBuy;
  final bool bestSell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = _rowName(quote);
    Widget price(int value, int change, {required bool best}) => Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(formatThousands(value), style: context.money.moneyMedium),
        ChangeLabel(
          change: change,
          text: formatThousands(change.abs()),
          style: context.money.moneySmall,
        ),
        if (best) const _BestTag(),
      ],
    );

    final Widget body;
    if (stacked) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: context.text.bodyMedium),
          SizedBox(height: context.space.xxs),
          Wrap(
            spacing: context.space.lg,
            runSpacing: context.space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Mua ${formatThousands(quote.buy)}',
                style: context.money.moneyMedium,
              ),
              Text(
                'Bán ${formatThousands(quote.sell)}',
                style: context.money.moneyMedium,
              ),
              ChangeLabel(
                change: quote.changeSell,
                text: formatThousands(quote.changeSell.abs()),
                style: context.money.moneySmall,
              ),
              if (bestBuy || bestSell) const _BestTag(),
            ],
          ),
        ],
      );
    } else {
      body = Row(
        children: [
          Expanded(child: Text(name, style: context.text.bodyMedium)),
          SizedBox(
            width: _priceColumnWidth,
            child: price(quote.buy, quote.changeBuy, best: bestBuy),
          ),
          SizedBox(
            width: _priceColumnWidth,
            child: price(quote.sell, quote.changeSell, best: bestSell),
          ),
        ],
      );
    }

    return Material(
      color: selected ? context.colors.surfaceContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.lg,
            vertical: context.space.md,
          ),
          child: body,
        ),
      ),
    );
  }
}

/// Nhãn "tốt nhất": giá MUA VÀO cao nhất (bán vàng cho tiệm này được nhiều
/// nhất) hoặc giá BÁN RA thấp nhất (mua ở đây rẻ nhất) — giữa các nơi bán
/// cùng vàng miếng SJC.
class _BestTag extends StatelessWidget {
  const _BestTag();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.space.xxs),
      child: Text(
        'tốt nhất',
        style: context.text.labelSmall?.copyWith(
          color: context.colors.brandText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.world,
    required this.vndPerUsd,
    required this.sjc,
    required this.selected,
    required this.onTap,
  });

  final WorldGoldQuote world;
  final double? vndPerUsd;
  final GoldQuote? sjc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final converted = vndPerUsd == null
        ? null
        : worldGoldVndPerLuong(
            usdPerOunce: world.usdPerOunce,
            vndPerUsd: vndPerUsd!,
          );
    final muted = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('XAU/USD', style: context.text.bodyLarge)),
              Text(
                formatDecimal(world.usdPerOunce, digits: 1),
                style: context.money.moneyMedium,
              ),
              SizedBox(width: context.space.sm),
              ChangePill(
                change: world.change,
                text: formatDecimal(world.change.abs(), digits: 1),
              ),
            ],
          ),
          if (converted != null) ...[
            SizedBox(height: context.space.xs),
            Text(
              '≈ ${formatVndFull(converted)} đ/lượng theo tỷ giá '
              '${formatVndFull(vndPerUsd!)} đ/USD',
              style: muted,
            ),
            if (sjc != null)
              Text(
                'Vàng miếng SJC bán ra cao hơn '
                '${formatVndFull(sjc!.sell - converted)} đ/lượng',
                style: muted,
              ),
          ],
          if (!selected)
            Padding(
              padding: EdgeInsets.only(top: context.space.xs),
              child: Text(
                'Chạm để xem biểu đồ',
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.brandText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dòng mở máy tính — máy tính là việc thỉnh thoảng mới làm, không chiếm
/// chỗ thường trực trên trang.
class _CalculatorEntry extends StatelessWidget {
  const _CalculatorEntry({required this.quotes});

  final List<GoldQuote> quotes;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => showAppBottomSheet<void>(
        context: context,
        builder: (_) => _CalculatorSheet(quotes: quotes),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.space.lg),
        child: Row(
          children: [
            Icon(kIconCalculate, color: context.colors.brandText),
            SizedBox(width: context.space.md),
            Expanded(
              child: Text(
                'Tính giá trị vàng đang giữ',
                style: context.text.bodyLarge,
              ),
            ),
            Icon(kIconChevronRight, color: context.colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

enum _GoldUnit {
  chi('chỉ', 0.1),
  luong('lượng', 1),
  gram('gam', 1 / gramsPerLuong);

  const _GoldUnit(this.label, this.inLuong);
  final String label;

  /// Bao nhiêu lượng trong một đơn vị này.
  final double inLuong;
}

/// "Vàng mình đang giữ đáng bao nhiêu?" — nhập số lượng, chọn loại vàng:
/// ra số tiền nếu BÁN cho tiệm (theo giá mua vào) và nếu MUA thêm (theo giá
/// bán ra). Không lưu gì, chỉ tính.
class _CalculatorSheet extends StatefulWidget {
  const _CalculatorSheet({required this.quotes});

  final List<GoldQuote> quotes;

  @override
  State<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<_CalculatorSheet> {
  final _controller = TextEditingController(text: '1');
  _GoldUnit _unit = _GoldUnit.chi;
  String? _code;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quotes = widget.quotes;
    final quote =
        quotes.where((q) => q.code == _code).firstOrNull ?? quotes.firstOrNull;
    if (quote == null) return const SizedBox.shrink();
    final amount =
        double.tryParse(_controller.text.replaceAll(',', '.').trim()) ?? 0;
    final luong = amount * _unit.inLuong;
    final sellValue = (quote.buy * luong).round();
    final buyValue = (quote.sell * luong).round();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.space.lg,
          context.space.lg,
          context.space.lg,
          context.space.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tính giá trị vàng', style: context.text.titleLarge),
            SizedBox(height: context.space.lg),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Số lượng',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: context.space.md),
                Expanded(
                  child: SegmentTrack<_GoldUnit>(
                    options: [for (final u in _GoldUnit.values) (u, u.label)],
                    value: _unit,
                    onChanged: (u) => setState(() => _unit = u),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.space.sm),
            DropdownButton<String>(
              isExpanded: true,
              value: quote.code,
              items: [
                for (final q in quotes)
                  DropdownMenuItem(
                    value: q.code,
                    child: Text(
                      q.product.isEmpty ? q.brand : '${q.brand} · ${q.product}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _code = v),
            ),
            SizedBox(height: context.space.md),
            _ResultRow(
              label: 'Bán cho tiệm được',
              value: '${formatVndFull(sellValue)} đ',
            ),
            _ResultRow(
              label: 'Mua thêm chừng này cần',
              value: '${formatVndFull(buyValue)} đ',
            ),
            _ResultRow(
              label: 'Mua xong bán ngay lỗ',
              value: '${formatVndFull(buyValue - sellValue)} đ',
            ),
            SizedBox(height: context.space.xs),
            Text(
              '1 lượng = 10 chỉ = 37,5 gam',
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.space.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodyMedium)),
          Text(value, style: context.money.moneyMedium),
        ],
      ),
    );
  }
}
