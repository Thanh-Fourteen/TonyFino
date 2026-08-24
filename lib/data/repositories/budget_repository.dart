import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../core/result/result.dart';
import '../../features/budgets/domain/budget_period.dart';
import '../../features/budgets/domain/budget_progress.dart';
import '../db/database.dart';
import 'effective_category_amounts.dart';

/// Trạng thái ngân sách LUÔN tính bằng SQL aggregate đối chiếu trực tiếp với
/// `transactions`, KHÔNG BAO GIỜ lưu cột `spentMinor`/bộ đếm nào — cùng lý
/// do D7 (số dư): không có cache thì không thể sai, đổi/xoá một giao dịch
/// cũ tự động phản ánh đúng ngay lần watch kế tiếp.
///
/// 🚨 `spentExpr` đọc qua `effectiveCategoryAmounts(_db)` (Phase 14), KHÔNG
/// phải `transactions.category_id` trực tiếp — một giao dịch bị tách dòng
/// đóng góp vào ngân sách của TỪNG danh mục dòng con của nó, không phải một
/// danh mục duy nhất của giao dịch cha (giờ đã `NULL`). Xem
/// docs/decisions.md § Phase 14 "Tách giao dịch: hai đường dữ liệu".
class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  /// Một dòng cho MỖI ngân sách đã đặt trong [period] — JOIN sẵn `categories`
  /// (tên/màu/icon) và gộp sẵn `SUM(amountMinor)` các giao dịch CHI của đúng
  /// danh mục đó trong đúng khoảng ngày của [period], tất cả trong MỘT query.
  /// Điều kiện lọc theo ngày nằm ở mệnh đề JOIN (không phải `WHERE` riêng)
  /// để LEFT JOIN vẫn giữ lại ngân sách chưa có giao dịch nào (spent = 0),
  /// không bị `WHERE` loại mất hàng đó.
  ///
  /// 🚨 Carry-in (Phase 15) đọc qua HAI `subqueryExpression` vô hướng tương
  /// quan theo `categoryId` — KHÔNG phải một JOIN thứ hai tới kỳ trước. JOIN
  /// thẳng `effectiveCategoryAmounts` của kỳ trước vào CÙNG câu lệnh đã JOIN
  /// kỳ đang xem rồi `groupBy([b.id])` một lần sẽ tạo tích Descartes nội bộ
  /// (N hàng khớp kỳ này × M hàng khớp kỳ trước nhân thành N×M hàng trong
  /// nhóm) mỗi khi một danh mục có nhiều giao dịch ở CẢ HAI kỳ — sai âm thầm
  /// cả hai SUM, không lỗi cú pháp nào báo. `subqueryExpression` luôn trả
  /// đúng MỘT giá trị/hàng, không thể fan-out ra ngoài — xem
  /// docs/decisions.md § Phase 15 "`effectiveCategoryAmounts` nhận thêm
  /// alias".
  Stream<List<BudgetProgress>> watchBudgetsForPeriod(BudgetPeriod period) {
    final b = _db.budgets;
    final c = _db.categories;
    final eff = effectiveCategoryAmounts(_db);
    final effCategoryId = eff.ref(_db.transactions.categoryId);
    final effAmount = eff.ref(_db.transactions.amountMinor);
    final effOccurredAt = eff.ref(_db.transactions.occurredAt);
    final effIsTransfer = eff.ref(_db.transactions.isTransfer);
    final spentExpr = effAmount.sum();

    final previous = period.previous;

    // Ngân sách GỐC của kỳ liền trước, CÙNG danh mục — `budgets` self-
    // correlated nên bảng trong subquery cần alias riêng (khác `b` ở ngoài),
    // không thì tham chiếu cột nhập nhằng.
    final prevBudgets = _db.alias(_db.budgets, 'prev_budgets_carry_in');
    final prevBudgetExpr = subqueryExpression<int>(
      _db.selectOnly(prevBudgets)
        ..addColumns([prevBudgets.amountMinor])
        ..where(
          prevBudgets.categoryId.equalsExp(b.categoryId) &
              prevBudgets.yearMonth.equals(previous.yearMonthKey),
        ),
    );

    // Đã chi THẬT của kỳ liền trước, cùng danh mục — alias riêng
    // (`effective_category_amounts_prev`) để không lẫn với `eff` ở trên dù
    // về lý thuyết SQL cho phép trùng tên ở hai phạm vi subquery lồng nhau
    // độc lập (một cái là JOIN ở tầng ngoài, một cái lồng trong scalar
    // subquery riêng).
    final effPrev = effectiveCategoryAmounts(
      _db,
      alias: 'effective_category_amounts_prev',
    );
    final effPrevCategoryId = effPrev.ref(_db.transactions.categoryId);
    final effPrevAmount = effPrev.ref(_db.transactions.amountMinor);
    final effPrevOccurredAt = effPrev.ref(_db.transactions.occurredAt);
    final effPrevIsTransfer = effPrev.ref(_db.transactions.isTransfer);
    final prevSpentExpr = subqueryExpression<int>(
      _db.selectOnly(effPrev)
        ..addColumns([effPrevAmount.sum()])
        ..where(
          effPrevCategoryId.equalsExp(b.categoryId) &
              effPrevOccurredAt.isBiggerOrEqualValue(previous.start) &
              effPrevOccurredAt.isSmallerThanValue(previous.end) &
              effPrevAmount.isSmallerThanValue(0) &
              effPrevIsTransfer.equals(false),
        ),
    );

    final query =
        _db.select(b).join([
            innerJoin(c, c.id.equalsExp(b.categoryId)),
            leftOuterJoin(
              eff,
              effCategoryId.equalsExp(b.categoryId) &
                  effOccurredAt.isBiggerOrEqualValue(period.start) &
                  effOccurredAt.isSmallerThanValue(period.end) &
                  effAmount.isSmallerThanValue(0) &
                  effIsTransfer.equals(false),
              useColumns: false,
            ),
          ])
          ..addColumns([spentExpr, prevBudgetExpr, prevSpentExpr])
          ..where(b.yearMonth.equals(period.yearMonthKey))
          ..groupBy([b.id])
          ..orderBy([OrderingTerm.asc(c.name)]);

    return query.watch().map(
      (rows) => rows.map((row) {
        final budget = row.readTable(b);
        final category = row.readTable(c);
        final prevBudgetAmount = row.read(prevBudgetExpr);
        final prevSpent = row.read(prevSpentExpr) ?? 0;
        // Bounded ĐÚNG MỘT kỳ: carryIn chỉ đọc ngân sách GỐC + chi tiêu THẬT
        // của kỳ liền trước, không bao giờ đọc carryIn của chính kỳ đó —
        // không có "kỳ trước-trước" nào tham gia công thức này.
        final carryInMinor = (budget.carryOver && prevBudgetAmount != null)
            ? prevBudgetAmount - prevSpent.abs()
            : 0;
        return BudgetProgress(
          budgetId: budget.id,
          categoryId: category.id,
          categoryName: category.name,
          categoryColorId: category.categoryColorId,
          iconCode: category.iconCode,
          budgetAmountMinor: budget.amountMinor,
          spentMinor: row.read(spentExpr) ?? 0,
          carryInMinor: carryInMinor,
          carryOverEnabled: budget.carryOver,
        );
      }).toList(),
    );
  }

  /// Đặt/sửa ngân sách của một danh mục trong một kỳ — kiểm tra hàng đã tồn
  /// tại (theo ràng buộc UNIQUE `(categoryId, yearMonth)`) rồi UPDATE, không
  /// thì INSERT. Không dùng `insertOrReplace` vì nó xoá-rồi-chèn-lại cả
  /// hàng, làm mất `id`/`createdAt` gốc một cách không cần thiết (cùng kiểu
  /// với `CategoryRepository.recordKeywordCorrection`).
  Future<Result<void, AppError>> upsertBudget({
    required int categoryId,
    required BudgetPeriod period,
    required Money amount,
    bool carryOver = false,
  }) async {
    try {
      final existing =
          await (_db.select(_db.budgets)..where(
                (row) =>
                    row.categoryId.equals(categoryId) &
                    row.yearMonth.equals(period.yearMonthKey),
              ))
              .getSingleOrNull();

      if (existing != null) {
        await (_db.update(
          _db.budgets,
        )..where((row) => row.id.equals(existing.id))).write(
          BudgetsCompanion(
            amountMinor: Value(amount.minorUnits),
            currency: Value(amount.currency),
            currencyScale: Value(amount.currencyScale),
            carryOver: Value(carryOver),
          ),
        );
      } else {
        await _db
            .into(_db.budgets)
            .insert(
              BudgetsCompanion.insert(
                categoryId: categoryId,
                yearMonth: period.yearMonthKey,
                amountMinor: amount.minorUnits,
                currency: amount.currency,
                currencyScale: amount.currencyScale,
                carryOver: Value(carryOver),
              ),
            );
      }
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không lưu được ngân sách.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  Future<Result<void, AppError>> deleteBudget(int budgetId) async {
    try {
      await (_db.delete(
        _db.budgets,
      )..where((row) => row.id.equals(budgetId))).go();
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không xoá được ngân sách.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  Future<void> _logError(AppError error) async {
    await _db
        .into(_db.appEvents)
        .insert(
          AppEventsCompanion.insert(
            level: 'error',
            message: error.message,
            contextJson: Value(error.cause?.toString()),
          ),
        );
  }
}
