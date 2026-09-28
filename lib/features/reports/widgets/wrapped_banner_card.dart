import 'package:flutter/material.dart';

import '../../../theme/context_ext.dart';
import '../../../ui/app_card.dart';
import '../../../theme/tokens/icons.dart';
import '../wrapped_screen.dart';

/// Lối vào "TonyFino Wrapped" ở đầu tab Báo cáo — một thẻ có chấm cam nhỏ
/// đủ gợi chú ý giữa các card trung tính khác, đúng ý "novelty một-lần-ghé" chứ không
/// phải điều hướng cốt lõi (khác `ReportFilterBar`, luôn hiện).
class WrappedBannerCard extends StatelessWidget {
  const WrappedBannerCard({super.key, required this.year});

  final int year;

  // Thẻ thường + một CHẤM cam nhỏ đựng icon. Bản cũ tô cam đặc cả dải
  // ngang màn hình — mảng cam lớn nhất app, ngay đầu tab Báo cáo, trái luật
  // màu của chính dự án (cam chỉ cho mảng nhỏ và đậm; rà soát 2026-09-28).
  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => openWrappedScreen(context),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.scheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              kIconCelebration,
              size: 22,
              color: context.scheme.onPrimary,
            ),
          ),
          SizedBox(width: context.space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TonyFino Wrapped', style: context.text.titleMedium),
                Text(
                  'Xem lại năm $year của bạn',
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(kIconChevronRight, color: context.colors.onSurfaceVariant),
        ],
      ),
    );
  }
}
