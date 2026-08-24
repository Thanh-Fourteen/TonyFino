// Golden cho mỗi widget nguyên tử ở lib/ui/, light + dark (Phase 5 § Xác minh).
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/theme/app_theme.dart';
import 'package:tonyfino/theme/context_ext.dart';
import 'package:tonyfino/ui/app_card.dart';
import 'package:tonyfino/ui/app_chip.dart';
import 'package:tonyfino/ui/budget_ring.dart';
import 'package:tonyfino/ui/category_avatar.dart';
import 'package:tonyfino/ui/count_up_text.dart';
import 'package:tonyfino/ui/day_header.dart';
import 'package:tonyfino/ui/empty_state.dart';
import 'package:tonyfino/ui/glass_surface.dart';
import 'package:tonyfino/ui/mascot/app_mascot.dart';
import 'package:tonyfino/ui/mascot/mascot_mood.dart';
import 'package:tonyfino/ui/money_text.dart';
import 'package:tonyfino/ui/transaction_row.dart';

Widget _themed(ThemeData theme, Widget child) {
  return Theme(
    data: theme,
    child: Builder(
      builder: (context) => ColoredBox(
        color: context.colors.canvas,
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    ),
  );
}

List<GoldenTestScenario> _lightAndDark(Widget Function(ThemeData) build) {
  return [
    GoldenTestScenario(
      name: 'light',
      child: _themed(lightTheme, build(lightTheme)),
    ),
    GoldenTestScenario(
      name: 'dark',
      child: _themed(darkTheme, build(darkTheme)),
    ),
  ];
}

void main() {
  goldenTest(
    'MoneyText — chi trung tính, thu xanh có +',
    fileName: 'money_text',
    constraints: const BoxConstraints(maxWidth: 260),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: _lightAndDark(
        (_) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MoneyText(Money.vnd(-35000), size: MoneySize.large),
            SizedBox(height: 8),
            MoneyText(Money.vnd(7000000), size: MoneySize.large),
          ],
        ),
      ),
    ),
  );

  goldenTest(
    'CategoryAvatar',
    fileName: 'category_avatar',
    constraints: const BoxConstraints(maxWidth: 260),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: _lightAndDark(
        (_) => const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryAvatar(categoryColorId: 0, iconCode: 'restaurant'),
            SizedBox(width: 12),
            CategoryAvatar(categoryColorId: 2, iconCode: 'directions_car'),
            SizedBox(width: 12),
            CategoryAvatar(categoryColorId: 11, iconCode: 'payments'),
          ],
        ),
      ),
    ),
  );

  goldenTest(
    'AppCard',
    fileName: 'app_card',
    constraints: const BoxConstraints(maxWidth: 300),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: _lightAndDark(
        (_) => AppCard(
          child: Builder(
            builder: (context) =>
                Text('Card nội dung', style: context.text.bodyLarge),
          ),
        ),
      ),
    ),
  );

  goldenTest(
    'AppChip',
    fileName: 'app_chip',
    constraints: const BoxConstraints(maxWidth: 320),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: _lightAndDark(
        (_) => const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppChip(label: 'Cà phê'),
            AppChip(label: 'Hôm nay', selected: true),
            AppChip(label: 'Danh mục', unconfirmed: true),
          ],
        ),
      ),
    ),
  );

  goldenTest(
    'DayHeader',
    fileName: 'day_header',
    constraints: const BoxConstraints(maxWidth: 320),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: _lightAndDark(
        (_) => const DayHeader(
          label: 'Hôm nay · Thứ Năm',
          netTotal: Money.vnd(-285000),
        ),
      ),
    ),
  );

  goldenTest(
    'TransactionRow',
    fileName: 'transaction_row',
    constraints: const BoxConstraints(maxWidth: 360),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: _lightAndDark(
        (_) => const TransactionRow(
          categoryColorId: 0,
          iconCode: 'restaurant',
          title: 'Ăn trưa bún bò',
          subtitle: 'Ăn uống',
          amount: Money.vnd(-65000),
        ),
      ),
    ),
  );

  // 4 trạng thái vạch nhịp (Phase 11 § Xác minh): dưới nhịp (xanh, ngày
  // 25/30 mà mới chi 40% — chậm hơn nhịp đều) · trên nhịp (vàng nhẹ, ngày
  // 10/30 mà đã chi 50% — nhanh hơn nhịp đều) · cảnh báo (vàng, gần chạm
  // ngân sách dù vẫn còn vài ngày — ngày 28/30 đã chi 97%) · vượt (đỏ, đã
  // chi quá 100% bất kể đang ở ngày nào).
  goldenTest(
    'BudgetRing — 4 trạng thái vạch nhịp',
    fileName: 'budget_ring',
    constraints: const BoxConstraints(maxWidth: 420),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: _lightAndDark(
        (_) => const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BudgetRing(progress: 0.4, paceFraction: 0.83), // dưới nhịp
            SizedBox(width: 12),
            BudgetRing(progress: 0.5, paceFraction: 0.33), // trên nhịp
            SizedBox(width: 12),
            BudgetRing(progress: 0.97, paceFraction: 0.93), // cảnh báo
            SizedBox(width: 12),
            BudgetRing(progress: 1.15, paceFraction: 0.6), // vượt
          ],
        ),
      ),
    ),
  );

  goldenTest(
    'GlassSurface',
    fileName: 'glass_surface',
    constraints: const BoxConstraints(maxWidth: 320),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: _lightAndDark(
        (theme) => Stack(
          children: [
            Container(
              width: 300,
              height: 140,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.teal],
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 60,
              child: GlassSurface(
                borderRadius: BorderRadius.circular(24),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text('Nhập tin nhắn...'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  goldenTest(
    'EmptyState',
    fileName: 'empty_state',
    constraints: const BoxConstraints(maxWidth: 320),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: _lightAndDark(
        (_) => const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Chưa có giao dịch',
          message: 'Gõ chi tiêu đầu tiên ở màn Nhập.',
        ),
      ),
    ),
  );

  goldenTest(
    'CountUpText',
    fileName: 'count_up_text',
    constraints: const BoxConstraints(maxWidth: 260),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: _lightAndDark((_) => const CountUpText(Money.vnd(1250000))),
    ),
  );

  // Phase 22 — mascot vẽ tay (CustomPainter thuần Flutter, xem
  // docs/decisions.md § Phase 22). Ảnh tĩnh tại t=0 (cờ `disableAnimations`
  // bật cho mọi test qua `flutter_test_config.dart` — xem
  // `AppMascot.didChangeDependencies`), đủ để soi hình dạng/màu.
  goldenTest(
    'AppMascot',
    fileName: 'app_mascot',
    constraints: const BoxConstraints(maxWidth: 420),
    // `precacheImages` (không phải `onlyPumpAndSettle` mặc định) — icon 3D
    // streak/celebrate là `Image.asset` thật (PNG đọc từ đĩa), cần
    // `tester.runAsync` để load xong TRƯỚC khi chụp, `pumpAndSettle` một
    // mình không đủ (đã tự bắt được: golden trống trơn không icon dù giá
    // trị opacity/scale bên dưới đã đúng 1.0, xem docs/decisions.md § Phase 22).
    pumpBeforeTest: precacheImages,
    builder: () => GoldenTestGroup(
      columns: 3,
      children: [
        for (final theme in [lightTheme, darkTheme])
          for (final mood in MascotMood.values)
            GoldenTestScenario(
              name: '${theme == lightTheme ? "light" : "dark"}_${mood.name}',
              child: _themed(theme, AppMascot(mood: mood, size: 96)),
            ),
      ],
    ),
  );

  goldenTest(
    'EmptyState với mascot',
    fileName: 'empty_state_mascot',
    constraints: const BoxConstraints(maxWidth: 320),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: _lightAndDark(
        (_) => const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Chưa có giao dịch',
          message: 'Gõ chi tiêu đầu tiên ở màn Nhập.',
          mascotMood: MascotMood.idle,
        ),
      ),
    ),
  );
}
