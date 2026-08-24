const _monthLabels = [
  'Tháng 1',
  'Tháng 2',
  'Tháng 3',
  'Tháng 4',
  'Tháng 5',
  'Tháng 6',
  'Tháng 7',
  'Tháng 8',
  'Tháng 9',
  'Tháng 10',
  'Tháng 11',
  'Tháng 12',
];

/// Một kỳ ngân sách = MỘT THÁNG LỊCH theo mặc định (quyết định D-Budget-1,
/// Phase 11), NHƯNG ranh giới NGÀY dịch được qua [anchorDay] (Phase 15, "kỳ
/// ngân sách theo ngày lương") — mặc định `1` giữ NGUYÊN hành vi Phase 11
/// (xem docs/decisions.md § Phase 15 "Kỳ ngân sách theo ngày neo").
/// `start`/`end` là ranh giới LOCAL wall-clock (nửa khoảng `[start, end)`),
/// dựng bằng `DateTime(year, month, ...)` — CÙNG cách mọi `occurredAt` được
/// chèn vào DB (quick-add, importer), nên so sánh trực tiếp với cột
/// `occurredAt` trong SQL không cần `.modify(DateTimeModifier.localTime())`.
///
/// `yearMonth` LUÔN là tháng lịch mà kỳ đó BẮT ĐẦU, bất kể [anchorDay] —
/// `budgets.year_month` giữ nguyên ý nghĩa này (không đổi theo Phase 15).
class BudgetPeriod {
  const BudgetPeriod({
    required this.year,
    required this.month,
    this.anchorDay = 1,
  });

  /// [reference] thuộc kỳ nào: nếu ngày trong tháng của [reference] đã tới
  /// [anchorDay], kỳ hiện tại BẮT ĐẦU từ tháng của [reference]; nếu chưa tới,
  /// kỳ hiện tại vẫn là kỳ bắt đầu từ THÁNG TRƯỚC (chưa qua ngày neo mới).
  /// `anchorDay = 1` (mặc định) luôn thoả `reference.day >= 1`, nên luôn rơi
  /// vào nhánh đầu — giữ nguyên hệt hành vi Phase 11.
  factory BudgetPeriod.of(DateTime reference, {int anchorDay = 1}) {
    if (reference.day >= anchorDay) {
      return BudgetPeriod(
        year: reference.year,
        month: reference.month,
        anchorDay: anchorDay,
      );
    }
    final month = reference.month == 1 ? 12 : reference.month - 1;
    final year = reference.month == 1 ? reference.year - 1 : reference.year;
    return BudgetPeriod(year: year, month: month, anchorDay: anchorDay);
  }

  final int year;

  /// 1–12. Tháng LỊCH mà kỳ này bắt đầu — xem `yearMonthKey`.
  final int month;

  /// Ngày trong tháng bắt đầu một kỳ mới, 1–31 (mặc định 1 = đầu tháng lịch,
  /// hành vi Phase 11). Nếu tháng cụ thể không có đủ số ngày đó (vd. neo 31,
  /// tháng 2), [start]/[end] KẸP về ngày cuối cùng thật của tháng đó — xem
  /// `_clampedAnchor`.
  final int anchorDay;

  /// Khớp `budgets.year_month` (`'YYYY-MM'`) — LUÔN là tháng mà kỳ BẮT ĐẦU,
  /// không đổi theo `anchorDay`.
  String get yearMonthKey => '$year-${month.toString().padLeft(2, '0')}';

  /// `anchorDay == 1`: tên tháng lịch (giữ nguyên chữ Phase 11) — kỳ trùng
  /// khít tháng lịch. `anchorDay != 1`: khoảng ngày cụ thể (`dd/MM – dd/MM`)
  /// vì kỳ không còn trùng một tháng lịch nào để đặt tên gọn.
  String get label {
    if (anchorDay == 1) return '${_monthLabels[month - 1]} $year';
    final lastDay = end.subtract(const Duration(days: 1));
    return '${_fmtDayMonth(start)} – ${_fmtDayMonth(lastDay)}';
  }

  static String _fmtDayMonth(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  DateTime get start => DateTime(year, month, _clampedAnchor(year, month));

  /// `DateTime(year, month + 1, ...)` — Dart tự chuẩn hoá `month: 13` thành
  /// tháng 1 năm sau (đã xác nhận bằng test ranh giới năm), nên ranh giới
  /// tháng 12 KHÔNG cần nhánh `if` riêng.
  DateTime get end {
    final nextMonthFirst = DateTime(year, month + 1, 1);
    return DateTime(
      nextMonthFirst.year,
      nextMonthFirst.month,
      _clampedAnchor(nextMonthFirst.year, nextMonthFirst.month),
    );
  }

  /// `DateTime(year, month + 1, 0)` = "ngày 0" của tháng sau = ngày cuối
  /// cùng của tháng này — mẹo chuẩn của Dart, không cần bảng tra 28/30/31.
  /// KHÔNG phụ thuộc `anchorDay` — luôn là số ngày lịch của `this.month`.
  int get daysInMonth => DateTime(year, month + 1, 0).day;

  /// [anchorDay] kẹp về ngày cuối cùng thật của tháng [y]/[m] nếu tháng đó
  /// không có đủ ngày (vd. neo 31 vào tháng 2) — cùng mẹo `daysInMonth`.
  int _clampedAnchor(int y, int m) {
    final lastDayOfMonth = DateTime(y, m + 1, 0).day;
    return anchorDay > lastDayOfMonth ? lastDayOfMonth : anchorDay;
  }

  bool contains(DateTime reference) =>
      !reference.isBefore(start) && reference.isBefore(end);

  BudgetPeriod get previous => month == 1
      ? BudgetPeriod(year: year - 1, month: 12, anchorDay: anchorDay)
      : BudgetPeriod(year: year, month: month - 1, anchorDay: anchorDay);

  BudgetPeriod get next => month == 12
      ? BudgetPeriod(year: year + 1, month: 1, anchorDay: anchorDay)
      : BudgetPeriod(year: year, month: month + 1, anchorDay: anchorDay);

  /// Vị trí trong kỳ, kẹp 0–1 — nguồn cho vạch nhịp trên `BudgetRing`. Kỳ đã
  /// qua hẳn (đang xem kỳ trước) → 1.0 (đã hết kỳ); kỳ chưa tới (đang xem kỳ
  /// sau) → 0.0. Tổng quát hoá từ Phase 11 (`reference.day / daysInMonth`)
  /// sang `(số ngày đã qua trong kỳ + 1) / tổng số ngày của kỳ` — cho kết
  /// quả GIỐNG HỆT công thức cũ khi `anchorDay == 1` (đã xác nhận bằng test:
  /// `start` luôn là ngày 1, nên hiệu số ngày = `reference.day - 1`).
  double paceFraction(DateTime reference) {
    if (reference.isBefore(start)) return 0.0;
    if (!reference.isBefore(end)) return 1.0;
    final totalDays = end.difference(start).inDays;
    final dayOfPeriod = reference.difference(start).inDays + 1;
    return (dayOfPeriod / totalDays).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      other is BudgetPeriod &&
      other.year == year &&
      other.month == month &&
      other.anchorDay == anchorDay;

  @override
  int get hashCode => Object.hash(year, month, anchorDay);
}
