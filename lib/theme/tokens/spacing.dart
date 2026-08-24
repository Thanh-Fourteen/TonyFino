/// Thang khoảng cách hệ 4 + các con số bố cục đã chốt trong đặc tả design
/// system. KHÔNG import `material.dart` (Luật #10) — file này chỉ có số.
///
/// Instance thay vì static để `context.space.lg` đọc gọn (`context_ext.dart`).
class AppSpacing {
  const AppSpacing();

  final double xxs = 2;
  final double xs = 4;
  final double sm = 8;
  final double md = 12;
  final double lg = 16;
  final double xl = 20;
  final double xxl = 24;
  final double xxxl = 32;
  final double huge = 40;
  final double massive = 48;

  /// Lề ngang màn hình.
  final double screenHorizontal = 16;

  /// Đệm trong card thường / hero card.
  final double cardPadding = 16;
  final double heroCardPadding = 24;

  /// Khoảng cách giữa các card / giữa các section.
  final double betweenCards = 12;
  final double betweenSections = 24;

  /// Đệm dọc hàng giao dịch — **con số phải bảo vệ**: cho ra hàng ~60px.
  /// Nhồi xuống 48px là thứ làm app quản lý chi tiêu trông như bảng tính.
  final double transactionRowVertical = 14;

  /// Thụt trái của divider trong danh sách giao dịch (căn theo mép chữ, sau
  /// avatar danh mục — không kéo dài hết chiều rộng).
  final double dividerIndent = 56;

  /// Vùng chạm tối thiểu (Material/HIG đều khuyến nghị ≥48dp).
  final double minTapTarget = 48;
}

const appSpacing = AppSpacing();
