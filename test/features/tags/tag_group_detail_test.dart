// Bấm lát nhóm thẻ ở biểu đồ tròn (Trang chủ/Báo cáo) → màn liệt kê đúng
// những giao dịch làm nên lát đó. Tony: "khi thống kê có tag ở trang chủ
// không nhấn vô để xem các giao dịch nào thuộc tag đó được".
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/reports/domain/category_slice.dart';
import 'package:tonyfino/features/reports/domain/report_range.dart';
import 'package:tonyfino/features/reports/widgets/category_pie_card.dart';
import 'package:tonyfino/features/tags/tag_group_detail_screen.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;
  late int walletId;
  final range = ReportRange(start: DateTime(2026, 9), end: DateTime(2026, 10));

  setUp(() async {
    installFakeSharedPreferences();
    db = openTestDatabase();
    walletId = await defaultWalletId(db);
  });
  tearDown(() => db.close());

  Future<int> tx(int amount, String note) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          amountMinor: amount,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: DateTime(2026, 9, 5),
          walletId: walletId,
          note: Value(note),
        ),
      );
  Future<int> tag(String name) => db
      .into(db.tags)
      .insert(TagsCompanion.insert(name: name, categoryColorId: 2));
  Future<void> link(int txId, int tagId) => db
      .into(db.transactionTags)
      .insert(
        TransactionTagsCompanion.insert(transactionId: txId, tagId: tagId),
      );

  test('lát nhóm thẻ CÓ handler chạm (trước đây trả null)', () {
    int? openedCategory;
    List<int>? openedTags;
    final handler = categorySliceTapHandler(
      slice: const CategorySlice(
        categoryId: null,
        label: '#Du lịch',
        categoryColorId: 2,
        iconCode: 'sell',
        amountMinor: -500000,
        isOther: false,
        tagIds: [7],
      ),
      openFullBreakdown: () {},
      openCategoryDetail: (id) => openedCategory = id,
      openTagGroupDetail: (ids) => openedTags = ids,
    );
    expect(handler, isNotNull);
    handler!();
    expect(openedTags, [7]);
    expect(openedCategory, isNull);
  });

  testWidgets('bấm lát "#Du lịch" → màn liệt kê đúng khoản mang ĐÚNG thẻ đó', (
    tester,
  ) async {
    final duLich = await tag('Du lịch');
    final giaDinh = await tag('Gia đình');
    final a = await tx(-300000, 'vé máy bay');
    await link(a, duLich);
    final b = await tx(-1000000, 'khách sạn cả nhà');
    await link(b, duLich);
    await link(b, giaDinh);
    await tx(-70000, 'không thẻ');

    final sources = [
      const CategorySourceAmount(
        categoryId: null,
        label: '#Du lịch',
        categoryColorId: 2,
        iconCode: 'sell',
        amountMinor: -300000,
        tagIds: [1],
      ),
    ];
    await pumpApp(
      tester,
      db: db,
      child: Scaffold(
        body: SingleChildScrollView(
          child: CategoryPieCard(
            slices: buildCategorySlices(sources),
            allSources: sources,
            range: range,
            rangeLabel: 'Tháng 9',
            groupByTag: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('#Du lịch'));
    await tester.pumpAndSettle();

    expect(find.byType(TagGroupDetailScreen), findsOneWidget);
    expect(find.text('vé máy bay'), findsOneWidget);
    // Khoản gắn HAI thẻ thuộc lát "#Du lịch + #Gia đình", không phải lát này.
    expect(find.text('khách sạn cả nhà'), findsNothing);
    expect(find.text('không thẻ'), findsNothing);
    expect(find.text('1 giao dịch'), findsOneWidget);
  });
}
