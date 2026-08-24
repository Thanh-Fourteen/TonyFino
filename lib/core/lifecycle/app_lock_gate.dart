import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/biometric/biometric_service.dart';
import 'app_lock_session.dart';
import '../../features/settings/settings_controller.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';

/// Bọc quanh `MaterialApp.router` (qua `builder:`) — khi
/// `AppSettings.biometricLockEnabled` bật, che TOÀN BỘ nội dung app bằng một
/// màn khoá cho tới khi xác thực thành công. Khoá lại mỗi lần app rời khỏi
/// foreground (`AppLifecycleState.paused`), không chỉ lúc khởi động lạnh —
/// đúng kỳ vọng của một khoá ứng dụng tài chính.
///
/// `unavailable` (máy mất khả năng sinh trắc học SAU khi đã bật cờ — vd. gỡ
/// vân tay đã đăng ký) coi như ĐÃ MỞ KHOÁ — fail open, không khoá cứng người
/// dùng khỏi chính app của họ vì một trục trặc phần cứng, xem
/// docs/decisions.md § Phase 12.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  final _biometric = BiometricService();

  bool _authenticating = false;

  /// Đã tự động hỏi vân tay cho LẦN KHOÁ NÀY chưa.
  ///
  /// Thiếu cờ này là bug Tony báo ("bấm vào là đứng luôn, không thoát ra
  /// được"): `build()` lên lịch `_tryUnlock()` mỗi lần dựng lại khi không
  /// đang xác thực, nên NGAY khi người dùng bấm huỷ hộp thoại vân tay,
  /// `_authenticating` về false → dựng lại → hỏi lại lập tức. Vòng lặp vô
  /// hạn, không có cách nào thoát. Test `app_lock_gate_test` tái hiện đúng
  /// bằng `pumpAndSettle timed out`.
  bool _autoPrompted = false;

  /// Lần thử trước đã thất bại — hiện lời nhắc thay vì im lặng, để người
  /// dùng biết vì sao vẫn còn ở màn khoá.
  bool _lastAttemptFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    if (!ref.read(appSettingsProvider).biometricLockEnabled) return;
    ref.read(appLockSessionProvider.notifier).lock();
    setState(() {
      // Khoá lại = một lần khoá MỚI, được phép tự hỏi lại đúng một lần.
      _autoPrompted = false;
      _lastAttemptFailed = false;
    });
  }

  Future<void> _tryUnlock() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _autoPrompted = true;
    });
    final result = await _biometric.authenticate();
    if (!mounted) return;
    final ok =
        result == BiometricAuthResult.success ||
        result == BiometricAuthResult.unavailable;
    if (ok) ref.read(appLockSessionProvider.notifier).trust();
    setState(() {
      _authenticating = false;
      _lastAttemptFailed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(appSettingsProvider).biometricLockEnabled;
    final locked = enabled && !ref.watch(appLockSessionProvider);
    if (!locked) return widget.child;

    // CHỈ tự hỏi một lần cho mỗi lần khoá. Sau đó người dùng chủ động bấm
    // — nếu không, huỷ hộp thoại là nó bật lại ngay và app trông như treo.
    if (!_authenticating && !_autoPrompted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryUnlock();
      });
    }
    return _LockScreen(
      authenticating: _authenticating,
      failed: _lastAttemptFailed,
      onRetry: _tryUnlock,
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.authenticating,
    required this.failed,
    required this.onRetry,
  });

  final bool authenticating;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.canvas,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(context.space.screenHorizontal),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  kIconFingerprint,
                  size: 64,
                  color: context.colors.onSurfaceVariant,
                ),
                SizedBox(height: context.space.lg),
                Text('TonyFino đã khoá', style: context.text.titleLarge),
                SizedBox(height: context.space.sm),
                Text(
                  failed
                      ? 'Chưa xác thực được — bấm "Thử lại" khi sẵn sàng.'
                      : 'Xác thực để tiếp tục',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: failed
                        ? context.colors.budgetOver
                        : context.colors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: context.space.xl),
                FilledButton(
                  onPressed: authenticating ? null : onRetry,
                  child: Text(
                    authenticating
                        ? 'Đang xác thực…'
                        : failed
                        ? 'Thử lại'
                        : 'Mở khoá',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
