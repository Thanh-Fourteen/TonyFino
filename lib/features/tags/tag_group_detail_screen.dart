import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart';
import '../../data/repositories/transaction_repository.dart'
    show TransactionWithCategory;
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/day_header.dart';
import '../../ui/empty_state.dart';
import '../../ui/money_text.dart';
import '../../ui/transaction_row.dart';
import '../reports/domain/report_range.dart';
import '../reports/widgets/report_category_color.dart';
import '../transactions/day_label.dart';
import '../transactions/domain/day_groups.dart';
import '../transactions/domain/transaction_row_display.dart';
import '../transactions/transaction_form_sheet.dart';
import '../transactions/transactions_providers.dart';
import 'tags_providers.dart';

/// Cửa duy nhất để mở [TagGroupDetailScreen] — lát nhóm thẻ ở biểu đồ tròn
/// (Trang chủ lẫn Báo cáo, qua `categorySliceTapHandler`).
void openTagGroupDetailScreen(
  BuildContext context,
  List<int> tagIds, {
  required ReportRange range,
  String? rangeLabel,
}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => TagGroupDetailScreen(
        tagIds: tagIds,
        range: range,
        rangeLabel: rangeLabel,
      ),
    ),
  );
}

/// "Những khoản nào làm nên lát #Du lịch này?" — Tony bấm vào lát thẻ ở
/// thống kê Trang chủ mà không có gì xảy ra, vì lát nhóm thẻ không phải một
/// danh mục nên không có màn Chi tiết danh mục nào để mở.
///
/// 🚨 Liệt kê đúng TỔ HỢP thẻ, không phải "có thẻ này": biểu đồ gom khoản
/// gắn cả "#Du lịch" lẫn "#Gia đình" thành lát riêng "#Du lịch + #Gia đình"
/// (xem `ReportsRepository.watchTagGroupBreakdown`), nên lát "#Du lịch" chỉ
/// gồm khoản mang ĐÚNG MỘT thẻ đó. Cùng bộ điều kiện với biểu đồ — chi
/// (`< 0`), không chuyển tiền, không gắn quỹ, trong kỳ đang xem — để tổng ở
/// đầu màn khớp con số trên lát.
class TagGroupDetailScreen extends ConsumerWidget {
  const TagGroupDetailScreen({
    super.key,
    required this.tagIds,
    required this.range,
    this.rangeLabel,
  });

  final List<int> tagIds;
  final ReportRange range;
  final String? rangeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final tagsById = {for (final t in tags) t.id: t};
    final label = tagIds
        .map((id) => '#${tagsById[id]?.name ?? '?'}')
        .join(' + ');
    final colorId = tagsById[tagIds.firstOrNull]?.categoryColorId ?? -1;
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final categoriesById = {for (final c in categories) c.id: c};
    final now = ref.watch(clockProvider).now();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: reportCategoryColor(context, colorId),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                kIconSell,
                size: 18,
                color: Colors.white,
                fill: 1,
              ),
            ),
            SizedBox(width: context.space.sm),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, overflow: TextOverflow.ellipsis),
                  if (rangeLabel != null)
                    Text(
                      rangeLabel!,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder(
        stream: ref
            .read(transactionRepositoryProvider)
            .watchAllWithCategory(
              exactTagIds: tagIds.toSet(),
              from: range.start,
              to: range.end,
              excludeGoalLinked: true,
            ),
        builder: (context, snapshot) {
          final transactions = [
            for (final twc
                in snapshot.data ?? const <TransactionWithCategory>[])
              if (twc.transaction.amountMinor < 0 &&
                  !twc.transaction.isTransfer)
                twc,
          ];
          final totalMinor = transactions.fold<int>(
            0,
            (sum, twc) => sum + twc.transaction.amountMinor,
          );
          final dayGroups = groupTransactionsByDay(transactions);

          return ListView(
            padding: EdgeInsets.only(bottom: context.space.xxl),
            children: [
              Padding(
                padding: EdgeInsets.all(context.space.screenHorizontal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng chi',
                      style: context.text.labelMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    MoneyText(Money.vnd(totalMinor), size: MoneySize.large),
                    if (snapshot.hasData)
                      Text(
                        '${transactions.length} giao dịch',
                        style: context.text.labelMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (snapshot.hasData && dayGroups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    icon: kIconReceiptLong,
                    title: 'Chưa có giao dịch',
                    message:
                        'Không có khoản chi nào mang đúng các thẻ này '
                        'trong kỳ đang xem.',
                  ),
                )
              else
                for (final group in dayGroups) ...[
                  DayHeader(
                    label: formatDayLabel(group.day, now),
                    netTotal: Money.vnd(group.netMinor),
                  ),
                  for (final twc in group.items) ...[
                    _row(context, twc, categoriesById),
                    TransactionRow.divider(context),
                  ],
                ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(
    BuildContext context,
    TransactionWithCategory twc,
    Map<int, Category> categoriesById,
  ) {
    final display = transactionRowDisplay(twc, categoriesById);
    return TransactionRow(
      categoryColorId: display.categoryColorId,
      iconCode: display.iconCode,
      emoji: display.emoji,
      title: display.title,
      subcategoryLabel: display.subcategoryLabel,
      subtitle: twc.transaction.note ?? '',
      amount: Money(
        minorUnits: twc.transaction.amountMinor,
        currency: twc.transaction.currency,
        currencyScale: twc.transaction.currencyScale,
      ),
      onTap: () => showTransactionFormSheet(context: context, existing: twc),
    );
  }
}
