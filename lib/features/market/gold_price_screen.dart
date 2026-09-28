import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/market/gold_prices.dart';
import '../../data/services/market/price_point.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_card.dart';
import 'market_providers.dart';
import 'widgets/market_widgets.dart';
import 'widgets/price_line_chart.dart';

/// Mã dòng "vàng thế giới" trên biểu đồ — cùng mã của vang.today.
const _worldCode = 'XAUUSD';

/// Trang Giá vàng — Tony 2026-09-28: "trang xem giá vàng hằng ngày của một
/// số doanh nghiệp, trong nước và ngoài nước, có biểu đồ, cập nhật
/// realtime".
///
/// Những gì một người đi mua/bán vàng thật sự cần (khảo sát các trang giá
/// vàng phổ biến — xem docs/decisions.md § 2026-09-28 (4)):
/// 1. Bảng MUA VÀO / BÁN RA của từng doanh nghiệp, kèm tăng/giảm so với
///    phiên trước và giờ NGUỒN cập nhật.
/// 2. Giá thế giới, quy ra đồng/lượng, và CHÊNH LỆCH trong nước – thế giới.
/// 3. Biểu đồ lịch sử của đúng dòng đang quan tâm (7 ngày → 1 năm), cao/
///    thấp/thay đổi trong khoảng.
/// 4. Máy tính: số vàng đang giữ bán ra được bao nhiêu, mua thêm hết bao
///    nhiêu — chênh lệch mua–bán hiện ra thành tiền thật.
///
/// Cần mạng; mất mạng thì hiện bảng giá lần trước kèm lời báo.
class GoldPriceScreen extends ConsumerStatefulWidget {
  const GoldPriceScreen({super.key});

  @override
  ConsumerState<GoldPriceScreen> createState() => _GoldPriceScreenState();
}

class _GoldPriceScreenState extends ConsumerState<GoldPriceScreen> {
  String _chartCode = 'SJL1L10';
  bool _sellSide = true;
  ChartSpan _span = ChartSpan.month;

  Future<void> _refreshAll() async {
    ref.invalidate(goldHistoryProvider);
    ref.invalidate(usdVndProvider);
    await ref.read(goldBoardProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(goldBoardProvider);
    final board = snapshot.data;
    final rate = ref.watch(usdVndProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giá vàng'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(kIconRefresh),
            onPressed: snapshot.isLoading ? null : _refreshAll,
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
            MarketStatusLine(
              label: 'Giá vàng',
              updatedAt: board?.updatedAt,
              isLoading: snapshot.isLoading,
              error: snapshot.error,
              hasData: board != null,
            ),
            SizedBox(height: context.space.md),
            if (board == null && !snapshot.isLoading)
              const _EmptyBoard()
            else if (board != null) ...[
              if (board.world != null) ...[
                _WorldCard(
                  world: board.world!,
                  vndPerUsd: rate?.sell,
                  sjc: board.quotes
                      .where((q) => q.code == 'SJL1L10')
                      .firstOrNull,
                  selected: _chartCode == _worldCode,
                  onTap: () => setState(() => _chartCode = _worldCode),
                ),
                SizedBox(height: context.space.md),
              ],
              _ChartCard(
                code: _chartCode,
                title: _chartTitle(board),
                sellSide: _sellSide,
                span: _span,
                onSellSideChanged: (v) => setState(() => _sellSide = v),
                onSpanChanged: (v) => setState(() => _span = v),
              ),
              SizedBox(height: context.space.md),
              _BoardCard(
                quotes: board.quotes,
                selectedCode: _chartCode,
                onSelect: (code) => setState(() => _chartCode = code),
              ),
              SizedBox(height: context.space.md),
              _CalculatorCard(quotes: board.quotes),
            ],
            SizedBox(height: context.space.lg),
            Text(
              'Nguồn: vang.today (tổng hợp giá niêm yết của các doanh '
              'nghiệp), dự phòng PNJ; tỷ giá USD bán ra của Vietcombank. '
              'Giá tham khảo — giá tại quầy có thể khác.',
              style: context.text.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _chartTitle(GoldBoard board) {
    if (_chartCode == _worldCode) return 'Vàng thế giới (USD/ounce)';
    final q = board.quotes.where((q) => q.code == _chartCode).firstOrNull;
    if (q == null) return 'Biểu đồ';
    return q.product.isEmpty ? q.brand : '${q.brand} · ${q.product}';
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
    final muted = context.text.labelMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Vàng thế giới (XAU/USD)',
                  style: context.text.titleMedium,
                ),
              ),
              if (selected)
                Icon(kIconShowChart, size: 18, color: context.colors.brandText),
            ],
          ),
          SizedBox(height: context.space.xs),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${formatDecimal(world.usdPerOunce, digits: 1)} USD/oz',
                style: context.text.headlineSmall,
              ),
              SizedBox(width: context.space.sm),
              ChangeLabel(
                change: world.change,
                text: formatDecimal(world.change.abs(), digits: 1),
              ),
            ],
          ),
          if (converted != null) ...[
            SizedBox(height: context.space.xs),
            Text(
              '≈ ${formatThousands(converted)} nghìn đ/lượng '
              '(tỷ giá ${formatVndFull(vndPerUsd!)} đ/USD)',
              style: muted,
            ),
            if (sjc != null)
              Text(
                'Vàng miếng SJC bán ra cao hơn thế giới '
                '${formatThousands(sjc!.sell - converted)} nghìn đ/lượng',
                style: muted,
              ),
          ],
        ],
      ),
    );
  }
}

class _ChartCard extends ConsumerWidget {
  const _ChartCard({
    required this.code,
    required this.title,
    required this.sellSide,
    required this.span,
    required this.onSellSideChanged,
    required this.onSpanChanged,
  });

  final String code;
  final String title;
  final bool sellSide;
  final ChartSpan span;
  final ValueChanged<bool> onSellSideChanged;
  final ValueChanged<ChartSpan> onSpanChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWorld = code == _worldCode;
    final history = ref.watch(goldHistoryProvider((code, sellSide || isWorld)));
    final points = pointsInSpan(history.value ?? const [], span);
    String full(double v) => isWorld
        ? '${formatDecimal(v, digits: 1)} USD'
        : '${formatVndFull(v)} đ';
    String axis(double v) =>
        isWorld ? formatDecimal(v, digits: 0) : formatCompactVnd(v);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleMedium),
          SizedBox(height: context.space.sm),
          Row(
            children: [
              Expanded(
                child: ChartSpanSelector(value: span, onChanged: onSpanChanged),
              ),
            ],
          ),
          if (!isWorld) ...[
            SizedBox(height: context.space.xs),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Bán ra')),
                ButtonSegment(value: false, label: Text('Mua vào')),
              ],
              selected: {sellSide},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onSellSideChanged(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ],
          SizedBox(height: context.space.md),
          if (history.isLoading && !history.hasValue)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (history.hasError && !history.hasValue)
            SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'Chưa tải được lịch sử giá.',
                  style: context.text.bodyMedium,
                ),
              ),
            )
          else if (code.startsWith('PNJ:'))
            SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  'Nguồn dự phòng không có lịch sử giá.',
                  style: context.text.bodyMedium,
                ),
              ),
            )
          else ...[
            PriceLineChart(points: points, formatValue: full, formatAxis: axis),
            SizedBox(height: context.space.sm),
            SpanSummary(
              points: points,
              format: (v) =>
                  isWorld ? formatDecimal(v, digits: 1) : formatThousands(v),
            ),
            if (!isWorld)
              Padding(
                padding: EdgeInsets.only(top: context.space.xxs),
                child: Text(
                  'Đơn vị bảng tóm tắt: nghìn đồng/lượng',
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
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
    final head = context.text.labelSmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Giá trong nước', style: context.text.titleMedium),
          Text('Nghìn đồng/lượng · chạm một dòng để xem biểu đồ', style: head),
          SizedBox(height: context.space.sm),
          Row(
            children: [
              Expanded(child: Text('Loại vàng', style: head)),
              SizedBox(
                width: 84,
                child: Text('Mua vào', style: head, textAlign: TextAlign.end),
              ),
              SizedBox(
                width: 84,
                child: Text('Bán ra', style: head, textAlign: TextAlign.end),
              ),
            ],
          ),
          const Divider(),
          for (final q in quotes)
            _QuoteRow(
              quote: q,
              selected: q.code == selectedCode,
              onTap: () => onSelect(q.code),
            ),
        ],
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({
    required this.quote,
    required this.selected,
    required this.onTap,
  });

  final GoldQuote quote;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget price(int value, int change) => SizedBox(
      width: 84,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatThousands(value), style: context.text.bodyMedium),
          ChangeLabel(
            change: change,
            text: formatThousands(change.abs()),
            style: context.text.labelSmall,
          ),
        ],
      ),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: context.space.xs,
          horizontal: context.space.xxs,
        ),
        decoration: selected
            ? BoxDecoration(
                color: context.colors.brandText.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quote.brand, style: context.text.bodyMedium),
                  if (quote.product.isNotEmpty)
                    Text(
                      quote.product,
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            price(quote.buy, quote.changeBuy),
            price(quote.sell, quote.changeSell),
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
class _CalculatorCard extends StatefulWidget {
  const _CalculatorCard({required this.quotes});

  final List<GoldQuote> quotes;

  @override
  State<_CalculatorCard> createState() => _CalculatorCardState();
}

class _CalculatorCardState extends State<_CalculatorCard> {
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kIconCalculate, size: 20, color: context.colors.brandText),
              SizedBox(width: context.space.xs),
              Text('Tính giá trị vàng', style: context.text.titleMedium),
            ],
          ),
          SizedBox(height: context.space.sm),
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
              SizedBox(width: context.space.sm),
              Expanded(
                child: SegmentedButton<_GoldUnit>(
                  segments: [
                    for (final u in _GoldUnit.values)
                      ButtonSegment(value: u, label: Text(u.label)),
                  ],
                  selected: {_unit},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _unit = s.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
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
          SizedBox(height: context.space.sm),
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
          Text(
            '1 lượng = 10 chỉ = 37,5 gam',
            style: context.text.labelSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
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
      padding: EdgeInsets.symmetric(vertical: context.space.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodyMedium)),
          Text(value, style: context.text.titleSmall),
        ],
      ),
    );
  }
}
