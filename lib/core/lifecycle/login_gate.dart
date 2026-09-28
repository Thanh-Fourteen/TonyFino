import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../theme/context_ext.dart';

/// Bọc quanh nội dung app (qua `MaterialApp.builder`, cùng khuôn
/// `OnboardingGate`/`AppLockGate`) — chưa đăng nhập thì chỉ thấy
/// [LoginScreen], không lối nào vào app (Tony 2026-09-28: "lần đầu phải
/// đăng nhập rồi mới vào app").
///
/// Đặt TRONG `AppLockGate`: khoá vân tay vẫn đứng trước mọi thứ, kể cả màn
/// Đăng nhập (màn này hiện tên + email tài khoản sau khi đăng xuất/đăng
/// nhập lại — không cho người cầm máy thấy khi chưa mở khoá).
class LoginGate extends ConsumerWidget {
  const LoginGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return switch (auth.status) {
      // Vài mili-giây đọc prefs: nền trơn, không nháy màn Đăng nhập ở người
      // đã đăng nhập, cũng không lộ nội dung app ở người chưa.
      AuthStatus.loading => ColoredBox(color: context.colors.canvas),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.signedIn || AuthStatus.skipped => child,
    };
  }
}
