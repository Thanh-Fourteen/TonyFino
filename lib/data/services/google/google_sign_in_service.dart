import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../core/result/result.dart';
import 'google_account.dart';

/// Bọc `package:google_sign_in` — tách interface ra để phần gọi (controller)
/// test được bằng fake, KHÔNG cần chạm plugin thật (giống cách
/// `backupHealthProbeProvider` bọc SAF thật ở tính năng sao lưu sẵn có).
/// `google_sign_in` là singleton toàn cục (`GoogleSignIn.instance`), không
/// có seam để dependency-inject trực tiếp, nên interface này LÀ seam.
abstract interface class GoogleSignInService {
  /// Tài khoản đang đăng nhập, `null` nếu chưa/không còn đăng nhập.
  GoogleAccount? get currentAccount;

  /// Bắn mỗi khi trạng thái đăng nhập đổi (đăng nhập/đăng xuất, kể cả do
  /// `attemptLightweightAuthentication` lúc khởi động khôi phục phiên cũ).
  Stream<GoogleAccount?> get accountChanges;

  /// Gọi đúng một lần trước khi dùng bất kỳ method nào khác (thường ở
  /// `build()` của controller).
  Future<void> initialize();

  Future<Result<GoogleAccount, AppError>> signIn();

  Future<void> signOut();

  /// `http.Client` đã có quyền `drive.appdata` — hỏi xin quyền (hiện màn
  /// đồng ý) nếu chưa có. Gọi đủ `close()` sau khi dùng xong.
  Future<Result<http.Client, AppError>> authorizedDriveClient();
}
