// Trang chủ: chọn khối hiển thị (Cài đặt) + "Còn lại" trừ cả tiết kiệm.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/home/home_screen.dart';
import 'package:tonyfino/features/settings/settings_controller.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

/// Cài đặt chỉ bật đúng những khối truyền vào.
class _Sections extends AppSettingsController {
  _Sections(this.sections);
  final Set<HomeSection> sections;

  @override
  AppSettings build() => AppSettings.initial.copyWith(homeSections: sections);
}

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<void> pumpHome(WidgetTester tester, Set<HomeSection> sections) async {
    await pumpApp(
      tester,
      db: db,
      child: const HomeScreen(),
      extraOverrides: [
        appSettingsProvider.overrideWith(() => _Sections(sections)),
      ],
    );
    await tester.pumpAndSettle();
  }

  // Hai lần `pumpApp` trong CÙNG một test không tạo lại container Riverpod
  // (widget cùng kiểu nên chỉ update, override không chạy lại) — tách thành
  // hai test để mỗi bên có một lần dựng sạch.
  testWidgets('trang Hạn mức đã bỏ — bật mọi khối cũng không còn thẻ Hạn '
      'mức ở Trang chủ', (tester) async {
    await pumpHome(tester, {...HomeSection.values});
    expect(find.text('Hạn mức'), findsNothing);
  });

  testWidgets('tắt hết → chỉ còn khối đầu trang (số dư + kỳ + thống kê)', (
    tester,
  ) async {
    await pumpHome(tester, const {});
    expect(find.text('Hạn mức'), findsNothing);
    expect(find.text('Gần đây'), findsNothing);
    // Khối đầu trang KHÔNG tắt được — tắt luôn cả số dư thì Trang chủ trống
    // trơn, không còn là trang chủ nữa.
    expect(find.text('Còn lại'), findsOneWidget);
    expect(find.text('Tiết kiệm'), findsOneWidget);
  });

  testWidgets(
    '🚨 "Còn lại" TRỪ phần đã cất vào tiết kiệm — Tony có tiết kiệm nên công '
    'thức thu−chi báo dư nhiều hơn số thật sự tiêu được',
    (tester) async {
      final walletId = (await db.select(db.wallets).get()).first.id;
      final goalId = await db
          .into(db.savingsGoals)
          .insert(
            SavingsGoalsCompanion.insert(
              name: 'Quỹ dự phòng',
              targetAmountMinor: 50000000,
              currency: 'VND',
              currencyScale: 0,
            ),
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
      await add(10000000);
      await add(-1000000);
      await add(-6000000, goal: goalId);

      await pumpHome(tester, const {});

      // 10.000.000 − 1.000.000 − 6.000.000 = 3.000.000, KHÔNG phải 9.000.000.
      expect(find.textContaining('3.000.000'), findsWidgets);
      expect(find.textContaining('9.000.000'), findsNothing);
    },
  );
}
