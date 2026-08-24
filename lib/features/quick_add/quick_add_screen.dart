import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/transaction_repository.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/empty_state.dart';
import '../transactions/day_label.dart';
import '../transactions/transactions_providers.dart';
import 'domain/models/session_draft_card.dart';
import 'quick_add_providers.dart';
import 'widgets/draft_card.dart';
import 'widgets/quick_add_input_bar.dart';
import 'widgets/saved_transaction_row.dart';

sealed class _TranscriptRow {
  const _TranscriptRow();
}

class _DividerRow extends _TranscriptRow {
  const _DividerRow(this.day);
  final DateTime day;
}

class _CardRow extends _TranscriptRow {
  const _CardRow(this.messageId, this.card);
  final String messageId;
  final SessionDraftCard card;
}

class _HistoryRow extends _TranscriptRow {
  const _HistoryRow(this.txn);
  final TransactionWithCategory txn;
}

/// Màn chat quick-add — "màn hình đinh" của app. KHÔNG phải chatbot: cuốn sổ
/// cái tình cờ nhận được câu văn (Luật khung Phase 8). Transcript = LỊCH SỬ
/// THẬT (từ `transactionsWithCategoryProvider`, đã có từ Phase 6) cộng với
/// các thẻ vừa gửi trong phiên này — nên chat log "cuộn được, không biến
/// mất" (Luật bố cục) MÀ KHÔNG cần một bảng lưu trữ transcript riêng: mỗi
/// thẻ đã lưu CHÍNH LÀ một giao dịch thật, tự nhiên tái hiện ở lần mở app
/// sau qua đúng stream đó.
///
/// NGOẠI LỆ: giao dịch nhập từ file (`sourceId != null`) bị loại khỏi
/// transcript — xem lý do ngay tại chỗ lọc trong `_buildRows`.
class QuickAddScreen extends ConsumerWidget {
  const QuickAddScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickAddState = ref.watch(quickAddControllerProvider);
    final historyAsync = ref.watch(transactionsWithCategoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final now = ref.watch(quickAddNowForLabelsProvider);

    final categories = categoriesAsync.value ?? const [];
    final history = historyAsync.value ?? const [];

    final savedIdsThisSession = <int>{
      for (final message in quickAddState.messages)
        for (final card in message.cards)
          if (card.savedTransactionId != null) card.savedTransactionId!,
    };

    final rows = _buildRows(
      messages: quickAddState.messages,
      history: history,
      excludeTransactionIds: savedIdsThisSession,
    );

    return Scaffold(
      extendBody: true,
      // KHÔNG dùng `SafeArea`/`resizeToAvoidBottomInset` toàn cục (Luật bố
      // cục Phase 8 + § Android edge-to-edge) — `Column` + `Expanded` để
      // thanh nhập luôn đứng ngay TRÊN bàn phím theo layout tự nhiên, và
      // transcript tự nhường chỗ mà không cần tính chiều cao tay.
      body: Column(
        children: [
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: EmptyState(
                      icon: kIconChat,
                      title: 'Chưa có gì ở đây',
                      message: 'Gõ một câu như "cà phê 35k" rồi gửi thử xem.',
                    ),
                  )
                : CustomScrollView(
                    reverse: true,
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.space.screenHorizontal,
                        ).copyWith(top: context.space.sm),
                        sliver: SliverList.separated(
                          itemCount: rows.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: context.space.sm),
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            return switch (row) {
                              _DividerRow() => Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: context.space.xs,
                                ),
                                child: Text(
                                  formatDayLabel(
                                    row.day,
                                    now,
                                  ).split(' · ').first,
                                  style: context.text.labelMedium?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              _CardRow() => DraftCard(
                                key: ValueKey(row.card.id),
                                messageId: row.messageId,
                                card: row.card,
                                categories: categories,
                              ),
                              _HistoryRow() => SavedTransactionRow(
                                key: ValueKey('txn-${row.txn.transaction.id}'),
                                entry: row.txn,
                              ),
                            };
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          const QuickAddInputBar(),
        ],
      ),
    );
  }

  List<_TranscriptRow> _buildRows({
    required List<SentMessage> messages,
    required List<TransactionWithCategory> history,
    required Set<int> excludeTransactionIds,
  }) {
    final entries = <(DateTime, _TranscriptRow)>[];

    for (final message in messages) {
      // Đảo ngược trong-message: card đầu tiên của một tin nhắn nhiều đoạn
      // đọc TRƯỚC (cao hơn trên màn hình) khi toàn danh sách hiển thị mới
      // nhất-ở-dưới (`reverse: true`).
      for (final card in message.cards.reversed) {
        entries.add((message.sentAt, _CardRow(message.id, card)));
      }
    }

    for (final txn in history) {
      if (excludeTransactionIds.contains(txn.transaction.id)) continue;
      // Giao dịch NHẬP TỪ FILE (Rolly/CSV — nhận ra qua `sourceId` khác
      // null) KHÔNG thuộc về transcript. Transcript là bản ghi những câu
      // Tony đã GÕ vào app; một lần import 358 dòng lịch sử cũ đổ hết vào
      // đây biến màn chat thành bức tường 358 thẻ, và không thẻ nào trong
      // đó từng là một câu văn cả. Chúng vẫn nằm đầy đủ ở tab Giao dịch —
      // nơi đúng để xem lịch sử.
      if (txn.transaction.sourceId != null) continue;
      // 🚨 Nhóm theo `occurredAt` (NGÀY GIAO DỊCH), không phải `createdAt`
      // (lúc ghi vào DB).
      //
      // Dùng `createdAt` là lý do Tony báo "đổi mỗi ngày, nhấn lưu, ngày
      // trong lịch sử chat không đổi": sửa ngày chỉ đụng `occurredAt`, còn
      // `createdAt` thì bất biến, nên vạch ngăn ngày đứng nguyên và thẻ
      // không nhúc nhích — trông hệt như nút Lưu không ăn.
      //
      // `occurredAt` cũng là ngày mà TAB GIAO DỊCH, báo cáo và lịch chi
      // tiêu đều dùng. Giữ `createdAt` ở đây nghĩa là cùng một giao dịch
      // nằm ở hai ngày khác nhau tuỳ đang mở màn nào.
      entries.add((txn.transaction.occurredAt, _HistoryRow(txn)));
    }

    entries.sort((a, b) => b.$1.compareTo(a.$1));

    // Danh sách dựng theo thứ tự index 0 = MỚI NHẤT (khớp
    // `CustomScrollView(reverse: true)`, index 0 vẽ ở đáy màn hình) — nên
    // vạch ngăn ngày phải nằm SAU (index lớn hơn = cao hơn trên màn hình)
    // toàn bộ mục của ngày đó, không phải trước, để đọc đúng kiểu "Hôm nay"
    // nằm phía trên khối tin nhắn hôm nay khi cuộn lên.
    final rows = <_TranscriptRow>[];
    DateTime? currentDay;
    for (final entry in entries) {
      final day = dayKey(entry.$1);
      if (currentDay != null && day != currentDay) {
        rows.add(_DividerRow(currentDay));
      }
      rows.add(entry.$2);
      currentDay = day;
    }
    if (currentDay != null) rows.add(_DividerRow(currentDay));
    return rows;
  }
}
