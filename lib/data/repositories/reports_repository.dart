import 'package:drift/drift.dart';

import '../../features/reports/domain/category_slice.dart';
import '../../features/reports/domain/daily_spend.dart';
import '../../features/reports/domain/monthly_total.dart';
import '../../features/reports/domain/report_range.dart';
import '../db/database.dart';
import 'effective_category_amounts.dart';

/// Mọi phép gộp ở đây chạy TRONG SQL (`groupBy` + `sum`/`FILTER`), KHÔNG bao
/// giờ kéo toàn bộ `transactions` về Dart rồi lặp (Luật hiệu năng Phase 10 —
/// khác `TransactionRepository.watchMonthToDateSummary`, vốn được PHÉP lặp
/// Dart vì đã lọc sẵn xuống một tháng nên khối lượng luôn nhỏ; báo cáo thì
/// không có giới hạn đó, có thể quét "Tất cả" nhiều năm dữ liệu).
///
/// 🚨 CẠM BẪY MÚI GIỜ đã xác minh trực tiếp trong mã nguồn `drift` (không
/// đoán): `Expression<DateTime>.year`/`.month`/`.day` mặc định trả kết quả
/// theo **UTC** dù giá trị lưu là local — một giao dịch lúc 2h sáng giờ VN
/// (UTC+7) ngày 1 đầu tháng sẽ bị strftime tính thành 19h ngày cuối tháng
/// TRƯỚC theo UTC, gộp nhầm tháng. Bắt buộc `.modify(DateTimeModifier.localTime())`
/// trước khi trích năm/tháng/ngày — xem `docs/decisions.md` § Phase 10.
///
/// 🚨 Mọi gộp theo DANH MỤC (4 method dưới đây) đọc qua
/// `effectiveCategoryAmounts(_db)` (Phase 14), KHÔNG phải
/// `transactions.category_id`/`amount_minor` trực tiếp — giao dịch bị tách
/// dòng phải gộp theo `transaction_lines.category_id` của từng dòng con, xem
/// docs/decisions.md § Phase 14 "Tách giao dịch: hai đường dữ liệu".
class ReportsRepository {
  ReportsRepository(this._db);

  final AppDatabase _db;

  /// Tổng chi theo danh mục trong [range], CHỈ chi (`amountMinor < 0`) — pie
  /// chart là biểu đồ chi tiêu, không trộn thu vào cùng lát. Trả về đã JOIN
  /// sẵn `categories` (tên/màu/icon) trong MỘT query, category `null` gộp
  /// riêng thành một hàng "chưa phân loại" (tự nhiên qua `groupBy(categoryId)`
  /// coi mọi `NULL` là cùng một nhóm).
  Stream<List<CategorySourceAmount>> watchCategoryBreakdown(
    ReportRange range, {
    Set<int>? categoryIds,
    Set<int>? tagIds,
  }) {
    final c = _db.categories;
    final eff = effectiveCategoryAmounts(_db);
    final effCategoryId = eff.ref(_db.transactions.categoryId);
    final effTransactionId = eff.ref(_db.transactions.id);
    final effAmount = eff.ref(_db.transactions.amountMinor);
    final effOccurredAt = eff.ref(_db.transactions.occurredAt);
    final effIsTransfer = eff.ref(_db.transactions.isTransfer);
    final effGoalId = eff.ref(_db.transactions.goalId);
    final sumExpr = effAmount.sum();

    var predicate =
        effOccurredAt.isBiggerOrEqualValue(range.start) &
        effOccurredAt.isSmallerThanValue(range.end) &
        effAmount.isSmallerThanValue(0) &
        effIsTransfer.equals(false) &
        effGoalId.isNull();
    if (categoryIds != null) {
      predicate = predicate & effCategoryId.isIn(categoryIds);
    }
    if (tagIds != null) {
      predicate = predicate & _taggedWith(effTransactionId, tagIds);
    }

    // `useColumns: true` BẮT BUỘC ở đây — statement gốc là `selectOnly(eff)`
    // (không phải `select(eff)`, vốn không tồn tại cho `Subquery`), nên mặc
    // định KHÔNG tự động đưa cột của bảng JOIN vào kết quả (khác `select(t)`
    // ở các repository khác, luôn tự làm điều đó) — thiếu cờ này,
    // `row.readTableOrNull(c)` luôn trả `null` dù JOIN khớp đúng ở tầng SQL,
    // vì cột `categories.*` chưa từng có mặt trong SELECT list. Bắt được lỗi
    // này bằng cách in SQL thật ra, không phải đoán.
    final query =
        _db.selectOnly(eff).join([
            leftOuterJoin(c, c.id.equalsExp(effCategoryId), useColumns: true),
          ])
          ..addColumns([sumExpr, effCategoryId])
          ..where(predicate)
          ..groupBy([effCategoryId]);

    return query.watch().map(
      (rows) => rows.map((row) {
        final category = row.readTableOrNull(c);
        final total = row.read(sumExpr) ?? 0;
        return CategorySourceAmount(
          categoryId: category?.id,
          label: category?.name ?? 'Chưa phân loại',
          // -1: sentinel NGOÀI bảng 12 màu danh mục — "chưa phân loại" không
          // phải một danh mục thật, không được mượn màu của danh mục nào
          // (cùng lý do lát "Khác" ở `category_slice.dart` cũng dùng -1).
          categoryColorId: category?.categoryColorId ?? -1,
          iconCode: category?.iconCode ?? 'question_mark',
          amountMinor: total,
        );
      }).toList(),
    );
  }

  /// Thu/chi gộp theo THÁNG LỊCH VN trong [range] — nguồn cho đường xu hướng
  /// + cột thu-vs-chi. Một query duy nhất, hai cột `SUM(...) FILTER (WHERE ...)`
  /// (SQLite ≥ 3.30 — đã xác minh trực tiếp trên bản sqlite3mc bundle, xem
  /// docs/decisions.md), không phải hai query riêng hay lặp Dart.
  Stream<List<MonthlyTotal>> watchMonthlyTrend(ReportRange range) {
    final eff = effectiveCategoryAmounts(_db);
    final effAmount = eff.ref(_db.transactions.amountMinor);
    final effOccurredAt = eff.ref(_db.transactions.occurredAt);
    final effIsTransfer = eff.ref(_db.transactions.isTransfer);
    final effGoalId = eff.ref(_db.transactions.goalId);
    final localOccurred = effOccurredAt.modify(
      const DateTimeModifier.localTime(),
    );
    final yearExpr = localOccurred.year;
    final monthExpr = localOccurred.month;
    final incomeExpr = effAmount.sum(filter: effAmount.isBiggerThanValue(0));
    final expenseExpr = effAmount.sum(filter: effAmount.isSmallerThanValue(0));

    final query = _db.selectOnly(eff)
      ..addColumns([yearExpr, monthExpr, incomeExpr, expenseExpr])
      ..where(
        effOccurredAt.isBiggerOrEqualValue(range.start) &
            effOccurredAt.isSmallerThanValue(range.end) &
            effIsTransfer.equals(false) &
            effGoalId.isNull(),
      )
      ..groupBy([yearExpr, monthExpr])
      ..orderBy([OrderingTerm.asc(yearExpr), OrderingTerm.asc(monthExpr)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => MonthlyTotal(
              year: row.read(yearExpr)!,
              month: row.read(monthExpr)!,
              incomeMinor: row.read(incomeExpr) ?? 0,
              expenseMinor: row.read(expenseExpr) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Tổng chi gộp theo NGÀY LỊCH VN trong [range] — nguồn cho heatmap. Cùng
  /// cạm bẫy múi giờ như trên, dùng `.date` (định dạng `YYYY-MM-DD`) sau khi
  /// `.modify(localTime())` thay vì `.year`/`.month`/`.day` riêng lẻ vì cần
  /// gộp theo NGÀY, không phải theo phần năm/tháng/ngày tách rời.
  Stream<List<DailySpend>> watchDailySpend(
    ReportRange range, {
    Set<int>? categoryIds,
    Set<int>? tagIds,
  }) {
    final eff = effectiveCategoryAmounts(_db);
    final effCategoryId = eff.ref(_db.transactions.categoryId);
    final effTransactionId = eff.ref(_db.transactions.id);
    final effAmount = eff.ref(_db.transactions.amountMinor);
    final effOccurredAt = eff.ref(_db.transactions.occurredAt);
    final effIsTransfer = eff.ref(_db.transactions.isTransfer);
    final effGoalId = eff.ref(_db.transactions.goalId);
    final localDateExpr = effOccurredAt
        .modify(const DateTimeModifier.localTime())
        .date;
    final sumExpr = effAmount.sum();

    var predicate =
        effOccurredAt.isBiggerOrEqualValue(range.start) &
        effOccurredAt.isSmallerThanValue(range.end) &
        effAmount.isSmallerThanValue(0) &
        effIsTransfer.equals(false) &
        effGoalId.isNull();
    if (categoryIds != null) {
      predicate = predicate & effCategoryId.isIn(categoryIds);
    }
    if (tagIds != null) {
      predicate = predicate & _taggedWith(effTransactionId, tagIds);
    }

    final query = _db.selectOnly(eff)
      ..addColumns([localDateExpr, sumExpr])
      ..where(predicate)
      ..groupBy([localDateExpr]);

    return query.watch().map(
      (rows) => rows.map((row) {
        final dateText = row.read(localDateExpr)!; // 'YYYY-MM-DD'
        final parts = dateText.split('-');
        return DailySpend(
          date: DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          ),
          expenseMinor: row.read(sumExpr) ?? 0,
        );
      }).toList(),
    );
  }

  /// Tổng thu/chi/số giao dịch trong [range] — nguồn cho 2 ô thống kê đầu
  /// bento grid. `FILTER` cùng kỹ thuật với [watchMonthlyTrend].
  Stream<PeriodSummary> watchPeriodSummary(
    ReportRange range, {
    Set<int>? categoryIds,
    Set<int>? tagIds,
  }) {
    final eff = effectiveCategoryAmounts(_db);
    final effCategoryId = eff.ref(_db.transactions.categoryId);
    final effTransactionId = eff.ref(_db.transactions.id);
    final effAmount = eff.ref(_db.transactions.amountMinor);
    final effOccurredAt = eff.ref(_db.transactions.occurredAt);
    final effIsTransfer = eff.ref(_db.transactions.isTransfer);
    final effGoalId = eff.ref(_db.transactions.goalId);
    // Thu/chi CHỈ tính dòng KHÔNG gắn mục tiêu tiết kiệm; phần gắn mục tiêu
    // gom riêng vào [PeriodSummary.savingsMinor]. Trước đây `goalId IS NULL`
    // nằm ở `where` nên tiền chuyển vào tiết kiệm biến mất khỏi mọi con số —
    // "Còn lại" vì thế coi số tiền đã cất đi là vẫn còn tiêu được, đúng chỗ
    // Tony kêu "tôi có tiết kiệm nên phần dư chưa hợp lý".
    final incomeExpr = effAmount.sum(
      filter: effAmount.isBiggerThanValue(0) & effGoalId.isNull(),
    );
    final expenseExpr = effAmount.sum(
      filter: effAmount.isSmallerThanValue(0) & effGoalId.isNull(),
    );
    // ÂM = cất tiền vào mục tiêu; DƯƠNG = rút ra khỏi mục tiêu.
    final savingsExpr = effAmount.sum(filter: effGoalId.isNotNull());
    // `distinct: true` — một giao dịch tách N dòng sinh ra N hàng hiệu lực
    // (Phase 14), nhưng "N giao dịch" phải đếm GIAO DỊCH thật, không phải
    // dòng con, nên đếm distinct transactionId chứ không phải COUNT(*) thô.
    final countExpr = effTransactionId.count(
      distinct: true,
      filter: effGoalId.isNull(),
    );

    var predicate =
        effOccurredAt.isBiggerOrEqualValue(range.start) &
        effOccurredAt.isSmallerThanValue(range.end) &
        // KHÔNG lọc `goalId IS NULL` ở đây: dòng gắn mục tiêu tiết kiệm
        // phải LỌT vào truy vấn để `savingsExpr` cộng được. Việc tách
        // thu/chi khỏi tiết kiệm nằm ở `filter:` của từng SUM phía trên.
        effIsTransfer.equals(false);
    if (categoryIds != null) {
      predicate = predicate & effCategoryId.isIn(categoryIds);
    }
    if (tagIds != null) {
      predicate = predicate & _taggedWith(effTransactionId, tagIds);
    }

    final query = _db.selectOnly(eff)
      ..addColumns([incomeExpr, expenseExpr, savingsExpr, countExpr])
      ..where(predicate);

    return query.watchSingle().map(
      (row) => PeriodSummary(
        incomeMinor: row.read(incomeExpr) ?? 0,
        expenseMinor: row.read(expenseExpr) ?? 0,
        savingsMinor: row.read(savingsExpr) ?? 0,
        transactionCount: row.read(countExpr) ?? 0,
      ),
    );
  }

  /// Lọc theo thẻ (Phase 17) — "giao dịch này CÓ gắn ít nhất một thẻ trong
  /// [tagIds]" qua `transaction_id IN (SELECT ... FROM transaction_tags
  /// WHERE tag_id IN (...))`. Dùng `isInQuery` (subquery vô hướng theo hàng,
  /// cùng họ kỹ thuật với `isNotInQuery` ở `effectiveCategoryAmounts` —
  /// KHÔNG JOIN thẳng `transaction_tags` vào câu lệnh ngoài, vì một giao
  /// dịch gắn N thẻ sẽ nhân hàng N lần qua JOIN, làm sai mọi SUM/COUNT cùng
  /// lớp lỗi Cartesian đã tránh ở Phase 15 (`docs/decisions.md` § Phase 15
  /// "carry-over").
  Expression<bool> _taggedWith(
    Expression<int> effTransactionId,
    Set<int> tagIds,
  ) {
    return effTransactionId.isInQuery(
      _db.selectOnly(_db.transactionTags)
        ..addColumns([_db.transactionTags.transactionId])
        ..where(_db.transactionTags.tagId.isIn(tagIds)),
    );
  }
}

class PeriodSummary {
  const PeriodSummary({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.transactionCount,
    this.savingsMinor = 0,
  });

  final int incomeMinor;
  final int expenseMinor;
  final int transactionCount;

  /// Tiền ra/vào MỤC TIÊU TIẾT KIỆM trong kỳ. ÂM = đã cất đi, DƯƠNG = đã rút
  /// ra. KHÔNG nằm trong [expenseMinor] — cất tiền không phải là tiêu tiền,
  /// đó là lý do báo cáo loại nó khỏi phần chi ngay từ đầu.
  final int savingsMinor;

  /// Còn lại THẬT SỰ tiêu được: thu − chi − phần đã cất vào tiết kiệm.
  ///
  /// Bỏ vế tiết kiệm ra khỏi đây là nói dối một cách êm ái: tiền đã chuyển
  /// vào mục tiêu thì không còn nằm trong ví để tiêu nữa.
  int get netMinor => incomeMinor + expenseMinor + savingsMinor;
}
