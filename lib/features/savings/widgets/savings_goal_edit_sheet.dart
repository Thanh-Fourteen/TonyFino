import '../../../ui/grouped_number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/time/clock_provider.dart';
import '../../../theme/context_ext.dart';
import '../../../ui/app_bottom_sheet.dart';

Future<void> showSavingsGoalEditSheet({
  required BuildContext context,
  int? existingId,
  String? existingName,
  int? existingTargetAmountMinor,
  DateTime? existingTargetDate,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => SavingsGoalEditSheet(
      existingId: existingId,
      existingName: existingName,
      existingTargetAmountMinor: existingTargetAmountMinor,
      existingTargetDate: existingTargetDate,
    ),
  );
}

/// Sheet thêm/sửa mục tiêu tiết kiệm (Phase 16) — cùng khuôn `WalletEditSheet`/
/// `BudgetEditSheet`. Không có nút xoá — mục tiêu CHỈ lưu trữ (archive) qua
/// popup menu ở tile danh sách, giống ví (xem docs/decisions.md § Phase 13).
class SavingsGoalEditSheet extends ConsumerStatefulWidget {
  const SavingsGoalEditSheet({
    super.key,
    this.existingId,
    this.existingName,
    this.existingTargetAmountMinor,
    this.existingTargetDate,
  });

  final int? existingId;
  final String? existingName;
  final int? existingTargetAmountMinor;
  final DateTime? existingTargetDate;

  @override
  ConsumerState<SavingsGoalEditSheet> createState() =>
      _SavingsGoalEditSheetState();
}

class _SavingsGoalEditSheetState extends ConsumerState<SavingsGoalEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  DateTime? _targetDate;
  bool _saving = false;
  String? _nameError;
  String? _amountError;

  bool get _isEditing => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingName ?? '');
    _amountController = TextEditingController(
      text: groupDigits(widget.existingTargetAmountMinor?.toString() ?? ''),
    );
    _targetDate = widget.existingTargetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final now = ref.read(clockProvider).now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final rawDigits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(rawDigits);

    var hasError = false;
    if (name.isEmpty) {
      setState(() => _nameError = 'Nhập tên mục tiêu');
      hasError = true;
    }
    if (parsed == null || parsed <= 0) {
      setState(() => _amountError = 'Nhập số tiền hợp lệ');
      hasError = true;
    }
    if (hasError) return;

    setState(() {
      _nameError = null;
      _amountError = null;
      _saving = true;
    });

    final repo = ref.read(savingsGoalRepositoryProvider);
    final target = Money.vnd(parsed!);
    final result = _isEditing
        ? await repo.update(
            id: widget.existingId!,
            name: name,
            targetAmount: target,
            targetDate: _targetDate,
          )
        : await repo.insert(
            name: name,
            targetAmount: target,
            targetDate: _targetDate,
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
            _isEditing ? 'Sửa mục tiêu' : 'Thêm mục tiêu tiết kiệm',
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
                      labelText: 'Tên mục tiêu',
                      errorText: _nameError,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsSeparatorInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Số tiền cần đạt',
                      suffixText: '₫',
                      errorText: _amountError,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  Row(
                    children: [
                      Text(
                        _targetDate == null
                            ? 'Không đặt hạn'
                            : 'Hạn: ${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}',
                        style: context.text.bodyMedium,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _pickTargetDate,
                        child: const Text('Đặt hạn'),
                      ),
                      if (_targetDate != null)
                        TextButton(
                          onPressed: () => setState(() => _targetDate = null),
                          child: const Text('Bỏ'),
                        ),
                    ],
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
