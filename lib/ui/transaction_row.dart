import 'package:flutter/material.dart';

import '../core/money/money.dart';
import '../theme/context_ext.dart';
import 'category_avatar.dart';
import 'money_text.dart';

/// 🔥 Quyết định bố cục đòn bẩy cao nhất app: hàng TRÀN VIỀN trên bề mặt
/// nền, KHÔNG phải card-mỗi-hàng. Card-mỗi-hàng ngốn ~30% chiều dọc vào lề
/// và tạo nhiễu thị giác từ viền lặp — đây chính xác là khác biệt giữa
/// Spendee/Copilot (thanh lịch) và app template (bừa bộn).
///
/// Chia bằng hairline thụt vào ngang chữ (`context.space.dividerIndent`),
/// KHÔNG phải viền quanh từng hàng — dùng `TransactionRow.divider` giữa các
/// item trong `ListView.separated`, đừng tự vẽ border trong widget này.
class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.categoryColorId,
    required this.iconCode,
    required this.title,
    required this.amount,
    this.subtitle,
    this.onTap,
    this.emoji,
    this.subcategoryLabel,
  });

  final int categoryColorId;
  final String iconCode;
  final String title;
  final String? subtitle;
  final Money amount;
  final VoidCallback? onTap;
  final String? emoji;

  /// Tên danh mục PHỤ, hiện thành chip nhỏ ngay sau tên danh mục cha —
  /// `null` ở giao dịch gắn thẳng vào danh mục gốc.
  ///
  /// Đây là TĂNG THÔNG TIN chứ không phải trang trí: dữ liệu danh mục phụ đã
  /// có sẵn trong sổ từ lần import Rolly (27 danh mục phụ) nhưng trước đây
  /// không hiện ở đâu trong danh sách — người dùng chỉ thấy "Ăn uống" cho cả
  /// bữa trưa lẫn cà phê. Rolly hiện chip này trên mọi dòng (`rolly.mp4`).
  final String? subcategoryLabel;

  /// Divider thụt trái đúng mép chữ (sau avatar) — dùng làm `separatorBuilder`.
  static Widget divider(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: context.space.dividerIndent),
      child: Divider(height: 1, thickness: 1, color: context.colors.hairline),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.screenHorizontal,
            vertical: context.space.transactionRowVertical,
          ),
          child: Row(
            children: [
              CategoryAvatar(
                categoryColorId: categoryColorId,
                iconCode: iconCode,
                size: 40,
                emoji: emoji,
              ),
              SizedBox(width: context.space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (subcategoryLabel == null)
                      Text(
                        title,
                        style: context.text.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Row(
                        children: [
                          // `Flexible` chứ không `Expanded`: tên danh mục co
                          // lại nhường chỗ cho chip, nhưng chip không bị đẩy
                          // ra khỏi hàng khi tên ngắn.
                          Flexible(
                            child: Text(
                              title,
                              style: context.text.bodyLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: context.space.xs),
                          Flexible(
                            child: _SubcategoryChip(label: subcategoryLabel!),
                          ),
                        ],
                      ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: context.text.labelMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox(width: context.space.sm),
              MoneyText(amount, size: MoneySize.medium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip tên danh mục phụ — cố ý NHẠT và nhỏ hơn tên danh mục cha: nó là
/// thông tin bổ trợ, không được cạnh tranh thị giác với tên danh mục hay số
/// tiền (hai thứ mắt phải bắt được trước tiên khi lướt danh sách).
class _SubcategoryChip extends StatelessWidget {
  const _SubcategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: context.colors.onSurfaceVariant.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
