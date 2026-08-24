/// Thang bo góc: bề mặt càng lớn, góc càng lớn. KHÔNG import `material.dart`.
class AppRadii {
  const AppRadii();

  final double xs = 6; // input nhỏ, tag
  final double sm = 10; // nút phụ
  final double md = 14; // nút chính
  final double lg = 18; // card
  final double xl = 24; // hero card
  final double xxl = 28; // bottom sheet (2 góc trên)
  final double full = 999; // chip / avatar / FAB / thanh nhập / pill nav

  /// Hàng giao dịch dùng riêng 12 (không nằm trong thang chính, nhưng đủ nhỏ
  /// để phân biệt với card 18 khi hàng có nền riêng — vd. trạng thái chọn).
  final double transactionRow = 12;
}

const appRadii = AppRadii();
