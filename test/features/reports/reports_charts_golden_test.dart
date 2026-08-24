// Golden mỗi biểu đồ báo cáo (Phase 10 § Xác minh), light + dark. `goldenTest`
// của alchemist pump-and-settle mặc định trước khi chụp, nên ảnh chụp là
// trạng thái ĐÃ VẼ XONG animation "vào tab" (bán kính/đường/cột đầy), không
// phải khung hình giữa chừng.
//
// ⚠️ H7 (TODOS.md § Cảnh báo môi trường): Phase 3 xác nhận renderer trên
// emulator tonyfino36 là Impeller-GLES (không tắt Impeller — chạy được trên
// SwiftShader mà không cần cờ `--enable-impeller=false`, xem docs/decisions.md
// § Phase 3). `flutter test` trên máy dev này KHÔNG chạy trên emulator đó —
// nhưng vẫn coi golden ở đây là tham khảo LAYOUT, không phải pixel-perfect
// cuối cùng; kênh xác thực thị giác thật là dogfood APK trên máy Redmi thật
// (GPU thật), đúng khớp H7.
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:tonyfino/features/reports/domain/category_slice.dart';
import 'package:tonyfino/features/reports/domain/report_range.dart';
import 'package:tonyfino/features/reports/domain/daily_spend.dart';
import 'package:tonyfino/features/reports/domain/monthly_total.dart';
import 'package:tonyfino/features/reports/widgets/category_pie_card.dart';
import 'package:tonyfino/features/reports/widgets/income_expense_bar_card.dart';
import 'package:tonyfino/features/reports/widgets/monthly_trend_card.dart';
import 'package:tonyfino/features/reports/widgets/spending_heatmap_card.dart';
import 'package:tonyfino/theme/app_theme.dart';

import '../../support/golden_pump.dart';

final _months = [
  const MonthlyTotal(
    year: 2026,
    month: 5,
    incomeMinor: 15000000,
    expenseMinor: -9200000,
  ),
  const MonthlyTotal(
    year: 2026,
    month: 6,
    incomeMinor: 15000000,
    expenseMinor: -11400000,
  ),
  const MonthlyTotal(
    year: 2026,
    month: 7,
    incomeMinor: 16000000,
    expenseMinor: -7800000,
  ),
  const MonthlyTotal(
    year: 2026,
    month: 8,
    incomeMinor: 15000000,
    expenseMinor: -10300000,
  ),
];

final _pieSources = [
  const CategorySourceAmount(
    categoryId: 1,
    label: 'Ăn uống',
    categoryColorId: 0,
    iconCode: 'restaurant',
    amountMinor: -3200000,
  ),
  const CategorySourceAmount(
    categoryId: 2,
    label: 'Di chuyển',
    categoryColorId: 1,
    iconCode: 'directions_car',
    amountMinor: -1500000,
  ),
  const CategorySourceAmount(
    categoryId: 3,
    label: 'Nhà cửa',
    categoryColorId: 2,
    iconCode: 'home',
    amountMinor: -2800000,
  ),
  const CategorySourceAmount(
    categoryId: 4,
    label: 'Mua sắm',
    categoryColorId: 4,
    iconCode: 'shopping_bag',
    amountMinor: -900000,
  ),
  const CategorySourceAmount(
    categoryId: 5,
    label: 'Giải trí',
    categoryColorId: 9,
    iconCode: 'theater_comedy',
    amountMinor: -450000,
  ),
  const CategorySourceAmount(
    categoryId: 6,
    label: 'Sức khỏe',
    categoryColorId: 6,
    iconCode: 'health_and_safety',
    amountMinor: -300000,
  ),
  const CategorySourceAmount(
    categoryId: 7,
    label: 'Giáo dục',
    categoryColorId: 8,
    iconCode: 'school',
    amountMinor: -150000,
  ),
  const CategorySourceAmount(
    categoryId: null,
    label: 'Chưa phân loại',
    categoryColorId: -1,
    iconCode: 'question_mark',
    amountMinor: -50000,
  ),
];

final _dailySpend = [
  for (var d = 1; d <= 21; d++)
    DailySpend(
      date: DateTime(2026, 8, d),
      expenseMinor: -((d * 37000) % 480000 + 20000),
    ),
];

Widget _themedCard(ThemeData theme, Widget child) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

/// Khoảng cố định — golden không được phụ thuộc đồng hồ máy chạy test.
final _goldenRange = ReportRange(
  start: DateTime(2026, 8),
  end: DateTime(2026, 9),
);

void main() {
  goldenTest(
    'CategoryPieCard — light/dark',
    fileName: 'category_pie_card',
    // Icon danh mục 3D (Image.asset thật) trên vành + chú giải —
    // settle rồi mới precache, xem test/support/golden_pump.dart.
    pumpBeforeTest: settleThenPrecacheImages,
    builder: () => GoldenTestGroup(
      columns: 2,
      scenarioConstraints: const BoxConstraints.tightFor(
        width: 380,
        height: 520,
      ),
      children: [
        GoldenTestScenario(
          name: 'light',
          child: _themedCard(
            lightTheme,
            CategoryPieCard(
              slices: buildCategorySlices(_pieSources),
              allSources: _pieSources,
              range: _goldenRange,
              rangeLabel: 'Tháng này',
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'dark',
          child: _themedCard(
            darkTheme,
            CategoryPieCard(
              slices: buildCategorySlices(_pieSources),
              allSources: _pieSources,
              range: _goldenRange,
              rangeLabel: 'Tháng này',
            ),
          ),
        ),
      ],
    ),
  );

  goldenTest(
    'MonthlyTrendCard — light/dark',
    fileName: 'monthly_trend_card',
    // Icon danh mục 3D (Image.asset thật) trên vành + chú giải —
    // settle rồi mới precache, xem test/support/golden_pump.dart.
    pumpBeforeTest: settleThenPrecacheImages,
    builder: () => GoldenTestGroup(
      columns: 2,
      scenarioConstraints: const BoxConstraints.tightFor(
        width: 380,
        height: 280,
      ),
      children: [
        GoldenTestScenario(
          name: 'light',
          child: _themedCard(lightTheme, MonthlyTrendCard(months: _months)),
        ),
        GoldenTestScenario(
          name: 'dark',
          child: _themedCard(darkTheme, MonthlyTrendCard(months: _months)),
        ),
      ],
    ),
  );

  goldenTest(
    'IncomeExpenseBarCard — light/dark',
    fileName: 'income_expense_bar_card',
    // Icon danh mục 3D (Image.asset thật) trên vành + chú giải —
    // settle rồi mới precache, xem test/support/golden_pump.dart.
    pumpBeforeTest: settleThenPrecacheImages,
    builder: () => GoldenTestGroup(
      columns: 2,
      scenarioConstraints: const BoxConstraints.tightFor(
        width: 380,
        height: 280,
      ),
      children: [
        GoldenTestScenario(
          name: 'light',
          child: _themedCard(lightTheme, IncomeExpenseBarCard(months: _months)),
        ),
        GoldenTestScenario(
          name: 'dark',
          child: _themedCard(darkTheme, IncomeExpenseBarCard(months: _months)),
        ),
      ],
    ),
  );

  goldenTest(
    'SpendingHeatmapCard — light/dark',
    fileName: 'spending_heatmap_card',
    // Icon danh mục 3D (Image.asset thật) trên vành + chú giải —
    // settle rồi mới precache, xem test/support/golden_pump.dart.
    pumpBeforeTest: settleThenPrecacheImages,
    builder: () => GoldenTestGroup(
      columns: 2,
      scenarioConstraints: const BoxConstraints.tightFor(
        width: 380,
        height: 340,
      ),
      children: [
        GoldenTestScenario(
          name: 'light',
          child: _themedCard(
            lightTheme,
            SpendingHeatmapCard(
              daily: _dailySpend,
              rangeStart: DateTime(2026, 8, 1),
              rangeEnd: DateTime(2026, 8, 22),
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'dark',
          child: _themedCard(
            darkTheme,
            SpendingHeatmapCard(
              daily: _dailySpend,
              rangeStart: DateTime(2026, 8, 1),
              rangeEnd: DateTime(2026, 8, 22),
            ),
          ),
        ),
      ],
    ),
  );
}
