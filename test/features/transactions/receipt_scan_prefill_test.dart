// Quét hoá đơn → form điền sẵn: số tiền VÀ CHIỀU TIỀN.
//
// Chiều tiền là chỗ dễ sai âm thầm: `extractReceiptInfo` trả về ĐỘ LỚN
// (dương), nên bất kỳ chỗ nào suy chiều tiền từ dấu của số điền sẵn sẽ biến
// mọi hoá đơn mua hàng thành khoản THU. Bắt được bằng cách quét hoá đơn
// Emart thật của Tony: ra "Thu 414.000đ" — đúng số, sai hẳn chiều.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/transactions/transaction_form_sheet.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

const _onePixelPng = [
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  2,
  0,
  0,
  0,
  144,
  119,
  83,
  222,
  0,
  0,
  0,
  12,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  255,
  255,
  63,
  0,
  5,
  254,
  2,
  254,
  13,
  239,
  70,
  184,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpForm(WidgetTester tester, TransactionFormPrefill p) async {
    await pumpApp(
      tester,
      db: db,
      child: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showTransactionFormSheet(context: context, prefill: p),
            child: const Text('mở'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  testWidgets('🚨 hoá đơn quét được → "Chi", KHÔNG phải "Thu"', (tester) async {
    await pumpForm(
      tester,
      TransactionFormPrefill.fromReceiptScan(
        amountMinor: 414000, // ĐỘ LỚN, dương — như OCR trả về
        merchantName: 'emart',
        // PNG 1×1 hợp lệ — `Uint8List(0)` làm form ném lỗi giải mã ảnh,
        // che mất chính thứ đang cần kiểm.
        receiptImageBytes: Uint8List.fromList(_onePixelPng),
        receiptImageExtension: 'jpg',
      ),
    );

    final segmented = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(
      segmented.selected,
      {true},
      reason: 'true = Chi. Hoá đơn mua hàng không bao giờ là khoản thu.',
    );
    expect(find.widgetWithText(TextField, 'Số tiền'), findsOneWidget);
    expect(find.text('414.000'), findsOneWidget);
    expect(find.text('emart'), findsOneWidget);
  });

  testWidgets('SỬA giao dịch THU thì vẫn giữ "Thu" (suy từ dấu thật)', (
    tester,
  ) async {
    // Giao dịch đã có mang dấu thật trong DB — ở đó dấu MỚI là nguồn đúng.
    await pumpForm(
      tester,
      const TransactionFormPrefill(amountMinor: 15000, isExpenseHint: false),
    );

    final segmented = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(segmented.selected, {false});
  });
}
