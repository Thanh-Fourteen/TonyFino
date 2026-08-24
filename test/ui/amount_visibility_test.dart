// Che số tiền (Tony: "các số tiền khi show khá nhạy cảm cần 1 icon nhấn thì
// mới show").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/theme/app_colors.dart';
import 'package:tonyfino/theme/app_theme.dart';
import 'package:tonyfino/ui/amount_visibility.dart';
import 'package:tonyfino/ui/money_text.dart';

void main() {
  Future<void> pump(WidgetTester tester, {bool? hidden}) {
    const money = MoneyText(Money.vnd(-1234000));
    return tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: hidden == null
              ? money
              : AmountVisibility(hidden: hidden, child: money),
        ),
      ),
    );
  }

  testWidgets('mặc định (không có AmountVisibility) → hiện số bình thường', (
    tester,
  ) async {
    // Quan trọng: hàng trăm chỗ dựng `MoneyText` trần, gồm cả golden test
    // không có ProviderScope — thiếu widget bọc thì phải chạy y như cũ.
    await pump(tester);
    expect(find.textContaining('1.234.000'), findsOneWidget);
  });

  testWidgets('hidden: false → hiện số', (tester) async {
    await pump(tester, hidden: false);
    expect(find.textContaining('1.234.000'), findsOneWidget);
  });

  testWidgets('🚨 hidden: true → che hết, KHÔNG lộ chữ số nào', (tester) async {
    await pump(tester, hidden: true);
    expect(find.text('••••••'), findsOneWidget);
    expect(find.textContaining('1.234'), findsNothing);
    expect(find.textContaining('234'), findsNothing);
  });

  testWidgets(
    '🚨 khi che, khoản THU không được lộ ra bằng màu xanh + dấu cộng',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: const Scaffold(
            body: AmountVisibility(
              hidden: true,
              child: MoneyText(Money.vnd(5000000)),
            ),
          ),
        ),
      );

      expect(find.textContaining('+'), findsNothing);
      final text = tester.widget<Text>(find.text('••••••'));
      expect(
        text.style!.color,
        AppColors.light.onSurfaceVariant,
        reason: 'phải là màu trung tính, không phải màu tiền thu',
      );
    },
  );

  testWidgets('đổi cờ → widget bên dưới vẽ lại ngay', (tester) async {
    await pump(tester, hidden: false);
    expect(find.textContaining('1.234.000'), findsOneWidget);
    await pump(tester, hidden: true);
    expect(find.text('••••••'), findsOneWidget);
  });
}
