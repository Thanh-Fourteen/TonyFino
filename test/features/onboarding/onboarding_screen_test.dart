import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/onboarding/onboarding_screen.dart';
import 'package:tonyfino/ui/mascot/app_mascot.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  bool mascotFestive(WidgetTester tester) =>
      tester.widget<AppMascot>(find.byType(AppMascot)).festive;

  testWidgets('đúng dịp Tết (mồng Một 2027) → linh vật có hoa mai', (
    tester,
  ) async {
    await pumpApp(
      tester,
      db: db,
      child: OnboardingScreen(onDone: () {}),
      extraOverrides: [
        clockProvider.overrideWithValue(Clock.fixed(DateTime(2027, 2, 6))),
      ],
    );
    await tester.pumpAndSettle();

    expect(mascotFestive(tester), isTrue);
  });

  testWidgets('ngày thường (giữa năm) → linh vật KHÔNG có hoa mai', (
    tester,
  ) async {
    await pumpApp(
      tester,
      db: db,
      child: OnboardingScreen(onDone: () {}),
      extraOverrides: [
        clockProvider.overrideWithValue(Clock.fixed(DateTime(2027, 7, 15))),
      ],
    );
    await tester.pumpAndSettle();

    expect(mascotFestive(tester), isFalse);
  });
}
