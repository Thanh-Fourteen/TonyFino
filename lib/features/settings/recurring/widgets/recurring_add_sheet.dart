import '../../../../ui/grouped_number_field.dart';
import '../../../../ui/two_level_category_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/time/clock_provider.dart';
import '../../../../theme/context_ext.dart';
import '../../../../ui/app_bottom_sheet.dart';
import '../../../transactions/transactions_providers.dart';
import '../domain/recurring_frequency.dart';

Future<void> showRecurringAddSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => const RecurringAddSheet(),
  );
}

/// Sheet thêm giao dịch định kỳ — CHỈ thêm (chưa có sửa ở v1, xoá rồi thêm
/// lại nếu cần đổi; danh sách ở `RecurringScreen` xử lý tạm dừng/xoá). Cùng
/// khuôn `TransactionFormSheet`/`BudgetEditSheet` (Bottom-sheet-first).
class RecurringAddSheet extends ConsumerStatefulWidget {
  const RecurringAddSheet({super.key});

  @override
  ConsumerState<RecurringAddSheet> createState() => _RecurringAddSheetState();
}

class _RecurringAddSheetState extends ConsumerState<RecurringAddSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isExpense = true;
  int? _selectedCategoryId;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  late DateTime _nextDate;
  bool _saving = false;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _nextDate = ref.read(clockProvider).now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider).now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDate.isBefore(now) ? now : _nextDate,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _nextDate = picked);
  }

  Future<void> _save() async {
    final rawDigits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(rawDigits);
    if (parsed == null || parsed <= 0) {
      setState(() => _amountError = 'Nhập số tiền hợp lệ');
      return;
    }
    setState(() {
      _amountError = null;
      _saving = true;
    });

    final repo = ref.read(recurringTransactionRepositoryProvider);
    final result = await repo.insert(
      categoryId: _selectedCategoryId,
      amount: Money.vnd(_isExpense ? -parsed : parsed),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      frequency: _frequency,
      nextOccurrenceDate: _nextDate,
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
          Text('Thêm giao dịch định kỳ', style: context.text.titleLarge),
          SizedBox(height: context.space.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Số tiền mỗi kỳ',
                      suffixText: '₫',
                      errorText: _amountError,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  Text('Tần suất', style: context.text.labelMedium),
                  SizedBox(height: context.space.xs),
                  Wrap(
                    spacing: context.space.xs,
                    children: [
                      for (final frequency in RecurringFrequency.values)
                        ChoiceChip(
                          label: Text(frequency.label),
                          selected: _frequency == frequency,
                          onSelected: (_) =>
                              setState(() => _frequency = frequency),
                        ),
                    ],
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
                  Row(
                    children: [
                      Text(
                        'Kỳ tới: ${_nextDate.day}/${_nextDate.month}/${_nextDate.year}',
                        style: context.text.bodyMedium,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _pickDate,
                        child: const Text('Đổi ngày'),
                      ),
                    ],
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
