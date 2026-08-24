import '../../../ui/amount_visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/providers/database_providers.dart';
import '../../../data/db/database.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/category_avatar.dart';
import '../../transactions/transactions_providers.dart';
import 'domain/recurring_frequency.dart';
import 'recurring_providers.dart';
import 'widgets/recurring_add_sheet.dart';

/// Quản lý mẫu giao dịch định kỳ (Phase 12) — CHỈ quản lý mẫu + tạm dừng/xoá,
/// KHÔNG tự tạo giao dịch thật (xem docs/decisions.md § Phase 12). "Đã xử lý"
/// chỉ đẩy `nextOccurrenceDate` sang kỳ tới, không đụng bảng `transactions`.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(activeRecurringTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Giao dịch định kỳ')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showRecurringAddSheet(context),
        child: const Icon(kIconAdd),
      ),
      body: rowsAsync.when(
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(context.space.screenHorizontal),
                child: Text(
                  'Chưa có giao dịch định kỳ nào. Bấm + để thêm hoá đơn/thu '
                  'nhập lặp lại — TonyFino sẽ nhắc khi đến hạn, không tự ghi sổ.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          final categoriesById = {
            for (final c in categoriesAsync.value ?? const <Category>[])
              c.id: c,
          };
          return ListView.builder(
            padding: EdgeInsets.all(context.space.screenHorizontal),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final category = categoriesById[row.categoryId];
              return _RecurringRow(row: row, category: category);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Lỗi: $error')),
      ),
    );
  }
}

class _RecurringRow extends ConsumerWidget {
  const _RecurringRow({required this.row, required this.category});

  final RecurringTransaction row;
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = Money(
      minorUnits: row.amountMinor,
      currency: row.currency,
      currencyScale: row.currencyScale,
    );
    final frequency = RecurringFrequency.fromDbValue(row.frequency);
    final repo = ref.read(recurringTransactionRepositoryProvider);

    return Card(
      margin: EdgeInsets.only(bottom: context.space.sm),
      child: Padding(
        padding: EdgeInsets.all(context.space.md),
        child: Row(
          children: [
            CategoryAvatar(
              categoryColorId: category?.categoryColorId ?? -1,
              iconCode: category?.iconCode ?? 'more_horiz',
            ),
            SizedBox(width: context.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.note ?? category?.name ?? 'Giao dịch định kỳ',
                    style: context.text.titleMedium,
                  ),
                  Text(
                    '${frequency.label} · kỳ tới ${row.nextOccurrenceDate.day}/'
                    '${row.nextOccurrenceDate.month}/${row.nextOccurrenceDate.year}',
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              AmountVisibility.mask(context, amount.format()),
              style: context.money.moneyMedium.copyWith(
                color: amount.isNegative
                    ? context.colors.onSurface
                    : context.colors.incomeText,
              ),
            ),
            PopupMenuButton<void>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () => repo.advanceToNextOccurrence(row.id),
                  child: const Text('Đã xử lý — dời sang kỳ tới'),
                ),
                PopupMenuItem(
                  onTap: () => repo.setActive(row.id, false),
                  child: const Text('Tạm dừng'),
                ),
                PopupMenuItem(
                  onTap: () => repo.delete(row.id),
                  child: Text(
                    'Xoá',
                    style: TextStyle(color: context.colors.expenseFill),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
