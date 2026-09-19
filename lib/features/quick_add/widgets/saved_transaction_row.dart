import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../data/db/database.dart' show Category;
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_card.dart';
import '../../../ui/category_avatar.dart';
import '../../../ui/category_two_tier_label.dart';
import '../../../ui/money_text.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../transactions/domain/transaction_row_display.dart';
import '../../transactions/transaction_form_sheet.dart';
import '../../transactions/transactions_providers.dart';

/// Một giao dịch ĐÃ CÓ SẴN trong lịch sử, hiện trong transcript ở đúng
/// trạng thái "đã lưu" gọn — vì đó chính xác là nó (không phải một
/// [SessionDraftCard] nào cả). Nhấn giữ → sheet Sửa/Nhân đôi/Xoá (Luật bố
/// cục Phase 8), tái dùng thẳng `TransactionFormSheet`/`deleteTransactionWithUndo`
/// đã có từ Phase 6 — không viết lại logic sửa/xoá lần hai.
class SavedTransactionRow extends ConsumerWidget {
  const SavedTransactionRow({super.key, required this.entry});

  final TransactionWithCategory entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byId = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };
    // Cùng một chỗ dùng chung với tab Giao dịch/Trang chủ/Tìm kiếm — xem
    // `transaction_row_display.dart`. Hàng ở transcript hẹp hơn nên nhãn hai
    // tầng gộp vào MỘT dòng ("Ăn uống › Cà phê", "Để dành › Mua nhà") thay vì
    // tách ra thành chip như hàng đầy đủ, nhưng NỘI DUNG phải giống hệt.
    final row = transactionRowDisplay(entry, byId);
    final label = row.subcategoryLabel == null
        ? row.title
        : '${row.title} › ${row.subcategoryLabel}';
    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.cardPadding,
        vertical: context.space.sm,
      ),
      onTap: () => showTransactionFormSheet(context: context, existing: entry),
      child: GestureDetector(
        onLongPress: () => showTransactionActionsSheet(context, ref, entry),
        child: Row(
          children: [
            CategoryAvatar(
              categoryColorId: row.categoryColorId,
              iconCode: row.iconCode,
              emoji: row.emoji,
              size: 28,
            ),
            SizedBox(width: context.space.sm),
            Expanded(
              child: Text(
                label,
                style: twoTierLabelStyle(context),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            MoneyText(
              Money(
                minorUnits: entry.transaction.amountMinor,
                currency: entry.transaction.currency,
                currencyScale: entry.transaction.currencyScale,
              ),
              size: MoneySize.small,
            ),
          ],
        ),
      ),
    );
  }
}

enum _RowAction { edit, duplicate, delete }

/// Sheet Sửa/Nhân đôi/Xoá — dùng chung cho MỌI thẻ đã lưu trong transcript,
/// dù đến từ lịch sử ([SavedTransactionRow]) hay vừa co lại trong phiên này
/// ([DraftCard]'s trạng thái "đã lưu"). Tách riêng để tránh viết logic hai
/// lần theo hai hình dạng khác nhau, giống tinh thần `deleteTransactionWithUndo`.
Future<void> showTransactionActionsSheet(
  BuildContext context,
  WidgetRef ref,
  TransactionWithCategory entry,
) async {
  final action = await showModalBottomSheet<_RowAction>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(kIconEdit),
            title: const Text('Sửa'),
            onTap: () => Navigator.of(sheetContext).pop(_RowAction.edit),
          ),
          ListTile(
            leading: const Icon(kIconContentCopy),
            title: const Text('Nhân đôi'),
            onTap: () => Navigator.of(sheetContext).pop(_RowAction.duplicate),
          ),
          ListTile(
            leading: Icon(kIconDelete, color: sheetContext.colors.expenseFill),
            title: Text(
              'Xoá',
              style: TextStyle(color: sheetContext.colors.expenseFill),
            ),
            onTap: () => Navigator.of(sheetContext).pop(_RowAction.delete),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;

  switch (action) {
    case _RowAction.edit:
      await showTransactionFormSheet(context: context, existing: entry);
    case _RowAction.duplicate:
      await openDuplicateTransactionSheet(context, entry.transaction);
    case _RowAction.delete:
      await deleteTransactionWithUndo(context, ref, entry.transaction);
  }
}
