import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/reports_repository.dart';
import 'package:tonyfino/features/reports/domain/category_slice.dart';
import 'package:tonyfino/features/reports/domain/report_range.dart';

import '../../support/open_test_database.dart';

/// Chế độ "gom theo thẻ" của biểu đồ tròn: khoản CÓ thẻ gom theo thẻ, khoản
/// KHÔNG thẻ vẫn theo danh mục — và hai nửa cộng lại phải đúng bằng tổng chi.
void main() {
  late AppDatabase db;
  late ReportsRepository repo;
  late int walletId;
  late int anUong;
  late int diChuyen;
  final range = ReportRange(start: DateTime(2026, 9), end: DateTime(2026, 10));

  setUp(() async {
    db = openTestDatabase();
    repo = ReportsRepository(db);
    walletId = await defaultWalletId(db);
    final cats = await db.select(db.categories).get();
    anUong = cats.firstWhere((c) => c.name == 'Ăn uống').id;
    diChuyen = cats.firstWhere((c) => c.name == 'Di chuyển').id;
  });
  tearDown(() => db.close());

  Future<int> tx(int amount, int? categoryId, {int? goalId, int day = 5}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          amountMinor: amount,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: DateTime(2026, 9, day),
          walletId: walletId,
          categoryId: Value(categoryId),
          goalId: Value(goalId),
        ),
      );
  Future<int> tag(String name, int color) => db
      .into(db.tags)
      .insert(TagsCompanion.insert(name: name, categoryColorId: color));
  Future<void> link(int txId, int tagId) => db
      .into(db.transactionTags)
      .insert(
        TransactionTagsCompanion.insert(transactionId: txId, tagId: tagId),
      );

  test('gộp theo TỔ HỢP thẻ; hai nửa cộng lại đúng tổng chi', () async {
    final duLich = await tag('Du lịch', 2);
    final giaDinh = await tag('Gia đình', 5);

    final a = await tx(-300000, anUong);
    await link(a, duLich);
    final b = await tx(-200000, diChuyen);
    await link(b, duLich);
    // Gắn HAI thẻ — phải thành nhóm riêng, không cộng vào cả hai.
    final c = await tx(-1000000, anUong);
    await link(c, duLich);
    await link(c, giaDinh);
    await tx(-50000, anUong); // không thẻ
    await tx(-70000, diChuyen); // không thẻ
    // Không tính: thu nhập, nạp quỹ, ngoài kỳ.
    final income = await tx(5000000, null);
    await link(income, duLich);
    final goalId = await db
        .into(db.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            name: 'Quỹ',
            targetAmountMinor: 1,
            currency: 'VND',
            currencyScale: 0,
          ),
        );
    final deposit = await tx(-900000, null, goalId: goalId);
    await link(deposit, duLich);
    final old = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: -400000,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: DateTime(2026, 8, 31),
            walletId: walletId,
          ),
        );
    await link(old, duLich);

    final groups = await repo.watchTagGroupBreakdown(range).first;
    final byKey = {for (final g in groups) g.tagIds.join(','): g.amountMinor};
    expect(byKey, {'$duLich': -500000, '$duLich,$giaDinh': -1000000});

    final untagged = await repo
        .watchCategoryBreakdown(range, untaggedOnly: true)
        .first;
    final untaggedTotal = untagged.fold(0, (s, r) => s + r.amountMinor);
    expect(untaggedTotal, -120000);

    final all = await repo.watchCategoryBreakdown(range).first;
    final allTotal = all.fold(0, (s, r) => s + r.amountMinor);
    final tagTotal = groups.fold(0, (s, g) => s + g.amountMinor);
    expect(tagTotal + untaggedTotal, allTotal);
  });

  test('gắn thẻ mới thì stream nhóm thẻ phát lại ngay', () async {
    final t = await tag('Công tác', 1);
    final id = await tx(-100000, anUong);
    final stream = repo.watchTagGroupBreakdown(range);
    final second = stream.skip(1).first;
    await link(id, t);
    final groups = await second.timeout(const Duration(seconds: 5));
    expect(groups.single.tagIds, [t]);
  });

  test('buildTagModeSources: nhãn "#A + #B", màu của thẻ đầu, nửa danh mục '
      'giữ nguyên', () {
    final sources = buildTagModeSources(
      untaggedRootSources: const [
        CategorySourceAmount(
          categoryId: 1,
          label: 'Ăn uống',
          categoryColorId: 0,
          iconCode: 'restaurant',
          amountMinor: -50000,
        ),
      ],
      tagGroups: const [
        TagGroupAmount(tagIds: [3, 7], amountMinor: -1000000),
      ],
      tagsById: const {
        3: TagInfo(id: 3, name: 'Du lịch', colorId: 2),
        7: TagInfo(id: 7, name: 'Gia đình', colorId: 5),
      },
    );
    expect(sources, hasLength(2));
    expect(sources.first.label, '#Du lịch + #Gia đình');
    expect(sources.first.categoryColorId, 2);
    expect(sources.first.categoryId, isNull);
    expect(sources.first.tagIds, [3, 7]);
    expect(sources.last.tagIds, isNull);

    final slices = buildCategorySlices(sources);
    expect(slices.first.isTagGroup, isTrue);
    expect(slices.last.isTagGroup, isFalse);
  });
}
