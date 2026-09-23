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

/// Chuỗi ngày ghi giao dịch liên tiếp DÀI NHẤT trong [occurredDates] — khác
/// [computeEntryStreakDays]: hàm đó neo vào [today] và trả về chuỗi ĐANG
/// CHẠY (0 nếu hôm nay/hôm qua không có gì); hàm này quét TOÀN BỘ tập ngày
/// đưa vào và tìm khoảng liên tiếp dài nhất, không quan tâm ngày hiện tại —
/// dùng cho thẻ tổng kết cuối năm ("TonyFino Wrapped"), nơi câu hỏi là "cả
/// năm chuỗi dài nhất là bao nhiêu ngày", không phải "chuỗi có đang chạy".
int computeLongestStreakDays(Iterable<DateTime> occurredDates) {
  final days = occurredDates.map(_dateOnly).toSet().toList()..sort();
  if (days.isEmpty) return 0;

  var longest = 1;
  var current = 1;
  for (var i = 1; i < days.length; i++) {
    final gap = days[i].difference(days[i - 1]).inDays;
    if (gap == 1) {
      current++;
      if (current > longest) longest = current;
    } else if (gap > 1) {
      current = 1;
    }
    // gap == 0 không thể xảy ra: `days` đã qua `.toSet()`.
  }
  return longest;
}
