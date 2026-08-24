// Widget test qua cây sản xuất thật (`CategoriesScreen`) — cùng kỷ luật
// `wallets_screen_test.dart`: thêm/sửa/gộp/lưu trữ qua sheet/dialog thật.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/categories/categories_screen.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpCategories(WidgetTester tester) async {
    await pumpApp(tester, db: db, child: const CategoriesScreen());
    await tester.pumpAndSettle();
  }

  testWidgets('hiện đủ danh mục seed, TÁCH nhóm chi và nhóm thu', (
    tester,
  ) async {
    await pumpCategories(tester);
    expect(find.text('Danh mục chi'), findsOneWidget);
    // "Danh mục thu" nằm dưới toàn bộ nhóm chi nên chưa được dựng ở khung
    // hình đầu — sliver chỉ dựng phần thấy được. Phải cuộn tới rồi mới kiểm.
    await tester.scrollUntilVisible(
      find.text('Danh mục thu'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Danh mục thu'), findsOneWidget);

    final categories = await db.select(db.categories).get();
    for (final category in categories) {
      // Danh sách giờ dài hơn (hai nhóm + tiêu đề) nên phần cuối nằm ngoài
      // màn hình test — phải cuộn tới, không thì test đỏ vì lý do bố cục
      // chứ không phải vì thiếu danh mục.
      await tester.scrollUntilVisible(
        find.text(category.name),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(category.name), findsOneWidget);
    }
  });

  testWidgets('thêm danh mục con — hiện lồng dưới danh mục cha đã chọn', (
    tester,
  ) async {
    await pumpCategories(tester);
    final parent = (await db.select(db.categories).get()).first;

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tên danh mục'),
      'Cà phê',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, parent.name));
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Cà phê'), findsOneWidget);
    final saved = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Cà phê'))).getSingle();
    expect(saved.parentCategoryId, parent.id);
  });

  testWidgets('lưu trữ danh mục — hiện trong "Đã lưu trữ", khôi phục được', (
    tester,
  ) async {
    await pumpCategories(tester);
    final categories = await db.select(db.categories).get();
    final target = categories.first;

    await tester.tap(find.byType(PopupMenuButton<void>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu trữ'));
    await tester.pumpAndSettle();

    // "Đã lưu trữ" nằm dưới 11 danh mục còn lại trong CÙNG một `ListView`
    // cuộn được — ngoài viewport 600px mặc định của test, phải cuộn tới mới
    // được build/tìm thấy (ListView không lazy-build phần chưa cuộn tới).
    await tester.scrollUntilVisible(
      find.text('Đã lưu trữ'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Đã lưu trữ'), findsOneWidget);

    await tester.tap(find.text('Khôi phục'));
    await tester.pumpAndSettle();

    final row = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(target.id))).getSingle();
    expect(row.isArchived, isFalse);
  });

  testWidgets(
    'gộp danh mục qua dialog — chuyển hết giao dịch, nguồn bị archive',
    (tester) async {
      final categories = await db.select(db.categories).get();
      final source = categories[0];
      final target = categories[1];
      final walletId = (await db.select(db.wallets).get()).first.id;
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -50000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 1),
              walletId: walletId,
              categoryId: Value(source.id),
            ),
          );

      await pumpCategories(tester);

      await tester.tap(find.byType(PopupMenuButton<void>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gộp vào danh mục khác'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(target.name).last);
      await tester.pumpAndSettle();

      final moved = await (db.select(
        db.transactions,
      )..where((t) => t.categoryId.equals(target.id))).get();
      expect(moved, hasLength(1));

      final sourceRow = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(source.id))).getSingle();
      expect(sourceRow.isArchived, isTrue);
    },
  );
}
