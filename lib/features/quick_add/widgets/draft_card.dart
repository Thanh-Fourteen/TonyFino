import '../../../ui/grouped_number_field.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/providers/database_providers.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../features/budgets/domain/budget_period.dart';
import '../../../features/budgets/domain/budget_progress.dart';
import '../../../features/settings/settings_controller.dart';
import '../../../features/transactions/day_label.dart';
import '../../../features/transactions/transaction_form_sheet.dart';
import '../../../features/transactions/transactions_providers.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/curves.dart';
import '../../../theme/tokens/durations.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_card.dart';
import '../../../ui/amount_visibility.dart';
import '../../../ui/app_chip.dart';
import '../../../ui/category_avatar.dart';
import '../../../ui/category_two_tier_label.dart';
import '../../../ui/money_text.dart';
import '../domain/models/session_draft_card.dart';
import '../quick_add_providers.dart';
import 'category_picker_sheet.dart';
import 'saved_transaction_row.dart';

/// Thẻ xác nhận — KHÔNG phải bong bóng chat, thẻ giao dịch full-width. Ba
/// trạng thái golden test yêu cầu:
/// - **chờ**: vừa ghi lạc quan xong, chip cỡ đầy đủ + "✓ Đã lưu" + "Hoàn
///   tác", sống đúng 6 giây (đếm bằng `Timer` cục bộ, KHÔNG `DateTime.now()`
///   — Luật #3 áp cho cả `lib/features/`, xem `tool/check_arch.sh`).
/// - **đã lưu**: co lại sau 6 giây, chip thành chữ thường, cao giảm ~40%.
/// - **không hiểu**: không tìm thấy số tiền — ô sửa giữ nguyên chữ gốc, ô
///   số tiền tự focus bàn phím mở ngay (Luật bố cục Phase 8, không phải toast).
class DraftCard extends ConsumerStatefulWidget {
  const DraftCard({
    super.key,
    required this.messageId,
    required this.card,
    required this.categories,
    this.initiallyCollapsed = false,
  });

  final String messageId;
  final SessionDraftCard card;
  final List<Category> categories;

  /// CHỈ dùng cho golden test (trạng thái "đã lưu" bình thường chỉ tới sau
  /// 6 giây thật — ép trực tiếp để chụp golden xác định, không đợi Timer).
  final bool initiallyCollapsed;

  @override
  ConsumerState<DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends ConsumerState<DraftCard>
    with SingleTickerProviderStateMixin {
  Timer? _collapseTimer;
  late bool _collapsed;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.initiallyCollapsed;
    _pulseController = AnimationController(
      vsync: this,
      duration: appDurations.confirmPulse,
    );
    _pulseScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.04), weight: 3),
          TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 2),
        ]).animate(
          CurvedAnimation(
            parent: _pulseController,
            curve: appCurves.confirmPulse,
          ),
        );
    if (widget.card.isSaved && !_collapsed)
      _startCollapseTimer(playPulse: false);
  }

  @override
  void didUpdateWidget(covariant DraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.card.isSaved && widget.card.isSaved) {
      _startCollapseTimer(playPulse: true);
    }
  }

  void _startCollapseTimer({required bool playPulse}) {
    if (playPulse) {
      _pulseController.forward(from: 0);
      HapticFeedback.lightImpact();
    }
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _collapsed = true);
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Category? get _category {
    for (final c in widget.categories) {
      if (c.id == widget.card.categoryId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.card.isUnderstood)
      return _ErrorCard(card: widget.card, messageId: widget.messageId);

    return AnimatedSize(
      duration: appDurations.sheet,
      curve: appCurves.sheet,
      alignment: Alignment.topCenter,
      child: ScaleTransition(
        scale: _pulseScale,
        child: _collapsed ? _buildSaved(context) : _buildPending(context),
      ),
    );
  }

  Widget _buildPending(BuildContext context) {
    final category = _category;
    final now = ref.watch(quickAddNowForLabelsProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(
                categoryColorId: category?.categoryColorId ?? 10,
                iconCode: category?.iconCode ?? 'more_horiz',
                size: 32,
              ),
              SizedBox(width: context.space.sm),
              Expanded(
                child: Text(
                  category?.name ?? 'Chưa phân loại',
                  style: context.text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              MoneyText(_money(category), size: MoneySize.medium),
            ],
          ),
          SizedBox(height: context.space.sm),
          Wrap(
            spacing: context.space.xs,
            runSpacing: context.space.xs,
            children: [
              // Chip hiện "Cha › Con" — thấy mỗi "Tiêu vặt" thì không biết
              // parser đã xếp nó vào Ăn uống hay Mua sắm, mà đây đúng là
              // chỗ Tony liếc qua để quyết định có sửa hay không.
              AppChip(
                label: twoTierCategoryLabel(category, {
                  for (final c in widget.categories) c.id: c,
                }),
                unconfirmed: category == null,
                icon: category == null
                    ? null
                    : CategoryAvatar(
                        categoryColorId: displayCategory(category, {
                          for (final c in widget.categories) c.id: c,
                        })!.categoryColorId,
                        iconCode: displayCategory(category, {
                          for (final c in widget.categories) c.id: c,
                        })!.iconCode,
                        size: 16,
                      ),
                onTap: () => _editCategory(context),
              ),
              AppChip(
                label: formatDayLabel(widget.card.date, now),
                unconfirmed: !widget.card.dateExplicit,
                onTap: () => _editDate(context),
              ),
            ],
          ),
          if (category != null && category.kind == 'expense')
            _BudgetProgressLine(categoryId: category.id),
          SizedBox(height: context.space.sm),
          Row(
            children: [
              Icon(kIconCheck, size: 16, color: context.colors.incomeText),
              SizedBox(width: context.space.xxs),
              Text(
                'Đã lưu',
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => ref
                    .read(quickAddControllerProvider.notifier)
                    .undoCard(widget.messageId, widget.card.id),
                child: const Text('Hoàn tác'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Trạng thái "đã lưu" (co lại) CHÍNH LÀ một giao dịch thật rồi — phải
  /// nhấn-giữ mở được sheet Sửa/Nhân đôi/Xoá y hệt một hàng lịch sử
  /// ([SavedTransactionRow]), không phải chỉ trong 6 giây đầu. Tra lại
  /// [TransactionWithCategory] thật qua id đã lưu thay vì tự dựng một bản
  /// giả từ state cục bộ — tránh lệch với DB thật nếu vừa bị sửa nơi khác.
  Widget _buildSaved(BuildContext context) {
    final now = ref.watch(quickAddNowForLabelsProvider);
    final history =
        ref.watch(transactionsWithCategoryProvider).value ?? const [];
    TransactionWithCategory? entry;
    for (final t in history) {
      if (t.transaction.id == widget.card.savedTransactionId) {
        entry = t;
        break;
      }
    }

    // 🚨 Đã lưu rồi thì HIỂN THỊ THEO DB, không theo bản nháp trong bộ nhớ.
    //
    // Trước đây hàm này có tra `entry` từ DB (và doc còn ghi rõ là để "tránh
    // lệch với DB thật nếu vừa bị sửa nơi khác") nhưng lại vẫn vẽ ngày, danh
    // mục, số tiền từ `widget.card` — bản nháp chụp lúc gõ câu, không bao
    // giờ đổi. Nên chat xong, bấm vào sửa NGÀY, lưu: DB đổi mà thẻ đứng im,
    // trông hệt như nút Lưu không ăn. Đúng lỗi Tony báo.
    final byId = {for (final c in widget.categories) c.id: c};
    final rawCategory = entry?.category ?? _category;
    final category = displayCategory(rawCategory, byId);
    final date = entry?.transaction.occurredAt ?? widget.card.date;
    final money = entry == null
        ? _money(category)
        : Money(
            minorUnits: entry.transaction.amountMinor,
            currency: entry.transaction.currency,
            currencyScale: entry.transaction.currencyScale,
          );

    final row = AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.cardPadding,
        vertical: context.space.sm,
      ),
      onTap: entry == null
          ? null
          : () => showTransactionFormSheet(context: context, existing: entry),
      child: Row(
        children: [
          CategoryAvatar(
            categoryColorId: category?.categoryColorId ?? 10,
            iconCode: category?.iconCode ?? 'more_horiz',
            size: 28,
          ),
          SizedBox(width: context.space.sm),
          Expanded(
            child: Text(
              '${(entry?.isSplit ?? false) ? 'Nhiều danh mục' : twoTierCategoryLabel(rawCategory, byId)} · '
              '${formatDayLabel(date, now).toLowerCase()}',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          MoneyText(money, size: MoneySize.small),
        ],
      ),
    );

    if (entry == null) return row;
    return GestureDetector(
      onLongPress: () => showTransactionActionsSheet(context, ref, entry!),
      child: row,
    );
  }

  Money _money(Category? category) {
    final isIncome = category?.kind == 'income';
    final magnitude = widget.card.amountMinor!;
    return Money.vnd(isIncome ? magnitude : -magnitude);
  }

  Future<void> _editCategory(BuildContext context) async {
    final picked = await showCategoryPickerSheet(
      context: context,
      categories: widget.categories,
      selectedCategoryId: widget.card.categoryId,
    );
    if (picked == null || !mounted) return;
    await ref
        .read(quickAddControllerProvider.notifier)
        .correctCategory(widget.messageId, widget.card.id, picked);
  }

  Future<void> _editDate(BuildContext context) async {
    final now = ref.read(quickAddNowForLabelsProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.card.date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    await ref
        .read(quickAddControllerProvider.notifier)
        .correctDate(widget.messageId, widget.card.id, picked);
  }
}

/// Tiến độ ngân sách hiện NGAY trong thẻ xác nhận (Phase 25, đúc theo cách
/// Rolly trả tiến độ ngân sách ngay trong câu trả lời chat —
/// `docs/rolly-uiux-research.md` § B) — chỉ hiện khi danh mục của thẻ THẬT
/// SỰ có một hàng ngân sách cho kỳ hiện tại, im lặng không hiện gì nếu
/// không (không phải "0/0", một hàng trống vô nghĩa). Tái dùng
/// `BudgetRepository.watchBudgetsForPeriod` đã có từ Phase 11/15, KHÔNG
/// query/cache riêng — CỐ Ý không dùng `budgetProgressProvider` (nó phản
/// ánh kỳ Tony đang XEM ở tab Ngân sách, có thể là tháng khác) mà tự tính
/// `BudgetPeriod.of(now)` — thẻ xác nhận luôn phải nói về kỳ HIỆN TẠI thật,
/// bất kể Tony đang xem tháng nào ở tab khác.
class _BudgetProgressLine extends ConsumerWidget {
  const _BudgetProgressLine({required this.categoryId});

  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(quickAddNowForLabelsProvider);
    final anchorDay = ref.read(appSettingsProvider).budgetAnchorDay;
    final period = BudgetPeriod.of(now, anchorDay: anchorDay);

    return StreamBuilder<List<BudgetProgress>>(
      stream: ref.read(budgetRepositoryProvider).watchBudgetsForPeriod(period),
      builder: (context, snapshot) {
        final progressList = snapshot.data ?? const <BudgetProgress>[];
        BudgetProgress? progress;
        for (final p in progressList) {
          if (p.categoryId == categoryId) {
            progress = p;
            break;
          }
        }
        if (progress == null) return const SizedBox.shrink();

        final remaining = progress.remainingMinor;
        final text = AmountVisibility.hiddenOf(context)
            // Che thì che luôn cả câu: "Còn ••••••" vẫn đọc được nghĩa mà
            // không lộ số.
            ? (remaining >= 0
                  ? 'Còn •••••• trong ngân sách ${progress.categoryName}'
                  : 'Đã vượt •••••• ngân sách ${progress.categoryName}')
            : (remaining >= 0
                  ? 'Còn ${Money.vnd(remaining).format()} trong ngân sách ${progress.categoryName}'
                  : 'Đã vượt ${Money.vnd(-remaining).format()} ngân sách ${progress.categoryName}');
        return Padding(
          padding: EdgeInsets.only(top: context.space.xxs),
          child: Text(
            text,
            style: context.text.labelMedium?.copyWith(
              color: remaining >= 0
                  ? context.colors.onSurfaceVariant
                  : context.colors.budgetOver,
            ),
          ),
        );
      },
    );
  }
}

/// Trạng thái lỗi — Luật bố cục Phase 8: MỘT THẺ, không phải toast. Giữ
/// nguyên chữ gốc trong ô sửa được; ô số tiền tự focus, bàn phím bật ngay.
class _ErrorCard extends ConsumerStatefulWidget {
  const _ErrorCard({required this.card, required this.messageId});

  final SessionDraftCard card;
  final String messageId;

  @override
  ConsumerState<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends ConsumerState<_ErrorCard> {
  late final TextEditingController _textController;
  late final TextEditingController _amountController;
  late final FocusNode _amountFocus;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.card.rawText);
    _amountController = TextEditingController();
    _amountFocus = FocusNode();
    // Tự focus + bật bàn phím ngay khi thẻ lỗi xuất hiện — không phải toast,
    // không được để người dùng phải tự chạm vào đâu cả.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    // Bỏ dấu phân nhóm trước khi parse — ô nhập giờ hiện "500.000",
    // `int.tryParse` trên chuỗi đó trả `null` và nút im lặng không làm gì.
    final amountText = digitsOf(_amountController.text);
    if (amountText.isEmpty) return;
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) return;
    await ref
        .read(quickAddControllerProvider.notifier)
        .retryUnderstoodCard(
          widget.messageId,
          widget.card.id,
          _textController.text,
          amount,
        );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                kIconQuestionMark,
                size: 20,
                color: context.colors.budgetWarn,
              ),
              SizedBox(width: context.space.xs),
              Expanded(
                child: Text(
                  'Mình chưa hiểu — chọn giúp mình nhé',
                  style: context.text.bodyLarge,
                ),
              ),
            ],
          ),
          SizedBox(height: context.space.sm),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(labelText: 'Nội dung'),
            minLines: 1,
            maxLines: 2,
          ),
          SizedBox(height: context.space.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  focusNode: _amountFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsSeparatorInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Số tiền',
                    suffixText: '₫',
                  ),
                  onSubmitted: (_) => _retry(),
                ),
              ),
              SizedBox(width: context.space.sm),
              FilledButton(onPressed: _retry, child: const Text('Lưu')),
            ],
          ),
        ],
      ),
    );
  }
}
