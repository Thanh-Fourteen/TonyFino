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
  final _accountController = StreamController<GoogleAccount?>.broadcast();

  GoogleAccount? _currentAccount;
  GoogleSignInAccount? _rawAccount;

  @override
  GoogleAccount? get currentAccount => _currentAccount;

  @override
  Stream<GoogleAccount?> get accountChanges => _accountController.stream;

  @override
  Future<void> initialize() async {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize(serverClientId: _serverClientId);
    signIn.authenticationEvents.listen(_onAuthenticationEvent);
    // Khôi phục phiên đã đăng nhập trước đó (nếu có) mà không hiện UI nào.
    unawaited(signIn.attemptLightweightAuthentication());
  }

  void _onAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        _rawAccount = event.user;
        _currentAccount = GoogleAccount(
          email: event.user.email,
          displayName: event.user.displayName,
          photoUrl: event.user.photoUrl,
        );
      case GoogleSignInAuthenticationEventSignOut():
        _rawAccount = null;
        _currentAccount = null;
    }
    _accountController.add(_currentAccount);
  }

  @override
  Future<Result<GoogleAccount, AppError>> signIn() async {
    try {
      final account = await GoogleSignIn.instance.authenticate();
      _rawAccount = account;
      _currentAccount = GoogleAccount(
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
      _accountController.add(_currentAccount);
      return Result.ok(_currentAccount!);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const Result.err(AppError('Đã huỷ đăng nhập.'));
      }
      return Result.err(
        AppError('Đăng nhập Google thất bại: ${e.description ?? e.code}', cause: e),
      );
    }
  }

  @override
  Future<void> signOut() async {
    // `disconnect()` thay vì `signOut()` — thu hồi luôn quyền đã cấp, để lần
    // đăng nhập lại sau xin quyền `drive.appdata` từ đầu, không kẹt ở trạng
    // thái "đã cấp quyền" ma từ phiên cũ.
    await GoogleSignIn.instance.disconnect();
    _rawAccount = null;
    _currentAccount = null;
    _accountController.add(null);
  }

  @override
  Future<Result<http.Client, AppError>> authorizedDriveClient() async {
    final account = _rawAccount;
    if (account == null) {
      return const Result.err(AppError('Chưa đăng nhập Google.'));
    }
    try {
      final authClient = account.authorizationClient;
      final authorization =
          await authClient.authorizationForScopes(_driveScopes) ??
          await authClient.authorizeScopes(_driveScopes);
      return Result.ok(authorization.authClient(scopes: _driveScopes));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const Result.err(AppError('Đã huỷ cấp quyền truy cập Drive.'));
      }
      return Result.err(
        AppError('Xin quyền Google Drive thất bại: ${e.description ?? e.code}', cause: e),
      );
    }
  }
}
