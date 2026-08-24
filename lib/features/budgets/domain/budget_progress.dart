import 'budget_pace.dart';

/// Kết quả JOIN + gộp SQL của `BudgetRepository.watchBudgetsForPeriod` — một
/// dòng cho MỖI ngân sách đã đặt trong kỳ đang xem, `spentMinor` tính bằng
/// `SUM(transactions.amount_minor)` (D7: không lưu bộ đếm, không thể sai).
class BudgetProgress {
  const BudgetProgress({
    required this.budgetId,
    required this.categoryId,
    required this.categoryName,
    required this.categoryColorId,
    required this.iconCode,
    required this.budgetAmountMinor,
    required this.spentMinor,
    this.carryInMinor = 0,
    this.carryOverEnabled = false,
  });

  final int budgetId;
  final int categoryId;
  final String categoryName;
  final int categoryColorId;
  final String iconCode;

  /// Luôn > 0 — số GỐC Tony đặt (biên độ ngân sách), KHÔNG cộng carry-in.
  /// Dùng cho hiển thị "ngân sách gốc"; mọi phép tính tiến độ dùng
  /// [effectiveBudgetAmountMinor] thay vì trường này.
  final int budgetAmountMinor;

  /// Luôn ≤ 0 — tổng `amountMinor` các giao dịch CHI của danh mục này trong
  /// kỳ, đọc thẳng từ SQL `SUM`.
  final int spentMinor;

  /// Phần dư (dương)/vượt (âm) của kỳ LIỀN TRƯỚC cộng vào kỳ này (Phase 15)
  /// — luôn `0` nếu `budgets.carry_over` tắt hoặc không có ngân sách kỳ
  /// trước để tính. Xem docs/decisions.md § Phase 15 "Carry-over".
  final int carryInMinor;

  /// Cờ THÔ `budgets.carry_over` — khác `carryInMinor` (số ÂM/DƯƠNG thực tế
  /// đã cộng vào), cần để tiền điền lại đúng trạng thái toggle khi mở lại
  /// `BudgetEditSheet`, kể cả khi `carryInMinor == 0` vì kỳ trước chưa có
  /// ngân sách nào (cờ vẫn có thể đang bật, chỉ chưa có gì để cộng).
  final bool carryOverEnabled;

  /// Ngân sách THỰC SỰ dùng để tính tiến độ/còn lại — gốc + carry-in. Có
  /// thể ÂM nếu carry-in âm (kỳ trước vượt) lớn hơn ngân sách gốc kỳ này
  /// (quyết định CÓ CHỦ Ý: phạt kỳ sau, không kẹp về 0).
  int get effectiveBudgetAmountMinor => budgetAmountMinor + carryInMinor;

  /// |đã chi| / ngân sách hiệu lực — có thể > 1 khi đã vượt.
  /// `effectiveBudgetAmountMinor <= 0` phòng thủ để không chia cho 0 (có
  /// thể xảy ra thật với carry-in âm rất lớn, không chỉ lý thuyết).
  double get progressFraction {
    if (effectiveBudgetAmountMinor <= 0) return spentMinor == 0 ? 0.0 : 1.0;
    return spentMinor.abs() / effectiveBudgetAmountMinor;
  }

  /// Có thể ÂM khi đã vượt ngân sách hiệu lực.
  int get remainingMinor => effectiveBudgetAmountMinor - spentMinor.abs();

  BudgetPaceState paceState(double paceFraction) => computeBudgetPaceState(
    progressFraction: progressFraction,
    paceFraction: paceFraction,
  );
}
