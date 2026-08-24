import 'package:flutter/widgets.dart';

/// Bật/tắt che số tiền cho cả cây widget bên dưới.
///
/// 🚨 Dùng `InheritedWidget` chứ KHÔNG cho `MoneyText` tự `ref.watch`
/// settings: `MoneyText` bị dựng ở hàng trăm chỗ, gồm cả golden test dựng
/// widget trần không có `ProviderScope` — biến nó thành `ConsumerWidget` là
/// mọi test đó nổ. Ở đây thiếu widget này thì mặc định KHÔNG che, nên chỗ
/// nào chưa bọc vẫn chạy đúng như trước.
///
/// Đây chỉ là lớp che THỊ GIÁC (đưa máy cho người khác xem, ngồi quán…),
/// không phải bảo mật: khoá thật là khoá vân tay + mã hoá DB.
class AmountVisibility extends InheritedWidget {
  const AmountVisibility({
    super.key,
    required this.hidden,
    required super.child,
  });

  final bool hidden;

  static bool hiddenOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AmountVisibility>()?.hidden ??
      false;

  /// Che một chuỗi tiền đã dựng sẵn.
  ///
  /// Dành cho những chỗ KHÔNG dùng được `MoneyText` vì cần ghép chuỗi —
  /// "đã tiêu / hạn mức", "còn lại −x", "5.000.000 / 20.000.000". Không có
  /// hàm này thì mỗi chỗ đó là một lỗ rò: bật con mắt mà số vẫn hiện.
  static String mask(BuildContext context, String formatted) =>
      hiddenOf(context) ? '••••••' : formatted;

  @override
  bool updateShouldNotify(AmountVisibility oldWidget) =>
      oldWidget.hidden != hidden;
}
