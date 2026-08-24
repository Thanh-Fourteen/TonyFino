// Tách giao dịch (Phase 14) qua cây sản xuất thật (`TransactionFormSheet`,
// mở từ `TransactionsScreen`'s FAB) — không lặp lại phép kiểm định số học đã
// làm kỹ ở `transaction_lines_test.dart`, chỉ xác nhận UI thật sự GỌI ĐÚNG
// qua `TransactionRepository.insert(lines: ...)`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/transactions/transactions_screen.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> openAddSheet(WidgetTester tester) async {
    await pumpApp(tester, db: db, child: const TransactionsScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tách giao dịch — tổng khớp lưu thành công, categoryId cha = null',
    (tester) async {
      await openAddSheet(tester);
      final categories = await db.select(db.categories).get();

      await tester.enterText(
        find.widgetWithText(TextField, 'Số tiền'),
        '30000',
      );
      await tester.tap(find.text('Tách giao dịch'));
      await tester.pumpAndSettle();

      expect(find.text('Các dòng con'), findsOneWidget);
      // "Tách giao dịch" đã tự tạo dòng #1 (không để màn hình trống lúc mới bật
      // — xem `_addLine`/`TextButton` "Tách giao dịch" gọi cùng handler) — chỉ
      // cần bấm "Thêm dòng" MỘT lần nữa để có đủ 2 dòng.
      await tester.tap(find.text('Thêm dòng'));
      await tester.pump();

      final amountFields = find.byType(TextField).evaluate().length;
      expect(amountFields, greaterThanOrEqualTo(3)); // tổng + 2 dòng con

      // Chọn danh mục cho từng dòng qua dialog "Chọn danh mục cho dòng này".
      await tester.tap(find.text('Chọn danh mục').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(categories[0].name).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chọn danh mục').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(categories[1].name).last);
      await tester.pumpAndSettle();

      // Điền số tiền cho 2 dòng con (tổng khớp 30000).
      final lineAmountFields = find.byType(TextField);
      await tester.enterText(lineAmountFields.at(1), '10000');
      await tester.enterText(lineAmountFields.at(2), '20000');
      await tester.pump();

      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm giao dịch'), findsNothing);
      final parent = await (db.select(
        db.transactions,
      )..where((t) => t.amountMinor.equals(-30000))).getSingle();
      expect(parent.categoryId, isNull);
      final lines = await (db.select(
        db.transactionLines,
      )..where((l) => l.transactionId.equals(parent.id))).get();
      expect(lines, hasLength(2));
      expect(lines.map((l) => l.amountMinor).toSet(), {-10000, -20000});
    },
  );

  testWidgets('tách giao dịch — tổng LỆCH → lưu báo lỗi, không ghi gì', (
    tester,
  ) async {
    await openAddSheet(tester);
    final categories = await db.select(db.categories).get();

    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '30000');
    await tester.tap(find.text('Tách giao dịch'));
    await tester.pumpAndSettle(); // đã tự có dòng #1 (xem test trên)

    await tester.tap(find.text('Chọn danh mục').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(categories[0].name).last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).at(1),
      '5000',
    ); // lệch với 30000
    await tester.pump();

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Không lưu được'), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  testWidgets(
    'bỏ tách — quay lại chọn một danh mục đơn, không còn UI dòng con',
    (tester) async {
      await openAddSheet(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Số tiền'),
        '30000',
      );
      await tester.tap(find.text('Tách giao dịch'));
      await tester.pumpAndSettle();
      expect(find.text('Các dòng con'), findsOneWidget);

      await tester.tap(find.text('Bỏ tách'));
      await tester.pumpAndSettle();

      expect(find.text('Các dòng con'), findsNothing);
      expect(find.text('Danh mục'), findsOneWidget);
    },
  );
}
