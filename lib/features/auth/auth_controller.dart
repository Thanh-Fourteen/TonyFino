import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/google/google_providers.dart';

enum AuthStatus {
  /// Đang đọc trạng thái đã lưu — chưa quyết định gì, `LoginGate` không vẽ
  /// màn Đăng nhập lẫn nội dung app (tránh nháy màn này rồi biến mất).
  loading,

  /// Chưa đăng nhập (lần đầu mở app, hoặc vừa đăng xuất) — `LoginGate` chặn
  /// lại ở màn Đăng nhập.
  signedOut,

  signedIn,

  /// Đăng nhập Google không được và người dùng chọn vào app không tài khoản
  /// — xem [AuthController.continueWithoutAccount].
  skipped,
}

@immutable
class AuthState {
  const AuthState({
    required this.status,
    this.email,
    this.displayName,
    this.isWorking = false,
    this.errorMessage,
    this.canSkip = false,
  });

  static const loading = AuthState(status: AuthStatus.loading);

  final AuthStatus status;
  final String? email;
  final String? displayName;

  /// Đang chờ bảng chọn tài khoản của Google.
  final bool isWorking;

  /// Lỗi của lần đăng nhập gần nhất, hiện ngay dưới nút.
  final String? errorMessage;

  /// Đã thử đăng nhập mà không được (lỗi hay huỷ) — màn Đăng nhập mới hiện
  /// lối "vào app không tài khoản". Lần đầu mở app thì chưa có lối này:
  /// phải thử đăng nhập trước.
  final bool canSkip;

  bool get passesGate =>
      status == AuthStatus.signedIn || status == AuthStatus.skipped;
}

/// Đăng nhập Google của CẢ APP — tách khỏi `BackupController` (nơi nó từng
/// sống, và vì thế cứ mở Cài đặt là plugin khởi tạo + tự thử đăng nhập
/// ngầm). Tony 2026-09-28: "đưa phần đăng nhập ra một trang riêng, lần đầu
/// phải đăng nhập rồi mới vào app".
///
/// Trạng thái "đã đăng nhập" LƯU XUỐNG prefs (email + tên), không hỏi lại
/// Google mỗi lần mở app: sổ chi tiêu là offline-first, mở app lúc mất mạng
/// không được phép bị chặn ở màn Đăng nhập chỉ vì không xác minh lại được
/// phiên. Phiên thật chỉ cần lúc gọi Drive, và `GoogleSignInService` tự khôi
/// phục nó đúng lúc đó.
class AuthController extends Notifier<AuthState> {
  static const _emailKey = 'tonyfino_auth_email';
  static const _nameKey = 'tonyfino_auth_display_name';
  static const _skippedKey = 'tonyfino_auth_skipped';

  final _prefs = SharedPreferencesAsync();

  @override
  AuthState build() {
    unawaited(_load());
    return AuthState.loading;
  }

  Future<void> _load() async {
    final email = await _prefs.getString(_emailKey);
    if (email != null) {
      state = AuthState(
        status: AuthStatus.signedIn,
        email: email,
        displayName: await _prefs.getString(_nameKey),
      );
      return;
    }
    final skipped = await _prefs.getBool(_skippedKey) ?? false;
    state = AuthState(
      status: skipped ? AuthStatus.skipped : AuthStatus.signedOut,
    );
  }

  Future<void> signIn() async {
    if (state.isWorking) return;
    final previous = state;
    state = AuthState(
      status: previous.status,
      email: previous.email,
      displayName: previous.displayName,
      isWorking: true,
      canSkip: previous.canSkip,
    );
    final result = await ref.read(googleSignInServiceProvider).signIn();
    await result.when(
      ok: (account) async {
        await _prefs.setString(_emailKey, account.email);
        final name = account.displayName;
        if (name == null) {
          await _prefs.remove(_nameKey);
        } else {
          await _prefs.setString(_nameKey, name);
        }
        await _prefs.remove(_skippedKey);
        state = AuthState(
          status: AuthStatus.signedIn,
          email: account.email,
          displayName: name,
        );
      },
      err: (error) async {
        state = AuthState(
          status: previous.status,
          email: previous.email,
          displayName: previous.displayName,
          errorMessage: error.message,
          // Mọi lần KHÔNG đăng nhập được đều mở lối vào — kể cả "huỷ".
          // Đo trên máy ảo: khi luồng của Google tự hỏng giữa chừng
          // ("Something went wrong", Play Services treo), đường thoát duy
          // nhất là nút Back, và plugin báo đúng mã "huỷ". Chỉ mở lối vào
          // cho lỗi "thật" thì máy đó bị khoá ngoài sổ của chính mình.
          canSkip: true,
        );
      },
    );
  }

  /// Chỉ dùng được sau một lần thử đăng nhập không thành ([AuthState.canSkip]).
  ///
  /// 🚨 Lối thoát này bắt buộc phải có: nếu Play Services trên máy hỏng hay
  /// cấu hình OAuth lệch chữ ký, một màn Đăng nhập không có đường vòng sẽ
  /// khoá Tony ngoài chính sổ chi tiêu của mình — dữ liệu vẫn nằm trên máy
  /// mà không mở được. Đăng nhập lại được bất cứ lúc nào ở Cài đặt.
  Future<void> continueWithoutAccount() async {
    if (!state.canSkip) return;
    await _prefs.setBool(_skippedKey, true);
    state = const AuthState(status: AuthStatus.skipped);
  }

  /// Đăng xuất = quay về màn Đăng nhập. Dữ liệu trên máy không đụng tới.
  Future<void> signOut() async {
    try {
      await ref.read(googleSignInServiceProvider).signOut();
    } catch (_) {
      // Thu hồi quyền phía Google hỏng (mất mạng, không Play Services) vẫn
      // phải đăng xuất được ở phía app — người dùng đã bấm Đăng xuất.
    }
    await _prefs.remove(_emailKey);
    await _prefs.remove(_nameKey);
    await _prefs.remove(_skippedKey);
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
