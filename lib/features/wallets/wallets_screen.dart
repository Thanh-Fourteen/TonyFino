import '../../ui/amount_visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/providers/database_providers.dart';
import '../../data/db/database.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/wallet_avatar.dart';
import 'wallets_providers.dart';
import 'widgets/transfer_sheet.dart';
import 'widgets/wallet_edit_sheet.dart';

/// Quản lý ví (Phase 13) — CRUD (thêm/sửa/lưu trữ, KHÔNG xoá cứng) + số dư
/// từng ví (SUM trực tiếp, D7) + lối vào "Chuyển khoản giữa ví".
class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key, this.embedded = false});

  /// `true` khi màn này nằm TRONG một tab của `MoneyHubScreen` —
  /// bỏ AppBar riêng vì hub đã có tiêu đề + thanh tab. FAB giữ
  /// nguyên: nó là hành động của riêng tab này.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(activeWalletBalancesProvider);
    final archivedAsync = ref.watch(archivedWalletsProvider);

    return Scaffold(
      backgroundColor: embedded ? Colors.transparent : null,
      appBar: embedded
          ? null
          : AppBar(
              title: const Text('Ví'),
              actions: [
                IconButton(
                  icon: const Icon(kIconSwapHoriz),
                  tooltip: 'Chuyển khoản giữa ví',
                  onPressed: () => showTransferSheet(context),
                ),
              ],
            ),
      // Hub tự dựng FAB theo tab đang xem — màn nhúng không dựng thêm cái
      // thứ hai chồng lên.
      floatingActionButton: embedded
          ? null
          : FloatingActionButton(
              onPressed: () => showWalletEditSheet(context: context),
              child: const Icon(kIconAdd),
            ),
      body: balancesAsync.when(
        data: (balances) {
          final archived = archivedAsync.value ?? const <Wallet>[];
          return ListView(
            padding: EdgeInsets.all(context.space.screenHorizontal),
            children: [
              for (final wb in balances)
                _WalletTile(
                  wallet: wb.wallet,
                  balance: wb.balance,
                  onArchive: () => ref
                      .read(walletRepositoryProvider)
                      .setArchived(wb.wallet.id, true),
                ),
              if (archived.isNotEmpty) ...[
                SizedBox(height: context.space.lg),
                Text('Đã lưu trữ', style: context.text.titleMedium),
                SizedBox(height: context.space.sm),
                for (final wallet in archived)
                  _ArchivedWalletTile(
                    wallet: wallet,
                    onRestore: () => ref
                        .read(walletRepositoryProvider)
                        .setArchived(wallet.id, false),
                  ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Lỗi: $error')),
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  const _WalletTile({
    required this.wallet,
    required this.balance,
    required this.onArchive,
  });

  final Wallet wallet;
  final Money balance;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: context.space.sm),
      child: ListTile(
        onTap: () => showWalletEditSheet(
          context: context,
          existingId: wallet.id,
          existingName: wallet.name,
          existingColorId: wallet.categoryColorId,
          existingIconCode: wallet.iconCode,
          existingOpeningBalanceMinor: wallet.openingBalanceMinor,
        ),
        leading: WalletAvatar(
          categoryColorId: wallet.categoryColorId,
          iconCode: wallet.iconCode,
        ),
        title: Text(wallet.name),
        trailing: PopupMenuButton<void>(
          itemBuilder: (context) => [
            PopupMenuItem(onTap: onArchive, child: const Text('Lưu trữ')),
          ],
        ),
        subtitle: Text(
          AmountVisibility.mask(context, balance.format()),
          style: context.money.moneyMedium.copyWith(
            color: balance.isNegative
                ? context.colors.onSurface
                : context.colors.incomeText,
          ),
        ),
      ),
    );
  }
}

class _ArchivedWalletTile extends StatelessWidget {
  const _ArchivedWalletTile({required this.wallet, required this.onRestore});

  final Wallet wallet;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: WalletAvatar(
        categoryColorId: wallet.categoryColorId,
        iconCode: wallet.iconCode,
        size: 32,
      ),
      title: Text(
        wallet.name,
        style: TextStyle(color: context.colors.onSurfaceVariant),
      ),
      trailing: TextButton(
        onPressed: onRestore,
        child: const Text('Khôi phục'),
      ),
    );
  }
}
