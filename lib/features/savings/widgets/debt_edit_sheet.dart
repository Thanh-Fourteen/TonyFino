import '../../../ui/grouped_number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/time/clock_provider.dart';
import '../../../theme/context_ext.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../domain/debt_kind.dart';

Future<void> showDebtEditSheet({
  required BuildContext context,
  int? existingId,
  String? existingCounterpartyName,
  DebtKind? existingKind,
  int? existingPrincipalMinor,
  DateTime? existingStartDate,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => DebtEditSheet(
      existingId: existingId,
      existingCounterpartyName: existingCounterpartyName,
      existingKind: existingKind,
      existingPrincipalMinor: existingPrincipalMinor,
      existingStartDate: existingStartDate,
    ),
  );
}

/// Sheet thêm/sửa khoản vay/cho vay (Phase 16) — cùng khuôn `SavingsGoalEditSheet`.
/// `principalMinor` (số gốc) CHỈ sửa được khi TẠO MỚI — sửa gốc của một
/// khoản đã có giao dịch trả/thu gắn vào sẽ làm `remainingMinor` nhảy đột
/// ngột không giải thích được, nên khoá lại lúc sửa (giữ nguyên gốc, chỉ đổi
/// tên/ngày).
class DebtEditSheet extends ConsumerStatefulWidget {
  const DebtEditSheet({
    super.key,
    this.existingId,
    this.existingCounterpartyName,
    this.existingKind,
    this.existingPrincipalMinor,
    this.existingStartDate,
  });

  final int? existingId;
  final String? existingCounterpartyName;
  final DebtKind? existingKind;
  final int? existingPrincipalMinor;
  final DateTime? existingStartDate;

  @override
  ConsumerState<DebtEditSheet> createState() => _DebtEditSheetState();
}

class _DebtEditSheetState extends ConsumerState<DebtEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _principalController;
  late DebtKind _kind;
  late DateTime _startDate;
  bool _saving = false;
  String? _nameError;
  String? _principalError;

  bool get _isEditing => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingCounterpartyName ?? '',
    );
    _principalController = TextEditingController(
      text: groupDigits(widget.existingPrincipalMinor?.toString() ?? ''),
    );
    _kind = widget.existingKind ?? DebtKind.debt;
    _startDate = widget.existingStartDate ?? ref.read(clockProvider).now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _principalController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = ref.read(clockProvider).now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final rawDigits = _principalController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final parsed = int.tryParse(rawDigits);

    var hasError = false;
    if (name.isEmpty) {
      setState(() => _nameError = 'Nhập tên đối tượng');
      hasError = true;
    }
    if (!_isEditing && (parsed == null || parsed <= 0)) {
      setState(() => _principalError = 'Nhập số tiền hợp lệ');
      hasError = true;
    }
    if (hasError) return;

    setState(() {
      _nameError = null;
      _principalError = null;
      _saving = true;
    });

    final repo = ref.read(debtRepositoryProvider);
    final result = _isEditing
        ? await repo.update(
            id: widget.existingId!,
            counterpartyName: name,
            kind: _kind,
            principal: Money.vnd(widget.existingPrincipalMinor!),
            startDate: _startDate,
          )
        : await repo.insert(
            counterpartyName: name,
            kind: _kind,
            principal: Money.vnd(parsed!),
            startDate: _startDate,
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
            _isEditing ? 'Sửa khoản vay' : 'Thêm khoản vay/cho vay',
            style: context.text.titleLarge,
          ),
          SizedBox(height: context.space.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<DebtKind>(
                    segments: [
                      for (final kind in DebtKind.values)
                        ButtonSegment(value: kind, label: Text(kind.label)),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (selection) =>
                        setState(() => _kind = selection.first),
                  ),
                  SizedBox(height: context.space.md),
                  TextField(
                    controller: _nameController,
                    autofocus: !_isEditing,
                    decoration: InputDecoration(
                      labelText: 'Tên người/đối tượng',
                      errorText: _nameError,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  TextField(
                    controller: _principalController,
                    enabled: !_isEditing,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsSeparatorInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Số tiền gốc',
                      suffixText: '₫',
                      errorText: _principalError,
                      helperText: _isEditing
                          ? 'Không sửa được số gốc sau khi tạo'
                          : null,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  Row(
                    children: [
                      Text(
                        'Ngày: ${_startDate.day}/${_startDate.month}/${_startDate.year}',
                        style: context.text.bodyMedium,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _pickStartDate,
                        child: const Text('Đổi ngày'),
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
