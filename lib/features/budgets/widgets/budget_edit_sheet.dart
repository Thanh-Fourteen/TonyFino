import '../../../ui/grouped_number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/result/result.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../../../ui/category_avatar.dart';
import '../domain/budget_period.dart';

/// Sheet đặt/sửa/xoá ngân sách của MỘT danh mục trong MỘT kỳ — Bottom-
/// sheet-first, cùng khuôn với `TransactionFormSheet` (Phase 6).
///
/// Nhận `category*` rời (id/tên/màu/icon) thay vì cả kiểu `Category` của
/// drift — cả hai call site (`_BudgetProgressCard` có `BudgetProgress`,
/// `_UnbudgetedRow` có `Category` thật) đều đã có sẵn 4 trường này, khỏi
/// phải dựng một hàng `Category` giả chỉ để thoả kiểu tham số.
Future<void> showBudgetEditSheet({
  required BuildContext context,
  required int categoryId,
  required String categoryName,
  required int categoryColorId,
  required String iconCode,
  required BudgetPeriod period,
  int? existingBudgetId,
  int? existingAmountMinor,
  bool existingCarryOver = false,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) => BudgetEditSheet(
      categoryId: categoryId,
      categoryName: categoryName,
      categoryColorId: categoryColorId,
      iconCode: iconCode,
      period: period,
      existingBudgetId: existingBudgetId,
      existingAmountMinor: existingAmountMinor,
      existingCarryOver: existingCarryOver,
    ),
  );
}

class BudgetEditSheet extends ConsumerStatefulWidget {
  const BudgetEditSheet({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryColorId,
    required this.iconCode,
    required this.period,
    this.existingBudgetId,
    this.existingAmountMinor,
    this.existingCarryOver = false,
  });

  final int categoryId;
  final String categoryName;
  final int categoryColorId;
  final String iconCode;
  final BudgetPeriod period;
  final int? existingBudgetId;
  final int? existingAmountMinor;
  final bool existingCarryOver;

  @override
  ConsumerState<BudgetEditSheet> createState() => _BudgetEditSheetState();
}

class _BudgetEditSheetState extends ConsumerState<BudgetEditSheet> {
  late final TextEditingController _amountController;
  bool _saving = false;
  String? _amountError;
  late bool _carryOver;

  bool get _isEditing => widget.existingBudgetId != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: groupDigits(widget.existingAmountMinor?.toString() ?? ''),
    );
    _carryOver = widget.existingCarryOver;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
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

    final repo = ref.read(budgetRepositoryProvider);
    final result = await repo.upsertBudget(
      categoryId: widget.categoryId,
      period: widget.period,
      amount: Money.vnd(parsed),
      carryOver: _carryOver,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    _handleResult(result);
  }

  Future<void> _delete() async {
    if (widget.existingBudgetId == null) return;
    setState(() => _saving = true);
    final repo = ref.read(budgetRepositoryProvider);
    final result = await repo.deleteBudget(widget.existingBudgetId!);
    if (!mounted) return;
    setState(() => _saving = false);
    _handleResult(result);
  }

  void _handleResult(Result<void, AppError> result) {
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
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.screenHorizontal,
        vertical: context.space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(
                categoryColorId: widget.categoryColorId,
                iconCode: widget.iconCode,
                size: 36,
              ),
              SizedBox(width: context.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.categoryName, style: context.text.titleLarge),
                    Text(
                      widget.period.label,
                      style: context.text.labelMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.space.lg),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: const [ThousandsSeparatorInputFormatter()],
            autofocus: !_isEditing,
            decoration: InputDecoration(
              labelText: 'Ngân sách tháng',
              suffixText: '₫',
              errorText: _amountError,
            ),
          ),
          SizedBox(height: context.space.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _carryOver,
            onChanged: _saving
                ? null
                : (value) => setState(() => _carryOver = value),
            title: const Text('Cộng dồn từ kỳ trước'),
            subtitle: Text(
              'Dư/vượt kỳ trước cộng vào ngân sách kỳ này',
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(height: context.space.sm),
          Row(
            children: [
              if (_isEditing)
                TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: Icon(kIconDelete, color: context.colors.expenseFill),
                  label: Text(
                    'Xoá ngân sách',
                    style: TextStyle(color: context.colors.expenseFill),
                  ),
                ),
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
