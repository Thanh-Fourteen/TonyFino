import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/clock_provider.dart';
import '../../theme/context_ext.dart';
import '../../ui/mascot/app_mascot.dart';
import '../../ui/mascot/mascot_mood.dart';
import '../home/domain/tet_season.dart';

/// Màn chào mừng lần đầu (Phase 22, mới hoàn toàn — chưa từng tồn tại
/// trước phase này). Chỉ hiện qua `OnboardingGate`, không phải một route
/// go_router riêng (giữ router đơn giản, đúng khuôn `AppLockGate`/
/// `AppResumeHooks` đã dùng cho mọi lớp phủ toàn màn khác trong app).
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).now();
    return Material(
      color: context.colors.canvas,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.space.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppMascot(
                mood: MascotMood.idle,
                size: 120,
                festive: isTetSeason(now),
              ),
              SizedBox(height: context.space.xl),
              Text(
                'Chào mừng đến với TonyFino',
                style: context.text.displayLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.space.sm),
              Text(
                'Một cuốn sổ cái gõ bằng câu văn tiếng Việt — không tài khoản, '
                'không server, dữ liệu nằm hoàn toàn trên máy của bạn.',
                style: context.text.bodyLarge?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.space.xxl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onDone,
                  child: const Text('Bắt đầu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
