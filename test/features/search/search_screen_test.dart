import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/features/search/search_screen.dart';
import 'package:tonyfino/theme/tokens/icons.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<void> pumpSearch(WidgetTester tester) async {
    await pumpApp(tester, db: db, child: const SearchScreen());
    await tester.pumpAndSettle();
  }

  testWidgets('chưa gõ gì → hiện gợi ý, không gọi query nào', (tester) async {
    await pumpSearch(tester);
    expect(find.text('Tìm giao dịch'), findsOneWidget);
  });

  testWidgets(
    '🚨 gõ từ khoá không dấu → khớp giao dịch có ghi chú dấu đầy đủ',
    (tester) async {
      final walletId = (await db.select(db.wallets).get()).first.id;
      // Chèn qua `TransactionRepository.insert` (KHÔNG chèn thẳng
      // `db.into(db.transactions)`) — chỉ đường này tự đồng bộ
      // `transactions_fts`, xem `TransactionRepository._syncFts`.
      await TransactionRepository(db).insert(
        amount: Money.vnd(-35000),
        occurredAt: DateTime.utc(2026, 8, 20),
        walletId: walletId,
        note: 'ăn trưa bún bò',
      );

      await pumpSearch(tester);
      await tester.enterText(find.byType(TextField), 'an trua');
      await tester.pumpAndSettle();

      expect(find.textContaining('ăn trưa bún bò'), findsOneWidget);
    },
  );

  testWidgets('không khớp → hiện "Không tìm thấy"', (tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'khong ton tai');
    await tester.pumpAndSettle();

    expect(find.text('Không tìm thấy'), findsOneWidget);
  });

  testWidgets(
    'chạm nút xoá trên app bar → xoá chữ đã gõ, quay lại gợi ý ban đầu',
    (tester) async {
      await pumpSearch(tester);
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pumpAndSettle();
      expect(find.text('Tìm giao dịch'), findsNothing);

      await tester.tap(find.byIcon(kIconClose));
      await tester.pumpAndSettle();

      expect(find.text('Tìm giao dịch'), findsOneWidget);
    },
  );
}
