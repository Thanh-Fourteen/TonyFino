/// Tần suất giao dịch định kỳ (Phase 12). Lưu dạng TEXT trong DB
/// (`recurring_transactions.frequency`) — cùng quy ước TEXT-enum với
/// `categories.kind`, validate ở tầng domain này chứ không phải CHECK
/// constraint trong DB.
enum RecurringFrequency {
  daily('daily', 'Hàng ngày'),
  weekly('weekly', 'Hàng tuần'),
  monthly('monthly', 'Hàng tháng'),
  yearly('yearly', 'Hàng năm');

  const RecurringFrequency(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static RecurringFrequency fromDbValue(String value) =>
      RecurringFrequency.values.firstWhere(
        (f) => f.dbValue == value,
        orElse: () => throw ArgumentError('Tần suất không hợp lệ: $value'),
      );
}

/// Ngày trong tháng [month]/[year] — mẹo "ngày 0 của tháng sau" (đã dùng ở
/// `BudgetPeriod.daysInMonth`, Phase 11).
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Kỳ tới của [current] theo [frequency]. Với tháng/năm: KẸP về ngày cuối
/// tháng đích thay vì để `DateTime` tự tràn sang tháng sau — ví dụ 31/1 hàng
/// tháng thì kỳ tới của tháng 2 phải là 28/2 (hoặc 29/2 năm nhuận), KHÔNG
/// phải 3/3 (hành vi mặc định nếu gọi thẳng `DateTime(year, month + 1, 31)`,
/// vì `DateTime` coi ngày tràn là "tiến thêm vào tháng sau" chứ không kẹp).
/// Giữ nguyên giờ/phút/giây của [current] — kỳ tới xảy ra cùng thời điểm
/// trong ngày, chỉ đổi ngày/tháng/năm.
DateTime computeNextOccurrence(DateTime current, RecurringFrequency frequency) {
  switch (frequency) {
    case RecurringFrequency.daily:
      return current.add(const Duration(days: 1));
    case RecurringFrequency.weekly:
      return current.add(const Duration(days: 7));
    case RecurringFrequency.monthly:
      final targetYear = current.year + (current.month == 12 ? 1 : 0);
      final targetMonth = current.month == 12 ? 1 : current.month + 1;
      final day = current.day.clamp(1, _daysInMonth(targetYear, targetMonth));
      return DateTime(
        targetYear,
        targetMonth,
        day,
        current.hour,
        current.minute,
        current.second,
      );
    case RecurringFrequency.yearly:
      final targetYear = current.year + 1;
      final day = current.day.clamp(1, _daysInMonth(targetYear, current.month));
      return DateTime(
        targetYear,
        current.month,
        day,
        current.hour,
        current.minute,
        current.second,
      );
  }
}
