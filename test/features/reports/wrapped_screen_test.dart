import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/reports/wrapped_screen.dart';
import 'package:tonyfino/theme/tokens/icons.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

/// Đóng băng ở giữa năm 2026 — cùng lý do mọi test lọc-theo-kỳ khác trong
/// dự án: seed dữ liệu và bộ lọc phải cùng một đồng hồ, không phải
/// `DateTime.now()` của máy chạy test.
final _frozenClock = Clock.fixed(DateTime(2026, 6, 15));

/// `WrappedScreen` gọi `Navigator.pop` khi đóng — cần một route bên dưới để
/// pop có chỗ về, giống hệt cách `notes_screen_test.dart` push
/// `NoteEditScreen` thay vì pump thẳng nó làm `home`.
class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => openWrappedScreen(context),
          child: const Text('Mở Wrapped'),
        ),
      ),
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<int> firstCategoryId() => (db.select(
    db.categories,
  )..limit(1)).getSingle().then((c) => c.id);

  Future<void> seedExpense({
    required int amountMinor,
    required DateTime occurredAt,
    int? categoryId,
  }) async {
    final wallet = await defaultWalletId(db);
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: amountMinor,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: occurredAt,
            walletId: wallet,
            categoryId: categoryId == null
                ? const Value.absent()
                : Value(categoryId),
          ),
        );
  }

  Future<void> openWrapped(WidgetTester tester) async {
    await pumpApp(
      tester,
      db: db,
      child: const _Launcher(),
      extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở Wrapped'));
    await tester.pumpAndSettle();
  }

  testWidgets('chưa có giao dịch nào trong năm vẫn hiện được, không crash', (
    tester,
  ) async {
    await openWrapped(tester);

    expect(find.textContaining('Năm 2026'), findsOneWidget);
    expect(
      find.textContaining('Chưa có giao dịch nào năm nay'),
      findsOneWidget,
    );
  });

  testWidgets('lướt qua đủ các thẻ, đúng số liệu đã seed', (tester) async {
    final categoryId = await firstCategoryId();
    // Danh mục chi nhiều nhất: 3 khoản cùng danh mục, tổng 550.000.
    await seedExpense(
      amountMinor: -300000,
      occurredAt: DateTime(2026, 3, 1),
      categoryId: categoryId,
    );
    await seedExpense(
      amountMinor: -200000,
      occurredAt: DateTime(2026, 3, 2),
      categoryId: categoryId,
    );
    // Chuỗi liên tiếp 3 ngày (1-3/3), dài hơn chuỗi 2 ngày cuối dưới đây.
    await seedExpense(
      amountMinor: -50000,
      occurredAt: DateTime(2026, 3, 3),
      categoryId: categoryId,
    );
    await seedExpense(
      amountMinor: -10000,
      occurredAt: DateTime(2026, 6, 10),
    );
    await seedExpense(amountMinor: -10000, occurredAt: DateTime(2026, 6, 11));

    await openWrapped(tester);

    // Thẻ 1 — mở đầu: đúng số giao dịch đã ghi trong năm.
    expect(find.textContaining('Năm 2026'), findsOneWidget);
    expect(find.textContaining('5 giao dịch'), findsOneWidget);

    // Thẻ 2 — danh mục chi nhiều nhất (550.000, gộp 3 khoản cùng danh mục).
    await tester.tap(find.byType(WrappedScreen));
    await tester.pumpAndSettle();
    expect(find.textContaining('550.000'), findsOneWidget);

    // Thẻ 3 — thu/chi cả năm: tổng chi 570.000, tổng thu 0.
    await tester.tap(find.byType(WrappedScreen));
    await tester.pumpAndSettle();
    expect(find.textContaining('570.000'), findsOneWidget);

    // Thẻ 4 — chuỗi dài nhất: 3 ngày liên tiếp (1-3/3), không phải 2 ngày
    // cuối (10-11/6).
    await tester.tap(find.byType(WrappedScreen));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 ngày liên tiếp'), findsOneWidget);

    // Thẻ 5 — lời chào cuối, rồi chạm lần nữa để thoát hẳn.
    await tester.tap(find.byType(WrappedScreen));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cảm ơn'), findsOneWidget);

    await tester.tap(find.byType(WrappedScreen));
    await tester.pumpAndSettle();
    expect(find.byType(WrappedScreen), findsNothing);
    expect(find.text('Mở Wrapped'), findsOneWidget);
  });

  testWidgets('nút X đóng lại giữa chừng', (tester) async {
    await openWrapped(tester);

    await tester.tap(find.byIcon(kIconClose));
    await tester.pumpAndSettle();
    expect(find.byType(WrappedScreen), findsNothing);
    expect(find.text('Mở Wrapped'), findsOneWidget);
  });
}
