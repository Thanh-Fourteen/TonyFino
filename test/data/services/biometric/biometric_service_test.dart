import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:tonyfino/data/services/biometric/biometric_service.dart';

/// Fake `LocalAuthPlatform` — ba kịch bản TODOS.md Phase 12 yêu cầu tường
/// minh ("thành công/thất bại/không có cảm biến"), không cần cảm biến vân
/// tay thật (xem docs/decisions.md § Phase 12).
class _FakeLocalAuthPlatform extends LocalAuthPlatform {
  _FakeLocalAuthPlatform({
    this.supported = true,
    this.authenticateResult,
    this.throwCode,
  });

  final bool supported;
  final bool? authenticateResult;
  final LocalAuthExceptionCode? throwCode;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    if (throwCode != null) {
      throw LocalAuthException(code: throwCode!);
    }
    return authenticateResult!;
  }
}

void main() {
  test('authenticate() thành công → success', () async {
    LocalAuthPlatform.instance = _FakeLocalAuthPlatform(
      authenticateResult: true,
    );
    final service = BiometricService();
    expect(await service.authenticate(), BiometricAuthResult.success);
  });

  test(
    'authenticate() người dùng thất bại thử thách → failed (không throw)',
    () async {
      LocalAuthPlatform.instance = _FakeLocalAuthPlatform(
        authenticateResult: false,
      );
      final service = BiometricService();
      expect(await service.authenticate(), BiometricAuthResult.failed);
    },
  );

  test(
    'authenticate() máy không có cảm biến → unavailable, KHÔNG ném ra ngoài',
    () async {
      LocalAuthPlatform.instance = _FakeLocalAuthPlatform(
        throwCode: LocalAuthExceptionCode.noBiometricHardware,
      );
      final service = BiometricService();
      expect(await service.authenticate(), BiometricAuthResult.unavailable);
    },
  );

  test(
    'authenticate() có cảm biến nhưng chưa đăng ký vân tay nào → unavailable',
    () async {
      LocalAuthPlatform.instance = _FakeLocalAuthPlatform(
        throwCode: LocalAuthExceptionCode.noBiometricsEnrolled,
      );
      final service = BiometricService();
      expect(await service.authenticate(), BiometricAuthResult.unavailable);
    },
  );

  test(
    'authenticate() người dùng huỷ → failed, không phải unavailable',
    () async {
      LocalAuthPlatform.instance = _FakeLocalAuthPlatform(
        throwCode: LocalAuthExceptionCode.userCanceled,
      );
      final service = BiometricService();
      expect(await service.authenticate(), BiometricAuthResult.failed);
    },
  );

  test('isSupported() phản ánh đúng LocalAuthPlatform', () async {
    LocalAuthPlatform.instance = _FakeLocalAuthPlatform(supported: false);
    expect(await BiometricService().isSupported(), isFalse);

    LocalAuthPlatform.instance = _FakeLocalAuthPlatform(supported: true);
    expect(await BiometricService().isSupported(), isTrue);
  });
}
