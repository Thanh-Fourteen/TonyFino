import '../../../ui/grouped_number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/time/clock_provider.dart';
import '../../../data/db/database.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../../../ui/wallet_avatar.dart';
import '../wallets_providers.dart';

Future<void> showTransferSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => const TransferSheet(),
  );
}

/// Chuyển khoản giữa 2 ví (Phase 13) — tạo cặp giao dịch liên kết qua
/// `WalletRepository.createTransfer`, loại khỏi báo cáo/ngân sách theo danh
/// mục (xem docs/decisions.md § Phase 13 "Chuyển khoản").
class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key});

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  int? _sourceWalletId;
  int? _destWalletId;
  bool _saving = false;
  String? _amountError;
  String? _walletError;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rawDigits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(rawDigits);
    if (parsed == null || parsed <= 0) {
      setState(() => _amountError = 'Nhập số tiền hợp lệ');
      return;
    }
    if (_sourceWalletId == null || _destWalletId == null) {
      setState(() => _walletError = 'Chọn ví nguồn và ví đích');
      return;
    }
    if (_sourceWalletId == _destWalletId) {
      setState(() => _walletError = 'Ví nguồn và ví đích phải khác nhau');
      return;
    }
    setState(() {
      _amountError = null;
      _walletError = null;
      _saving = true;
    });

    final repo = ref.read(walletRepositoryProvider);
    final now = ref.read(clockProvider).now();
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final result = await repo.createTransfer(
      sourceWalletId: _sourceWalletId!,
      destWalletId: _destWalletId!,
      amount: Money.vnd(parsed),
      occurredAt: now,
      note: note,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      ok: (_) => Navigator.of(context).pop(),
      err: (error) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Không tạo được chuyển khoản'),
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
    final walletsAsync = ref.watch(activeWalletsProvider);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.screenHorizontal,
        vertical: context.space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chuyển khoản giữa ví', style: context.text.titleLarge),
          SizedBox(height: context.space.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsSeparatorInputFormatter()],
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Số tiền',
                      suffixText: '₫',
                      errorText: _amountError,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  Text('Từ ví', style: context.text.labelMedium),
                  SizedBox(height: context.space.xs),
                  walletsAsync.when(
                    data: (wallets) => _WalletChips(
                      key: const Key('sourceWalletChips'),
                      wallets: wallets,
                      selectedId: _sourceWalletId,
                      onSelected: (id) => setState(() => _sourceWalletId = id),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (error, _) => Text('Không tải được ví: $error'),
                  ),
                  SizedBox(height: context.space.md),
                  Text('Đến ví', style: context.text.labelMedium),
                  SizedBox(height: context.space.xs),
                  walletsAsync.when(
                    data: (wallets) => _WalletChips(
                      key: const Key('destWalletChips'),
                      wallets: wallets,
                      selectedId: _destWalletId,
                      onSelected: (id) => setState(() => _destWalletId = id),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (error, _) => Text('Không tải được ví: $error'),
                  ),
                  if (_walletError != null) ...[
                    SizedBox(height: context.space.xs),
                    Text(
                      _walletError!,
                      style: context.text.labelMedium?.copyWith(
                        color: context.colors.expenseFill,
                      ),
                    ),
                  ],
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
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(kIconSwapHoriz),
                label: const Text('Chuyển'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletChips extends StatelessWidget {
  const _WalletChips({
    super.key,
    required this.wallets,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Wallet> wallets;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.space.xs,
      runSpacing: context.space.xs,
      children: [
        for (final wallet in wallets)
          ChoiceChip(
            label: Text(wallet.name),
            avatar: WalletAvatar(
              categoryColorId: wallet.categoryColorId,
              iconCode: wallet.iconCode,
              size: 18,
            ),
            selected: wallet.id == selectedId,
            onSelected: (_) => onSelected(wallet.id),
          ),
      ],
    );
  }
}
