/// Ba trạng thái vạch nhịp (🔥 ý tưởng ăn cắp từ Copilot Money, TODOS.md §
/// Phase 11) — tô theo NHỊP ĐỘ so với tiến độ thời gian trong tháng, không
/// phải phần trăm tuyệt đối. 60% ở ngày 10/30 là tệ (đang tiêu nhanh hơn
/// nhịp đều); 60% ở ngày 25/30 là tốt (đang chậm hơn nhịp đều dù số tuyệt
/// đối giống nhau) — đây chính là điều một progress bar phần trăm thường
/// không thể hiện được.
enum BudgetPaceState {
  /// Xanh — chi tiêu đang chậm hơn hoặc bằng nhịp thời gian, trên đà không vượt.
  onTrack,

  /// Vàng — chi tiêu đang nhanh hơn nhịp thời gian, trên đà sẽ vượt nếu giữ
  /// nguyên tốc độ, nhưng CHƯA vượt tổng ngân sách.
  trendingOver,

  /// Đỏ — đã chi bằng hoặc vượt tổng ngân sách, bất kể đang ở ngày nào.
  over,
}

/// [progressFraction] = |đã chi| / ngân sách (có thể > 1). [paceFraction] =
/// vị trí trong tháng (`BudgetPeriod.paceFraction`), 0–1. Thuần hàm — test
/// được không cần DB/widget.
BudgetPaceState computeBudgetPaceState({
  required double progressFraction,
  required double paceFraction,
}) {
  if (progressFraction >= 1.0) return BudgetPaceState.over;
  if (progressFraction > paceFraction) return BudgetPaceState.trendingOver;
  return BudgetPaceState.onTrack;
}
