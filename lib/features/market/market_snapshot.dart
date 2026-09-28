import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/clock_provider.dart';
import '../../data/services/market/market_http.dart';
import '../../data/services/market/market_repository.dart';

final marketHttpProvider = Provider<MarketHttp>((ref) => MarketHttp());

final marketRepositoryProvider = Provider<MarketRepository>(
  (ref) => MarketRepository(ref.watch(marketHttpProvider)),
);

/// Trạng thái một bảng giá "sống": dữ liệu gần nhất (có thể là bản đã cất
/// từ lần trước), lỗi của lần tải gần nhất (nếu có), và lúc tải xong.
@immutable
class MarketSnapshot<T> {
  const MarketSnapshot({
    this.data,
    this.error,
    this.fetchedAt,
    this.isLoading = false,
    this.fromCache = false,
  });

  final T? data;

  /// Lỗi của lần tải GẦN NHẤT — có thể đi cùng [data] cũ: tải lại hỏng thì
  /// vẫn giữ bảng giá đang hiện, chỉ báo thêm một dòng lỗi.
  final String? error;

  /// Lúc app tải thành công lần gần nhất (theo `clockProvider`).
  final DateTime? fetchedAt;
  final bool isLoading;

  /// [data] đang là bản cất từ phiên trước, chưa tải được bản mới.
  final bool fromCache;

  MarketSnapshot<T> copyWith({
    T? data,
    String? error,
    bool clearError = false,
    DateTime? fetchedAt,
    bool? isLoading,
    bool? fromCache,
  }) => MarketSnapshot<T>(
    data: data ?? this.data,
    error: clearError ? null : (error ?? this.error),
    fetchedAt: fetchedAt ?? this.fetchedAt,
    isLoading: isLoading ?? this.isLoading,
    fromCache: fromCache ?? this.fromCache,
  );
}

/// Khuôn chung cho bảng giá cập nhật liên tục: lần đầu hiện ngay bản đã cất
/// (nếu có) rồi tải bản mới; sau đó tự tải lại mỗi [refreshEvery] CHỪNG
/// NÀO trang còn mở — provider `autoDispose`, rời trang là hẹn giờ bị huỷ,
/// app không âm thầm gọi mạng ở nền.
abstract class LiveMarketNotifier<T> extends Notifier<MarketSnapshot<T>> {
  Duration get refreshEvery;
  Future<T> fetch(MarketRepository repo);
  Future<T?> fetchCached(MarketRepository repo);

  bool _inFlight = false;

  @override
  MarketSnapshot<T> build() {
    final timer = Timer.periodic(refreshEvery, (_) => unawaited(refresh()));
    ref.onDispose(timer.cancel);
    unawaited(_start());
    return MarketSnapshot<T>(isLoading: true);
  }

  Future<void> _start() async {
    T? cached;
    try {
      cached = await fetchCached(ref.read(marketRepositoryProvider));
    } catch (_) {
      // Bản cất hỏng/định dạng cũ — bỏ qua, chờ bản mới.
    }
    // Rời trang trong lúc đang đọc bản cất: provider đã huỷ, không được
    // chạm `state`/`ref` nữa (Riverpod 3 ném lỗi).
    if (!ref.mounted) return;
    if (cached != null && state.data == null) {
      state = state.copyWith(data: cached, fromCache: true);
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (_inFlight) return;
    _inFlight = true;
    state = state.copyWith(isLoading: true);
    try {
      final data = await fetch(ref.read(marketRepositoryProvider));
      if (!ref.mounted) return;
      state = MarketSnapshot<T>(
        data: data,
        fetchedAt: ref.read(clockProvider).now(),
      );
    } on MarketFetchException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Nguồn giá đổi định dạng, chưa đọc được bản mới.',
      );
    } finally {
      _inFlight = false;
    }
  }
}
