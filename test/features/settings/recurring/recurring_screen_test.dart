// Widget test qua cây sản xuất thật (`RecurringScreen`) — cùng kỷ luật
// `budgets_screen_test.dart` (Phase 11): thêm qua sheet thật, xác nhận hiện
// ngay trên danh sách không cần khởi động lại.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/recurring_transaction_repository.dart';
import 'package:tonyfino/features/settings/recurring/domain/recurring_frequency.dart';
import 'package:tonyfino/features/settings/recurring/recurring_screen.dart';

import '../../../support/open_test_database.dart';
import '../../../support/pump_app.dart';

final _fixedClock = Clock.fixed(DateTime(2026, 8, 21, 10));

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpRecurring(WidgetTester tester) async {
    await pumpApp(
      tester,
      db: db,
      child: const RecurringScreen(),
      extraOverrides: [clockProvider.overrideWithValue(_fixedClock)],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chưa có dòng nào → hiện trạng thái rỗng', (tester) async {
    await pumpRecurring(tester);
    expect(
      find.textContaining('Chưa có giao dịch định kỳ nào'),
      findsOneWidget,
    );
  });

  testWidgets(
    'thêm qua sheet — hiện ngay trên danh sách không cần khởi động lại',
    (tester) async {
      await pumpRecurring(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '500000');
      await tester.enterText(
        find.widgetWithText(TextField, 'Ghi chú (tuỳ chọn)'),
        'Tiền nhà',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(find.text('Tiền nhà'), findsOneWidget);
      expect(find.textContaining('Hàng tháng'), findsOneWidget);
    },
  );

  testWidgets('"Đã xử lý" đẩy kỳ tới, dòng vẫn còn active', (tester) async {
    final repo = RecurringTransactionRepository(db);
    await repo.insert(
      categoryId: null,
      amount: const Money.vnd(-500000),
      note: 'Internet',
      frequency: RecurringFrequency.monthly,
      nextOccurrenceDate: DateTime(2026, 8, 25),
    );

    await pumpRecurring(tester);
    expect(find.textContaining('kỳ tới 25/8/2026'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã xử lý — dời sang kỳ tới'));
    await tester.pumpAndSettle();

    expect(find.textContaining('kỳ tới 25/9/2026'), findsOneWidget);
  });
}
