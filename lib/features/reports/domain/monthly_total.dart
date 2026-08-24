const _monthLabels = [
  'Th1',
  'Th2',
  'Th3',
  'Th4',
  'Th5',
  'Th6',
  'Th7',
  'Th8',
  'Th9',
  'Th10',
  'Th11',
  'Th12',
];

/// Một tháng đã gộp SQL: `year`/`month` đọc qua
/// `occurredAt.modify(DateTimeModifier.localTime())` (xem
/// `reports_repository.dart`) — nếu không, ranh giới tháng lệch tới 7 tiếng
/// (UTC+7) và một giao dịch lúc 0h–6h59 ngày 1 sẽ bị tính nhầm sang tháng
/// trước, đúng loại "bug ngày/tháng" mà TODOS.md cảnh báo (xem docs/decisions.md).
class MonthlyTotal {
  const MonthlyTotal({
    required this.year,
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final int year;
  final int month;

  /// Luôn ≥ 0.
  final int incomeMinor;

  /// Luôn ≤ 0.
  final int expenseMinor;

  String get shortLabel => _monthLabels[month - 1];

  @override
  bool operator ==(Object other) =>
      other is MonthlyTotal &&
      other.year == year &&
      other.month == month &&
      other.incomeMinor == incomeMinor &&
      other.expenseMinor == expenseMinor;

  @override
  int get hashCode => Object.hash(year, month, incomeMinor, expenseMinor);
}
