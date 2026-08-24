import 'package:flutter/material.dart';

import '../core/money/money.dart';
import '../theme/app_theme.dart';
import '../theme/context_ext.dart';
import '../theme/tokens/icons.dart';
import '../theme/tokens/radii.dart';
import '../theme/tokens/spacing.dart';
import '../ui/app_card.dart';
import '../ui/app_chip.dart';
import '../ui/budget_ring.dart';
import '../ui/category_avatar.dart';
import '../ui/count_up_text.dart';
import '../ui/day_header.dart';
import '../ui/empty_state.dart';
import '../ui/glass_surface.dart';
import '../ui/money_text.dart';
import '../ui/transaction_row.dart';

/// Liệt kê mọi token + widget nguyên tử — vừa tài liệu sống, vừa chỗ soi
/// mắt. CHỈ dùng ở debug build (`kDebugMode`) — call site (`main.dart`) tự
/// gác cổng, widget này không tự kiểm tra để giữ test được ở mọi build mode.
class StyleGalleryScreen extends StatefulWidget {
  const StyleGalleryScreen({super.key});

  @override
  State<StyleGalleryScreen> createState() => _StyleGalleryScreenState();
}

class _StyleGalleryScreenState extends State<StyleGalleryScreen> {
  Brightness _brightness = Brightness.light;
  int _demoStep = 0;

  static const _pangram = 'Đồng Nai — ế ữ ỗ ặ ỡ Ế Ữ Ỗ · 1.234.567 ₫';

  @override
  Widget build(BuildContext context) {
    final theme = _brightness == Brightness.dark ? darkTheme : lightTheme;
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final colors = context.colors;
          return Scaffold(
            backgroundColor: colors.canvas,
            appBar: AppBar(title: const Text('Style Gallery')),
            body: ListView(
              padding: EdgeInsets.all(context.space.screenHorizontal),
              children: [
                _Section(
                  title: 'Brightness: ${_brightness.name}',
                  child: FilledButton(
                    onPressed: () => setState(() {
                      _brightness = _brightness == Brightness.dark
                          ? Brightness.light
                          : Brightness.dark;
                    }),
                    child: const Text('Đổi light ↔ dark'),
                  ),
                ),
                _Section(
                  title: 'Màu nền & chữ',
                  child: _neutralSwatches(context),
                ),
                _Section(
                  title: 'Thu / chi / ngân sách',
                  child: _semanticSwatches(context),
                ),
                _Section(
                  title: '12 màu danh mục',
                  child: _categorySwatches(context),
                ),
                _Section(
                  title: 'Heatmap 5 bậc',
                  child: _heatmapSwatches(context),
                ),
                _Section(
                  title: 'Chữ — chuỗi chống cắt dấu',
                  child: _typographySpecimen(context),
                ),
                _Section(
                  title: 'Khoảng cách (AppSpacing)',
                  child: _spacingSwatches(context),
                ),
                _Section(
                  title: 'Bo góc (AppRadii)',
                  child: _radiiSwatches(context),
                ),
                _Section(
                  title: 'MoneyText',
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MoneyText(Money.vnd(-65000), size: MoneySize.medium),
                      SizedBox(height: 8),
                      MoneyText(Money.vnd(7000000), size: MoneySize.large),
                    ],
                  ),
                ),
                _Section(
                  title: 'CountUpText (bấm để đổi giá trị)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CountUpText(Money.vnd(1000000 + _demoStep * 250000)),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => setState(() => _demoStep++),
                        child: const Text('Tăng số'),
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'CategoryAvatar',
                  child: const Wrap(
                    spacing: 12,
                    children: [
                      CategoryAvatar(
                        categoryColorId: 0,
                        iconCode: 'restaurant',
                      ),
                      CategoryAvatar(
                        categoryColorId: 1,
                        iconCode: 'directions_car',
                      ),
                      CategoryAvatar(
                        categoryColorId: 3,
                        iconCode: 'shopping_bag',
                      ),
                      CategoryAvatar(
                        categoryColorId: 6,
                        iconCode: 'health_and_safety',
                      ),
                      CategoryAvatar(categoryColorId: 11, iconCode: 'payments'),
                    ],
                  ),
                ),
                _Section(
                  title: 'AppChip',
                  child: const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppChip(label: 'Cà phê'),
                      AppChip(label: 'Hôm nay', selected: true),
                      AppChip(label: 'Danh mục', unconfirmed: true),
                    ],
                  ),
                ),
                _Section(
                  title: 'AppCard',
                  child: AppCard(
                    onTap: () {},
                    child: Text(
                      'Chạm được — có InkWell',
                      style: context.text.bodyLarge,
                    ),
                  ),
                ),
                _Section(
                  title: 'DayHeader + TransactionRow (tràn viền)',
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(context.radii.lg),
                      border: Border.all(color: context.shadows.level1Border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DayHeader(
                          label: 'Hôm nay · Thứ Năm',
                          netTotal: Money.vnd(-285000),
                        ),
                        TransactionRow.divider(context),
                        const TransactionRow(
                          categoryColorId: 0,
                          iconCode: 'restaurant',
                          title: 'Ăn trưa bún bò',
                          subtitle: 'Ăn uống',
                          amount: Money.vnd(-65000),
                        ),
                        TransactionRow.divider(context),
                        const TransactionRow(
                          categoryColorId: 11,
                          iconCode: 'payments',
                          title: 'Lương tháng 8',
                          subtitle: 'Lương',
                          amount: Money.vnd(15000000),
                        ),
                      ],
                    ),
                  ),
                ),
                _Section(
                  title:
                      'BudgetRing — vạch nhịp (đúng nhịp / trên nhịp / đã vượt)',
                  child: const Row(
                    children: [
                      // Ngày 25/30 (nhịp 0.83), chi 35% — dưới nhịp, xanh.
                      BudgetRing(progress: 0.35, paceFraction: 0.83),
                      SizedBox(width: 16),
                      // Ngày 10/30 (nhịp 0.33), chi 60% — trên nhịp, vàng.
                      BudgetRing(progress: 0.6, paceFraction: 0.33),
                      SizedBox(width: 16),
                      BudgetRing(progress: 1.2, paceFraction: 0.9),
                    ],
                  ),
                ),
                _Section(
                  title: 'GlassSurface (chỉ dùng ở nav bar + thanh nhập chat)',
                  child: SizedBox(
                    height: 140,
                    child: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.indigo, Colors.teal],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          bottom: 16,
                          right: 16,
                          child: GlassSurface(
                            borderRadius: BorderRadius.circular(
                              context.radii.full,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                'Nhập tin nhắn...',
                                style: context.text.bodyLarge,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _Section(
                  title: 'EmptyState',
                  child: EmptyState(
                    icon: kIconInbox,
                    title: 'Chưa có giao dịch',
                    message: 'Gõ chi tiêu đầu tiên ở màn Nhập.',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _neutralSwatches(BuildContext context) {
    final c = context.colors;
    return _swatchRow({
      'canvas': c.canvas,
      'card': c.card,
      'surfaceContainer': c.surfaceContainer,
      'sheet': c.sheet,
      'hairline': c.hairline,
    });
  }

  Widget _semanticSwatches(BuildContext context) {
    final c = context.colors;
    return _swatchRow({
      'incomeText': c.incomeText,
      'incomeFill': c.incomeFill,
      'expenseFill': c.expenseFill,
      'transfer': c.transfer,
      'budgetOk': c.budgetOk,
      'budgetWarn': c.budgetWarn,
      'budgetOver': c.budgetOver,
    });
  }

  Widget _categorySwatches(BuildContext context) {
    final fills = context.colors.categoryFills;
    return _swatchRow({for (var i = 0; i < fills.length; i++) '$i': fills[i]});
  }

  Widget _heatmapSwatches(BuildContext context) {
    final steps = context.colors.heatmapScale;
    return _swatchRow({
      for (var i = 0; i < steps.length; i++) '${i + 1}': steps[i],
    });
  }

  Widget _swatchRow(Map<String, Color> swatches) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: swatches.entries.map((entry) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: entry.value,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x22000000)),
              ),
            ),
            const SizedBox(height: 4),
            Text(entry.key, style: const TextStyle(fontSize: 10)),
          ],
        );
      }).toList(),
    );
  }

  Widget _typographySpecimen(BuildContext context) {
    final text = context.text;
    final money = context.money;
    final styles = <String, TextStyle?>{
      'displayLarge': text.displayLarge,
      'titleLarge': text.titleLarge,
      'titleMedium': text.titleMedium,
      'bodyLarge': text.bodyLarge,
      'bodyMedium': text.bodyMedium,
      'labelMedium': text.labelMedium,
      'moneyHero': money.moneyHero,
      'moneyLarge': money.moneyLarge,
      'moneyMedium': money.moneyMedium,
      'moneySmall': money.moneySmall,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: styles.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(_pangram, style: entry.value),
        );
      }).toList(),
    );
  }

  Widget _spacingSwatches(BuildContext context) {
    const spacing = AppSpacing();
    final values = {
      'xxs': spacing.xxs,
      'xs': spacing.xs,
      'sm': spacing.sm,
      'md': spacing.md,
      'lg': spacing.lg,
      'xl': spacing.xl,
      'xxl': spacing.xxl,
      'xxxl': spacing.xxxl,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: values.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(width: 60, child: Text(entry.key)),
              Container(
                width: entry.value,
                height: 12,
                color: context.colors.transfer,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _radiiSwatches(BuildContext context) {
    const radii = AppRadii();
    final values = {
      'xs': radii.xs,
      'sm': radii.sm,
      'md': radii.md,
      'lg': radii.lg,
      'xl': radii.xl,
    };
    return Wrap(
      spacing: 12,
      children: values.entries.map((entry) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.colors.surfaceContainer,
                borderRadius: BorderRadius.circular(entry.value),
                border: Border.all(color: context.colors.hairline),
              ),
            ),
            const SizedBox(height: 4),
            Text(entry.key, style: const TextStyle(fontSize: 10)),
          ],
        );
      }).toList(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.space.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleMedium),
          SizedBox(height: context.space.sm),
          child,
        ],
      ),
    );
  }
}
