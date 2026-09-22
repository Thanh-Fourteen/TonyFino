// Bộ chọn quỹ của chip "Nạp quỹ" (Trang chủ → Ghi một khoản → Nạp quỹ).
//
// Lỗi Tony báo 2026-09-22: "khi có nhiều hơn 6 quỹ không vuốt chọn được".
// Sheet mở với `isScrollControlled: false` (Material kẹp chiều cao ở 9/16
// màn hình) và nội dung là một `Column` thẳng đuột — quá 6 quỹ là tràn
// khung, và tràn thì KHÔNG cuộn được, chỉ kêu overflow.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/savings_goal_repository.dart';
import 'package:tonyfino/features/savings/savings_providers.dart';
import 'package:tonyfino/features/savings/widgets/savings_goal_picker.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

/// Nút mở luồng nạp quỹ, kèm `ref.watch` của chính stream mà
/// `openSavingsDepositFlow` sẽ `ref.read` — y hệt chip thật ở thanh nhập
/// nhanh. Không watch thì `StreamProvider` của Riverpod 3 nằm im và
/// `.value` mãi mãi là `null` (bẫy đã ghi ở project_tonyfino_gotchas).
class _OpenPickerButton extends ConsumerWidget {
  const _OpenPickerButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(activeSavingsGoalsWithProgressProvider).value;
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: goals == null || goals.isEmpty
              ? null
              : () => openSavingsDepositFlow(context, ref),
          child: const Text('Nạp quỹ'),
        ),
      ),
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  testWidgets('9 quỹ: danh sách cuộn được tới quỹ cuối cùng', (tester) async {
    final repo = SavingsGoalRepository(db);
    for (var i = 1; i <= 9; i++) {
      await repo.insert(
        name: 'Quỹ số $i',
        targetAmount: const Money.vnd(10000000),
      );
    }

    // Màn hình điện thoại thật (Redmi Note 13 Pro ~ 393×873 dp) — khung test
    // mặc định 800×600 nằm ngang, mọi thứ vừa hết và lỗi không tái hiện.
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(tester, db: db, child: const _OpenPickerButton());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nạp quỹ'));
    await tester.pumpAndSettle();

    expect(find.text('Nạp vào quỹ nào?'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'không được tràn khung');

    // Quỹ cuối phải CUỘN TỚI ĐƯỢC — đây chính là thứ hỏng trước đây.
    final list = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    for (var i = 0; i < 12 && find.text('Quỹ số 9').evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, -80));
      await tester.pumpAndSettle();
    }
    expect(find.text('Quỹ số 9'), findsOneWidget);

    await tester.tap(find.text('Quỹ số 9'));
    await tester.pumpAndSettle();
    // Chọn xong thì sang sheet nạp tiền của ĐÚNG quỹ đó.
    expect(find.textContaining('Quỹ số 9'), findsWidgets);
  });
}
