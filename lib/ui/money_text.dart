import 'package:flutter/material.dart';

import '../core/money/money.dart';
import '../theme/context_ext.dart';
import 'amount_visibility.dart';

/// Cỡ chữ tiền — khớp 4 style trong `AppTypography` (bảng design system).
enum MoneySize { hero, large, medium, small }

/// 🔥 Hai quyết định thị giác đáng giá nhất của app này, đều nằm ở đây:
///
/// 1. **Chi tiêu render màu TRUNG TÍNH** (`context.colors.expenseText`, vốn
///    chính là `onSurface`) — KHÔNG BAO GIỜ đỏ. ~90% dòng trong app quản lý
///    chi tiêu là chi; đỏ hết thì đỏ vô nghĩa và màn hình gào lên. Đỏ chỉ
///    dành cho vượt ngân sách và hành động phá huỷ.
/// 2. **Thu render xanh kèm dấu `+` tường minh** — không bao giờ mã hoá
///    nghĩa chỉ bằng sắc độ (đỏ-xanh là cặp va chạm của mù màu deuteranopia/
///    protanopia); dấu `+`/`−` luôn đi kèm màu.
///
/// Luôn tabular figures (`AppTypography` đã bọc sẵn `kMoneyFeatures`).
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.size = MoneySize.medium,
    this.style,
    this.signed = true,
  });

  final Money amount;
  final MoneySize size;

  /// Ghi đè style cơ sở (màu vẫn luôn tính theo dấu số tiền, không đổi được
  /// từ đây — tránh vô tình phá luật màu #2 ở một call site lẻ).
  final TextStyle? style;

  /// `false` = số TRUNG TÍNH: không dấu `+`, không tô xanh/đỏ.
  ///
  /// Dành cho những con số KHÔNG phải một dòng tiền vào/ra — hạn mức hũ,
  /// phần còn lại của hũ, số dư đầu kỳ. Hiển thị "+16.243.150 đ" màu xanh
  /// cho một HẠN MỨC khiến nó trông như vừa thu được ngần ấy, sai hoàn toàn
  /// nghĩa (thấy tận mắt ở màn Hũ).
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final base = switch (size) {
      MoneySize.hero => context.money.moneyHero,
      MoneySize.large => context.money.moneyLarge,
      MoneySize.medium => context.money.moneyMedium,
      MoneySize.small => context.money.moneySmall,
    }.merge(style);

    // Che số: giữ NGUYÊN kiểu chữ (cùng cỡ, cùng khoảng cách) để bố cục
    // không nhảy khi bật/tắt, nhưng dùng màu TRUNG TÍNH — tô xanh cho khoản
    // thu trong lúc đang che thì vẫn lộ ra đó là tiền vào.
    if (AmountVisibility.hiddenOf(context)) {
      return Text(
        '••••••',
        style: base.copyWith(color: context.colors.onSurfaceVariant),
      );
    }

    if (!signed) {
      return _grouped(
        context,
        amount.format(),
        base.copyWith(color: context.colors.onSurface),
      );
    }

    final isIncome = amount.isPositive;
    final color = isIncome
        ? context.colors.incomeText
        : context.colors.expenseText;
    final label = isIncome ? '+${amount.format()}' : amount.format();

    return _grouped(context, label, base.copyWith(color: color));
  }

  /// Vẽ số tiền với DẤU PHÂN NHÓM nhạt hơn chữ số.
  ///
  /// "34.559.000" toàn một màu là một dãy chín ký tự đặc, mắt phải tự đếm
  /// để biết là ba mươi tư triệu hay ba trăm tư mươi lăm triệu. Làm dấu
  /// chấm nhạt đi (~45% độ đậm) khiến ba cụm số nổi lên thành ba khối riêng
  /// — đọc được bậc độ lớn bằng liếc mắt, mà KHÔNG rút gọn số (sổ sách phải
  /// chính xác tới từng đồng).
  ///
  /// Chỉ đụng ký tự phân nhóm; dấu, chữ số và ký hiệu tiền giữ nguyên màu.
  Widget _grouped(BuildContext context, String label, TextStyle style) {
    const separators = {'.', ',', '\u00A0', ' '};
    final muted = style.color?.withValues(alpha: 0.45);
    final spans = <TextSpan>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString()));
      buffer.clear();
    }

    for (final ch in label.split('')) {
      if (separators.contains(ch)) {
        flush();
        spans.add(
          TextSpan(
            text: ch,
            style: TextStyle(color: muted),
          ),
        );
      } else {
        buffer.write(ch);
      }
    }
    flush();

    return Text.rich(TextSpan(children: spans), style: style);
  }
}
