import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../data/repositories/reports_repository.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/category_avatar.dart';
import '../../ui/mascot/app_mascot.dart';
import '../../ui/mascot/mascot_mood.dart';
import 'domain/category_slice.dart';
import 'wrapped_providers.dart';

/// Số tiền trên nền cam full-bleed của Wrapped — KHÔNG dùng `MoneyText`: màu
/// của nó khoá cứng theo dấu số tiền (`context.colors.incomeText`/
/// `expenseText`/`onSurface`, xem `money_text.dart`), đúng cho card trung
/// tính nhưng không đọc được trên nền cam rực + có thể vô hình ở dark mode.
/// Vẫn giữ `context.money.moneyLarge` (tabular figures) cho đúng kiểu chữ,
/// chỉ tự set màu `onPrimary`.
class _WrappedAmountText extends StatelessWidget {
  const _WrappedAmountText(this.amount);

  final Money amount;

  @override
  Widget build(BuildContext context) {
    return Text(
      amount.format(),
      style: context.money.moneyLarge.copyWith(
        color: context.scheme.onPrimary,
      ),
    );
  }
}

void openWrappedScreen(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const WrappedScreen()));
}

/// "TonyFino Wrapped" — thẻ tổng kết năm kiểu Actual Budget Wrapped/Spotify
/// Wrapped, nhưng KHÔNG chia sẻ mạng xã hội (docs/competitor-feature-research.md
/// § Bổ sung 2026-09-23 mục 28) — chỉ để Tony tự xem lại một năm ghi chép,
/// hợp tông "không phán xét" đã chốt từ Phase 8/25: không xếp hạng, không so
/// sánh với ai, chỉ kể lại số liệu của chính Tony.
///
/// Dữ liệu LUÔN của năm hiện tại (`wrappedYearRangeProvider`), không đọc bộ
/// lọc của tab Báo cáo — xem lý do ở đó.
class WrappedScreen extends ConsumerStatefulWidget {
  const WrappedScreen({super.key});

  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends ConsumerState<WrappedScreen> {
  final _pageController = PageController();
  int _page = 0;
  static const _pageCount = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _pageCount - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pageController.nextPage(
      duration: context.durations.sheet,
      curve: context.curves.sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(wrappedYearRangeProvider);
    final summaryAsync = ref.watch(wrappedSummaryProvider);
    final breakdownAsync = ref.watch(wrappedCategoryBreakdownProvider);
    final longestStreak = ref.watch(wrappedLongestStreakProvider);

    final summary = summaryAsync.value;
    final breakdown = breakdownAsync.value;
    final loading = summary == null || breakdown == null;

    return Scaffold(
      backgroundColor: context.scheme.primary,
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Column(
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        icon: Icon(kIconClose, color: context.scheme.onPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _next,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _page = i),
                        children: [
                          _IntroCard(
                            year: range.start.year,
                            transactionCount: summary.transactionCount,
                          ),
                          _TopCategoryCard(breakdown: breakdown),
                          _IncomeExpenseCard(summary: summary),
                          _StreakCard(days: longestStreak),
                          _ClosingCard(year: range.start.year),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: context.space.md,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _pageCount; i++)
                          AnimatedContainer(
                            duration: context.durations.confirmPulse,
                            margin: EdgeInsets.symmetric(
                              horizontal: context.space.xxs,
                            ),
                            width: i == _page ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: context.scheme.onPrimary.withValues(
                                alpha: i == _page ? 1 : 0.4,
                              ),
                              borderRadius: BorderRadius.circular(
                                context.radii.full,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Khung dùng chung cho mọi thẻ: canvas cam, một khối nội dung trắng nổi
/// giữa — cùng ngôn ngữ "một khối nổi trên nền màu" mà `AppCard` dùng cho
/// toàn app, chỉ đổi nền cam thay vì canvas trung tính.
class _WrappedCardScaffold extends StatelessWidget {
  const _WrappedCardScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.lg,
        vertical: context.space.xl,
      ),
      child: Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [child],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.year, required this.transactionCount});

  final int year;
  final int transactionCount;

  @override
  Widget build(BuildContext context) {
    return _WrappedCardScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppMascot(mood: MascotMood.celebrate, size: 120),
          SizedBox(height: context.space.lg),
          Text(
            'Năm $year của bạn',
            textAlign: TextAlign.center,
            style: context.text.headlineMedium?.copyWith(
              color: context.scheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.space.sm),
          Text(
            transactionCount == 0
                ? 'Chưa có giao dịch nào năm nay — bắt đầu ghi thôi.'
                : 'Bạn đã ghi $transactionCount giao dịch.',
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(
              color: context.scheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: context.space.xl),
          Text(
            'Chạm để xem tiếp',
            style: context.text.labelMedium?.copyWith(
              color: context.scheme.onPrimary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCategoryCard extends StatelessWidget {
  const _TopCategoryCard({required this.breakdown});

  final List<CategorySourceAmount> breakdown;

  @override
  Widget build(BuildContext context) {
    // `amountMinor` luôn âm hoặc 0 (tổng chi) — nhỏ nhất (âm nhất) là chi
    // nhiều nhất.
    CategorySourceAmount? top;
    for (final row in breakdown) {
      if (top == null || row.amountMinor < top.amountMinor) top = row;
    }

    return _WrappedCardScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Danh mục chi nhiều nhất',
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              color: context.scheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: context.space.lg),
          if (top == null || top.amountMinor == 0)
            Text(
              'Chưa chi khoản nào năm nay.',
              style: context.text.bodyLarge?.copyWith(
                color: context.scheme.onPrimary,
              ),
            )
          else ...[
            CategoryAvatar(
              categoryColorId: top.categoryColorId,
              iconCode: top.iconCode,
              size: 72,
            ),
            SizedBox(height: context.space.md),
            Text(
              top.label,
              textAlign: TextAlign.center,
              style: context.text.headlineSmall?.copyWith(
                color: context.scheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.space.xs),
            _WrappedAmountText(Money.vnd(top.amountMinor.abs())),
          ],
        ],
      ),
    );
  }
}

class _IncomeExpenseCard extends StatelessWidget {
  const _IncomeExpenseCard({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    return _WrappedCardScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cả năm nhìn lại',
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              color: context.scheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: context.space.lg),
          _StatRow(
            label: 'Tổng thu',
            child: _WrappedAmountText(Money.vnd(summary.incomeMinor)),
          ),
          SizedBox(height: context.space.md),
          _StatRow(
            label: 'Tổng chi',
            child: _WrappedAmountText(Money.vnd(summary.expenseMinor.abs())),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: context.text.bodyMedium?.copyWith(
            color: context.scheme.onPrimary.withValues(alpha: 0.75),
          ),
        ),
        child,
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return _WrappedCardScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppMascot(mood: MascotMood.streak, size: 96),
          SizedBox(height: context.space.lg),
          Text(
            days <= 1
                ? 'Chưa có chuỗi ngày nào đáng kể năm nay.'
                : 'Chuỗi ghi chép liên tiếp dài nhất năm nay',
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              color: context.scheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
          if (days > 1) ...[
            SizedBox(height: context.space.sm),
            Text(
              '$days ngày liên tiếp',
              style: context.text.headlineMedium?.copyWith(
                color: context.scheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClosingCard extends StatelessWidget {
  const _ClosingCard({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return _WrappedCardScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppMascot(mood: MascotMood.idle, size: 96),
          SizedBox(height: context.space.lg),
          Text(
            'Cảm ơn vì đã ghi chép đều đặn năm $year.',
            textAlign: TextAlign.center,
            style: context.text.titleLarge?.copyWith(
              color: context.scheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.space.sm),
          Text(
            'Hẹn gặp lại năm sau.',
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(
              color: context.scheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
