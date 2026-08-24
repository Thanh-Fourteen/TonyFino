import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/onboarding_screen.dart';
import '../../features/settings/settings_controller.dart';
import '../../features/transactions/transactions_providers.dart';

/// Bọc quanh `MaterialApp.router` (qua `builder:`, cùng khuôn `AppLockGate`)
/// — hiện `OnboardingScreen` MỘT LẦN thay vì nội dung app, khi ĐỒNG THỜI:
/// (1) `AppSettings.hasSeenOnboarding` còn `false`, VÀ (2) chưa có giao dịch
/// nào. Điều kiện (2) là chốt an toàn cho người dùng NÂNG CẤP từ bản trước
/// Phase 22 — họ cũng đọc `hasSeenOnboarding == false` (key chưa từng tồn
/// tại trong prefs) nhưng đã có dữ liệu thật, nên không bao giờ thấy màn
/// chào — chỉ người cài MỚI, chưa nhập gì mới thấy.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    if (settings.hasSeenOnboarding) return child;

    final transactions = ref.watch(transactionsWithCategoryProvider);
    // Đang tải: không quyết định gì — tránh nháy màn chào rồi biến mất ngay
    // khi stream đầu tiên trả về danh sách không rỗng.
    final hasAnyTransaction = transactions.value?.isNotEmpty ?? false;
    if (transactions.isLoading || hasAnyTransaction) return child;

    return OnboardingScreen(
      onDone: () =>
          ref.read(appSettingsProvider.notifier).setHasSeenOnboarding(true),
    );
  }
}
