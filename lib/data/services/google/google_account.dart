import 'package:flutter/foundation.dart';

/// Thông tin tối thiểu về tài khoản Google đang đăng nhập — tách khỏi
/// `GoogleSignInAccount` của plugin để phần còn lại của app (controller, UI,
/// test) không phụ thuộc trực tiếp vào kiểu dữ liệu của `package:google_sign_in`.
@immutable
class GoogleAccount {
  const GoogleAccount({
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;

  @override
  bool operator ==(Object other) =>
      other is GoogleAccount &&
      other.email == email &&
      other.displayName == displayName &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(email, displayName, photoUrl);
}
