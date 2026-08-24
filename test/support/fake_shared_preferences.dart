import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// `SharedPreferencesAsync()` (dùng ở `AppSettingsController` Phase 6 và
/// `RecentInputsController` Phase 8) ném lỗi ĐỒNG BỘ ("Bad state: The
/// SharedPreferencesAsyncPlatform instance must be set") ngay khi khởi tạo
/// nếu chưa có platform instance nào đăng ký — không tự có sẵn trong môi
/// trường `flutter_test` (khác `flutter_secure_storage`/DB, vốn được override
/// thẳng qua provider). Gọi hàm này trong `setUp()` của MỌI test pump một
/// widget có khả năng chạm tới `appSettingsProvider`/`recentInputsProvider`.
void installFakeSharedPreferences() {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
}
