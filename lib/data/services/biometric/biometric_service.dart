import 'package:local_auth/local_auth.dart';

/// Kết quả một lần thử xác thực vân tay/khuôn mặt/mã khoá thiết bị.
/// `unavailable` gộp cả ba lý do máy không dùng được sinh trắc học (không có
/// cảm biến, có cảm biến nhưng chưa đăng ký vân tay nào, hoặc máy không có
/// PIN/pattern/mật khẩu nào để làm phương án dự phòng) — Settings xử lý cả
/// ba như nhau: ẩn/tắt toggle, không phân biệt lý do cụ thể với người dùng.
enum BiometricAuthResult { success, failed, unavailable }

/// Bọc `local_auth` 3.x — API mới ném `LocalAuthException` thay vì trả
/// `false`/`PlatformException` cho lỗi hệ thống (xem docs/decisions.md §
/// Phase 12). Test bằng `LocalAuthPlatform` giả (widget test), KHÔNG cần
/// cảm biến vân tay thật trên emulator.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on LocalAuthException {
      return false;
    }
  }

  Future<BiometricAuthResult> authenticate() async {
    try {
      final success = await _auth.authenticate(
        localizedReason: 'Xác thực để mở TonyFino',
      );
      return success ? BiometricAuthResult.success : BiometricAuthResult.failed;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noCredentialsSet:
          return BiometricAuthResult.unavailable;
        default:
          return BiometricAuthResult.failed;
      }
    }
  }
}
