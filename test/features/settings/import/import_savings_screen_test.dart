import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/features/settings/import/import_screen.dart';

import '../../../support/fake_file_picker.dart';
import '../../../support/open_test_database.dart';
import '../../../support/pump_app.dart';

void main() {
  late AppDatabase db;
  late FakeFilePicker filePicker;

  setUp(() {
    db = openTestDatabase();
    filePicker = installFakeFilePicker();
  });
  tearDown(() => db.close());

  Uint8List sampleSavingsFile() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'savings': [
          {
            'id': 49755,
            'title': 'CCTG',
            'achieve_amount': 30000000.0,
            'achieve_date': '2026-08-22',
            'currency_code': 'VND',
            'completed': true,
            'total_amount': 15000000.0,
          },
        ],
        'input': [
          {
            'id': 100,
            'type': 'Savings',
            'wallet_id': 1,
            'linking_savings_id': 49755,
          },
          {
            'id': 101,
            'type': 'Savings',
            'wallet_id': 1,
            'linking_savings_id': 49755,
          },
        ],
      }),
    ),
  );

  Future<void> pickSavingsFile(WidgetTester tester) async {
    filePicker.nextFileBytes = sampleSavingsFile();
    await tester.tap(find.text('Chọn file JSON tiết kiệm Rolly'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'chọn file tiết kiệm → xem trước → xác nhận → tạo goal + gắn goalId vào giao dịch cũ, import lại thì idempotent',
    (tester) async {
      final walletId = (await db.select(db.wallets).get()).first.id;
      final txRepo = TransactionRepository(db);
      final tx1 = (await txRepo.insert(
        amount: Money.vnd(-10000000),
        occurredAt: DateTime(2026, 7, 1),
        walletId: walletId,
        sourceId: 'rolly:100',
      )).valueOrNull!;
      final tx2 = (await txRepo.insert(
        amount: Money.vnd(-5000000),
        occurredAt: DateTime(2026, 7, 2),
        walletId: walletId,
        sourceId: 'rolly:101',
      )).valueOrNull!;

      await pumpApp(tester, db: db, child: const ImportScreen());

      await pickSavingsFile(tester);

      expect(find.textContaining('1 mục tiêu MỚI'), findsOneWidget);
      expect(find.textContaining('CCTG'), findsOneWidget);
      expect(find.textContaining('2 giao dịch đóng góp'), findsOneWidget);

      await tester.tap(find.text('Xác nhận nhập 1 mục tiêu'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã nhập 1 mục tiêu mới'), findsOneWidget);
      expect(
        find.textContaining('2 giao dịch đã được gắn lại'),
        findsOneWidget,
      );

      final goals = await db.select(db.savingsGoals).get();
      expect(goals, hasLength(1));
      expect(goals.single.name, 'CCTG');

      final t1 = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(tx1))).getSingle();
      final t2 = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(tx2))).getSingle();
      expect(t1.goalId, goals.single.id);
      expect(t2.goalId, goals.single.id);

      // Import LẠI CHÍNH FILE ĐÓ → không tạo goal trùng, không nhân đôi liên kết.
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      await pickSavingsFile(tester);
      expect(find.textContaining('0 mục tiêu MỚI'), findsOneWidget);
      expect(find.text('Không có gì mới để nhập'), findsOneWidget);

      expect(await db.select(db.savingsGoals).get(), hasLength(1));
    },
  );
}
