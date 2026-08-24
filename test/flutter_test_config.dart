import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';

/// Áp dụng cho MỌI test dưới `test/` (cơ chế `flutter_test` per-directory-hierarchy).
///
/// Tách platform test (chữ thật, chạy local — soi mắt được) khỏi CI test
/// (chữ thành khối màu, ổn định xuyên nền tảng) — đây là cách diệt nguồn
/// giật golden số 1: khác biệt render font giữa máy dev và CI (TODOS.md
/// § Phase 5, "Nghiên cứu trước").
///
/// Quy ước theo README chính thức của alchemist (Recommended Setup Guide):
/// CI goldens (`test/**/goldens/ci/*.png`) commit vào git — CI cần chúng để
/// so sánh. Platform goldens (`test/**/goldens/linux/*.png` trên máy này)
/// KHÔNG commit — output phụ thuộc nền tảng, chỉ để dev soi mắt cục bộ.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // ignore: do_not_use_environment
  const isRunningInCi = bool.fromEnvironment('CI', defaultValue: false);

  // 🚨 Phase 22: `AppMascot`/`HeroGradientBackground` dùng `AnimationController`
  // lặp vô hạn (`repeat()`) cho hiệu ứng "thở"/nền trôi — TỰ KIỂM tra cờ trợ
  // năng `disableAnimations` (`MediaQuery.disableAnimationsOf`) trước khi
  // gọi `repeat()`, nên bật cờ này ở ĐÂY, một lần, cho MỌI test — không cần
  // sửa từng file test đang gọi `pumpAndSettle()` (vốn treo timeout mãi mãi
  // trước một animation không bao giờ dừng). Xem docs/decisions.md § Phase 22.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);

  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      platformGoldensConfig: const PlatformGoldensConfig(
        enabled: !isRunningInCi,
      ),
      ciGoldensConfig: const CiGoldensConfig(),
    ),
    run: testMain,
  );
}
