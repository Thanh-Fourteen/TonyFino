// Mẫu giao dịch (Phase 14) qua cây sản xuất thật: thêm/sửa/xoá mẫu ở
// `TransactionTemplatesScreen`, và áp dụng nhanh từ FAB nhấn giữ ở
// `TransactionsScreen`.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/transactions/transaction_templates_screen.dart';
import 'package:tonyfino/features/transactions/transactions_screen.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

/// Tab Giao dịch lọc theo kỳ (mặc định "Tháng này") kể từ khi Tony yêu cầu
/// bộ chọn khoảng. Đóng băng đồng hồ để "tháng này" luôn là tháng chứa dữ
/// liệu seed của test — nếu để đồng hồ thật, bộ test này tự hỏng khi sang
/// tháng mới, đúng loại lỗi chỉ nổ ra vào một ngày ngẫu nhiên trong tương lai.
final _frozenClock = Clock.fixed(DateTime(2026, 8, 25));

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  testWidgets(
    '🚨 Phase 18: nhấn giữ FAB khi CHƯA CÓ mẫu nào vẫn hiện sheet (không tự nhảy '
    'thẳng tới màn quản lý như hành vi Phase 14 cũ) — luôn có lựa chọn "Quét hoá đơn"',
    (tester) async {
      await pumpApp(
        tester,
        db: db,
        child: const TransactionsScreen(),
        extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Thêm nhanh'), findsOneWidget);
      expect(find.text('Quét hoá đơn'), findsOneWidget);
      expect(find.text('Quản lý mẫu giao dịch'), findsOneWidget);
      expect(find.byType(TransactionTemplatesScreen), findsNothing);
    },
  );

  testWidgets('thêm mẫu qua sheet — hiện ngay trên danh sách quản lý', (
    tester,
  ) async {
    await pumpApp(
      tester,
      db: db,
      child: const TransactionTemplatesScreen(),
      extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có mẫu'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tên mẫu'),
      'Cà phê sáng',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '25000');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Cà phê sáng'), findsOneWidget);
    expect(await db.select(db.transactionTemplates).get(), hasLength(1));
  });

  testWidgets('xoá mẫu qua popup menu — biến mất khỏi danh sách', (
    tester,
  ) async {
    await db
        .into(db.transactionTemplates)
        .insert(
          TransactionTemplatesCompanion.insert(
            name: 'Cà phê sáng',
            amountMinor: -25000,
            currency: 'VND',
            currencyScale: 0,
          ),
        );

    await pumpApp(
      tester,
      db: db,
      child: const TransactionTemplatesScreen(),
      extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();

    expect(find.text('Cà phê sáng'), findsNothing);
    expect(await db.select(db.transactionTemplates).get(), isEmpty);
  });

  testWidgets(
    'nhấn giữ FAB "Thêm" ở Giao dịch → chọn mẫu → mở sheet Thêm điền sẵn',
    (tester) async {
      await db
          .into(db.transactionTemplates)
          .insert(
            TransactionTemplatesCompanion.insert(
              name: 'Cà phê sáng',
              amountMinor: -25000,
              currency: 'VND',
              currencyScale: 0,
            ),
          );

      await pumpApp(
        tester,
        db: db,
        child: const TransactionsScreen(),
        extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Phase 18: sheet đổi tên "Áp dụng mẫu" → "Thêm nhanh" (giờ còn có
      // lựa chọn "Quét hoá đơn").
      expect(find.text('Thêm nhanh'), findsOneWidget);
      expect(find.text('Cà phê sáng'), findsOneWidget);

      await tester.tap(find.text('Cà phê sáng'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm giao dịch'), findsOneWidget);
      final amountField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Số tiền'),
      );
      expect(amountField.controller!.text, '25.000');
    },
  );

  testWidgets(
    'sửa/xoá một mẫu KHÔNG ảnh hưởng giao dịch đã tạo từ mẫu đó trước đây',
    (tester) async {
      final templateId = await db
          .into(db.transactionTemplates)
          .insert(
            TransactionTemplatesCompanion.insert(
              name: 'Cà phê sáng',
              amountMinor: -25000,
              currency: 'VND',
              currencyScale: 0,
            ),
          );

      await pumpApp(
        tester,
        db: db,
        child: const TransactionsScreen(),
        extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cà phê sáng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      final createdTx = await (db.select(
        db.transactions,
      )..where((t) => t.amountMinor.equals(-25000))).getSingle();

      await db
          .into(db.transactionTemplates)
          .insertOnConflictUpdate(
            TransactionTemplatesCompanion(
              id: Value(templateId),
              name: const Value('Cà phê (đã đổi tên)'),
              amountMinor: const Value(-99999),
              currency: const Value('VND'),
              currencyScale: const Value(0),
            ),
          );
      var tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(createdTx.id))).getSingle();
      expect(tx.amountMinor, -25000);

      await (db.delete(
        db.transactionTemplates,
      )..where((t) => t.id.equals(templateId))).go();
      tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(createdTx.id))).getSingle();
      expect(tx.amountMinor, -25000);
    },
  );
}
