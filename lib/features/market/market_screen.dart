import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import 'coffee_price_screen.dart';
import 'gold_price_screen.dart';

/// Tab "Thị trường" ở thanh dưới — hai trang **Vàng · Cà phê** (Tony
/// 2026-09-28: "cho 2 trang đó ra ngoài"; trước đó chúng nằm sâu trong
/// Quản lý, hai chạm mới tới).
///
/// Không dựng AppBar riêng — `AppShell` đã có tiêu đề tab; cùng khuôn với
/// `MoneyHubScreen`. Nút tải lại nằm cuối hàng tab con, áp cho trang đang
/// xem.
class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TabBar(
                controller: _tab,
                labelPadding: EdgeInsets.symmetric(
                  horizontal: context.space.sm,
                ),
                tabs: const [
                  Tab(text: 'Vàng'),
                  Tab(text: 'Cà phê'),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Tải lại',
              icon: const Icon(kIconRefresh),
              onPressed: () => _tab.index == 0
                  ? refreshGoldPrices(ref)
                  : refreshCoffeePrices(ref),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [GoldPriceScreen(), CoffeePriceScreen()],
          ),
        ),
      ],
    );
  }
}
