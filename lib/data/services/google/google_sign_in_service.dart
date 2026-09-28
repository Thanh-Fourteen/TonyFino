import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../core/result/result.dart';
import 'google_account.dart';

/// Bọc `package:google_sign_in` — tách interface ra để phần gọi (controller)
/// test được bằng fake, KHÔNG cần chạm plugin thật (giống cách
/// `backupHealthProbeProvider` bọc SAF thật ở tính năng sao lưu sẵn có).
/// `google_sign_in` là singleton toàn cục (`GoogleSignIn.instance`), không
/// có seam để dependency-inject trực tiếp, nên interface này LÀ seam.
///
/// 🚨 Không method nào tự bật giao diện đăng nhập ngầm. Bản trước khởi tạo
/// plugin kèm `attemptLightweightAuthentication()` ngay khi màn Cài đặt
/// dựng lên, nên cứ vào Cài đặt là thấy bảng "Đang đăng nhập…" của Google
/// trồi lên (Tony: "cứ vào trang cài đặt là load đăng nhập"). Giờ đăng nhập
/// chỉ xảy ra khi người dùng bấm, ở màn Đăng nhập hoặc Cài đặt; phiên cũ chỉ
/// được khôi phục lúc THẬT SỰ cần gọi Drive ([authorizedDriveClient]).
abstract interface class GoogleSignInService {
  /// Đăng nhập tương tác (bảng chọn tài khoản của Google). Tự khởi tạo
  /// plugin ở lần gọi đầu.
  Future<Result<GoogleAccount, AppError>> signIn();

  Future<void> signOut();

  /// `http.Client` đã có quyền `drive.appdata` — khôi phục phiên đã đăng
  /// nhập (không UI) nếu tiến trình này chưa có, hỏi xin quyền (hiện màn
  /// đồng ý) nếu chưa có. Gọi đủ `close()` sau khi dùng xong.
  Future<Result<http.Client, AppError>> authorizedDriveClient();
}

/// Người dùng đóng bảng chọn tài khoản (hoặc bấm Back khỏi màn lỗi của
/// chính Google — plugin báo cùng một mã). Tách riêng để thông báo đúng
/// giọng "đã huỷ" thay vì "thất bại".
class GoogleSignInCanceled extends AppError {
  const GoogleSignInCanceled() : super('Đã huỷ đăng nhập Google.');
}
