import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/empty_state.dart';
import '../../data/db/database.dart' show Category;
import '../transactions/transactions_providers.dart';
import '../../ui/transaction_row.dart';
import '../transactions/day_label.dart';
import '../transactions/domain/transaction_row_display.dart';
import '../transactions/transaction_form_sheet.dart';

/// Tìm kiếm giao dịch theo từ khoá không dấu (Phase 17) — FTS5 trên
/// `note_ascii` qua `TransactionRepository.watchSearch`. Danh sách phẳng
/// (không gom theo ngày như `TransactionsScreen` — kết quả tìm kiếm đã lọc
/// mỏng, gom ngày chỉ thêm nhiễu cho một danh sách thường rất ngắn).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).now();
    // Bảng tra danh mục để dựng nhãn hai tầng (cha + chip con) — cùng cách
    // tab Giao dịch làm, xem `category_two_tier_label.dart`.
    final categoriesById = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Tìm theo ghi chú…',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(kIconClose),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.trim().isEmpty
          ? const EmptyState(
              icon: kIconSearch,
              title: 'Tìm giao dịch',
              message: 'Gõ vài chữ trong ghi chú — có dấu hay không đều được.',
            )
          : StreamBuilder(
              stream: ref
                  .read(transactionRepositoryProvider)
                  .watchSearch(_query),
              builder: (context, snapshot) {
                final items =
                    snapshot.data ?? const <TransactionWithCategory>[];
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: kIconSearch,
                    title: 'Không tìm thấy',
                    message: 'Không có giao dịch nào khớp từ khoá này.',
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: context.space.sm),
                  itemCount: items.length,
                  separatorBuilder: (context, _) =>
                      TransactionRow.divider(context),
                  itemBuilder: (context, index) {
                    final twc = items[index];
                    // Một chỗ dùng chung với tab Giao dịch/Trang chủ — xem
                    // `transaction_row_display.dart`.
                    final row = transactionRowDisplay(twc, categoriesById);
                    return TransactionRow(
                      categoryColorId: row.categoryColorId,
                      iconCode: row.iconCode,
                      emoji: row.emoji,
                      title: row.title,
                      subcategoryLabel: row.subcategoryLabel,
                      subtitle:
                          '${formatDayLabel(twc.transaction.occurredAt, now)}'
                          '${twc.transaction.note == null ? '' : ' · ${twc.transaction.note}'}',
                      amount: Money(
                        minorUnits: twc.transaction.amountMinor,
                        currency: twc.transaction.currency,
                        currencyScale: twc.transaction.currencyScale,
                      ),
                      onTap: () => showTransactionFormSheet(
                        context: context,
                        existing: twc,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
