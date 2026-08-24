// OnboardingGate (Phase 22) — qua cây sản xuất thật.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/lifecycle/onboarding_gate.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<void> pumpGate(WidgetTester tester) async {
    await pumpApp(
      tester,
      db: db,
      child: const OnboardingGate(child: Text('Nội dung app thật')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('DB mới hoàn toàn, chưa có giao dịch nào → hiện màn chào mừng', (
    tester,
  ) async {
    await pumpGate(tester);
    expect(find.text('Chào mừng đến với TonyFino'), findsOneWidget);
    expect(find.text('Nội dung app thật'), findsNothing);
  });

  testWidgets('bấm "Bắt đầu" → ẩn màn chào, hiện nội dung app', (tester) async {
    await pumpGate(tester);
    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();

    expect(find.text('Nội dung app thật'), findsOneWidget);
    expect(find.text('Chào mừng đến với TonyFino'), findsNothing);
  });

  testWidgets(
    '🚨 người dùng NÂNG CẤP (đã có giao dịch thật, hasSeenOnboarding vẫn '
    'false vì key chưa từng tồn tại) → KHÔNG hiện màn chào',
    (tester) async {
      final walletId = (await db.select(db.wallets).get()).first.id;
      await TransactionRepository(db).insert(
        amount: Money.vnd(-50000),
        occurredAt: DateTime(2026, 8, 20),
        walletId: walletId,
      );

      await pumpGate(tester);

      expect(find.text('Nội dung app thật'), findsOneWidget);
      expect(find.text('Chào mừng đến với TonyFino'), findsNothing);
    },
  );
}
