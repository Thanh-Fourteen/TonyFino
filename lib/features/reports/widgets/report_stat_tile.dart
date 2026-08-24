import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../theme/context_ext.dart';
import '../../../ui/app_card.dart';
import '../../../ui/count_up_text.dart';
import '../../../ui/money_text.dart';

/// Ô thống kê 2 cột đầu bento grid — dùng `CountUpText` (animation #1 ngân
/// sách 5 animation, chỉ chạy khi GIÁ TRỊ ĐỔI, không phải lần vẽ đầu) thay vì
/// `MoneyText` tĩnh, vì đổi filter khiến số này đổi liên tục.
class ReportStatTile extends StatelessWidget {
  const ReportStatTile({
    super.key,
    required this.label,
    required this.icon,
    required this.amount,
  });

  final String label;
  final IconData icon;

  /// `null` khi đang tải — vẽ skeleton thay vì số 0 gây hiểu nhầm.
  final Money? amount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(context.space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.colors.onSurfaceVariant),
              SizedBox(width: context.space.xs),
              Expanded(
                child: Text(
                  label,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: context.space.xs),
          amount == null
              ? Container(
                  width: 96,
                  height: 22,
                  decoration: BoxDecoration(
                    color: context.colors.skeletonBase,
                    borderRadius: BorderRadius.circular(context.radii.xs),
                  ),
                )
              : CountUpText(amount!, size: MoneySize.medium),
        ],
      ),
    );
  }
}
