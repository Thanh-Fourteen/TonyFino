import '../../../ui/grouped_number_field.dart';
import '../../../ui/two_level_category_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/providers/database_providers.dart';
import '../../../theme/context_ext.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../transactions_providers.dart';

Future<void> showTransactionTemplateEditSheet({
  required BuildContext context,
  int? existingId,
  String? existingName,
  int? existingAmountMinor,
  int? existingCategoryId,
  String? existingNote,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => TransactionTemplateEditSheet(
      existingId: existingId,
      existingName: existingName,
      existingAmountMinor: existingAmountMinor,
      existingCategoryId: existingCategoryId,
      existingNote: existingNote,
    ),
  );
}

/// Sheet thêm/sửa mẫu giao dịch (Phase 14) — cùng khuôn `WalletEditSheet`.
/// Xoá là xoá thật (không có lưu trữ) — mẫu không phải dữ liệu tài chính, chỉ
/// là một khuôn điền sẵn (xem docs/decisions.md § Phase 14 "Mẫu giao dịch").
class TransactionTemplateEditSheet extends ConsumerStatefulWidget {
  const TransactionTemplateEditSheet({
    super.key,
    this.existingId,
    this.existingName,
    this.existingAmountMinor,
    this.existingCategoryId,
    this.existingNote,
  });

  final int? existingId;
  final String? existingName;
  final int? existingAmountMinor;
  final int? existingCategoryId;
  final String? existingNote;

  @override
  ConsumerState<TransactionTemplateEditSheet> createState() =>
      _TransactionTemplateEditSheetState();
}

class _TransactionTemplateEditSheetState
    extends ConsumerState<TransactionTemplateEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late bool _isExpense;
  int? _selectedCategoryId;
  bool _saving = false;
  String? _nameError;
  String? _amountError;

  bool get _isEditing => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingName ?? '');
    final seedAmount = widget.existingAmountMinor;
    _isExpense = seedAmount == null ? true : seedAmount < 0;
    _amountController = TextEditingController(
      text: seedAmount == null ? '' : groupDigits(seedAmount.abs().toString()),
    );
    _noteController = TextEditingController(text: widget.existingNote ?? '');
    _selectedCategoryId = widget.existingCategoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final rawDigits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(rawDigits);

    var hasError = false;
    if (name.isEmpty) {
      setState(() => _nameError = 'Nhập tên mẫu');
      hasError = true;
    }
    if (parsed == null || parsed == 0) {
      setState(() => _amountError = 'Nhập số tiền hợp lệ');
      hasError = true;
    }
    if (hasError) return;

    setState(() {
      _nameError = null;
      _amountError = null;
      _saving = true;
    });

    final amount = Money.vnd(_isExpense ? -parsed! : parsed!);
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final repo = ref.read(transactionTemplateRepositoryProvider);

    final result = _isEditing
        ? await repo.update(
            id: widget.existingId!,
            name: name,
            amount: amount,
            categoryId: _selectedCategoryId,
            note: note,
          )
        : await repo.insert(
            name: name,
            amount: amount,
            categoryId: _selectedCategoryId,
            note: note,
          );

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      ok: (_) => Navigator.of(context).pop(),
      err: (error) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Không lưu được'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(activeCategoriesProvider);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.screenHorizontal,
        vertical: context.space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Sửa mẫu giao dịch' : 'Thêm mẫu giao dịch',
            style: context.text.titleLarge,
          ),
          SizedBox(height: context.space.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: !_isEditing,
                    decoration: InputDecoration(
                      labelText: 'Tên mẫu',
                      errorText: _nameError,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Chi')),
                      ButtonSegment(value: false, label: Text('Thu')),
                    ],
                    selected: {_isExpense},
                    onSelectionChanged: (selection) =>
                        setState(() => _isExpense = selection.first),
                  ),
                  SizedBox(height: context.space.md),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsSeparatorInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Số tiền',
                      suffixText: '₫',
                      errorText: _amountError,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  Text('Danh mục (tuỳ chọn)', style: context.text.labelMedium),
                  SizedBox(height: context.space.xs),
                  categoriesAsync.when(
                    data: (categories) => TwoLevelCategoryPicker(
                      categories: categories,
                      kind: null,
                      selectedId: _selectedCategoryId,
                      onChanged: (id) =>
                          setState(() => _selectedCategoryId = id),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (error, _) =>
                        Text('Không tải được danh mục: $error'),
                  ),
                  SizedBox(height: context.space.md),
                  TextField(
                    controller: _noteController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú (tuỳ chọn)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.space.lg),
          Row(
            children: [
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lưu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
