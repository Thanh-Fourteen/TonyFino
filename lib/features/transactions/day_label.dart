const _kWeekdayNames = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

/// `Hôm nay · Thứ Năm` / `Hôm qua · Thứ Tư` / `Thứ Hai, 18/8` — [now] LUÔN
/// đến từ `Clock` inject ở tầng gọi (Luật #3), hàm này thuần, không tự đọc
/// giờ hệ thống.
String formatDayLabel(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final target = DateTime(date.year, date.month, date.day);
  final weekday = _kWeekdayNames[date.weekday - 1];

  if (target == today) return 'Hôm nay · $weekday';
  if (target == yesterday) return 'Hôm qua · $weekday';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$weekday, $day/$month';
}

/// Khoá nhóm theo ngày (không giờ) — dùng làm key gom `TransactionWithCategory`.
DateTime dayKey(DateTime date) => DateTime(date.year, date.month, date.day);
