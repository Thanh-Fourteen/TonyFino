import '../../../data/db/database.dart';

/// Kết quả JOIN + `SUM` của `SavingsGoalRepository.watchActiveWithProgress` —
/// một dòng cho MỖI mục tiêu, [savedMinor] tính bằng `-SUM(transactions.amount_minor)`
/// của các giao dịch gắn `goalId` (D7: không lưu bộ đếm, không thể sai). Xem
/// docs/decisions.md § Phase 16 "Mục tiêu tiết kiệm & nợ vay" cho công thức
/// đầy đủ + vì sao không dùng `ABS()`.
class SavingsGoalProgress {
  const SavingsGoalProgress({required this.goal, required this.savedMinor});

  final SavingsGoal goal;

  /// `-SUM(amount_minor)` — đóng góp (chi, âm) cộng dương, rút (thu, dương)
  /// trừ đi. Có thể ÂM nếu rút nhiều hơn đã đóng góp (dữ liệu bất thường,
  /// không chặn ở DB — xem `_validate` nếu cần chặn sau này).
  final int savedMinor;

  /// Kẹp 0.0–1.0 cho vòng tiến độ — có thể vượt 1.0 (đã đạt/vượt mục tiêu)
  /// hoặc âm (rút nhiều hơn đóng góp), cả hai đều hiển thị rõ bằng SỐ, vòng
  /// chỉ cần kẹp để không vẽ lỗi.
  double get progressFraction {
    if (goal.targetAmountMinor <= 0) return 0.0;
    return (savedMinor / goal.targetAmountMinor).clamp(0.0, 1.0);
  }

  /// Có thể ÂM nếu đã vượt mục tiêu (đóng góp nhiều hơn số tiền cần).
  int get remainingMinor => goal.targetAmountMinor - savedMinor;

  bool get isAchieved => savedMinor >= goal.targetAmountMinor;
}
