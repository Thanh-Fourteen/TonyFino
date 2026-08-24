import 'staged_transaction.dart';

/// Đối chiếu tháng — CHỈ tính từ dòng `Expense`/`Income`, loại `Savings` hoàn
/// toàn. Đây đúng là cách oracle Phase 2 (`docs/rolly-schema.md`) tự định
/// nghĩa hai cột "Expense"/"Income" của nó — không gộp Savings.
class MonthReconciliation {
  const MonthReconciliation({
    required this.yearMonth,
    required this.transactionCount,
    required this.expenseMinor,
    required this.incomeMinor,
  });

  /// `'YYYY-MM'`.
  final String yearMonth;
  final int transactionCount;

  /// ≤0 — tổng `amountMinor` của mọi dòng Expense trong tháng.
  final int expenseMinor;

  /// ≥0 — tổng `amountMinor` của mọi dòng Income trong tháng.
  final int incomeMinor;
}

/// Báo cáo đối chiếu đầy đủ — sinh trực tiếp từ dữ liệu ĐÃ PARSE (không phải
/// đọc lại từ DB sau khi commit), vì DB không giữ lại "dòng này gốc là
/// Expense/Income/Savings" sau khi import — chỉ giữ dấu + categoryId. Tính
/// TRƯỚC khi mất thông tin đó là cách duy nhất tái tạo đúng định nghĩa oracle.
class RollyReconciliationReport {
  const RollyReconciliationReport({
    required this.months,
    required this.totalTransactionCount,
    required this.totalExpenseMinor,
    required this.totalIncomeMinor,
    required this.savingsTransferCount,
  });

  final List<MonthReconciliation> months;
  final int totalTransactionCount;
  final int totalExpenseMinor;
  final int totalIncomeMinor;

  /// Số dòng Savings ĐÃ KHỬ TRÙNG LẶP (một mỗi cặp transfer) — hiển thị
  /// riêng, KHÔNG cộng vào tổng Chi/Thu ở trên.
  final int savingsTransferCount;
}

RollyReconciliationReport computeRollyReconciliation(
  List<StagedRollyTransaction> rows,
) {
  final byMonth = <String, ({int count, int expense, int income})>{};
  var savingsCount = 0;

  for (final row in rows) {
    if (row.sourceType == RollySourceType.savingsTransfer) {
      savingsCount++;
      continue;
    }
    final ym =
        '${row.occurredAt.year.toString().padLeft(4, '0')}-'
        '${row.occurredAt.month.toString().padLeft(2, '0')}';
    final prev = byMonth[ym] ?? (count: 0, expense: 0, income: 0);
    byMonth[ym] = (
      count: prev.count + 1,
      expense: prev.expense + (row.amountMinor < 0 ? row.amountMinor : 0),
      income: prev.income + (row.amountMinor > 0 ? row.amountMinor : 0),
    );
  }

  final months =
      byMonth.entries
          .map(
            (e) => MonthReconciliation(
              yearMonth: e.key,
              transactionCount: e.value.count,
              expenseMinor: e.value.expense,
              incomeMinor: e.value.income,
            ),
          )
          .toList()
        ..sort((a, b) => a.yearMonth.compareTo(b.yearMonth));

  return RollyReconciliationReport(
    months: months,
    totalTransactionCount: months.fold(0, (sum, m) => sum + m.transactionCount),
    totalExpenseMinor: months.fold(0, (sum, m) => sum + m.expenseMinor),
    totalIncomeMinor: months.fold(0, (sum, m) => sum + m.incomeMinor),
    savingsTransferCount: savingsCount,
  );
}
