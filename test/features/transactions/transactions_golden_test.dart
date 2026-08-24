// Golden light/dark cho danh sách, hero card, form (Phase 6 § Xác minh).
import 'package:alchemist/alchemist.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/providers/database_providers.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/transactions/transaction_form_sheet.dart';
import 'package:tonyfino/features/transactions/transactions_screen.dart';
import 'package:tonyfino/theme/app_theme.dart';

import '../../support/golden_pump.dart';

import '../../support/open_test_database.dart';

// Cố định "hôm nay" — golden không được phụ thuộc ngày chạy thật (Luật #3
// cũng áp cho test: nhãn "Hôm nay"/"Hôm qua" phải tái lập được mọi lúc).
final _fixedClock = Clock.fixed(DateTime(2026, 8, 21, 20));

Widget _themedScreen(ThemeData theme, AppDatabase db, Widget child) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(_fixedClock),
    ],
    child: MaterialApp(theme: theme, home: child),
  );
}

void main() {
  // Seed MỘT LẦN trong setUpAll — `goldenTest`'s `builder` phải đồng bộ nên
  // không thể mở/seed DB (bất đồng bộ) ngay trong đó; làm vậy từng lần
  // rebuild sẽ mở lại DB nhiều lần (đã tự bắt qua warning "created the
  // database class AppDatabase multiple times" của drift khi thử FutureBuilder).
  late AppDatabase db;

  setUpAll(() async {
    db = openTestDatabase();
    final categories = await db.select(db.categories).get();
    final walletId = (await db.select(db.wallets).get()).first.id;
    await db.batch((batch) {
      batch.insertAll(db.transactions, [
        TransactionsCompanion.insert(
          amountMinor: -65000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: DateTime(2026, 8, 21, 12),
          walletId: walletId,
          categoryId: Value(categories[0].id),
          note: const Value('ăn trưa bún bò'),
        ),
        TransactionsCompanion.insert(
          amountMinor: -35000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: DateTime(2026, 8, 21, 8),
          walletId: walletId,
          categoryId: Value(categories[5].id),
          note: const Value('cà phê'),
        ),
        TransactionsCompanion.insert(
          amountMinor: 15000000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: DateTime(2026, 8, 20, 9),
          walletId: walletId,
          categoryId: Value(categories[11].id),
          note: const Value('lương tháng 8'),
        ),
      ]);
    });
  });

  tearDownAll(() => db.close());

  goldenTest(
    'TransactionsScreen — danh sách + hero card',
    fileName: 'transactions_screen',
    // Icon danh mục 3D dùng `Image.asset` thật — cần precache, nếu
    // không golden chụp lúc ảnh chưa lên (xem widgets_golden_test.dart).
    pumpBeforeTest: settleThenPrecacheImages,
    builder: () => GoldenTestGroup(
      columns: 1,
      // `Scaffold` (AppBar/body/FAB) cần chiều cao HỮU HẠN thật sự, không
      // chỉ `maxHeight` ở `goldenTest()` (đó chỉ giới hạn ẢNH xuất ra —
      // từng `GoldenTestScenario` không tự thừa hưởng, mặc định unbounded
      // 0..∞ nên `Scaffold` cố "to vô hạn" và ném lỗi layout). Bắt được qua
      // chạy thử, không đoán.
      scenarioConstraints: const BoxConstraints.tightFor(
        width: 390,
        height: 760,
      ),
      children: [
        GoldenTestScenario(
          name: 'light',
          child: _themedScreen(lightTheme, db, const TransactionsScreen()),
        ),
        GoldenTestScenario(
          name: 'dark',
          child: _themedScreen(darkTheme, db, const TransactionsScreen()),
        ),
      ],
    ),
  );

  goldenTest(
    'TransactionFormSheet — thêm giao dịch',
    fileName: 'transaction_form_sheet',
    // Icon danh mục 3D dùng `Image.asset` thật — cần precache, nếu
    // không golden chụp lúc ảnh chưa lên (xem widgets_golden_test.dart).
    pumpBeforeTest: settleThenPrecacheImages,
    builder: () => GoldenTestGroup(
      columns: 1,
      scenarioConstraints: const BoxConstraints.tightFor(
        width: 390,
        height: 620,
      ),
      children: [
        GoldenTestScenario(
          name: 'light',
          child: _themedScreen(
            lightTheme,
            db,
            const Scaffold(body: TransactionFormSheet()),
          ),
        ),
        GoldenTestScenario(
          name: 'dark',
          child: _themedScreen(
            darkTheme,
            db,
            const Scaffold(body: TransactionFormSheet()),
          ),
        ),
      ],
    ),
  );
}
