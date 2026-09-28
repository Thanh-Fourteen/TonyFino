import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/clock_provider.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/mascot/app_mascot.dart';
import '../../ui/mascot/mascot_mood.dart';
import '../home/domain/tet_season.dart';
import 'auth_controller.dart';

/// Màn Đăng nhập — trang RIÊNG, đứng chặn trước toàn bộ app cho tới khi
/// đăng nhập (xem `LoginGate`). Chỉ hiện ở lần mở đầu tiên và sau khi đăng
/// xuất; đã đăng nhập thì mở app thẳng vào Trang chủ, kể cả khi mất mạng.
///
/// Cùng khuôn với `OnboardingScreen` (Material trơn + SafeArea, không phải
/// route go_router): nó sống ở `MaterialApp.builder`, bên ngoài Navigator.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final now = ref.watch(clockProvider).now();

    return Material(
      color: context.colors.canvas,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.space.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppMascot(
                  mood: MascotMood.idle,
                  size: 112,
                  festive: isTetSeason(now),
                ),
                SizedBox(height: context.space.xl),
                Text(
                  'Đăng nhập TonyFino',
                  style: context.text.displayLarge,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.space.sm),
                Text(
                  'Đăng nhập bằng tài khoản Google để sao lưu sổ chi tiêu '
                  '(đã mã hoá) lên Google Drive và lấy lại khi đổi máy. Sổ '
                  'vẫn nằm trên máy này và dùng được cả khi không có mạng.',
                  style: context.text.bodyLarge?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.space.xxl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: auth.isWorking ? null : controller.signIn,
                    child: auth.isWorking
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.scheme.onPrimary,
                            ),
                          )
                        : const Text('Đăng nhập bằng Google'),
                  ),
                ),
                if (auth.errorMessage != null) ...[
                  SizedBox(height: context.space.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        kIconError,
                        size: 18,
                        color: context.colors.budgetOver,
                      ),
                      SizedBox(width: context.space.xs),
                      Expanded(
                        child: Text(
                          auth.errorMessage!,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.budgetOver,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // Lối thoát chỉ mở sau một lần thử không thành — xem
                // `AuthController.continueWithoutAccount`.
                if (auth.canSkip && !auth.isWorking) ...[
                  SizedBox(height: context.space.md),
                  TextButton(
                    onPressed: controller.continueWithoutAccount,
                    child: const Text(
                      'Vào app không tài khoản — đăng nhập sau ở Cài đặt',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
