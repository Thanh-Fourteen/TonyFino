import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/reports_repository.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/features/reports/domain/report_range.dart';

import '../../support/open_test_database.dart';

/// Bấm lát nhóm thẻ ở biểu đồ tròn → danh sách giao dịch. Danh sách phải là
/// ĐÚNG tổ hợp thẻ của lát (không phải "có thẻ này"), nếu không cộng lại ra
/// khác con số trên lát.
void main() {
  late AppDatabase db;
  late int walletId;
  final range = ReportRange(start: DateTime(2026, 9), end: DateTime(2026, 10));

  setUp(() async {
    db = openTestDatabase();
    walletId = await defaultWalletId(db);
  });
  tearDown(() => db.close());

  Future<int> tx(int amount, {int day = 5}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          amountMinor: amount,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: DateTime(2026, 9, day),
          walletId: walletId,
        ),
      );
  Future<int> tag(String name) => db
      .into(db.tags)
      .insert(TagsCompanion.insert(name: name, categoryColorId: 1));
  Future<void> link(int txId, int tagId) => db
      .into(db.transactionTags)
      .insert(
        TransactionTagsCompanion.insert(transactionId: txId, tagId: tagId),
      );

  test('exactTagIds: chỉ giao dịch có tập thẻ ĐÚNG BẰNG tập hỏi', () async {
    final duLich = await tag('Du lịch');
    final giaDinh = await tag('Gia đình');
    final chiDuLich = await tx(-300000);
    await link(chiDuLich, duLich);
    final caHai = await tx(-1000000);
    await link(caHai, duLich);
    await link(caHai, giaDinh);
    final chiGiaDinh = await tx(-50000);
    await link(chiGiaDinh, giaDinh);
    await tx(-70000); // không thẻ

    final repo = TransactionRepository(db);
    Future<Set<int>> ids(Set<int> exact) async => {
      for (final t in await repo.watchAllWithCategory(exactTagIds: exact).first)
        t.transaction.id,
    };

    expect(await ids({duLich}), {chiDuLich});
    expect(await ids({duLich, giaDinh}), {caHai});
    expect(await ids({giaDinh}), {chiGiaDinh});
  });

  test(
    'tổng danh sách (chi, trong kỳ, không quỹ) KHỚP con số trên lát',
    () async {
      final duLich = await tag('Du lịch');
      final a = await tx(-300000);
      await link(a, duLich);
      final b = await tx(-200000, day: 20);
      await link(b, duLich);
      final income = await tx(5000000);
      await link(income, duLich);

      final groups = await ReportsRepository(
        db,
      ).watchTagGroupBreakdown(range).first;
      final slice = groups.single;

      final listed = await TransactionRepository(db)
          .watchAllWithCategory(
            exactTagIds: slice.tagIds.toSet(),
            from: range.start,
            to: range.end,
            excludeGoalLinked: true,
          )
          .first;
      final total = listed
          .where(
            (t) => t.transaction.amountMinor < 0 && !t.transaction.isTransfer,
          )
          .fold<int>(0, (sum, t) => sum + t.transaction.amountMinor);
      expect(total, slice.amountMinor);
      expect(total, -500000);
    },
  );
}
