// Xác minh bắt buộc (Phase 5): chi ra màu trung tính (KHÔNG đỏ), thu ra
// xanh có tiền tố "+", cả hai tabular figures.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/theme/app_colors.dart';
import 'package:tonyfino/theme/app_theme.dart';
import 'package:tonyfino/ui/money_text.dart';

// NumberFormat.currency chèn U+00A0 (NBSP) trước ₫, không phải dấu cách
// thường (xem money_test.dart Phase 4) — lặp lại cạm bẫy này ở đây vì
// `find.text()` cần khớp chuỗi byte-chính-xác.
const _nbsp = ' ';
const _expenseLabel = '-35.000$_nbsp₫';
const _incomeLabel = '+7.000.000$_nbsp₫';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {ThemeData? theme}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme ?? lightTheme,
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('chi (âm) tô màu onSurface — TRUNG TÍNH, không phải đỏ', (
    tester,
  ) async {
    await pump(tester, const MoneyText(Money.vnd(-35000)));

    final text = tester.widget<Text>(find.text(_expenseLabel));
    expect(text.style!.color, AppColors.light.expenseText);
    expect(text.style!.color, AppColors.light.onSurface);
    expect(text.style!.color, isNot(AppColors.light.expenseFill)); // KHÔNG đỏ
  });

  testWidgets('thu (dương) tô xanh + tiền tố "+"', (tester) async {
    await pump(tester, const MoneyText(Money.vnd(7000000)));

    final text = tester.widget<Text>(find.text(_incomeLabel));
    expect(text.style!.color, AppColors.light.incomeText);
  });

  testWidgets('cả hai đều tabular figures', (tester) async {
    await pump(tester, const MoneyText(Money.vnd(-35000)));
    final expenseStyle = tester.widget<Text>(find.text(_expenseLabel)).style!;
    expect(
      expenseStyle.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );

    await pump(tester, const MoneyText(Money.vnd(7000000)));
    final incomeStyle = tester.widget<Text>(find.text(_incomeLabel)).style!;
    expect(
      incomeStyle.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('dark theme: chi vẫn trung tính (onSurface dark), không đỏ', (
    tester,
  ) async {
    await pump(tester, const MoneyText(Money.vnd(-35000)), theme: darkTheme);
    final text = tester.widget<Text>(find.text(_expenseLabel));
    expect(text.style!.color, AppColors.dark.onSurface);
    expect(text.style!.color, isNot(AppColors.dark.expenseFill));
  });

  testWidgets('style ghi đè (size) vẫn giữ nguyên màu tính theo dấu', (
    tester,
  ) async {
    await pump(
      tester,
      const MoneyText(Money.vnd(-35000), size: MoneySize.hero),
    );
    final text = tester.widget<Text>(find.text(_expenseLabel));
    expect(text.style!.color, AppColors.light.expenseText);
    expect(text.style!.fontSize, 34); // moneyHero
  });
}
