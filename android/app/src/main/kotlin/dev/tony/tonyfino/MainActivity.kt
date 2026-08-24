package dev.tony.tonyfino

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/// 🚨 PHẢI là `FlutterFragmentActivity`, KHÔNG phải `FlutterActivity`.
///
/// `local_auth` gọi `BiometricPrompt` của AndroidX, mà `BiometricPrompt`
/// gắn vào một `FragmentManager` — chỉ `FragmentActivity` mới có. Chạy trên
/// `FlutterActivity` thường thì `authenticate()` thất bại NGAY, không hiện
/// hộp thoại vân tay nào cả: đúng triệu chứng Tony báo ("nút mở khoá vân
/// tay chưa dùng được"). Chỉ lộ ra khi chạy tay trên máy CÓ vân tay đã đăng
/// ký — widget test dùng `LocalAuthPlatform` giả nên không bao giờ chạm tới
/// tầng Android này.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SafBackupChannel.register(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}
