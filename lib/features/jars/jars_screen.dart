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
import 'jar_detail_screen.dart';
import 'widgets/jar_categories_sheet.dart';
import 'widgets/jar_edit_sheet.dart';
import '../../core/money/money.dart';
import '../../ui/amount_visibility.dart';
import '../savings/widgets/savings_contribution_sheet.dart';
import '../home/widgets/period_chip.dart';

/// Màn Hũ — chia thu nhập của kỳ thành các hũ theo phần trăm.
///
/// Khác màn Ngân sách ở chỗ căn bản: ngân sách là "tôi cho phép mình tiêu
/// tối đa X đồng cho danh mục này", hũ là "mỗi đồng THU về được chia sẵn
/// theo tỉ lệ trước khi tiêu". Tháng thu nhiều thì mọi hũ tự rộng ra — đó
/// là điểm khiến phương pháp hũ chịu được thu nhập thất thường, và cũng là
/// lý do nó là một màn riêng chứ không phải một kiểu ngân sách.
class JarsScreen extends ConsumerStatefulWidget {
  const JarsScreen({super.key, this.embedded = false});

  /// `true` khi màn này nằm TRONG một tab của `MoneyHubScreen` —
  /// bỏ AppBar riêng vì hub đã có tiêu đề + thanh tab. FAB giữ
  /// nguyên: nó là hành động của riêng tab này.
  final bool embedded;

  @override
  ConsumerState<JarsScreen> createState() => _JarsScreenState();
}

class _JarsScreenState extends ConsumerState<JarsScreen> {
  /// Thứ tự vừa kéo thả, giữ tạm cho tới khi stream từ DB phát đúng thứ tự
  /// đó. Không có nó thì thả tay ra là thẻ nhảy về chỗ cũ một nhịp rồi mới
  /// sang chỗ mới — trông như kéo thả không ăn.
  List<int>? _pendingOrder;

  bool get embedded => widget.embedded;

  List<JarProgress> _ordered(List<JarProgress> fromDb) {
    final pending = _pendingOrder;
    if (pending == null) return fromDb;
    final dbOrder = [for (final p in fromDb) p.jar.id];
    // DB đã bắt kịp — hoặc bộ hũ đã đổi (thêm/xoá) — thì bỏ thứ tự tạm.
    if (_sameList(dbOrder, pending) ||
        dbOrder.length != pending.length ||
        !dbOrder.toSet().containsAll(pending)) {
      _pendingOrder = null;
      return fromDb;
    }
    final byId = {for (final p in fromDb) p.jar.id: p};
    return [for (final id in pending) byId[id]!];
  }

  static bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// `onReorderItem` (KHÔNG phải `onReorder`, đã deprecated sau Flutter
  /// 3.41): bản mới tự trừ chỗ trống của thẻ đang kéo, nên [newIndex] đã là
  /// vị trí cuối cùng — không được tự `-1` nữa, làm thế là lệch một ô khi
  /// kéo xuống.
  void _onReorder(List<JarProgress> jars, int oldIndex, int newIndex) {
    final ids = [for (final p in jars) p.jar.id];
    ids.insert(newIndex, ids.removeAt(oldIndex));
    setState(() => _pendingOrder = ids);
    ref.read(jarRepositoryProvider).reorder(ids);
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(jarProgressProvider);
    final period = ref.watch(homePeriodProvider);
    final walletId = ref.watch(selectedWalletIdProvider);
    final overview = progressAsync.value ?? JarsOverview.empty;

    return Scaffold(
      backgroundColor: embedded ? Colors.transparent : null,
      appBar: embedded ? null : AppBar(title: const Text('Hũ chia thu nhập')),
      // Nhúng trong hub thì FAB do hub dựng (nó mới biết chừa chỗ cho thanh
      // điều hướng nổi) — xem `MoneyHubScreen._fab`.
      floatingActionButton: embedded || overview.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => showJarEditSheet(context: context),
              tooltip: 'Thêm hũ',
              child: const Icon(kIconAdd),
            ),
      body: progressAsync.isLoading && !progressAsync.hasValue
          ? const Center(child: CircularProgressIndicator())
          : overview.isEmpty
          ? _EmptyJars(walletId: walletId)
          : Builder(
              builder: (context) {
                final jars = _ordered(overview.jars);
                // 🚨 Phần tĩnh (chip kỳ, thẻ tổng, dòng tổng %) đi vào
                // `header`/`footer`, KHÔNG làm con của danh sách: trộn thẻ
                // kéo được với thẻ tĩnh làm lệch chỉ số `onReorder` (bẫy đã
                // dính ở màn Danh mục, xem project_tonyfino_gotchas).
                return ReorderableListView(
                  padding: EdgeInsets.fromLTRB(
                    context.space.screenHorizontal,
                    context.space.screenHorizontal,
                    context.space.screenHorizontal,
                    context.space.screenHorizontal +
                        (embedded ? kBottomNavReservedHeight : 0),
                  ),
                  onReorderItem: (from, to) => _onReorder(jars, from, to),
                  header: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bộ chọn kỳ ngay tại đây — hũ là "ngân sách theo
                      // kỳ", nên đổi kỳ phải làm được ở chính màn này.
                      // Dùng CHUNG provider với Trang chủ (xem `PeriodChip`).
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PeriodChip(period: period),
                      ),
                      SizedBox(height: context.space.md),
                      JarsTotalsCard(overview: overview),
                      SizedBox(height: context.space.betweenCards),
                    ],
                  ),
                  footer: Column(
                    children: [
                      _PercentFooter(totalPercent: overview.totalPercent),
                      SizedBox(height: context.space.xs),
                      Text(
                        'Nhấn giữ một hũ rồi kéo để đổi thứ tự.',
                        textAlign: TextAlign.center,
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    for (final p in jars)
                      Padding(
                        key: ValueKey(p.jar.id),
                        padding: EdgeInsets.only(
                          bottom: context.space.betweenCards,
                        ),
                        child: _JarCard(progress: p),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

/// Nguồn chia + tổng cộng mọi hũ của kỳ.
///
/// Hiện TƯỜNG MINH con số thu nhập mà mọi phần trăm đang nhân vào: trước
/// đây màn này chỉ ghi "tỉ lệ tính trên TỔNG THU của kỳ" mà không nói tổng
/// thu là bao nhiêu, nên khi con số đó sai (nó từng đếm cả tiền RÚT từ quỹ
/// về là thu nhập) thì không có cách nào nhìn ra.
class JarsTotalsCard extends StatelessWidget {
  const JarsTotalsCard({super.key, required this.overview});

  final JarsOverview overview;

  @override
  Widget build(BuildContext context) {
    final remaining = overview.totalRemaining;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tổng thu của kỳ',
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              MoneyText(overview.income, size: MoneySize.medium),
            ],
          ),
          SizedBox(height: context.space.xxs),
          Text(
            'Mỗi hũ nhận đúng phần trăm của con số này.',
            style: context.text.labelSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.space.md),
          Divider(height: 1, color: context.colors.hairline),
          SizedBox(height: context.space.md),
          Row(
            spacing: context.space.sm,
            children: [
              Expanded(
                child: JarStat(
                  label: 'Đã chia ${overview.totalPercent}%',
                  amount: overview.totalAllotted,
                ),
              ),
              Expanded(
                child: JarStat(label: 'Đã dùng', amount: overview.totalUsed),
              ),
              Expanded(
                child: JarStat(
                  label: remaining.minorUnits < 0 ? 'Vượt' : 'Còn lại',
                  amount: remaining.minorUnits < 0 ? -remaining : remaining,
                  color: remaining.minorUnits < 0
                      ? context.colors.budgetOver
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Một ô "nhãn + số tiền" nhỏ — dùng chung cho thẻ tổng ở màn Hũ và thẻ Hũ
/// ở Trang chủ, để hai chỗ gọi cùng một con số bằng cùng một chữ.
class JarStat extends StatelessWidget {
  const JarStat({
    super.key,
    required this.label,
    required this.amount,
    this.color,
  });

  final String label;
  final Money amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: color ?? context.colors.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: context.space.xxs),
        // Co lại cho vừa một dòng — ba ô chia một hàng, số VND dài tới
        // "29.533.000 ₫"; gãy dòng thì chữ số bị cắt đọc thành số khác.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MoneyText(amount, size: MoneySize.small, signed: false),
        ),
      ],
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
    final saving = progress.kind == JarKind.saving;

    final String subtitle;
    if (saving) {
      final flowLabel = progress.spendsFromGoals ? 'Tiêu từ quỹ' : 'Tiết kiệm';
      subtitle = switch (progress.goals.length) {
        0 => '${jar.percent}% · $flowLabel · chưa gắn quỹ',
        1 =>
          '${jar.percent}% · $flowLabel → ${progress.goals.single.goal.name}',
        final n => '${jar.percent}% · $flowLabel · $n quỹ',
      };
    } else {
      subtitle =
          '${jar.percent}% · ${progress.categoryCount} danh mục'
          '${jar.carryOver ? ' · cộng dồn' : ''}';
    }

    return AppCard(
      // Bấm THẺ = XEM hũ tiêu vào đâu (màn Chi tiết hũ) — câu hỏi hay gặp
      // nhất. Sửa hũ nằm ở nút bút chì trên màn đó; chọn danh mục/nạp quỹ
      // vẫn có nút riêng ngay dưới thẻ.
      onTap: () => openJarDetailScreen(context, jar.id),
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
                      subtitle,
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // "đã tiêu / tổng nên tiêu" — Tony muốn thấy CẢ HAI con số ở
              // đây, không chỉ hạn mức: một mình hạn mức không nói được
              // tháng này đang đi tới đâu. Cùng lý do, dòng dưới chỉ còn
              // phần CÒN LẠI thay vì lặp lại "đã tiêu".
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      MoneyText(
                        progress.used,
                        size: MoneySize.medium,
                        signed: false,
                      ),
                      // Hũ không đặt mức nào cho kỳ (0%) thì "/ 0 ₫" là
                      // nhiễu — con số duy nhất có nghĩa là số đã dùng.
                      if (progress.allotted.minorUnits > 0)
                        Text(
                          AmountVisibility.mask(
                            context,
                            ' / ${progress.allotted.format()}',
                          ),
                          style: context.text.labelMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.space.sm),
          JarProgressBar(progress: progress, height: 8),
          SizedBox(height: context.space.xs),
          Row(
            children: [
              if (saving && progress.goals.isNotEmpty) ...[
                Text(
                  progress.spendsFromGoals ? 'Còn trong quỹ ' : 'Tổng quỹ ',
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                MoneyText(
                  progress.savedTotal,
                  size: MoneySize.small,
                  signed: false,
                ),
                // Đích chỉ có nghĩa với hũ ĐANG GOM tiền; hũ tiêu từ quỹ thì
                // con số đáng nhìn là phần còn lại, không phải cái đích.
                if (!progress.spendsFromGoals &&
                    progress.goalTarget.minorUnits > 0)
                  Text(
                    AmountVisibility.mask(
                      context,
                      ' / ${progress.goalTarget.format()}',
                    ),
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
              ],
              const Spacer(),
              ..._remainingLabel(context, progress),
            ],
          ),
          SizedBox(height: context.space.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: saving
                ? _SavingAction(progress: progress)
                : TextButton.icon(
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

  List<Widget> _remainingLabel(BuildContext context, JarProgress p) {
    final remaining = p.remaining;
    final String label;
    final Color color;
    final Money amount;
    if (p.tracksGoalDrawdown) {
      // Hũ tiêu từ quỹ, không đặt trần: phần đáng nói là quỹ còn bao nhiêu
      // — đã hiện ở bên trái, nên bên phải chỉ nói "còn dùng được".
      return [
        Text(
          p.savedTotal.minorUnits > 0 ? 'còn dùng được' : 'quỹ đã hết',
          style: context.text.labelMedium?.copyWith(
            color: p.savedTotal.minorUnits > 0
                ? context.colors.onSurfaceVariant
                : context.colors.budgetOver,
          ),
        ),
      ];
    }
    if (p.spendsFromGoals) {
      // Có TRẦN: giống hũ tiêu — còn được rút bao nhiêu, hay đã vượt.
      final over = remaining.minorUnits < 0;
      return [
        Text(
          over ? 'Vượt trần ' : 'Còn được rút ',
          style: context.text.labelMedium?.copyWith(
            color: over
                ? context.colors.budgetOver
                : context.colors.onSurfaceVariant,
          ),
        ),
        MoneyText(
          over ? -remaining : remaining,
          size: MoneySize.small,
          signed: false,
        ),
      ];
    }
    if (p.tracksGoalTotal) {
      // Hũ 0%: không có mốc của kỳ để nói "còn cần gửi" — thay bằng phần
      // còn thiếu so với ĐÍCH của các quỹ (thanh cũng đang đo cái đó).
      final left = p.goalTarget - p.savedTotal;
      if (p.goalTarget.minorUnits == 0 || left.minorUnits <= 0) {
        return [
          Text(
            p.goalTarget.minorUnits == 0 ? '' : 'Đã đạt đích',
            style: context.text.labelMedium?.copyWith(
              color: context.colors.budgetOk,
            ),
          ),
        ];
      }
      return [
        Text(
          'Còn thiếu ',
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        MoneyText(left, size: MoneySize.small, signed: false),
      ];
    }
    if (p.kind == JarKind.saving) {
      if (remaining.minorUnits <= 0) {
        label = remaining.minorUnits == 0 ? 'Đã đủ' : 'Đã đủ, dư ';
        color = context.colors.budgetOk;
        amount = -remaining;
      } else {
        label = 'Còn cần gửi ';
        color = context.colors.onSurfaceVariant;
        amount = remaining;
      }
    } else if (remaining.minorUnits < 0) {
      label = 'Vượt ';
      color = context.colors.budgetOver;
      amount = -remaining;
    } else {
      label = 'Còn ';
      color = context.colors.onSurfaceVariant;
      amount = remaining;
    }
    return [
      Text(label, style: context.text.labelMedium?.copyWith(color: color)),
      if (amount.minorUnits != 0)
        MoneyText(amount, size: MoneySize.small, signed: false),
    ];
  }
}

/// Nút hành động của hũ tiết kiệm: gửi tiền vào quỹ gắn kèm, hoặc — khi
/// chưa gắn quỹ nào — mời gắn.
class _SavingAction extends ConsumerWidget {
  const _SavingAction({required this.progress});

  final JarProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (progress.goals.length > 1) {
      return TextButton.icon(
        onPressed: () => openJarDetailScreen(context, progress.jar.id),
        icon: const Icon(kIconSavings, size: 18),
        label: Text('Xem ${progress.goals.length} quỹ trong hũ'),
      );
    }
    final linked = progress.goals.singleOrNull;
    if (linked == null) {
      return TextButton.icon(
        onPressed: () =>
            showJarEditSheet(context: context, existing: progress.jar),
        icon: const Icon(kIconSavings, size: 18),
        label: const Text('Chọn quỹ cho hũ'),
      );
    }
    final remaining = progress.remaining.minorUnits;
    return TextButton.icon(
      onPressed: () => showSavingsContributionSheet(
        context: context,
        goalId: linked.goal.id,
        goalName: linked.goal.name,
        // Hũ "tiêu từ quỹ" thì việc hay làm là RÚT ra tiêu, không phải nạp.
        move: progress.spendsFromGoals
            ? SavingsMove.withdraw
            : SavingsMove.deposit,
        // Gợi ý đúng phần còn thiếu của kỳ — lý do chính để mở nút này.
        // Hũ tiêu từ quỹ không gợi ý số: rút bao nhiêu là tuỳ hoá đơn.
        prefillMinor: !progress.spendsFromGoals && remaining > 0
            ? remaining
            : null,
      ),
      icon: const Icon(kIconAdd, size: 18),
      label: Text(
        progress.spendsFromGoals
            ? 'Rút từ "${linked.goal.name}"'
            : 'Gửi vào "${linked.goal.name}"',
      ),
    );
  }
}

/// Thanh tiến độ của một hũ — dùng chung cho màn Hũ và Trang chủ.
///
/// Hũ tiêu: xanh → cam khi quá 80% → đỏ khi vượt. Hũ tiết kiệm đi NGƯỢC:
/// gửi càng nhiều càng tốt, nên không bao giờ đỏ — đầy thanh là đạt.
class JarProgressBar extends StatelessWidget {
  const JarProgressBar({super.key, required this.progress, this.height = 6});

  final JarProgress progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (progress.isOverspent) {
      color = context.colors.budgetOver;
    } else if (progress.spendsFromGoals) {
      // Tiêu từ quỹ: thanh cho thấy đã rút bao nhiêu phần của quỹ — dùng
      // màu "đang tiêu" như hũ tiêu, chuyển cam khi quỹ sắp cạn.
      color = progress.ratio > 0.8
          ? context.colors.budgetWarn
          : context.colors.budgetOk;
    } else if (progress.kind == JarKind.saving) {
      color = context.colors.incomeFill;
    } else if (progress.isOverspent) {
      color = context.colors.budgetOver;
    } else if (progress.ratio > 0.8) {
      color = context.colors.budgetWarn;
    } else {
      color = context.colors.budgetOk;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.radii.full),
      child: LinearProgressIndicator(
        // Kẹp ở 1.0: đã tiêu quá hũ thì thanh đầy và ĐỔI MÀU, không tràn ra
        // ngoài khung.
        value: progress.ratio.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: context.colors.surfaceContainer,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

/// Tổng phần trăm — cảnh báo khi khác 100%.
class _PercentFooter extends StatelessWidget {
  const _PercentFooter({required this.totalPercent});

  final int totalPercent;

  @override
  Widget build(BuildContext context) {
    final total = totalPercent;
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
