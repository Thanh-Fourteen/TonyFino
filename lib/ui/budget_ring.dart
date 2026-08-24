import 'package:flutter/material.dart';

import '../theme/context_ext.dart';
import 'progress_ring.dart';

/// Vòng tiến độ ngân sách — mỏng bọc quanh `ProgressRing` (hình học dùng
/// chung, tách ra ở Phase 16), chỉ còn giữ lại logic MÀU đặc thù ngân sách:
/// 🔥 tô theo NHỊP ĐỘ (so [progress] với [paceFraction] — ý tưởng ăn cắp từ
/// Copilot Money, Phase 11), KHÔNG phải phần trăm tuyệt đối — 60% đã chi ở
/// ngày 10/30 (nhịp 33%) là tệ (vàng), 60% ở ngày 25/30 (nhịp 83%) là tốt
/// (xanh). Widget này KHÔNG biết gì về `Budget`/`Category` — chỉ nhận hai số
/// thuần, logic "60% ở ngày nào thì tệ" được quyết định độc lập ở
/// `features/budgets/domain/budget_pace.dart` (`computeBudgetPaceState`, có
/// test riêng) và LẶP LẠI y hệt ở đây bằng tay thay vì import thẳng, vì
/// `lib/ui/` là tầng nguyên tử dùng chung, không phụ thuộc ngược vào
/// `lib/features/` — hai chỗ phải giữ đồng bộ nếu quy tắc màu đổi.
class BudgetRing extends StatelessWidget {
  const BudgetRing({
    super.key,
    required this.progress,
    required this.paceFraction,
    this.size = 96,
    this.strokeWidth = 10,
    this.child,
  });

  /// |đã chi| / ngân sách — có thể > 1.0 khi đã vượt (vòng vẫn dừng ở một
  /// vòng đầy, chỉ đổi màu).
  final double progress;

  /// `ngày_trong_tháng / số_ngày_tháng` của kỳ đang xem, 0.0–1.0 (xem
  /// `BudgetPeriod.paceFraction`).
  final double paceFraction;

  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pace = paceFraction.clamp(0.0, 1.0);

    // Cùng logic `computeBudgetPaceState` — xem doc comment lớp này.
    final Color ringColor;
    if (progress >= 1.0) {
      ringColor = colors.budgetOver;
    } else if (progress > pace) {
      ringColor = colors.budgetWarn;
    } else {
      ringColor = colors.budgetOk;
    }

    return ProgressRing(
      progress: progress,
      ringColor: ringColor,
      trackColor: colors.hairline,
      paceFraction: pace,
      paceMarkColor: colors.onSurface,
      size: size,
      strokeWidth: strokeWidth,
      child: child,
    );
  }
}
