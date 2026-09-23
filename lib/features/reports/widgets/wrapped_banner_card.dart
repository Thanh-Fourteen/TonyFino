import 'package:flutter/material.dart';

import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../wrapped_screen.dart';

/// Lối vào "TonyFino Wrapped" ở đầu tab Báo cáo — một băng nền cam nổi bật
/// giữa các card trung tính khác, đúng ý "novelty một-lần-ghé" chứ không
/// phải điều hướng cốt lõi (khác `ReportFilterBar`, luôn hiện).
class WrappedBannerCard extends StatelessWidget {
  const WrappedBannerCard({super.key, required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.scheme.primary,
      borderRadius: BorderRadius.circular(context.radii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(context.radii.lg),
        onTap: () => openWrappedScreen(context),
        child: Padding(
          padding: EdgeInsets.all(context.space.md),
          child: Row(
            children: [
              Icon(kIconCelebration, color: context.scheme.onPrimary),
              SizedBox(width: context.space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TonyFino Wrapped',
                      style: context.text.titleMedium?.copyWith(
                        color: context.scheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Xem lại năm $year của bạn',
                      style: context.text.bodySmall?.copyWith(
                        color: context.scheme.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(kIconChevronRight, color: context.scheme.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
