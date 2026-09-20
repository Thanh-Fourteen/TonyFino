// Trang chủ: thẻ Hũ hiện ĐỦ mọi hũ, mỗi hũ đủ hạn mức / đã dùng / còn lại,
// cộng dòng tổng — và hũ tiết kiệm nói bằng chữ của nó.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/jar_repository.dart';
import 'package:tonyfino/features/home/home_screen.dart';
import 'package:tonyfino/features/settings/settings_controller.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

class _JarsOnly extends AppSettingsController {
  @override
  AppSettings build() =>
      AppSettings.initial.copyWith(homeSections: {HomeSection.jars});
}

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  testWidgets('đủ 7 hũ (không cắt ở 4), có tổng thu làm gốc và dòng tổng; hũ '
      'tiết kiệm hiện "đã gửi"', (tester) async {
    final walletId = await defaultWalletId(db);
    final repo = JarRepository(db);
    await repo.seedDefaultJars(walletId); // 6 hũ, tổng 100%
    final goalId = await db
        .into(db.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            name: 'Quỹ ngắn hạn',
            targetAmountMinor: 50000000,
            currency: 'VND',
            currencyScale: 0,
          ),
        );
    await repo.insert(
      walletId: walletId,
      name: 'Gửi quỹ',
      percent: 10,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      goals: [JarGoalLink(goalId: goalId)],
    );
    final now = DateTime.now();
    Future<void> add(int amount, {int? goal}) => db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: amount,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: DateTime(now.year, now.month, 2),
            walletId: walletId,
            goalId: Value(goal),
          ),
        );
    await add(20000000);
    await add(-100000, goal: goalId);

    await pumpApp(
      tester,
      db: db,
      child: const HomeScreen(),
      extraOverrides: [appSettingsProvider.overrideWith(_JarsOnly.new)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Hũ kỳ này'), findsOneWidget);
    expect(find.textContaining('Chia từ tổng thu 20.000.000'), findsOneWidget);
    for (final name in [
      'Thiết yếu',
      'Tiết kiệm dài hạn',
      'Giáo dục',
      'Hưởng thụ',
      'Tự do tài chính',
      'Cho đi',
      'Gửi quỹ',
    ]) {
      await tester.scrollUntilVisible(
        find.textContaining('$name ·'),
        80,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('$name ·'), findsOneWidget, reason: name);
    }
    // Hũ tiết kiệm: 10% × 20tr = 2tr, đã gửi 100k, còn cần gửi 1,9tr.
    // Định dạng tiền dùng khoảng trắng KHÔNG NGẮT trước "₫" — so từng phần.
    final savingLine = find.textContaining(
      RegExp(r'Đã gửi 100\.000.*/ 2\.000\.000'),
    );
    expect(savingLine, findsOneWidget);
    expect(find.text('Còn cần gửi '), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tổng hũ 110%'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tổng hũ 110%'), findsOneWidget);
  });
}
