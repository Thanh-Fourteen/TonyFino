// Màn Chi tiết hũ: chỉ những giao dịch + danh mục THUỘC hũ, kể cả khi cùng
// một danh mục cha có con nằm ở hũ khác.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/jar_repository.dart';
import 'package:tonyfino/features/jars/jar_detail_screen.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  testWidgets('hũ tiêu: biểu đồ + danh sách chỉ gồm phần thuộc hũ; con tách '
      'sang hũ khác không lọt vào', (tester) async {
    final walletId = await defaultWalletId(db);
    final repo = JarRepository(db);
    await repo.seedDefaultJars(walletId);
    final jars = await db.select(db.jars).get();
    final thietYeu = jars.firstWhere((j) => j.name == 'Thiết yếu');
    final huongThu = jars.firstWhere((j) => j.name == 'Hưởng thụ');
    final cats = await db.select(db.categories).get();
    final anUong = cats.firstWhere(
      (c) => c.name == 'Ăn uống' && c.parentCategoryId == null,
    );
    final tieuVat = cats.firstWhere((c) => c.parentCategoryId == anUong.id);
    await repo.setCategoryJar(categoryId: anUong.id, jarId: thietYeu.id);
    await repo.setCategoryJar(categoryId: tieuVat.id, jarId: huongThu.id);

    final now = DateTime.now();
    Future<void> add(int amount, int? categoryId, String note) => db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: amount,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: DateTime(now.year, now.month, 2),
            walletId: walletId,
            categoryId: Value(categoryId),
            note: Value(note),
          ),
        );
    await add(10000000, null, 'lương');
    await add(-45000, anUong.id, 'cơm trưa');
    await add(-20000, tieuVat.id, 'trà đá');

    await pumpApp(
      tester,
      db: db,
      child: JarDetailScreen(jarId: thietYeu.id),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thiết yếu'), findsOneWidget);
    expect(find.text('Theo danh mục'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('cơm trưa'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('cơm trưa'), findsOneWidget);
    expect(
      find.text('trà đá'),
      findsNothing,
      reason: '"Tiêu vặt" đã tách sang hũ Hưởng thụ',
    );
  });

  testWidgets('hũ tiết kiệm: liệt kê các lần nạp quỹ, không có biểu đồ danh '
      'mục', (tester) async {
    final walletId = await defaultWalletId(db);
    final goalId = await db
        .into(db.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            name: 'Quỹ ngắn hạn',
            targetAmountMinor: 10000000,
            currency: 'VND',
            currencyScale: 0,
          ),
        );
    final jarId = (await JarRepository(db).insert(
      walletId: walletId,
      name: 'Gửi quỹ',
      percent: 10,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      goals: [JarGoalLink(goalId: goalId)],
    )).when(ok: (id) => id, err: (e) => throw e);
    final now = DateTime.now();
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: -100000,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: DateTime(now.year, now.month, 2),
            walletId: walletId,
            goalId: Value(goalId),
            note: const Value('gửi đợt 1'),
          ),
        );

    await pumpApp(
      tester,
      db: db,
      child: JarDetailScreen(jarId: jarId),
    );
    await tester.pumpAndSettle();

    expect(find.text('Theo danh mục'), findsNothing);
    // Ba ô đều nói về KỲ NÀY và về nhiệm vụ của hũ; tiền đang có trong quỹ
    // là dòng BỐI CẢNH dưới thanh — xem `JarProgress.used` (gross, đúng
    // chiều) và `savedTotal`. Kiểm phần TRÊN màn hình TRƯỚC khi cuộn xuống
    // — cuộn xuống để thấy danh sách giao dịch có thể đẩy phần này ra khỏi
    // viewport (`ListView` non-`.builder` cũng chỉ mount trong viewport +
    // cache extent, xem project_tonyfino_gotchas.md).
    expect(find.text('Hạn mức 10%'), findsOneWidget);
    expect(find.text('Đã nạp kỳ này'), findsOneWidget);
    expect(find.textContaining('1 quỹ trong hũ đang có'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('gửi đợt 1'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Các lần nạp/rút quỹ'), findsOneWidget);
    expect(find.text('gửi đợt 1'), findsOneWidget);
    // Dòng giao dịch đọc theo chiều QUỸ: nạp 100k hiện "+100.000", không
    // phải "−100.000" như chiều ví.
    expect(find.textContaining('+100.000'), findsWidgets);
  });

  testWidgets('hũ tiết kiệm 0%: ô thứ ba nói về ĐÍCH các quỹ, không phải mốc '
      'của kỳ', (tester) async {
    final walletId = await defaultWalletId(db);
    final goalId = await db
        .into(db.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            name: 'Khám bệnh',
            targetAmountMinor: 20000000,
            currency: 'VND',
            currencyScale: 0,
          ),
        );
    final jarId = (await JarRepository(db).insert(
      walletId: walletId,
      name: 'Sức khoẻ',
      percent: 0,
      categoryColorId: 4,
      iconCode: 'savings',
      kind: JarKind.saving,
      goals: [JarGoalLink(goalId: goalId)],
    )).when(ok: (id) => id, err: (e) => throw e);
    final now = DateTime.now();
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: -5000000,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: DateTime(now.year, now.month, 2),
            walletId: walletId,
            goalId: Value(goalId),
          ),
        );

    await pumpApp(
      tester,
      db: db,
      child: JarDetailScreen(jarId: jarId),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không lấy % thu'), findsOneWidget);
    expect(find.text('Còn thiếu'), findsOneWidget);
    expect(find.text('Đã đủ, dư'), findsNothing);
    // 20tr đích − 5tr đã có = 15tr.
    expect(find.textContaining('15.000.000'), findsWidgets);
  });
}
