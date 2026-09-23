// Widget test qua CÂY SẢN XUẤT THẬT (không mock ReportsScreen) — cùng kiểu
// test đã bắt được 2 bug `ref.watch`-trong-`Notifier.build()` nghiêm trọng ở
// Phase 9 (`import_screen_test.dart`, `quick_add_screen_test.dart`); Phase 10
// không có `Notifier` giữ state tích luỹ nào (chỉ `ReportFilterController`,
// thuần UI state — xem `reports_providers.dart`) nhưng vẫn exercise đúng
// đường filter → provider → widget để bắt lỗi wiring tương tự nếu có.
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/reports/reports_screen.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

final _fixedClock = Clock.fixed(DateTime(2026, 8, 21, 20));

void main() {
  late AppDatabase db;
  late List<Category> categories;

  setUp(() async {
    db = openTestDatabase();
    categories = await db.select(db.categories).get();
    final walletId = (await db.select(db.wallets).get()).first.id;
    await db.batch((batch) {
      batch.insertAll(db.transactions, [
        TransactionsCompanion.insert(
          amountMinor: -300000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: DateTime(2026, 8, 10),
          walletId: walletId,
          categoryId: Value(categories[0].id),
        ),
        TransactionsCompanion.insert(
          amountMinor: -100000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: DateTime(2026, 7, 5),
          walletId: walletId,
          categoryId: Value(categories[1].id),
        ),
        TransactionsCompanion.insert(
          amountMinor: 15000000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: DateTime(2026, 8, 1),
          walletId: walletId,
          categoryId: Value(categories[0].id),
        ),
      ]);
    });
  });

  tearDown(() => db.close());

  Future<void> pumpReports(WidgetTester tester) async {
    await pumpApp(
      tester,
      db: db,
      child: const ReportsScreen(),
      extraOverrides: [clockProvider.overrideWithValue(_fixedClock)],
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'hiện tiêu đề, 2 ô thống kê đúng tổng thu/chi trong khoảng mặc định',
    (tester) async {
      await pumpReports(tester);

      // Tiêu đề màn nằm ở AppBar của `AppShell` (không dựng trong test này) —
      // màn tự nó KHÔNG lặp lại chữ "Báo cáo" nữa.
      expect(find.text('Báo cáo'), findsNothing);
      expect(find.text('Tổng chi'), findsOneWidget);
      expect(find.text('Tổng thu'), findsOneWidget);
      // -300.000 + -100.000 = -400.000 ₫ (cả 2 tháng đều trong preset mặc định
      // "6 tháng qua").
      expect(find.textContaining('400.000'), findsWidgets);
      expect(find.text(categories[0].name), findsOneWidget);
      expect(find.text(categories[1].name), findsOneWidget);
    },
  );

  testWidgets(
    'lọc theo danh mục: chọn 1 danh mục ẩn các danh mục còn lại khỏi legend',
    (tester) async {
      await pumpReports(tester);

      expect(find.text('Mọi danh mục'), findsOneWidget);
      await tester.tap(find.text('Mọi danh mục'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(categories[0].name).last);
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      expect(find.text('1 danh mục'), findsOneWidget);
      expect(find.text(categories[0].name), findsOneWidget);
      expect(find.text(categories[1].name), findsNothing);
    },
  );

  testWidgets('lọc theo khoảng ngày: đổi preset cập nhật nhãn chip', (
    tester,
  ) async {
    await pumpReports(tester);

    expect(find.text('6 tháng qua'), findsOneWidget);
    await tester.tap(find.text('6 tháng qua'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('7 ngày qua'));
    await tester.pumpAndSettle();

    expect(find.text('7 ngày qua'), findsOneWidget);
    // Giao dịch tháng 7 rơi ngoài "7 ngày qua" — danh mục của nó biến mất
    // khỏi legend (còn giao dịch categories[0] ngày 10/8 vẫn ngoài 7 ngày kể
    // từ 21/8 nên legend rỗng hoàn toàn — dùng để xác nhận filter THẬT SỰ
    // chạy lại query, không phải chỉ đổi nhãn).
    expect(find.text(categories[0].name), findsNothing);
    expect(find.text(categories[1].name), findsNothing);
  });

  testWidgets(
    '🚨 Phase 25: bấm vào danh mục ở Báo cáo → mở MÀN "Chi tiết danh mục" '
    '(không phải sheet), có breakdown con và % tính trên tổng CHA',
    (tester) async {
      final parent = categories[0];
      final childId = await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Ăn trưa thiết yếu',
              kind: parent.kind,
              categoryColorId: parent.categoryColorId,
              iconCode: parent.iconCode,
              parentCategoryId: Value(parent.id),
              walletId: parent.walletId,
            ),
          );
      final walletId = (await db.select(db.wallets).get()).first.id;
      // categories[0] đã có -300.000 (thẳng vào cha) từ setUp — thêm một
      // giao dịch NỮA vào con để cha THẬT SỰ có breakdown (>1 nguồn).
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -100000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 12),
              walletId: walletId,
              categoryId: Value(childId),
            ),
          );

      await pumpReports(tester);

      // Tổng cha lúc này: -300.000 (chính cha) + -100.000 (con) = -400.000.
      await tester.tap(find.text(parent.name));
      await tester.pumpAndSettle();

      // Neo vào phần CHỈ màn chi tiết mới có — chứng minh đã ĐẨY MÀN chứ
      // không mở sheet như trước Phase 25.
      expect(find.text('Theo danh mục con'), findsOneWidget);
      expect(find.text('Ăn trưa thiết yếu'), findsWidgets);
      // % trên tổng CHA (-400.000), không phải tổng toàn báo cáo (-500.000
      // gồm cả categories[1]) — con đóng góp 100.000/400.000 = 25%.
      expect(find.textContaining('25%'), findsOneWidget);
    },
  );

  testWidgets(
    '🚨 Phase 25: danh mục CHƯA có con vẫn bấm được — mọi lát bánh đều mở '
    'được màn chi tiết, không còn hàng "chết" im lặng',
    (tester) async {
      await pumpReports(tester);

      // categories[1] chỉ có đúng 1 nguồn (chính nó). Trước Phase 25 hàng
      // này KHÔNG bấm được — người dùng bấm mà không có gì xảy ra, không
      // cách nào biết là do thiết kế hay do lỗi.
      await tester.tap(find.text(categories[1].name));
      await tester.pumpAndSettle();

      // Đã rời màn Báo cáo, đang ở màn chi tiết của chính danh mục đó.
      expect(find.text('Tổng chi'), findsNothing);
      expect(find.text('Tổng cộng'), findsOneWidget);
      expect(find.text(categories[1].name), findsWidgets);
    },
  );

  testWidgets(
    '"Gom theo thẻ": chỉ hiện khi sổ có thẻ; bật lên thì khoản có thẻ '
    'thành lát "#thẻ", khoản không thẻ vẫn theo danh mục',
    (tester) async {
      await pumpReports(tester);
      expect(
        find.text('Gom theo thẻ'),
        findsNothing,
        reason: 'chưa có thẻ nào — bật lên cũng không đổi được gì',
      );

      final walletId = (await db.select(db.wallets).get()).first.id;
      final tagId = await db
          .into(db.tags)
          .insert(TagsCompanion.insert(name: 'Du lịch', categoryColorId: 2));
      final txId = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -250000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 12),
              walletId: walletId,
              categoryId: Value(categories[2].id),
            ),
          );
      await db
          .into(db.transactionTags)
          .insert(
            TransactionTagsCompanion.insert(transactionId: txId, tagId: tagId),
          );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Gom theo thẻ'),
        80,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('#Du lịch'), findsNothing);
      await tester.tap(find.text('Gom theo thẻ'));
      await tester.pumpAndSettle();

      expect(find.text('Theo thẻ & danh mục'), findsOneWidget);
      expect(find.text('#Du lịch'), findsOneWidget);
      // Danh mục của khoản ĐÃ gắn thẻ không còn là một lát riêng; hai danh mục
      // của khoản không thẻ vẫn còn.
      expect(find.text(categories[2].name), findsNothing);
      expect(find.text(categories[0].name), findsOneWidget);
    },
  );

  testWidgets('băng "TonyFino Wrapped" ở đầu tab, bấm vào mở đúng màn', (
    tester,
  ) async {
    await pumpReports(tester);

    expect(find.text('TonyFino Wrapped'), findsOneWidget);
    expect(find.text('Xem lại năm 2026 của bạn'), findsOneWidget);

    await tester.tap(find.text('TonyFino Wrapped'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Năm 2026'), findsOneWidget);
  });
}
