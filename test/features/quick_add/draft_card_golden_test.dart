// Golden 3 trạng thái thẻ xác nhận (chờ / đã lưu / không hiểu) × light/dark
// (Phase 8 § Xác minh).
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/providers/database_providers.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/quick_add/domain/models/session_draft_card.dart';
import 'package:tonyfino/features/quick_add/widgets/draft_card.dart';
import 'package:tonyfino/theme/app_theme.dart';

import '../../support/golden_pump.dart';
import 'package:clock/clock.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';

final _fixedClock = Clock.fixed(DateTime(2026, 8, 21));

Widget _themedCard(
  ThemeData theme,
  AppDatabase db,
  List<Category> categories,
  SessionDraftCard card, {
  bool initiallyCollapsed = false,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(_fixedClock),
    ],
    child: MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: DraftCard(
            messageId: 'msg-golden',
            card: card,
            categories: categories,
            initiallyCollapsed: initiallyCollapsed,
          ),
        ),
      ),
    ),
  );
}

void main() {
  late AppDatabase db;
  late List<Category> categories;

  setUpAll(() async {
    // Phase 25: `_BudgetProgressLine` (bên trong `DraftCard`) đọc
    // `appSettingsProvider.budgetAnchorDay` — provider đó ném lỗi đồng bộ
    // nếu chưa có `SharedPreferencesAsyncPlatform` đăng ký (không tự có sẵn
    // trong `flutter_test`), khác `appDatabaseProvider`/`clockProvider` vốn
    // override thẳng qua `ProviderScope` ở dưới.
    installFakeSharedPreferences();
    db = openTestDatabase();
    categories = await db.select(db.categories).get();
  });

  tearDownAll(() => db.close());

  final pendingCard = SessionDraftCard(
    id: 'card-pending',
    rawText: 'cà phê 35k',
    leftoverText: 'cà phê',
    amountMinor: 35000,
    amountConfident: true,
    categoryId: null, // để categoriesAsync tự resolve ở test — gán dưới đây
    categoryConfirmed: false,
    date: DateTime(2026, 8, 21),
    dateExplicit: false,
    savedTransactionId: 1,
    savedAt: DateTime(2026, 8, 21),
  );

  final errorCard = SessionDraftCard(
    id: 'card-error',
    rawText: 'đi chơi với bạn',
    leftoverText: 'đi chơi với bạn',
    amountMinor: null,
    amountConfident: false,
    categoryId: null,
    categoryConfirmed: false,
    date: DateTime(2026, 8, 21),
    dateExplicit: false,
  );

  goldenTest(
    'DraftCard — 3 trạng thái',
    fileName: 'draft_card_states',
    // `CategoryAvatar` giờ vẽ icon 3D bằng `Image.asset` THẬT — asset I/O là
    // async thật, không drain dưới `pump()` fake-async, nên thiếu dòng này
    // golden chụp đúng lúc ảnh chưa kịp lên (xem gotcha ở
    // `test/ui/widgets_golden_test.dart`).
    pumpBeforeTest: settleThenPrecacheImages,
    builder: () {
      final categoryId = categories.isNotEmpty ? categories.first.id : null;
      final withCategory = pendingCard.copyWith(categoryId: categoryId);
      return GoldenTestGroup(
        columns: 2,
        scenarioConstraints: const BoxConstraints.tightFor(
          width: 380,
          height: 260,
        ),
        children: [
          GoldenTestScenario(
            name: 'cho-light',
            child: _themedCard(lightTheme, db, categories, withCategory),
          ),
          GoldenTestScenario(
            name: 'cho-dark',
            child: _themedCard(darkTheme, db, categories, withCategory),
          ),
          GoldenTestScenario(
            name: 'da-luu-light',
            child: _themedCard(
              lightTheme,
              db,
              categories,
              withCategory,
              initiallyCollapsed: true,
            ),
          ),
          GoldenTestScenario(
            name: 'da-luu-dark',
            child: _themedCard(
              darkTheme,
              db,
              categories,
              withCategory,
              initiallyCollapsed: true,
            ),
          ),
          GoldenTestScenario(
            name: 'khong-hieu-light',
            child: _themedCard(lightTheme, db, categories, errorCard),
          ),
          GoldenTestScenario(
            name: 'khong-hieu-dark',
            child: _themedCard(darkTheme, db, categories, errorCard),
          ),
        ],
      );
    },
  );
}
