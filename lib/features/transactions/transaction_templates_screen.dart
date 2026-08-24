import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/amount_visibility.dart';
import '../../core/money/money.dart';
import '../../core/providers/database_providers.dart';
import '../../core/router/app_bottom_nav.dart';
import '../../data/db/database.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/category_avatar.dart';
import 'receipt_scan.dart';
import 'transaction_form_sheet.dart';
import 'transaction_templates_providers.dart';
import 'transactions_providers.dart';
import 'widgets/transaction_template_edit_sheet.dart';

/// Sheet hành động nhanh của FAB Giao dịch nhấn giữ (Phase 14 "Áp dụng mẫu",
/// Phase 18 thêm "Quét hoá đơn") — LUÔN hiện sheet (kể cả 0 mẫu, khác hành
/// vi Phase 14 cũ tự nhảy thẳng tới màn quản lý) vì giờ sheet còn có lựa
/// chọn quét hoá đơn không phụ thuộc có mẫu hay không.
Future<void> showApplyTemplateSheet(BuildContext context, WidgetRef ref) async {
  // `TransactionTemplateRepository.getAll()` (Future một lần), KHÔNG phải
  // `ref.read(transactionTemplatesProvider.future)`/`.value` — provider này
  // không có ai `ref.watch()` thường trực lúc mở sheet (không giống
  // `categoriesProvider`), và một lần đọc rời rạc qua `Stream`/`.future`
  // ngoài `build()` (không qua `ref.watch` nào giữ subscription sống) không
  // đáng tin cậy hoàn tất đúng lúc — bắt được y hệt bằng widget test thật ở
  // `TransactionFormSheet._loadExistingLines` (Phase 14), cùng họ gotcha
  // StreamProvider đã gặp ở Phase 8/9 nhưng biểu hiện khác (treo, không
  // phải trả `null`/dữ liệu cũ).
  final templates = await ref
      .read(transactionTemplateRepositoryProvider)
      .getAll();
  if (!context.mounted) return;

  // `Object?` chứ không `TransactionTemplate?` — sheet có nhiều kết quả:
  // chọn một mẫu, chọn "Quét hoá đơn", chọn "Quản lý", hoặc đóng tay không
  // chọn gì (`null`).
  final picked = await showModalBottomSheet<Object>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(sheetContext.space.md),
            child: Text('Thêm nhanh', style: sheetContext.text.titleMedium),
          ),
          ListTile(
            leading: const Icon(kIconReceiptLong),
            title: const Text('Quét hoá đơn'),
            subtitle: const Text('Chụp/chọn ảnh, đọc số tiền tự động'),
            onTap: () => Navigator.of(sheetContext).pop(_scanReceiptChoice),
          ),
          if (templates.isNotEmpty) const Divider(height: 1),
          for (final template in templates)
            ListTile(
              leading: const Icon(kIconBookmark),
              title: Text(template.name),
              subtitle: Text(
                AmountVisibility.mask(
                  sheetContext,
                  Money(
                    minorUnits: template.amountMinor,
                    currency: template.currency,
                    currencyScale: template.currencyScale,
                  ).format(),
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop(template),
            ),
          ListTile(
            leading: const Icon(kIconSettings),
            title: const Text('Quản lý mẫu giao dịch'),
            onTap: () => Navigator.of(sheetContext).pop(_manageTemplatesChoice),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;

  if (picked is TransactionTemplate) {
    await showTransactionFormSheet(
      context: context,
      prefill: TransactionFormPrefill.fromTemplate(picked),
    );
  } else if (picked == _manageTemplatesChoice) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TransactionTemplatesScreen(),
      ),
    );
  } else if (picked == _scanReceiptChoice) {
    await openReceiptScanFlow(context, ref);
  }
}

const _manageTemplatesChoice = 'manage';
const _scanReceiptChoice = 'scan_receipt';

/// Quản lý mẫu giao dịch (Phase 14) — CRUD đầy đủ, KHÔNG có lưu trữ (xoá là
/// xoá thật, mẫu không phải dữ liệu tài chính). Sửa/xoá một mẫu KHÔNG ảnh
/// hưởng giao dịch đã tạo từ nó trước đây — xem
/// `TransactionTemplateRepository`.
class TransactionTemplatesScreen extends ConsumerWidget {
  const TransactionTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(transactionTemplatesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    // `extendBody` + FAB đệm đáy = chiều cao thanh nav nổi — màn này được
    // push vào Navigator của NHÁNH hiện tại (`Navigator.of(context).push`,
    // xem `showApplyTemplateSheet`), vẫn nằm TRONG `body` của `AppShell`
    // ngoài nên thanh nav nổi (`extendBody: true` ở Scaffold ngoài) vẫn vẽ
    // ĐÈ lên đáy màn này — không đệm sẽ che gần hết FAB, đúng bug đã bắt ở
    // Phase 6 (`TransactionsScreen`), tái diễn ở đây vì màn hình MỚI.
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Mẫu giao dịch')),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom:
              kBottomNavReservedHeight +
              MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: FloatingActionButton(
          onPressed: () => showTransactionTemplateEditSheet(context: context),
          child: const Icon(kIconAdd),
        ),
      ),
      body: templatesAsync.when(
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Text(
                'Chưa có mẫu nào — bấm "+" để tạo mẫu đầu tiên.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            );
          }
          final categoriesById = {
            for (final c in categoriesAsync.value ?? const <Category>[])
              c.id: c,
          };
          final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
          return ListView(
            padding: EdgeInsets.all(context.space.screenHorizontal),
            children: [
              for (final template in templates)
                _TemplateTile(
                  template: template,
                  category: categoriesById[template.categoryId],
                ),
              SizedBox(height: kBottomNavReservedHeight + bottomInset),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Lỗi: $error')),
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template, required this.category});

  final TransactionTemplate template;
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = Money(
      minorUnits: template.amountMinor,
      currency: template.currency,
      currencyScale: template.currencyScale,
    );
    return Card(
      margin: EdgeInsets.only(bottom: context.space.sm),
      child: ListTile(
        onTap: () => showTransactionTemplateEditSheet(
          context: context,
          existingId: template.id,
          existingName: template.name,
          existingAmountMinor: template.amountMinor,
          existingCategoryId: template.categoryId,
          existingNote: template.note,
        ),
        leading: CategoryAvatar(
          categoryColorId: category?.categoryColorId ?? 10,
          iconCode: category?.iconCode ?? 'more_horiz',
        ),
        title: Text(template.name),
        subtitle: Text(AmountVisibility.mask(context, amount.format())),
        trailing: PopupMenuButton<void>(
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: () => ref
                  .read(transactionTemplateRepositoryProvider)
                  .delete(template.id),
              child: Text(
                'Xoá',
                style: TextStyle(color: context.colors.expenseFill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
