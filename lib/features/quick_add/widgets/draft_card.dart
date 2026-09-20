import '../../../ui/grouped_number_field.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/providers/database_providers.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../features/savings/savings_providers.dart';
import '../../../features/transactions/day_label.dart';
import '../../../features/transactions/transaction_form_sheet.dart';
import '../../../features/transactions/transactions_providers.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/curves.dart';
import '../../../theme/tokens/durations.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip.dart';
import '../../../ui/category_avatar.dart';
import '../../../ui/category_two_tier_label.dart';
import '../../../ui/money_text.dart';
import '../domain/models/session_draft_card.dart';
import '../quick_add_providers.dart';
import '../domain/category_keyword_entries.dart';
import 'category_picker_sheet.dart';
import 'learn_keywords_sheet.dart';
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

  /// Tên mục tiêu tiết kiệm của thẻ để dành — `null` cho thẻ thường, và
  /// cũng `null` nếu mục tiêu vừa bị xoá/lưu trữ ở màn khác (lúc đó thẻ vẫn
  /// vẽ được, chỉ mất cái tên).
  String? get _goalName {
    final goalId = widget.card.goalId;
    if (goalId == null) return null;
    final goals = ref.watch(activeSavingsGoalsProvider).value ?? const [];
    for (final g in goals) {
      if (g.id == goalId) return g.name;
    }
    return null;
  }

  /// Nhãn một dòng cho thẻ để dành: "Để dành › Quỹ mua nhà" / "Rút từ quỹ …".
  String _savingsLabel(String? goalName) {
    final name = goalName ?? 'Mục tiêu tiết kiệm';
    return widget.card.goalWithdrawal ? 'Rút từ $name' : 'Để dành › $name';
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
    // Thẻ ĐỂ DÀNH mượn nguyên bố cục thẻ thường nhưng đổi danh tính: icon
    // con heo đất, tên mục tiêu thay tên danh mục, và KHÔNG có chip danh mục
    // để bấm — một dòng để dành không thuộc danh mục nào (xem
    // `savings_matcher.dart`), hiện chip "Chưa phân loại" ở đây chỉ mời gọi
    // gán bừa một danh mục rồi làm hỏng cả tiến độ mục tiêu lẫn báo cáo chi.
    final goalName = _goalName;
    final isSavings = widget.card.isSavings;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(
                categoryColorId: isSavings
                    ? 11
                    : (category?.categoryColorId ?? 10),
                iconCode: isSavings
                    ? 'savings'
                    : (category?.iconCode ?? 'more_horiz'),
                size: 32,
              ),
              SizedBox(width: context.space.sm),
              Expanded(
                child: Text(
                  isSavings
                      ? (goalName ?? 'Mục tiêu tiết kiệm')
                      : (category?.name ?? 'Chưa phân loại'),
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
              if (isSavings)
                AppChip(
                  label: _savingsLabel(goalName),
                  editable: false,
                  icon: const CategoryAvatar(
                    categoryColorId: 11,
                    iconCode: 'savings',
                    size: 16,
                  ),
                )
              else
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
            categoryColorId: widget.card.isSavings
                ? 11
                : (category?.categoryColorId ?? 10),
            iconCode: widget.card.isSavings
                ? 'savings'
                : (category?.iconCode ?? 'more_horiz'),
            size: 28,
          ),
          SizedBox(width: context.space.sm),
          Expanded(
            child: Text(
              '${_collapsedLabel(entry, rawCategory, byId)} · '
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

  /// Nhãn danh tính ở hàng "đã lưu" — thẻ để dành nói tên MỤC TIÊU, thẻ
  /// thường nói "Cha › Con" như cũ (`twoTierCategoryLabel`).
  String _collapsedLabel(
    TransactionWithCategory? entry,
    Category? rawCategory,
    Map<int, Category> byId,
  ) {
    if (widget.card.isSavings) return _savingsLabel(_goalName);
    if (entry?.isSplit ?? false) return 'Nhiều danh mục';
    return twoTierCategoryLabel(rawCategory, byId);
  }

  Money _money(Category? category) {
    // Cùng công thức với `QuickAddController._resolveMoney` — thẻ để dành
    // không có danh mục nào để hỏi `kind`, dấu đến từ chiều cất-vào/rút-ra.
    final magnitude = widget.card.amountMinor!;
    if (widget.card.isSavings) {
      return Money.vnd(widget.card.goalWithdrawal ? magnitude : -magnitude);
    }
    final isIncome = category?.kind == 'income';
    return Money.vnd(isIncome ? magnitude : -magnitude);
  }

  Future<void> _editCategory(BuildContext context) async {
    final picked = await showCategoryPickerSheet(
      context: context,
      categories: widget.categories,
      selectedCategoryId: widget.card.categoryId,
    );
    if (picked == null || !mounted) return;
    final leftoverText = widget.card.leftoverText;
    await ref
        .read(quickAddControllerProvider.notifier)
        .correctCategory(widget.messageId, widget.card.id, picked);
    if (!mounted) return;
    await _offerToLearn(categoryId: picked, leftoverText: leftoverText);
  }

  /// 🚨 HỎI trước khi nhớ, không nhớ sau lưng người dùng.
  ///
  /// Trước bản này việc sửa danh mục âm thầm ghi cả cụm chữ vào
  /// `category_keywords`: Tony không biết app đang học gì, và một lần sửa
  /// nhầm là nhớ luôn cái sai mà không có chỗ nào gỡ. Giờ: snackbar 6 giây,
  /// KHÔNG bấm gì = KHÔNG học gì.
  ///
  /// Snackbar (không phải dialog) là cố ý — sửa danh mục là việc người dùng
  /// làm liên tục, chặn tay mỗi lần bằng một hộp thoại Có/Không sẽ biến một
  /// tính năng giúp đỡ thành phiền toái.
  Future<void> _offerToLearn({
    required int categoryId,
    required String leftoverText,
  }) async {
    final candidates = keywordCandidates(leftoverText);
    final suggestedWords = {
      for (final c in candidates)
        if (c.suggested) c.word,
    };
    // Học theo CỤM liên tiếp, không theo từ rời — "hủ tíu" phải ở nguyên
    // một khoá (xem `groupIntoPhrases`).
    final suggested = groupIntoPhrases(leftoverText, suggestedWords);
    if (suggested.isEmpty) return;

    // Đã nhớ đủ những từ này rồi thì đừng hỏi lại — hỏi một câu mà câu trả
    // lời không đổi được gì là làm phiền.
    final repo = ref.read(categoryRepositoryProvider);
    var allKnown = true;
    for (final word in suggested) {
      if (!await repo.hasKeyword(categoryId: categoryId, keyword: word)) {
        allKnown = false;
        break;
      }
    }
    if (allKnown || !mounted) return;

    final categoryLabel = twoTierCategoryLabel(_category, {
      for (final c in widget.categories) c.id: c,
    });
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        // `SnackBar.action` chỉ nhận MỘT nút, mà ở đây cần hai lối ra khác
        // nhau ("nhớ ngay" và "để tôi chọn từ"), nên cả hai nằm trong
        // `content`. Text co lại bằng `Expanded` để tên danh mục dài không
        // đẩy nút ra khỏi màn.
        content: Row(
          children: [
            Expanded(
              child: Text('Nhớ "${suggested.join('", "')}" → $categoryLabel?'),
            ),
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                unawaited(
                  _pickWordsToLearn(
                    categoryId: categoryId,
                    leftoverText: leftoverText,
                    categoryLabel: categoryLabel,
                    suggestedWords: suggestedWords.toList(),
                  ),
                );
              },
              child: const Text('Chọn từ'),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Nhớ',
          onPressed: () => unawaited(_learn(categoryId, suggested)),
        ),
      ),
    );
  }

  Future<void> _pickWordsToLearn({
    required int categoryId,
    required String leftoverText,
    required String categoryLabel,
    required List<String> suggestedWords,
  }) async {
    if (!mounted) return;
    final picked = await showLearnKeywordsSheet(
      context: context,
      leftoverText: leftoverText,
      categoryLabel: categoryLabel,
      initiallySelected: suggestedWords,
    );
    if (picked == null || picked.isEmpty) return;
    await _learn(categoryId, picked);
  }

  Future<void> _learn(int categoryId, List<String> words) async {
    await ref
        .read(quickAddControllerProvider.notifier)
        .learnFromCorrection(categoryId: categoryId, keywords: words);
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
