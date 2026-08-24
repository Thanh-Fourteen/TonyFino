import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/reports_repository.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/features/reports/domain/report_range.dart';

import '../../support/open_test_database.dart';

void main() {
  late AppDatabase db;
  late ReportsRepository repo;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    repo = ReportsRepository(db);
    walletId = (await db.select(db.wallets).get()).first.id;
  });
  tearDown(() => db.close());

  Future<int> insert({
    required int amountMinor,
    required DateTime occurredAt,
    int? categoryId,
    bool isTransfer = false,
    int? goalId,
  }) {
    return db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            amountMinor: amountMinor,
            currency: 'VND',
            currencyScale: 0,
            occurredAt: occurredAt,
            walletId: walletId,
            categoryId: Value(categoryId),
            isTransfer: Value(isTransfer),
            goalId: Value(goalId),
          ),
        );
  }

  test(
    'watchCategoryBreakdown: gộp theo danh mục, CHỈ tính chi, join sẵn tên/màu/icon; '
    'chưa phân loại tách riêng với categoryColorId sentinel -1',
    () async {
      final category = (await db.select(db.categories).get()).first;
      await insert(
        amountMinor: -30000,
        occurredAt: DateTime(2026, 8, 10),
        categoryId: category.id,
      );
      await insert(
        amountMinor: -20000,
        occurredAt: DateTime(2026, 8, 11),
        categoryId: category.id,
      );
      await insert(
        amountMinor: 5000000,
        occurredAt: DateTime(2026, 8, 12),
        categoryId: category.id,
      ); // thu — pie chart không tính
      await insert(amountMinor: -15000, occurredAt: DateTime(2026, 8, 13));

      final result = await repo
          .watchCategoryBreakdown(
            ReportRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 9, 1)),
          )
          .first;

      expect(result, hasLength(2));
      final byLabel = {for (final r in result) r.label: r};
      expect(byLabel[category.name]!.amountMinor, -50000);
      expect(byLabel[category.name]!.categoryColorId, category.categoryColorId);
      expect(byLabel['Chưa phân loại']!.amountMinor, -15000);
      expect(byLabel['Chưa phân loại']!.categoryColorId, -1);
    },
  );

  test(
    'watchCategoryBreakdown: lọc theo categoryIds bỏ qua danh mục không được chọn',
    () async {
      final categories = await db.select(db.categories).get();
      final a = categories[0];
      final b = categories[1];
      await insert(
        amountMinor: -1000,
        occurredAt: DateTime(2026, 8, 1),
        categoryId: a.id,
      );
      await insert(
        amountMinor: -2000,
        occurredAt: DateTime(2026, 8, 1),
        categoryId: b.id,
      );

      final result = await repo
          .watchCategoryBreakdown(
            ReportRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 9, 1)),
            categoryIds: {a.id},
          )
          .first;

      expect(result, hasLength(1));
      expect(result.single.label, a.name);
    },
  );

  test(
    '🚨 watchMonthlyTrend: gộp theo THÁNG LỊCH VN (local), KHÔNG theo UTC — '
    'giao dịch 2h sáng giờ VN ngày 1 phải thuộc tháng ĐÓ, không rơi ngược về '
    'tháng trước như strftime mặc định (UTC) sẽ tính (xem docs/decisions.md § Phase 10)',
    () async {
      await insert(amountMinor: -10000, occurredAt: DateTime(2026, 1, 1, 2, 0));
      await insert(amountMinor: 2000000, occurredAt: DateTime(2026, 1, 15));

      final result = await repo
          .watchMonthlyTrend(
            ReportRange(
              start: DateTime(2025, 12, 1),
              end: DateTime(2026, 2, 1),
            ),
          )
          .first;

      expect(result, hasLength(1));
      expect(result.single.year, 2026);
      expect(result.single.month, 1);
      expect(result.single.expenseMinor, -10000);
      expect(result.single.incomeMinor, 2000000);
    },
  );

  test(
    'watchMonthlyTrend: nhiều tháng sắp theo thứ tự thời gian tăng dần',
    () async {
      await insert(amountMinor: -1000, occurredAt: DateTime(2026, 3, 5));
      await insert(amountMinor: -2000, occurredAt: DateTime(2026, 1, 5));
      await insert(amountMinor: -3000, occurredAt: DateTime(2026, 2, 5));

      final result = await repo
          .watchMonthlyTrend(
            ReportRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 4, 1)),
          )
          .first;

      expect(result.map((m) => m.month).toList(), [1, 2, 3]);
    },
  );

  test(
    'watchDailySpend: gộp theo NGÀY LỊCH VN, nhiều giao dịch cùng ngày cộng dồn',
    () async {
      await insert(amountMinor: -10000, occurredAt: DateTime(2026, 8, 21, 8));
      await insert(amountMinor: -25000, occurredAt: DateTime(2026, 8, 21, 20));
      await insert(amountMinor: -5000, occurredAt: DateTime(2026, 8, 22));

      final result = await repo
          .watchDailySpend(
            ReportRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 9, 1)),
          )
          .first;

      expect(result, hasLength(2));
      final byDate = {for (final r in result) r.date: r};
      expect(byDate[DateTime(2026, 8, 21)]!.expenseMinor, -35000);
      expect(byDate[DateTime(2026, 8, 22)]!.expenseMinor, -5000);
    },
  );

  test(
    'watchPeriodSummary: tổng thu/chi/số giao dịch trong khoảng, ngoài khoảng bị loại',
    () async {
      final category = (await db.select(db.categories).get()).first;
      await insert(
        amountMinor: -10000,
        occurredAt: DateTime(2026, 8, 5),
        categoryId: category.id,
      );
      await insert(
        amountMinor: 3000000,
        occurredAt: DateTime(2026, 8, 6),
        categoryId: category.id,
      );
      await insert(
        amountMinor: -99999,
        occurredAt: DateTime(2026, 7, 1),
        categoryId: category.id,
      );

      final summary = await repo
          .watchPeriodSummary(
            ReportRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 9, 1)),
          )
          .first;

      expect(summary.expenseMinor, -10000);
      expect(summary.incomeMinor, 3000000);
      expect(summary.transactionCount, 2);
    },
  );

  test(
    '🚨 Phase 13: chuyển khoản (isTransfer) bị loại khỏi CẢ 4 query — không thổi phồng thu/chi/breakdown',
    () async {
      final category = (await db.select(db.categories).get()).first;
      await insert(
        amountMinor: -30000,
        occurredAt: DateTime(2026, 8, 10),
        categoryId: category.id,
      );
      // Cặp chuyển khoản: cùng biên độ, dấu đối nhau — nếu KHÔNG bị lọc sẽ vẫn
      // cộng ròng về 0 ở watchPeriodSummary nhưng vẫn SAI ở breakdown/monthly
      // (mỗi vế cộng riêng vào chi/thu) và ở watchCategoryBreakdown (categoryId
      // null → gộp nhầm vào "chưa phân loại").
      await insert(
        amountMinor: -500000,
        occurredAt: DateTime(2026, 8, 12),
        isTransfer: true,
      );
      await insert(
        amountMinor: 500000,
        occurredAt: DateTime(2026, 8, 12),
        isTransfer: true,
      );

      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 9, 1),
      );

      final summary = await repo.watchPeriodSummary(range).first;
      expect(summary.expenseMinor, -30000);
      expect(summary.incomeMinor, 0);
      expect(summary.transactionCount, 1);

      final breakdown = await repo.watchCategoryBreakdown(range).first;
      expect(breakdown, hasLength(1));
      expect(breakdown.single.categoryId, category.id);

      final monthly = await repo.watchMonthlyTrend(range).first;
      expect(monthly.single.expenseMinor, -30000);
      expect(monthly.single.incomeMinor, 0);

      final daily = await repo.watchDailySpend(range).first;
      expect(daily.single.expenseMinor, -30000);
    },
  );

  test(
    '🚨 Phase 14: giao dịch TÁCH DÒNG — watchCategoryBreakdown gộp theo '
    'TỪNG DÒNG CON (không phải categoryId của giao dịch cha, đã null), và '
    'watchPeriodSummary đếm "1 giao dịch" dù có 2 dòng con (không đếm dòng)',
    () async {
      final categories = await db.select(db.categories).get();
      final catA = categories[0];
      final catB = categories[1];

      final txRepo = TransactionRepository(db);
      final splitResult = await txRepo.insert(
        amount: Money.vnd(-30000),
        occurredAt: DateTime(2026, 8, 10),
        walletId: walletId,
        lines: [
          TransactionLineInput(categoryId: catA.id, amountMinor: -10000),
          TransactionLineInput(categoryId: catB.id, amountMinor: -20000),
        ],
      );
      expect(splitResult.isOk, isTrue);

      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 9, 1),
      );

      final breakdown = await repo.watchCategoryBreakdown(range).first;
      final byId = {for (final b in breakdown) b.categoryId: b.amountMinor};
      expect(byId[catA.id], -10000);
      expect(byId[catB.id], -20000);

      final summary = await repo.watchPeriodSummary(range).first;
      expect(summary.expenseMinor, -30000);
      expect(summary.transactionCount, 1);
    },
  );

  test(
    '🚨 Phase 17: lọc theo tagIds — chỉ tính giao dịch gắn ÍT NHẤT MỘT thẻ trong tập chọn',
    () async {
      final categories = await db.select(db.categories).get();
      final catA = categories[0];

      final tagWorkId = await db
          .into(db.tags)
          .insert(TagsCompanion.insert(name: 'Công tác', categoryColorId: 0));
      final tagFamilyId = await db
          .into(db.tags)
          .insert(TagsCompanion.insert(name: 'Gia đình', categoryColorId: 1));

      final taggedWork = await insert(
        amountMinor: -10000,
        occurredAt: DateTime(2026, 8, 1),
        categoryId: catA.id,
      );
      final taggedFamily = await insert(
        amountMinor: -20000,
        occurredAt: DateTime(2026, 8, 2),
        categoryId: catA.id,
      );
      // Giao dịch gắn CẢ HAI thẻ — bài test "một trong hai" (isInQuery,
      // không JOIN) mà không nhân đôi số tiền của chính nó trong kết quả.
      final taggedBoth = await insert(
        amountMinor: -40000,
        occurredAt: DateTime(2026, 8, 3),
        categoryId: catA.id,
      );
      await insert(
        amountMinor: -99999,
        occurredAt: DateTime(2026, 8, 4),
        categoryId: catA.id,
      ); // không gắn thẻ nào — không được tính khi lọc theo thẻ

      await db
          .into(db.transactionTags)
          .insert(
            TransactionTagsCompanion.insert(
              transactionId: taggedWork,
              tagId: tagWorkId,
            ),
          );
      await db
          .into(db.transactionTags)
          .insert(
            TransactionTagsCompanion.insert(
              transactionId: taggedFamily,
              tagId: tagFamilyId,
            ),
          );
      await db
          .into(db.transactionTags)
          .insert(
            TransactionTagsCompanion.insert(
              transactionId: taggedBoth,
              tagId: tagWorkId,
            ),
          );
      await db
          .into(db.transactionTags)
          .insert(
            TransactionTagsCompanion.insert(
              transactionId: taggedBoth,
              tagId: tagFamilyId,
            ),
          );

      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 9, 1),
      );

      final summary = await repo
          .watchPeriodSummary(range, tagIds: {tagWorkId})
          .first;
      expect(
        summary.expenseMinor,
        -10000 + -40000,
        reason:
            'chỉ 2 giao dịch gắn thẻ Công tác, KHÔNG nhân đôi giao dịch gắn cả hai thẻ',
      );
      expect(summary.transactionCount, 2);

      final breakdown = await repo
          .watchCategoryBreakdown(range, tagIds: {tagFamilyId})
          .first;
      expect(breakdown.single.amountMinor, -20000 + -40000);
    },
  );

  test(
    '🚨 Phase 20: giao dịch gán vào danh mục CON ra một hàng RIÊNG, độc lập với hàng của danh mục CHA — '
    'nền tảng để rollupToRootCategories cộng đúng ở tầng Dart',
    () async {
      final parent = (await db.select(db.categories).get()).first;
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

      await insert(
        amountMinor: -500000,
        occurredAt: DateTime(2026, 8, 10),
        categoryId: parent.id,
      );
      await insert(
        amountMinor: -480000,
        occurredAt: DateTime(2026, 8, 11),
        categoryId: childId,
      );
      await insert(
        amountMinor: -268000,
        occurredAt: DateTime(2026, 8, 12),
        categoryId: childId,
      );

      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 9, 1),
      );
      final result = await repo.watchCategoryBreakdown(range).first;

      final parentRow = result.firstWhere((r) => r.categoryId == parent.id);
      final childRow = result.firstWhere((r) => r.categoryId == childId);
      // Hai hàng TÁCH BIỆT, mỗi hàng đúng tổng CỦA RIÊNG NÓ — không có gì
      // "tự cộng dồn" ở tầng SQL, đúng ý đồ để rollup xảy ra ở Dart.
      expect(parentRow.amountMinor, -500000);
      expect(childRow.amountMinor, -480000 + -268000);
    },
  );

  test(
    '🚨 tiền NẠP VÀO MỤC TIÊU TIẾT KIỆM không bị tính là chi tiêu',
    () async {
      // Bug thật trên sổ của Tony: báo cáo hiện "Chưa phân loại 46% =
      // 43.220.000₫" — đúng bằng số tiền đã gửi tiết kiệm CCTG. Nạp/rút
      // mục tiêu là CHUYỂN TIỀN giữa hai túi của chính mình, không phải
      // tiêu mất; chính báo cáo đối chiếu lúc import cũng tách riêng chúng.
      final db = openTestDatabase();
      addTearDown(db.close);
      final walletId = await defaultWalletId(db);
      final categoryId = (await db.select(db.categories).get()).first.id;

      final goalId = await db
          .into(db.savingsGoals)
          .insert(
            SavingsGoalsCompanion.insert(
              name: 'CCTG',
              targetAmountMinor: 30000000,
              currency: 'VND',
              currencyScale: 0,
            ),
          );

      Future<void> add(int amount, {int? goal, int? cat}) => db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: amount,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 10),
              walletId: walletId,
              categoryId: Value(cat),
              goalId: Value(goal),
            ),
          );

      await add(-200000, cat: categoryId); // chi thật
      await add(-43220000, goal: goalId); // nạp tiết kiệm — KHÔNG phải chi

      final repo = ReportsRepository(db);
      final range = ReportRange(
        start: DateTime(2026, 8),
        end: DateTime(2026, 9),
      );
      final summary = await repo.watchPeriodSummary(range).first;
      expect(
        summary.expenseMinor,
        -200000,
        reason: 'chỉ khoản chi thật, không gồm tiền chuyển vào tiết kiệm',
      );

      final breakdown = await repo.watchCategoryBreakdown(range).first;
      final total = breakdown.fold<int>(0, (s, b) => s + b.amountMinor);
      expect(
        total,
        -200000,
        reason: 'biểu đồ danh mục cũng không được cộng tiền tiết kiệm vào',
      );
    },
  );

  test('🚨 "Còn lại" TRỪ cả phần đã cất vào tiết kiệm — tiền đã chuyển vào mục '
      'tiêu thì không còn nằm trong ví để tiêu', () async {
    final goalId = await db
        .into(db.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            name: 'Quỹ dự phòng',
            targetAmountMinor: 50000000,
            currency: 'VND',
            currencyScale: 0,
          ),
        );

    await insert(amountMinor: 20000000, occurredAt: DateTime(2026, 5, 1));
    await insert(amountMinor: -3000000, occurredAt: DateTime(2026, 5, 10));
    // Cất 12 triệu vào mục tiêu.
    await insert(
      amountMinor: -12000000,
      occurredAt: DateTime(2026, 5, 11),
      goalId: goalId,
    );

    final summary = await repo
        .watchPeriodSummary(
          ReportRange(start: DateTime(2026, 5), end: DateTime(2026, 6)),
        )
        .first;

    // Thu/chi KHÔNG đổi: cất tiền không phải là tiêu tiền.
    expect(summary.incomeMinor, 20000000);
    expect(summary.expenseMinor, -3000000);
    // Nhưng phần cất đi phải hiện ra và bị trừ khỏi "còn lại".
    expect(summary.savingsMinor, -12000000);
    expect(summary.netMinor, 5000000);
    // Đếm giao dịch vẫn chỉ đếm thu/chi thật.
    expect(summary.transactionCount, 2);
  });

  test('rút tiền RA khỏi mục tiêu làm "còn lại" tăng lên', () async {
    final goalId = await db
        .into(db.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            name: 'Quỹ dự phòng',
            targetAmountMinor: 50000000,
            currency: 'VND',
            currencyScale: 0,
          ),
        );
    await insert(amountMinor: -1000000, occurredAt: DateTime(2026, 5, 10));
    await insert(
      amountMinor: 4000000,
      occurredAt: DateTime(2026, 5, 12),
      goalId: goalId,
    );

    final summary = await repo
        .watchPeriodSummary(
          ReportRange(start: DateTime(2026, 5), end: DateTime(2026, 6)),
        )
        .first;

    expect(summary.savingsMinor, 4000000);
    expect(summary.netMinor, 3000000);
  });
}
