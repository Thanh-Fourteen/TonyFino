// Kéo thả thứ tự QUỸ ở tab "Túi tiền → Quỹ" (v18), và chỗ chừa cho thanh
// điều hướng nổi — hai lỗi Tony báo 2026-09-22: "không kéo di chuyển thứ tự
// các quỹ được, quỹ ở cuối bị che".
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/core/router/app_bottom_nav.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/savings_goal_repository.dart';
import 'package:tonyfino/features/savings/savings_screen.dart';

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

  Future<List<String>> orderInDb() async {
    final goals =
        await (db.select(db.savingsGoals)..orderBy([
              (g) => OrderingTerm.asc(g.sortOrder),
              (g) => OrderingTerm.asc(g.id),
            ]))
            .get();
    return [for (final g in goals) g.name];
  }

  Future<void> dragGoal(WidgetTester tester, String name, double dy) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(name)),
    );
    // Nhấn GIỮ rồi mới kéo — `ReorderableListView` trên mobile dùng
    // long-press để bắt đầu, kéo ngay lập tức chỉ làm cuộn danh sách.
    await tester.pump(kLongPressTimeout + kPressTimeout);
    for (var moved = 0.0; moved.abs() < dy.abs(); moved += dy.sign * 40) {
      await gesture.moveBy(Offset(0, dy.sign * 40));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('kéo quỹ cuối lên đầu — thứ tự ghi vào DB đúng như thấy trên '
      'màn', (tester) async {
    final repo = SavingsGoalRepository(db);
    for (final name in ['A', 'B', 'C']) {
      await repo.insert(name: name, targetAmount: const Money.vnd(10000000));
    }

    tester.view.physicalSize = const Size(700, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(tester, db: db, child: const SavingsGoalsTab());
    await tester.pumpAndSettle();
    expect(await orderInDb(), ['A', 'B', 'C']);

    List<String> orderOnScreen() {
      final names = ['A', 'B', 'C']
        ..sort(
          (a, b) => tester
              .getCenter(find.text(a))
              .dy
              .compareTo(tester.getCenter(find.text(b)).dy),
        );
      return names;
    }

    await dragGoal(tester, 'C', -600);
    expect(orderOnScreen(), ['C', 'A', 'B']);
    expect(await orderInDb(), orderOnScreen());

    // Kéo XUỐNG — ca dễ lệch một ô nếu tự trừ chỉ số thêm lần nữa.
    await dragGoal(tester, 'C', 300);
    expect(orderOnScreen().first, 'A', reason: 'C phải rời khỏi vị trí đầu');
    expect(await orderInDb(), orderOnScreen());
  });

  testWidgets('nhúng trong Túi tiền: danh sách chừa chỗ cho thanh điều hướng '
      'nổi, quỹ cuối không bị che', (tester) async {
    final repo = SavingsGoalRepository(db);
    for (final name in ['A', 'B']) {
      await repo.insert(name: name, targetAmount: const Money.vnd(10000000));
    }

    await pumpApp(
      tester,
      db: db,
      child: const SavingsGoalsTab(embedded: true),
    );
    await tester.pumpAndSettle();

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    final padding = list.padding!.resolve(TextDirection.ltr);
    expect(
      padding.bottom,
      greaterThanOrEqualTo(kBottomNavReservedHeight),
      reason: 'thiếu chỗ này thì quỹ cuối nằm khuất dưới thanh nav',
    );
  });
}
