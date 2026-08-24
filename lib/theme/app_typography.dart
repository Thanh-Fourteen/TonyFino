import 'package:flutter/material.dart';

/// Cờ tính năng bắt buộc trên MỌI style hiển thị tiền (Luật #13) — thiếu là
/// cột số căn phải giật nhìn thấy được mỗi khi chữ số đổi.
const kMoneyFeatures = [FontFeature.tabularFigures()];

/// Các style tiền — thứ duy nhất `TextTheme` (M3) không mô hình hoá được,
/// vì nó cần font khác (Inter, không phải Be Vietnam Pro) + tabular figures.
/// Style chữ thường (display/title/body/label) sống trong `TextTheme` chuẩn,
/// dựng thẳng trong `app_theme.dart` — không lặp lại ở đây.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.moneyHero,
    required this.moneyLarge,
    required this.moneyMedium,
    required this.moneySmall,
  });

  /// 40 / 700 / 1.10, `opsz 32`, tabular. Số hero (chi tiêu từ đầu tháng...).
  final TextStyle moneyHero;

  /// 28 / 600 / 1.15, tabular.
  final TextStyle moneyLarge;

  /// 17 / 600 / 1.20, tabular. Cỡ dùng trong hàng giao dịch.
  final TextStyle moneyMedium;

  /// 13 / 500 / 1.25, tabular. Cỡ dùng trong chip/nhãn phụ.
  final TextStyle moneySmall;

  static const _family = 'Inter';

  static const light = AppTypography(
    // 🚨 Số tiền lớn: NHẸ NÉT và CHẶT CHỮ, không to-đậm.
    //
    // Trước đây hero là 40px/w700 — bốn con số triệu đồng thành một khối
    // đen đặc chiếm gần hết bề ngang, đúng thứ Tony gọi là "font số xấu" và
    // "trang chủ không thanh mảnh". Chữ số càng nhiều thì nét càng phải
    // NHẸ đi chứ không phải nặng thêm: cỡ vẫn đủ lớn để là điểm nhìn chính,
    // nhưng w600 + tracking âm sâu hơn cho khối số một dáng mảnh.
    moneyHero: TextStyle(
      fontFamily: _family,
      fontSize: 34,
      fontWeight: FontWeight.w600,
      height: 1.10,
      letterSpacing: -1.02, // -0.03em × 34
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: kMoneyFeatures,
      fontVariations: [FontVariation('opsz', 32)],
    ),
    moneyLarge: TextStyle(
      fontFamily: _family,
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 1.15,
      letterSpacing: -0.48, // -0.02em × 24
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: kMoneyFeatures,
    ),
    moneyMedium: TextStyle(
      fontFamily: _family,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.20,
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: kMoneyFeatures,
    ),
    moneySmall: TextStyle(
      fontFamily: _family,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.25,
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: kMoneyFeatures,
    ),
  );

  /// Dark chỉ khác `light` ở màu (đặt qua `DefaultTextStyle`/tô riêng ở
  /// `MoneyText`, không cố định màu trong đây) — hình dạng font giống hệt.
  static const dark = light;

  @override
  AppTypography copyWith({
    TextStyle? moneyHero,
    TextStyle? moneyLarge,
    TextStyle? moneyMedium,
    TextStyle? moneySmall,
  }) {
    return AppTypography(
      moneyHero: moneyHero ?? this.moneyHero,
      moneyLarge: moneyLarge ?? this.moneyLarge,
      moneyMedium: moneyMedium ?? this.moneyMedium,
      moneySmall: moneySmall ?? this.moneySmall,
    );
  }

  /// Nội suy THẬT (Luật #3) qua `TextStyle.lerp` — quan trọng khi cỡ chữ hệ
  /// thống đổi hoặc theme animate, không riêng light/dark.
  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      moneyHero: TextStyle.lerp(moneyHero, other.moneyHero, t)!,
      moneyLarge: TextStyle.lerp(moneyLarge, other.moneyLarge, t)!,
      moneyMedium: TextStyle.lerp(moneyMedium, other.moneyMedium, t)!,
      moneySmall: TextStyle.lerp(moneySmall, other.moneySmall, t)!,
    );
  }
}
