import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../features/budgets/domain/budget_period.dart';
import '../db/database.dart';

/// Số "An toàn để tiêu hôm nay" (kiểu PocketGuard "In My Pocket", Phase 15)
/// — MỘT con số TOÀN VÍ theo ngày, khác hẳn vòng nhịp TỪNG DANH MỤC của
/// Phase 11. Công thức đầy đủ + lý do từng quyết định kỹ thuật ở
/// docs/decisions.md § Phase 15 "Số 'An toàn để tiêu hôm nay'":
///
/// ```
/// netKỳNày = SUM(transactions.amount_minor) trong [kỳ.start, kỳ.end) — mọi
///            ví, KHÔNG lọc isTransfer (tổng TOÀN VÍ tự triệt tiêu cặp
///            chuyển khoản, giống watchBalance()).
/// sắpTới   = SUM(recurring_transactions.amount_minor) VỚI is_active và
///            next_occurrence_date TRONG [kỳ.start, kỳ.end) — CÓ DẤU (bill
///            âm trừ, thu định kỳ dương cộng, cùng một SUM không cần CASE).
/// an toàn hôm nay = (netKỳNày + sắpTới) / số ngày còn lại trong kỳ (≥ 1).
/// ```
///
/// Tính 100% bằng SQL (một `selectOnly` + hai `subqueryExpression` vô
/// hướng cho phần định kỳ) — KHÔNG lưu bộ đếm nào, D7.
class SafeToSpendRepository {
  SafeToSpendRepository(this._db);

  final AppDatabase _db;

  /// [now] LUÔN phải tới từ `Clock` được inject (LUẬT #3) — không bao giờ
  /// `DateTime.now()` trực tiếp ở đây. [now] xác định CẢ kỳ hiện tại (qua
  /// [anchorDay]) LẪN số ngày còn lại — cố ý tách khỏi `budgetPeriodProvider`
  /// (màn Ngân sách có thể đang xem một kỳ QUÁ KHỨ/TƯƠNG LAI qua nút
  /// trước/sau) vì "an toàn để tiêu HÔM NAY" chỉ có nghĩa cho kỳ hiện tại
  /// thật, không phải kỳ Tony đang lướt xem.
  Stream<Money> watchSafeToSpendToday(DateTime now, {int anchorDay = 1}) {
    final period = BudgetPeriod.of(now, anchorDay: anchorDay);
    final t = _db.transactions;
    final r = _db.recurringTransactions;

    final netExpr = t.amountMinor.sum();
    final recurringExpr = subqueryExpression<int>(
      _db.selectOnly(r)
        ..addColumns([r.amountMinor.sum()])
        ..where(
          r.isActive.equals(true) &
              r.nextOccurrenceDate.isBiggerOrEqualValue(period.start) &
              r.nextOccurrenceDate.isSmallerThanValue(period.end),
        ),
    );

    final query = _db.selectOnly(t)
      ..addColumns([netExpr, recurringExpr])
      ..where(
        t.occurredAt.isBiggerOrEqualValue(period.start) &
            t.occurredAt.isSmallerThanValue(period.end),
      );

    return query.watchSingle().map((row) {
      final net = row.read(netExpr) ?? 0;
      final recurring = row.read(recurringExpr) ?? 0;
      final today = DateTime(now.year, now.month, now.day);
      final daysRemaining = period.end.difference(today).inDays;
      final safeDaysRemaining = daysRemaining < 1 ? 1 : daysRemaining;
      final safeMinor = ((net + recurring) / safeDaysRemaining).round();
      return Money.vnd(safeMinor);
    });
  }
}
