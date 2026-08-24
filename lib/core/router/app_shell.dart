import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/manage/manage_screen.dart';
import '../../features/settings/backup/backup_health_provider.dart';
import '../../features/settings/settings_controller.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/ambient_background.dart';
import 'app_bottom_nav.dart';

/// Chrome dùng chung cho 4 tab: app bar (tiêu đề tab hiện tại + icon Cài đặt)
/// + `AppBottomNav` nổi trên `GlassSurface`. `extendBody: true` để nội dung
/// cuộn TRÀN xuống dưới thanh nav mờ (Android 15+ edge-to-edge, TODOS.md
/// § Bố cục) — từng scroll view trong mỗi tab tự chừa đệm đáy
/// (`kBottomNavReservedHeight`), KHÔNG có `SafeArea` bao trùm ở đây.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(backupHealthProvider);
    final hideAmounts = ref.watch(appSettingsProvider).hideAmounts;
    // [AmbientBackground] bọc NGOÀI Scaffold, không nằm trong `body`: cả
    // Scaffold lẫn AppBar đều để trong suốt, nên nếu quầng sáng chỉ vẽ trong
    // body thì vùng AppBar hở ra nền trần của app.
    return AmbientBackground(
      child: Scaffold(
        extendBody: true,
        // Trong suốt để [AmbientBackground] phía dưới là thứ duy nhất vẽ nền —
        // nếu để canvas đục ở đây thì quầng sáng bị che mất hoàn toàn.
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(kNavTabs[navigationShell.currentIndex].label),
          actions: [
            IconButton(
              icon: const Icon(kIconSearch),
              tooltip: 'Tìm giao dịch',
              onPressed: () => context.push('/search'),
            ),
            // Che/hiện số tiền — một chạm, ngay nơi dễ với nhất. Tony ngồi
            // quán hoặc đưa máy cho người khác xem thì bấm một cái là mọi
            // con số thành `••••••` (xem `AmountVisibility`).
            IconButton(
              icon: Icon(hideAmounts ? kIconVisibilityOff : kIconVisibility),
              tooltip: hideAmounts ? 'Hiện số tiền' : 'Ẩn số tiền',
              onPressed: () => ref
                  .read(appSettingsProvider.notifier)
                  .setHideAmounts(!hideAmounts),
            ),
            // "Quản lý" ở ngay thanh trên cùng, KHÔNG chôn trong Cài đặt:
            // tạo/sửa ví, danh mục, hạn mức là việc hằng tuần, còn Cài đặt
            // là nơi chỉnh cách app chạy — hai loại việc khác tần suất hẳn
            // nhau thì không nên chung một cửa (xem `ManageScreen`).
            IconButton(
              icon: const Icon(kIconTune),
              tooltip: 'Quản lý',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ManageScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(kIconSettings),
              tooltip: 'Cài đặt',
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        body: Column(
          children: [
            if (health.healthy == false)
              _BackupHealthBanner(onTap: () => context.push('/settings')),
            Expanded(child: navigationShell),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) => navigationShell.goBranch(
            index,
            // Chạm lại tab đang đứng thì về root của nhánh đó (không giữ
            // lịch sử điều hướng con) — hành vi chuẩn của bottom nav.
            initialLocation: index == navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}

/// H6: banner CỐ ĐỊNH, không có nút tự tắt — chỉ biến mất khi
/// [backupHealthProvider] tự xác nhận lại mạnh khoẻ (xem doc comment ở
/// `BackupHealthController`). Đặt ở `AppShell` (không phải riêng Settings)
/// để không thể lướt qua 4 tab mà không thấy.
class _BackupHealthBanner extends StatelessWidget {
  const _BackupHealthBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.budgetOver,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.screenHorizontal,
            vertical: context.space.sm,
          ),
          child: Row(
            children: [
              const Icon(kIconWarning, color: Colors.white, size: 20),
              SizedBox(width: context.space.sm),
              Expanded(
                child: Text(
                  'Sao lưu tự động đang hỏng — chạm để kiểm tra',
                  style: context.text.bodyMedium?.copyWith(color: Colors.white),
                ),
              ),
              const Icon(kIconChevronRight, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
