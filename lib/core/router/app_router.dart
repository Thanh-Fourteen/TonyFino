import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/market/market_screen.dart';
import '../../features/money_hub/money_hub_screen.dart';
import '../../features/quick_add/quick_add_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import 'app_shell.dart';

/// `StatefulShellRoute.indexedStack` — 5 nhánh giữ state riêng (cuộn, form
/// đang mở) khi đổi tab qua lại, đúng thứ tự nav: Trang chủ · Giao dịch ·
/// Báo cáo · Túi tiền · Thị trường. Cài đặt là route riêng, ĐẨY LÊN TRÊN.
/// (Từng giữ 4 tab — "5 tab là lúc nav trông như thanh công cụ bảng tính" —
/// Tony chọn tab thứ 5 cho Thị trường ngày 2026-09-28: xem giá hằng ngày.)
///
/// `/quick-add` KHÔNG còn là tab: nhập liệu là một hành động, đẩy lên trên
/// từ nút cộng. Xem doc của `HomeScreen`.
final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) => const TransactionsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reports',
              builder: (context, state) => const ReportsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/money',
              builder: (context, state) => const MoneyHubScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/market',
              builder: (context, state) => const MarketScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    // Ngân sách THEO DANH MỤC không còn là tab: nó là một cách xem chi
    // tiêu, không phải một "nơi tiền nằm". Tab thứ 4 giờ là Túi tiền
    // (Ví/Quỹ/Hũ). Vào ngân sách từ Cài đặt.
    GoRoute(
      path: '/quick-add',
      builder: (context, state) => const QuickAddScreen(),
    ),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
  ],
);
