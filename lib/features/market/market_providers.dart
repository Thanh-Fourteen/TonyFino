import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/clock_provider.dart';
import '../../data/services/market/coffee_prices.dart';
import '../../data/services/market/gold_prices.dart';
import '../../data/services/market/market_repository.dart';
import '../../data/services/market/price_point.dart';
import 'market_snapshot.dart';

/// Giá vàng trong nước đổi vài lần một ngày — 2 phút/lần là đủ "sống" mà
/// không gõ cửa nguồn liên tục.
class GoldBoardController extends LiveMarketNotifier<GoldBoard> {
  @override
  Duration get refreshEvery => const Duration(minutes: 2);

  @override
  Future<GoldBoard> fetch(MarketRepository repo) => repo.goldBoard();

  @override
  Future<GoldBoard?> fetchCached(MarketRepository repo) =>
      repo.cachedGoldBoard();
}

final goldBoardProvider =
    NotifierProvider.autoDispose<
      GoldBoardController,
      MarketSnapshot<GoldBoard>
    >(GoldBoardController.new);

/// Lịch sử một dòng giá vàng; khoá = (mã, giá bán ra?).
final goldHistoryProvider = FutureProvider.autoDispose
    .family<List<PricePoint>, (String, bool)>(
      (ref, key) => ref
          .watch(marketRepositoryProvider)
          .goldHistory(key.$1, sellSide: key.$2),
    );

final usdVndProvider = FutureProvider.autoDispose<UsdVndRate>(
  (ref) => ref
      .watch(marketRepositoryProvider)
      .usdVnd(ref.watch(clockProvider).now()),
);

/// Giá cà phê nhân chốt theo ngày (thường cập nhật buổi sáng) — 10 phút/lần.
class DomesticCoffeeController
    extends LiveMarketNotifier<List<ProvinceCoffee>> {
  @override
  Duration get refreshEvery => const Duration(minutes: 10);

  @override
  Future<List<ProvinceCoffee>> fetch(MarketRepository repo) =>
      repo.domesticCoffee();

  @override
  Future<List<ProvinceCoffee>?> fetchCached(MarketRepository repo) async {
    final cached = await repo.domesticCoffee(cacheOnly: true);
    return cached.isEmpty ? null : cached;
  }
}

final domesticCoffeeProvider =
    NotifierProvider.autoDispose<
      DomesticCoffeeController,
      MarketSnapshot<List<ProvinceCoffee>>
    >(DomesticCoffeeController.new);

/// Giá khớp lệnh sàn London/New York nhảy liên tục trong phiên — 30 giây/lần
/// khi trang đang mở (trang nguồn tự làm mới 8 giây/lần).
class CoffeeFuturesController extends LiveMarketNotifier<CoffeeFuturesBoard> {
  @override
  Duration get refreshEvery => const Duration(seconds: 30);

  @override
  Future<CoffeeFuturesBoard> fetch(MarketRepository repo) =>
      repo.coffeeFutures();

  @override
  Future<CoffeeFuturesBoard?> fetchCached(MarketRepository repo) =>
      repo.cachedCoffeeFutures();
}

final coffeeFuturesProvider =
    NotifierProvider.autoDispose<
      CoffeeFuturesController,
      MarketSnapshot<CoffeeFuturesBoard>
    >(CoffeeFuturesController.new);

final coffeeHistoryProvider = FutureProvider.autoDispose
    .family<({String strip, List<PricePoint> points}), CoffeeExchange>(
      (ref, exchange) =>
          ref.watch(marketRepositoryProvider).coffeeHistory(exchange),
    );
