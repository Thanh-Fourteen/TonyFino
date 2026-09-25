import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'google_auth_config.dart';
import 'google_sign_in_service.dart';
import 'google_sign_in_service_impl.dart';

/// `GoogleSignIn.instance` là singleton toàn cục của plugin — provider này
/// chỉ tạo MỘT `GoogleSignInServiceImpl` bọc quanh nó cho suốt vòng đời app,
/// khớp đúng yêu cầu "gọi `initialize()` đúng một lần" của plugin.
final googleSignInServiceProvider = Provider<GoogleSignInService>(
  (ref) => GoogleSignInServiceImpl(
    serverClientId: GoogleAuthConfig.serverClientId,
  ),
);
