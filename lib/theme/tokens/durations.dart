/// Ngân sách cứng 5 animation (đặc tả design system) + vài hằng số dùng
/// chung. KHÔNG import `material.dart` — `Duration` là `dart:core` thuần.
class AppDurations {
  const AppDurations();

  /// #1 Số đếm lên (hero, ngân sách còn lại) — chỉ khi giá trị đổi.
  final Duration countUp = const Duration(milliseconds: 600);

  /// #2 Biểu đồ vẽ vào khi vào tab, một lần.
  final Duration chartDraw = const Duration(milliseconds: 450);

  /// #3 Danh sách vào lệch pha — độ trễ GIỮA MỖI item (giới hạn 8 item).
  final Duration listStaggerStep = const Duration(milliseconds: 24);
  final int listStaggerMaxItems = 8;
  final Duration listStaggerItemDuration = const Duration(milliseconds: 260);

  /// #4 Sheet trồi lên.
  final Duration sheet = const Duration(milliseconds: 320);

  /// #5 Nhịp xác nhận (dấu tích lưu thẻ chat) — khoảnh khắc chữ ký duy nhất.
  final Duration confirmPulse = const Duration(milliseconds: 220);

  /// Theme switch (light/dark) — không thuộc 5 animation trên nhưng
  /// `ThemeExtension.lerp` cần một mốc thời gian tham chiếu nhất quán.
  final Duration themeSwitch = const Duration(milliseconds: 260);

  /// Pill nav biến hình + icon FILL 0→1 khi đổi tab (TODOS.md § Package UI —
  /// một trong 3 ý tưởng M3 Expressive mượn riêng, KHÔNG thuộc 5 animation
  /// nội dung ở trên; đây là phản hồi điều hướng cốt lõi, không phải trang trí).
  final Duration navMorph = const Duration(milliseconds: 250);

  /// Cột biểu đồ: lệch pha mỗi cột.
  final Duration chartBarStep = const Duration(milliseconds: 30);
}

const appDurations = AppDurations();
