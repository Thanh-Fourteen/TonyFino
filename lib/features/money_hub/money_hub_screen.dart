import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_bottom_nav.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../jars/jars_screen.dart';
import '../jars/widgets/jar_edit_sheet.dart';
import 'money_hub_tab_provider.dart';
import '../savings/savings_screen.dart';
import '../savings/widgets/savings_goal_edit_sheet.dart';
import '../wallets/wallets_screen.dart';
import '../wallets/widgets/transfer_sheet.dart';
import '../wallets/widgets/wallet_edit_sheet.dart';

/// Tab "Túi tiền" — ba trang đứng cạnh nhau: **Ví · Quỹ · Hũ**.
///
/// Gom lại một chỗ vì cả ba trả lời cùng một câu hỏi ("tiền của tôi đang
/// nằm ở đâu và được chia thế nào"), chỉ khác lát cắt: ví là nơi tiền THỰC
/// SỰ nằm, quỹ là tiền để dành cho một mục tiêu, hũ là tỉ lệ chia thu nhập
/// cho kỳ này.
///
/// Giữ bottom nav ở 4 tab — TODOS.md ghi rõ "5 tab là lúc nav bắt đầu trông
/// như thanh công cụ bảng tính".
class MoneyHubScreen extends ConsumerStatefulWidget {
  const MoneyHubScreen({super.key});

  @override
  ConsumerState<MoneyHubScreen> createState() => _MoneyHubScreenState();
}

class _MoneyHubScreenState extends ConsumerState<MoneyHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 3,
      vsync: this,
      // Mở đúng trang mà thẻ tổng quan ở Trang chủ vừa yêu cầu.
      initialIndex: ref.read(moneyHubTabProvider),
    );
    // Rebuild khi đổi tab để FAB đổi theo tab đang xem.
    _tab.addListener(() {
      setState(() {});
      // Nhớ tab đang xem để lần sau quay lại đúng chỗ.
      ref.read(moneyHubTabProvider.notifier).select(_tab.index);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      // KHÔNG dựng AppBar riêng: `AppShell` đã có một cái mang đúng tiêu đề
      // tab ("Túi tiền") cùng nút tìm kiếm/cài đặt. Thêm AppBar thứ hai là
      // hai dòng chữ "Túi tiền" chồng nhau — đúng lỗi tiêu đề lặp đã sửa ở
      // màn Báo cáo/Ngân sách trước đó.
      floatingActionButton: _fab(context, bottomInset),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tab,
                  // 🚨 Cỡ chữ lớn thì tab phải CUỘN được.
                  //
                  // Bốn tab chia đều bề ngang: ở cỡ chữ hệ thống 2.0× (Cài
                  // đặt trợ năng) "Hạn mức" bị cắt cụt thành "Hạn mứ" — mất
                  // luôn dấu, đúng loại lỗi cổng Phase 24 canh. Ngưỡng 1.3
                  // vì đó là mốc bắt đầu thiếu chỗ; dưới ngưỡng vẫn chia đều
                  // (đẹp hơn, và bốn tab ngắn thì không cần cuộn).
                  isScrollable:
                      MediaQuery.textScalerOf(context).scale(14) > 14 * 1.3,
                  labelPadding: EdgeInsets.symmetric(
                    horizontal: context.space.sm,
                  ),
                  tabs: const [
                    Tab(text: 'Ví'),
                    Tab(text: 'Quỹ'),
                    Tab(text: 'Hũ'),
                  ],
                ),
              ),
              // Chuyển khoản chỉ có nghĩa ở tab Ví — giữ chỗ cố định để
              // thanh tab không nhảy ngang khi đổi tab.
              SizedBox(
                width: 48,
                child: _tab.index == 0
                    ? IconButton(
                        icon: const Icon(kIconSwapHoriz),
                        tooltip: 'Chuyển khoản giữa ví',
                        onPressed: () => showTransferSheet(context),
                      )
                    : null,
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                WalletsScreen(embedded: true),
                // `embedded: true` để danh sách chừa chỗ cho thanh điều
                // hướng NỔI — thiếu nó thì quỹ cuối cùng nằm khuất dưới
                // thanh nav, cuộn hết cỡ vẫn không thấy.
                SavingsGoalsTab(embedded: true),
                JarsScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// FAB đổi theo tab — mỗi trang có đúng một hành động chính.
  ///
  /// 🚨 FAB của tab con PHẢI dựng ở ĐÂY, không phải trong Scaffold của màn
  /// con. `JarsScreen` từng tự khai FAB "Thêm hũ": Scaffold lồng trong
  /// Scaffold neo FAB theo mép dưới của CHÍNH NÓ, không biết gì về thanh
  /// điều hướng nổi phía trên — nút bị che gần hết, đúng lỗi Tony báo. Ở
  /// đây có sẵn `padding` chừa `kBottomNavReservedHeight`.
  Widget? _fab(BuildContext context, double bottomInset) {
    final padding = EdgeInsets.only(
      bottom: kBottomNavReservedHeight + bottomInset,
    );
    return switch (_tab.index) {
      0 => Padding(
        padding: padding,
        child: FloatingActionButton(
          onPressed: () => showWalletEditSheet(context: context),
          tooltip: 'Thêm ví',
          child: const Icon(kIconAdd),
        ),
      ),
      1 => Padding(
        padding: padding,
        child: FloatingActionButton(
          onPressed: () => showSavingsGoalEditSheet(context: context),
          tooltip: 'Thêm mục tiêu',
          child: const Icon(kIconAdd),
        ),
      ),
      2 => Padding(
        padding: padding,
        child: FloatingActionButton(
          onPressed: () => showJarEditSheet(context: context),
          tooltip: 'Thêm hũ',
          child: const Icon(kIconAdd),
        ),
      ),
      _ => null,
    };
  }
}
