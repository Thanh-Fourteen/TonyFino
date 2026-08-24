/// Chuỗi ngày ghi giao dịch liên tiếp (Phase 22, phản ứng của [AppMascot]).
///
/// 🚨 Tính theo NGÀY GIAO DỊCH THẬT (`occurredAt`), KHÔNG PHẢI ngày người
/// dùng thao tác nhập — Rolly mắc đúng lỗi ngược lại, khiến streak gãy vô lý
/// khi nhập bù một khoản của hôm qua (xem docs/rolly-product-research.md §
/// Ý nghĩa cho TonyFino). Vì schema TonyFino chỉ lưu `occurredAt` (không có
/// cột "ngày nhập" nào để lỡ tay dùng nhầm — xem Luật #3, không
/// `DateTime.now()` ở bất cứ đâu ngoài qua `Clock`), hàm này CHỈ nhận vào
/// danh sách ngày giao dịch, không có cách nào vô tình đọc nhầm nguồn khác.
///
/// Thuần Dart, không phụ thuộc Flutter/DB — nhận [occurredDates] (mỗi phần
/// tử là NGÀY của một giao dịch, trùng ngày không sao) và [today] (từ
/// `Clock`, do caller inject).
int computeEntryStreakDays({
  required Iterable<DateTime> occurredDates,
  required DateTime today,
}) {
  final days = occurredDates.map(_dateOnly).toSet();
  final todayOnly = _dateOnly(today);

  // Streak "đang chạy" phải bao gồm HÔM NAY hoặc HÔM QUA — nếu ngày gần nhất
  // có giao dịch xa hơn 1 ngày so với hôm nay, streak đã đứt, trả về 0 (chưa
  // ghi gì hôm nay thì không lẽ đứng lại đếm ngược vô hạn).
  DateTime cursor;
  if (days.contains(todayOnly)) {
    cursor = todayOnly;
  } else if (days.contains(todayOnly.subtract(const Duration(days: 1)))) {
    cursor = todayOnly.subtract(const Duration(days: 1));
  } else {
    return 0;
  }

  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
