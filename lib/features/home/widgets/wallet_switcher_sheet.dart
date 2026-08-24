import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/money_text.dart';
import '../../../ui/wallet_avatar.dart';
import '../../wallets/selected_wallet_provider.dart';
import '../../wallets/wallets_providers.dart';

/// Bảng đổi ví. Đổi ví là đổi CẢ BỐI CẢNH — danh mục, ngân sách, báo cáo
/// đều theo ví (v11) — nên nó xứng đáng một thao tác tường minh chứ không
/// phải một dropdown lẫn trong Cài đặt.
Future<void> showWalletSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _WalletSwitcherSheet(),
  );
}

class _WalletSwitcherSheet extends ConsumerWidget {
  const _WalletSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(activeWalletBalancesProvider).value ?? const [];
    final selected = ref.watch(selectedWalletIdProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.space.screenHorizontal,
              0,
              context.space.screenHorizontal,
              context.space.sm,
            ),
            child: Text('Chọn ví', style: context.text.titleMedium),
          ),
          for (final b in balances)
            ListTile(
              leading: WalletAvatar(
                categoryColorId: b.wallet.categoryColorId,
                iconCode: b.wallet.iconCode,
              ),
              title: Text(b.wallet.name),
              subtitle: MoneyText(b.balance, size: MoneySize.small),
              trailing: b.wallet.id == selected
                  ? Icon(kIconCheck, color: context.colors.brandText)
                  : null,
              onTap: () {
                ref
                    .read(walletSelectionOverrideProvider.notifier)
                    .select(b.wallet.id);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}
