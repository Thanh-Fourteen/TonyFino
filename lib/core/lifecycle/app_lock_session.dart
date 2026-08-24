import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phiên hiện tại đã được mở khoá chưa.
///
/// 🚨 Vì sao phải là state TƯỜNG MINH, không suy ra từ cờ cài đặt:
///
/// Bật khoá trong Cài đặt mà bị ném ra màn khoá ngay giây đó là hỏi lại một
/// câu vừa được trả lời — người dùng đang đứng trong app và vừa tự tay bật.
/// Cách sửa "khôn" là bắt chuyển dịch `false → true` của
/// `biometricLockEnabled` rồi coi như đã mở. Cách đó SAI, và tôi đã dính:
/// cài đặt nạp từ prefs BẤT ĐỒNG BỘ, nên mỗi lần khởi động lạnh cờ cũng đi
/// từ `false` (giá trị mặc định) lên `true` (giá trị đã lưu) — trông y hệt
/// một cú bật công tắc. Kết quả: app không bao giờ khoá nữa, tức là mất
/// hẳn tính năng bảo mật mà vẫn báo "đã bật".
///
/// Nên: chỉ người BẤM công tắc mới gọi [trust]. Khởi động lạnh không ai gọi
/// → mặc định `false` → khoá đúng như phải thế.
class AppLockSession extends Notifier<bool> {
  @override
  bool build() => false;

  /// Phiên này khỏi hỏi nữa (vừa xác thực xong, hoặc vừa tự bật khoá).
  void trust() => state = true;

  /// Khoá lại — gọi khi app rời foreground.
  void lock() => state = false;
}

final appLockSessionProvider = NotifierProvider<AppLockSession, bool>(
  AppLockSession.new,
);
