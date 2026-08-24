import 'package:flutter/material.dart';

import '../theme/context_ext.dart';
import 'mascot/app_mascot.dart';
import 'mascot/mascot_mood.dart';

/// Trạng thái rỗng chung — icon lớn mờ (mặc định), hoặc [AppMascot] (Phase
/// 22, chỉ khi truyền [mascotMood]) + tiêu đề, mô tả phụ, hành động tuỳ
/// chọn. `mascotMood` mặc định `null` — MỌI call site không truyền tham số
/// này giữ nguyên pixel-identical với trước Phase 22 (icon mờ như cũ).
/// (Ghi chú cũ ở đây từng nói "không Lottie/Rive" — Phase 22 thêm mascot vẽ
/// tay bằng `CustomPainter` thuần Flutter, KHÔNG dùng Lottie/Rive, xem
/// `docs/decisions.md` § Phase 22 cho lý do.)
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.mascotMood,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final MascotMood? mascotMood;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.all(context.space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mascotMood != null
              ? AppMascot(mood: mascotMood!, size: 88)
              : Icon(
                  icon,
                  size: 56,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
          SizedBox(height: context.space.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleMedium,
          ),
          if (message != null) ...[
            SizedBox(height: context.space.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (action != null) ...[SizedBox(height: context.space.lg), action!],
        ],
      ),
    );
  }
}
