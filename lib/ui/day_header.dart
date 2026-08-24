import 'package:flutter/material.dart';

import '../core/money/money.dart';
import '../theme/context_ext.dart';
import 'money_text.dart';

/// Header ngày dính đầu danh sách giao dịch — `Hôm nay · Thứ Năm` trái,
/// tổng ròng của ngày phải bằng Inter tabular. Biến một danh sách phẳng
/// thành một cuốn sổ cái; tín hiệu "có thiết kế" rẻ nhất có thể thêm.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.label, required this.netTotal});

  final String label;
  final Money netTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.canvas,
      padding: EdgeInsets.symmetric(
        horizontal: context.space.screenHorizontal,
        vertical: context.space.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          MoneyText(netTotal, size: MoneySize.small),
        ],
      ),
    );
  }
}
