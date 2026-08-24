// Widget test qua CÂY SẢN XUẤT THẬT — cùng kỷ luật đã bắt được 2 bug
// `ref.watch`-trong-`Notifier.build()` nghiêm trọng ở Phase 9. Phase 11 chỉ
// có `BudgetPeriodController`, thuần UI state (không watch stream trong
// `build()`, xem `budgets_providers.dart`) nhưng vẫn exercise đúng đường
// filter tháng → provider → SQL → widget để bắt lỗi wiring tương tự nếu có.
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/budgets/budgets_screen.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

final _fixedClock = Clock.fixed(DateTime(2026, 8, 21, 20));

void main() {
  late AppDatabase db;
  late List<Category> categories;

  setUp(() async {
    // Phase 15: `BudgetPeriodController` giờ đọc `appSettingsProvider`
    // (`budgetAnchorDay`) trong `build()` — cần fake SharedPreferences
    // platform trước, xem doc comment `installFakeSharedPreferences`.
    installFakeSharedPreferences();
    db = openTestDatabase();
    categories = await db.select(db.categories).get();
  });
  tearDown(() => db.close());

  Future<void> pumpBudgets(WidgetTester tester) async {
    await pumpApp(
      tester,
      db: db,
      child: const BudgetsScreen(),
      extraOverrides: [clockProvider.overrideWithValue(_fixedClock)],
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'hiện tháng hiện tại, danh mục có ngân sách và danh mục chưa có ngân sách',
    (tester) async {
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              categoryId: categories[0].id,
              yearMonth: '2026-08',
              amountMinor: 1000000,
              currency: 'VND',
              currencyScale: 0,
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -300000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 10),
              walletId: (await db.select(db.wallets).get()).first.id,
              categoryId: Value(categories[0].id),
            ),
          );

      await pumpBudgets(tester);

      // Tiêu đề màn do AppBar của `AppShell` hiện (không dựng trong test này)
      // — màn tự nó không lặp lại chữ "Ngân sách" nữa.
      expect(find.text('Ngân sách'), findsNothing);
      expect(find.text('Tháng 8 2026'), findsOneWidget);
      expect(find.text(categories[0].name), findsOneWidget);
      expect(find.textContaining('300.000'), findsWidgets);
      expect(find.text('Chưa có ngân sách'), findsOneWidget);
      // Danh mục thứ hai chưa có ngân sách tháng này — phải xuất hiện trong
      // danh sách "chưa có" thay vì bị lặng lẽ bỏ qua.
      expect(find.text(categories[1].name), findsOneWidget);
    },
  );

  testWidgets(
    'chuyển sang tháng trước không xoá dữ liệu tháng hiện tại, chỉ đổi kỳ đang xem',
    (tester) async {
      await pumpBudgets(tester);

      expect(find.text('Tháng 8 2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();
      expect(find.text('Tháng 7 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Tháng sau'));
      await tester.pumpAndSettle();
      expect(find.text('Tháng 8 2026'), findsOneWidget);
    },
  );

  testWidgets(
    'đặt ngân sách mới cho danh mục qua sheet — hiện ngay trên màn không cần khởi động lại',
    (tester) async {
      await pumpBudgets(tester);

      await tester.tap(find.text(categories[0].name));
      await tester.pumpAndSettle();

      expect(find.text('Ngân sách tháng'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '2000000');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      // Ngân sách mới hiện NGAY trên màn (StreamProvider tự phát lại, không
      // cần điều hướng lại) — 11 danh mục chi còn lại vẫn chưa có ngân sách
      // nên mục "Chưa có ngân sách" vẫn còn, chỉ categories[0] rời khỏi đó.
      expect(find.textContaining('2.000.000'), findsWidgets);
    },
  );

  testWidgets(
    '🚨 Phase 15: bật "Cộng dồn từ kỳ trước" khi đặt ngân sách → lưu đúng cờ, mở lại sheet vẫn hiện đã bật',
    (tester) async {
      await pumpBudgets(tester);

      await tester.tap(find.text(categories[0].name));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1000000');
      await tester.tap(find.text('Cộng dồn từ kỳ trước'));
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      final saved = await (db.select(
        db.budgets,
      )..where((b) => b.categoryId.equals(categories[0].id))).getSingle();
      expect(saved.carryOver, isTrue);

      // Mở lại sheet — toggle phải hiện ĐÚNG trạng thái đã lưu (không reset
      // về mặc định tắt), xác nhận `existingCarryOver` được truyền đúng từ
      // `BudgetProgress.carryOverEnabled`.
      await tester.tap(find.text(categories[0].name));
      await tester.pumpAndSettle();
      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isTrue);
    },
  );

  testWidgets(
    '🚨 Phase 15: số "An toàn để tiêu hôm nay" hiện ở đầu màn, tính đúng từ giao dịch trong kỳ',
    (tester) async {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: 3100000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 1),
              walletId: (await db.select(db.wallets).get()).first.id,
              categoryId: Value(categories[0].id),
            ),
          );

      await pumpBudgets(tester);

      expect(find.text('An toàn để tiêu hôm nay'), findsOneWidget);
      // "Hôm nay" (clock đóng băng) = 21/8 → kỳ tháng 8 kết thúc 1/9 → còn 11
      // ngày. 3.100.000 / 11 = 281.818,18… → làm tròn 281.818.
      expect(find.textContaining('281.818'), findsOneWidget);
    },
  );

  testWidgets(
    '🚨 danh sách "Chưa có ngân sách" xếp HAI CẤP: con nằm ngay dưới cha và '
    'thụt vào, không đổ phẳng theo thứ tự bảng',
    (tester) async {
      final parent = categories.firstWhere(
        (c) => c.parentCategoryId == null && c.kind == 'expense',
      );
      final other = categories.firstWhere(
        (c) =>
            c.parentCategoryId == null &&
            c.kind == 'expense' &&
            c.id != parent.id,
      );
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Con của ${parent.name}',
              kind: 'expense',
              categoryColorId: parent.categoryColorId,
              iconCode: parent.iconCode,
              parentCategoryId: Value(parent.id),
              walletId: parent.walletId,
            ),
          );

      await pumpBudgets(tester);

      // Thứ tự dựng: cha → con của nó → danh mục gốc kế tiếp. Kiểm bằng toạ
      // độ Y thật, không phải bằng thứ tự trong danh sách nguồn.
      final parentY = tester.getTopLeft(find.text(parent.name)).dy;
      final childY = tester.getTopLeft(find.text('Con của ${parent.name}')).dy;
      final otherY = tester.getTopLeft(find.text(other.name)).dy;
      expect(childY, greaterThan(parentY), reason: 'con phải nằm DƯỚI cha');
      expect(
        otherY,
        greaterThan(childY),
        reason: 'danh mục gốc kế tiếp phải nằm sau hết con của cha trước',
      );

      // Con THỤT VÀO so với cha — dấu hiệu thị giác của cấp hai.
      expect(
        tester.getTopLeft(find.text('Con của ${parent.name}')).dx,
        greaterThan(tester.getTopLeft(find.text(parent.name)).dx),
      );
    },
  );
}
