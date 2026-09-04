import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/transactions/transactions_screen.dart';
import 'package:tonyfino/ui/app_chip.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

/// Tab Giao dịch lọc theo kỳ (mặc định "Tháng này") kể từ khi Tony yêu cầu
/// bộ chọn khoảng. Đóng băng đồng hồ để "tháng này" luôn là tháng chứa dữ
/// liệu seed của test — nếu để đồng hồ thật, bộ test này tự hỏng khi sang
/// tháng mới, đúng loại lỗi chỉ nổ ra vào một ngày ngẫu nhiên trong tương lai.
///
/// 🚨 Và phải seed giao dịch bằng CHÍNH đồng hồ này (`_frozenClock.now()`),
/// không phải `DateTime.now()`: đóng băng bộ lọc ở tháng 8/2026 trong khi
/// dữ liệu rơi vào tháng thật của máy chạy test là hai tháng khác nhau, nên
/// hàng seed nằm ngoài kỳ và biến mất. Chính cái bẫy đoạn trên cảnh báo, chỉ
/// là ở nửa còn lại — bộ test này đã đỏ sẵn từ ngày 1/9/2026.
final _frozenClock = Clock.fixed(DateTime(2026, 8, 25));

void main() {
  late AppDatabase db;

  setUp(() {
    db = openTestDatabase();
  });

  tearDown(() => db.close());

  Future<int> firstCategoryId() async {
    final categories = await db.select(db.categories).get();
    return categories.first.id;
  }

  Future<int> firstWalletId() async {
    final wallets = await db.select(db.wallets).get();
    return wallets.first.id;
  }

  testWidgets('hiển thị hero card + hàng giao dịch đã seed', (tester) async {
    final categoryId = await firstCategoryId();
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: -65000,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: _frozenClock.now(),
            walletId: await firstWalletId(),
            categoryId: Value(categoryId),
            note: const Value('ăn trưa'),
          ),
        );

    await pumpApp(
      tester,
      db: db,
      child: const TransactionsScreen(),
      extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Chi tiêu trong kỳ'), findsOneWidget);
    expect(find.textContaining('ăn trưa'), findsOneWidget);
  });

  testWidgets('rỗng thì hiện EmptyState, không crash', (tester) async {
    await pumpApp(
      tester,
      db: db,
      child: const TransactionsScreen(),
      extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Không có giao dịch trong kỳ này'), findsOneWidget);
    expect(find.text('Chi tiêu trong kỳ'), findsOneWidget);
  });

  testWidgets('bấm FAB mở bottom sheet thêm giao dịch', (tester) async {
    await pumpApp(
      tester,
      db: db,
      child: const TransactionsScreen(),
      extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();

    expect(find.text('Thêm giao dịch'), findsOneWidget);
    expect(find.text('Số tiền'), findsOneWidget);
  });

  testWidgets('thêm giao dịch qua form → xuất hiện trong danh sách', (
    tester,
  ) async {
    await pumpApp(
      tester,
      db: db,
      child: const TransactionsScreen(),
      extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '50000');
    await tester.tap(find.byType(AppChip).first);
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Thêm giao dịch'), findsNothing);
    expect(find.textContaining('50.000'), findsWidgets);
  });

  testWidgets('vuốt xoá hiện SnackBar Hoàn tác', (tester) async {
    final categoryId = await firstCategoryId();
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: -20000,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: _frozenClock.now(),
            walletId: await firstWalletId(),
            categoryId: Value(categoryId),
          ),
        );

    await pumpApp(
      tester,
      db: db,
      child: const TransactionsScreen(),
      extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Đã xoá giao dịch'), findsOneWidget);
    expect(find.text('Hoàn tác'), findsOneWidget);
  });

  testWidgets(
    '🚨 NHIỀU NGÀY, mỗi ngày một giao dịch → cuộn xuống vẫn thấy ĐƯỢC giao '
    'dịch, không phải một chồng header ngày',
    (tester) async {
      // Bug thật Tony báo: sổ có 358 giao dịch trải trên ~100 ngày, cuộn
      // xuống thì danh sách chỉ còn các header ngày xếp chồng, mất sạch
      // dòng giao dịch. Nguyên nhân: mỗi ngày là một
      // `SliverPersistentHeader(pinned: true)` RIÊNG đặt tuần tự trong
      // `slivers` — chúng KHÔNG nhường chỗ cho nhau khi mỗi nhóm chỉ cao
      // bằng một dòng, nên tích lại và nuốt hết viewport.
      final categoryId = await firstCategoryId();
      final walletId = await firstWalletId();
      for (var i = 0; i < 40; i++) {
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                amountMinor: -10000 - i,
                currency: 'VND',
                currencyScale: 0,
                occurredAt: DateTime(2026, 8, 20).subtract(Duration(days: i)),
                walletId: walletId,
                categoryId: Value(categoryId),
                note: Value('khoan $i'),
              ),
            );
      }

      await pumpApp(
        tester,
        db: db,
        child: const TransactionsScreen(),
        extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
      );
      await tester.pumpAndSettle();

      final list = find.byType(CustomScrollView);
      for (var i = 0; i < 12; i++) {
        await tester.drag(list, const Offset(0, -400));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Sau khi cuộn sâu, trên màn PHẢI còn dòng giao dịch thật (ghi chú),
      // không chỉ toàn header ngày.
      expect(
        find.textContaining('khoan '),
        findsWidgets,
        reason: 'cuộn xuống mà chỉ còn header ngày là bug',
      );
    },
  );
}
