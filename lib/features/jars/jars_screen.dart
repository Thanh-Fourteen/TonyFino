import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../data/repositories/jar_repository.dart';
import '../../core/router/app_bottom_nav.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_card.dart';
import '../../ui/category_avatar.dart';
import '../../ui/empty_state.dart';
import '../../ui/money_text.dart';
import '../home/home_period_provider.dart';
import '../wallets/selected_wallet_provider.dart';
import 'jars_providers.dart';
import 'widgets/jar_categories_sheet.dart';
import 'widgets/jar_edit_sheet.dart';
import '../home/widgets/period_chip.dart';

/// Màn Hũ — chia thu nhập của kỳ thành các hũ theo phần trăm.
///
/// Khác màn Ngân sách ở chỗ căn bản: ngân sách là "tôi cho phép mình tiêu
/// tối đa X đồng cho danh mục này", hũ là "mỗi đồng THU về được chia sẵn
/// theo tỉ lệ trước khi tiêu". Tháng thu nhiều thì mọi hũ tự rộng ra — đó
/// là điểm khiến phương pháp hũ chịu được thu nhập thất thường, và cũng là
/// lý do nó là một màn riêng chứ không phải một kiểu ngân sách.
class JarsScreen extends ConsumerWidget {
  const JarsScreen({super.key, this.embedded = false});

  /// `true` khi màn này nằm TRONG một tab của `MoneyHubScreen` —
  /// bỏ AppBar riêng vì hub đã có tiêu đề + thanh tab. FAB giữ
  /// nguyên: nó là hành động của riêng tab này.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(jarProgressProvider);
    final period = ref.watch(homePeriodProvider);
    final walletId = ref.watch(selectedWalletIdProvider);
    final progress = progressAsync.value ?? const <JarProgress>[];

    return Scaffold(
      backgroundColor: embedded ? Colors.transparent : null,
      appBar: embedded ? null : AppBar(title: const Text('Hũ chia thu nhập')),
      // Nhúng trong hub thì FAB do hub dựng (nó mới biết chừa chỗ cho thanh
      // điều hướng nổi) — xem `MoneyHubScreen._fab`.
      floatingActionButton: embedded || progress.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => showJarEditSheet(context: context),
              tooltip: 'Thêm hũ',
              child: const Icon(kIconAdd),
            ),
      body: progressAsync.isLoading && !progressAsync.hasValue
          ? const Center(child: CircularProgressIndicator())
          : progress.isEmpty
          ? _EmptyJars(walletId: walletId)
          : ListView(
              padding: EdgeInsets.fromLTRB(
                context.space.screenHorizontal,
                context.space.screenHorizontal,
                context.space.screenHorizontal,
                context.space.screenHorizontal +
                    (embedded ? kBottomNavReservedHeight : 0),
              ),
              children: [
                // Bộ chọn kỳ ngay tại đây — hũ là "ngân sách theo kỳ", nên
                // đổi kỳ phải làm được ở chính màn này, không phải quay về
                // Trang chủ. Dùng CHUNG provider với Trang chủ (xem
                // `PeriodChip`).
                Row(
                  children: [
                    PeriodChip(period: period),
                    SizedBox(width: context.space.sm),
                    Expanded(
                      child: Text(
                        'tỉ lệ tính trên TỔNG THU của kỳ',
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.space.md),
                for (final p in progress) ...[
                  _JarCard(progress: p),
                  SizedBox(height: context.space.betweenCards),
                ],
                _PercentFooter(progress: progress),
              ],
            ),
    );
  }
}

class _EmptyJars extends ConsumerWidget {
  const _EmptyJars({required this.walletId});

  final int? walletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.space.screenHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyState(
              icon: kIconSavings,
              title: 'Chưa chia hũ nào',
              message:
                  'Chia mỗi khoản thu theo tỉ lệ cố định trước khi tiêu. '
                  'Mẫu 6 hũ kinh điển: Thiết yếu 55% · Tiết kiệm dài hạn 10% '
                  '· Giáo dục 10% · Hưởng thụ 10% · Tự do tài chính 10% · '
                  'Cho đi 5%.',
            ),
            SizedBox(height: context.space.lg),
            FilledButton(
              onPressed: walletId == null
                  ? null
                  : () => ref
                        .read(jarRepositoryProvider)
                        .seedDefaultJars(walletId!),
              child: const Text('Dùng mẫu 6 hũ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _JarCard extends ConsumerWidget {
  const _JarCard({required this.progress});

  final JarProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jar = progress.jar;
    final over = progress.remaining.minorUnits < 0;
    final barColor = over
        ? context.colors.budgetOver
        : progress.ratio > 0.8
        ? context.colors.budgetWarn
        : context.colors.budgetOk;

    return AppCard(
      // Bấm THẺ = sửa chính cái hũ (tên/tỉ lệ/màu/cộng dồn) — thao tác hay
      // dùng hơn. Chọn danh mục có nút riêng bên dưới, nói rõ bằng chữ.
      onTap: () => showJarEditSheet(context: context, existing: jar),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(
                categoryColorId: jar.categoryColorId,
                iconCode: jar.iconCode,
                size: 40,
              ),
              SizedBox(width: context.space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(jar.name, style: context.text.bodyLarge),
                    Text(
                      '${jar.percent}% · ${progress.categoryCount} danh mục'
                      '${jar.carryOver ? ' · cộng dồn' : ''}',
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Hạn mức KHÔNG phải dòng tiền vào — hiện trung tính.
              MoneyText(
                progress.allotted,
                size: MoneySize.medium,
                signed: false,
              ),
            ],
          ),
          SizedBox(height: context.space.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(context.radii.full),
            child: LinearProgressIndicator(
              // Kẹp ở 1.0: đã tiêu quá hũ thì thanh đầy và ĐỔI MÀU, không
              // tràn ra ngoài khung.
              value: progress.ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: context.colors.surfaceContainer,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          SizedBox(height: context.space.xs),
          Row(
            children: [
              Text(
                'Đã tiêu ',
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              MoneyText(progress.spent, size: MoneySize.small, signed: false),
              const Spacer(),
              Text(
                over ? 'Vượt ' : 'Còn ',
                style: context.text.labelMedium?.copyWith(
                  color: over
                      ? context.colors.budgetOver
                      : context.colors.onSurfaceVariant,
                ),
              ),
              MoneyText(
                over ? -progress.remaining : progress.remaining,
                size: MoneySize.small,
                signed: false,
              ),
            ],
          ),
          SizedBox(height: context.space.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showJarCategoriesSheet(context, jar),
              icon: const Icon(kIconCategory, size: 18),
              label: Text(
                progress.categoryCount == 0
                    ? 'Chọn danh mục cho hũ'
                    : 'Sửa ${progress.categoryCount} danh mục',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tổng phần trăm — cảnh báo khi khác 100%.
class _PercentFooter extends StatelessWidget {
  const _PercentFooter({required this.progress});

  final List<JarProgress> progress;

  @override
  Widget build(BuildContext context) {
    final total = progress.fold(0, (s, p) => s + p.jar.percent);
    if (total == 100) {
      return Text(
        'Tổng 100% — mọi đồng thu đều đã có chỗ.',
        textAlign: TextAlign.center,
        style: context.text.labelMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      );
    }
    // Nguyên tắc cốt lõi của phương pháp phong bì: "gán từng đồng cho tới
    // khi phần chưa gán bằng 0". Lệch 100% mà im lặng thì hũ chỉ còn là
    // trang trí.
    return Text(
      total < 100
          ? 'Tổng mới $total% — còn ${100 - total}% thu nhập chưa vào hũ nào.'
          : 'Tổng $total% — vượt quá thu nhập ${total - 100}%.',
      textAlign: TextAlign.center,
      style: context.text.labelMedium?.copyWith(
        color: context.colors.budgetWarn,
      ),
    );
  }
}
