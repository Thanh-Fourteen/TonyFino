import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../../../core/result/result.dart';
import 'google_account.dart';
import 'google_sign_in_service.dart';

const _driveScopes = [drive.DriveApi.driveAppdataScope];

/// Bản thật của [GoogleSignInService], gọi thẳng `GoogleSignIn.instance` —
/// KHÔNG test trực tiếp bằng widget/unit test, giống cách `AndroidSafDestination`
/// (SAF thật) và `ShareSheetDestination` (`share_plus`) của tính năng sao
/// lưu sẵn có: cần Activity/Play Services thật, chỉ kiểm tay trên máy.
class GoogleSignInServiceImpl implements GoogleSignInService {
  GoogleSignInServiceImpl({required this._serverClientId});

  final String _serverClientId;

  /// Plugin đòi `initialize()` ĐÚNG MỘT LẦN trước mọi lệnh khác — nhớ lại
  /// Future của lần đầu, mọi lối vào cùng chờ nó.
  Future<void>? _initialized;
  GoogleSignInAccount? _rawAccount;

  Future<void> _ensureInitialized() => _initialized ??= GoogleSignIn.instance
      .initialize(serverClientId: _serverClientId);

  static GoogleAccount _toAccount(GoogleSignInAccount account) => GoogleAccount(
    email: account.email,
    displayName: account.displayName,
    photoUrl: account.photoUrl,
  );

  static AppError _errorFrom(GoogleSignInException e, String action) {
    if (e.code == GoogleSignInExceptionCode.canceled) {
      return AppError('Đã huỷ $action.', cause: e);
    }
    return AppError(
      '${action[0].toUpperCase()}${action.substring(1)} thất bại: '
      '${e.description ?? e.code.name}',
      cause: e,
    );
  }

  @override
  Future<Result<GoogleAccount, AppError>> signIn() async {
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate();
      _rawAccount = account;
      return Result.ok(_toAccount(account));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const Result.err(GoogleSignInCanceled());
      }
      return Result.err(_errorFrom(e, 'đăng nhập Google'));
    } catch (e) {
      // Máy không có Google Play Services, không có mạng lúc khởi tạo… —
      // plugin ném lỗi nền tảng thường, không phải `GoogleSignInException`.
      return Result.err(AppError('Đăng nhập Google thất bại: $e', cause: e));
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    // `disconnect()` thay vì `signOut()` — thu hồi luôn quyền đã cấp, để lần
    // đăng nhập lại sau xin quyền `drive.appdata` từ đầu, không kẹt ở trạng
    // thái "đã cấp quyền" ma từ phiên cũ.
    await GoogleSignIn.instance.disconnect();
    _rawAccount = null;
  }

  @override
  Future<Result<http.Client, AppError>> authorizedDriveClient() async {
    try {
      await _ensureInitialized();
      // Tiến trình mới (mở lại app) chưa có tài khoản trong bộ nhớ: thử khôi
      // phục phiên cũ không UI trước, không được thì mới hỏi chọn tài khoản
      // — người dùng vừa bấm một nút Drive nên hiện UI lúc này là đúng lúc.
      final account =
          _rawAccount ??
          await GoogleSignIn.instance.attemptLightweightAuthentication() ??
          await GoogleSignIn.instance.authenticate();
      _rawAccount = account;
      final authClient = account.authorizationClient;
      final authorization =
          await authClient.authorizationForScopes(_driveScopes) ??
          await authClient.authorizeScopes(_driveScopes);
      return Result.ok(authorization.authClient(scopes: _driveScopes));
    } on GoogleSignInException catch (e) {
      return Result.err(_errorFrom(e, 'xin quyền Google Drive'));
    }
  }
}
