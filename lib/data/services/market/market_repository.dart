import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'coffee_prices.dart';
import 'gold_prices.dart';
import 'market_http.dart';
import 'price_point.dart';

/// Giá cà phê nhân của một tỉnh: 7 ngày mới nhất từ nguồn + lịch sử dài hơn
/// app tự tích luỹ.
class ProvinceCoffee {
  const ProvinceCoffee({
    required this.province,
    required this.latest,
    required this.history,
  });

  final CoffeeProvince province;

  /// Ngày mới nhất trên trang (giá + thay đổi).
  final CoffeeDayPrice latest;

  /// Mọi ngày app từng thấy (7 ngày của lần tải này ∪ các lần trước), tăng
  /// dần theo thời gian.
  final List<PricePoint> history;
}

enum CoffeeExchange {
  /// Robusta London — ICE Futures Europe.
  robusta(15247, 17451),

  /// Arabica "Coffee C" New York — ICE Futures US.
  arabica(580, 728);

  const CoffeeExchange(this.productId, this.hubId);
  final int productId;
  final int hubId;
}

/// Mọi nguồn giá thị trường, mỗi hàm một câu hỏi. Nguồn nào có dự phòng thì
/// tự chuyển — nơi gọi chỉ nhận dữ liệu hoặc một [MarketFetchException]
/// có thông điệp tiếng Việt.
///
/// Nguồn đã chọn và lý do: docs/decisions.md § 2026-09-28 (4).
class MarketRepository {
  MarketRepository(this._http);

  final MarketHttp _http;
  final _prefs = SharedPreferencesAsync();

  static final _vangTodayNow = Uri.https('www.vang.today', '/api/prices');
  static final _pnj = Uri.https(
    'edge-api.pnj.io',
    '/ecom-frontend/v1/get-gold-price',
    {'zone': '00'},
  );

  static Uri _vangTodayHistory(String code) =>
      Uri.https('www.vang.today', '/api/prices', {'type': code, 'days': '365'});

  // ── Vàng ──

  /// Bảng giá nhiều doanh nghiệp (vang.today); hỏng thì dự phòng bảng giá
  /// riêng của PNJ.
  Future<GoldBoard> goldBoard() async {
    try {
      return parseVangTodayCurrent(await _http.get(_vangTodayNow));
    } catch (primaryError) {
      try {
        return parsePnjGold(await _http.get(_pnj));
      } catch (_) {
        throw primaryError is MarketFetchException
            ? primaryError
            : const MarketFetchException('Chưa đọc được bảng giá vàng.');
      }
    }
  }

  Future<GoldBoard?> cachedGoldBoard() async {
    final body = await _http.cached(_vangTodayNow);
    if (body != null) return parseVangTodayCurrent(body);
    final pnj = await _http.cached(_pnj);
    return pnj == null ? null : parsePnjGold(pnj);
  }

  /// Giá chốt từng ngày (~310 ngày) của một dòng vang.today; [sellSide] =
  /// giá bán ra. Dòng dự phòng của PNJ không có lịch sử → danh sách rỗng.
  Future<List<PricePoint>> goldHistory(
    String code, {
    bool sellSide = true,
  }) async {
    if (code.startsWith('PNJ:')) return const [];
    final uri = _vangTodayHistory(code);
    String body;
    try {
      body = await _http.get(uri);
    } on MarketFetchException {
      final cached = await _http.cached(uri);
      if (cached == null) rethrow;
      body = cached;
    }
    return parseVangTodayHistory(body, code: code, sellSide: sellSide);
  }

  // ── Tỷ giá ──

  static Uri _vcb(DateTime day) => Uri.https(
    'www.vietcombank.com.vn',
    '/api/exchangerates',
    {'date': _ymd(day)},
  );

  /// Tỷ giá USD Vietcombank ngày [today]; sáng sớm/cuối tuần chưa có bảng
  /// của hôm nay thì lùi dần tối đa 4 ngày.
  Future<UsdVndRate> usdVnd(DateTime today) async {
    Object? lastError;
    for (var back = 0; back < 5; back++) {
      final uri = _vcb(today.subtract(Duration(days: back)));
      try {
        return parseVcbUsdRate(await _http.get(uri));
      } catch (e) {
        lastError = e;
        final cached = await _http.cached(uri);
        if (cached != null) return parseVcbUsdRate(cached);
      }
    }
    throw lastError is MarketFetchException
        ? lastError
        : const MarketFetchException('Chưa lấy được tỷ giá USD.');
  }

  // ── Cà phê trong nước ──

  static String _historyKey(CoffeeProvince p) =>
      'tonyfino_coffee_history:${p.slug}';

  /// Bốn tỉnh song song. Tỉnh nào tải hỏng thì dùng bản đã cất của tỉnh đó;
  /// chỉ ném lỗi khi KHÔNG tỉnh nào có số.
  Future<List<ProvinceCoffee>> domesticCoffee({bool cacheOnly = false}) async {
    final results = await Future.wait([
      for (final p in CoffeeProvince.values) _province(p, cacheOnly: cacheOnly),
    ]);
    final ok = results.whereType<ProvinceCoffee>().toList();
    if (ok.isEmpty && !cacheOnly) {
      throw const MarketFetchException(
        'Chưa tải được giá cà phê trong nước — kiểm tra mạng.',
      );
    }
    return ok;
  }

  Future<ProvinceCoffee?> _province(
    CoffeeProvince p, {
    required bool cacheOnly,
  }) async {
    String? body;
    if (!cacheOnly) {
      try {
        body = await _http.get(p.uri);
      } catch (_) {}
    }
    body ??= await _http.cached(p.uri);
    if (body == null) return null;
    final List<CoffeeDayPrice> rows;
    try {
      rows = parseGiacapheProvincePage(body);
    } catch (_) {
      return null;
    }
    final history = await _mergeHistory(p, rows);
    return ProvinceCoffee(province: p, latest: rows.first, history: history);
  }

  /// Nguồn chỉ cho xem 7 ngày — app tự GHI LẠI mỗi ngày nó thấy, lâu dần
  /// thành lịch sử dài. Lưu `{"2026-09-28": 93600, …}` trong prefs (giá
  /// công khai, không phải dữ liệu của Tony — không cần DB mã hoá), giữ tối
  /// đa ~3 năm.
  Future<List<PricePoint>> _mergeHistory(
    CoffeeProvince p,
    List<CoffeeDayPrice> rows,
  ) async {
    final key = _historyKey(p);
    final stored = <String, int>{};
    final raw = await _prefs.getString(key);
    if (raw != null) {
      try {
        (jsonDecode(raw) as Map<String, dynamic>).forEach(
          (k, v) => stored[k] = (v as num).toInt(),
        );
      } catch (_) {
        // Bản lưu hỏng — bắt đầu lại từ 7 ngày của lần này.
      }
    }
    for (final r in rows) {
      stored[_ymd(r.date)] = r.price;
    }
    final keys = stored.keys.toList()..sort();
    while (keys.length > 1100) {
      stored.remove(keys.removeAt(0));
    }
    await _prefs.setString(key, jsonEncode(stored));
    return [
      for (final k in keys)
        PricePoint(DateTime.parse(k), stored[k]!.toDouble()),
    ];
  }

  // ── Cà phê thế giới ──

  static final _liveQuotesPage = Uri.https(
    'giacaphe.com',
    '/gia-ca-phe-truc-tuyen/',
  );
  static const _liveQuotesUrlKey = 'tonyfino_coffee_live_quotes_url';
  static const _defaultLiveQuotesUrl =
      'https://giacaphe.com/live-quotes/quotes-update-nOsjt.php';
  static const _liveQuotesHeaders = {
    'X-Requested-With': 'XMLHttpRequest',
    'X-Auth-Site': 'giacaphe',
    'Referer': 'https://giacaphe.com/gia-ca-phe-truc-tuyen/',
  };

  static Uri _liveQuotesUri(String base) =>
      Uri.parse(base).replace(queryParameters: {'sid': '', 'g': 'coffee'});

  /// Giá khớp lệnh sàn London/New York. Tên file JSON của nguồn thay đổi
  /// theo thời gian: địa chỉ đang nhớ hỏng thì đọc lại từ trang giá trực
  /// tuyến rồi thử đúng một lần nữa.
  Future<CoffeeFuturesBoard> coffeeFutures() async {
    final remembered =
        await _prefs.getString(_liveQuotesUrlKey) ?? _defaultLiveQuotesUrl;
    try {
      return parseGiacapheLiveQuotes(
        await _http.get(
          _liveQuotesUri(remembered),
          headers: _liveQuotesHeaders,
        ),
      );
    } on FormatException {
      // Trả về HTML/lỗi thay vì JSON — địa chỉ đã đổi.
    } on MarketFetchException {
      // Có thể là 404 vì tên file đổi — thử tìm địa chỉ mới bên dưới.
    }
    final page = await _http.get(_liveQuotesPage);
    final fresh = parseLiveQuotesUrl(page);
    if (fresh == null) {
      throw const MarketFetchException(
        'Nguồn giá cà phê thế giới đổi cấu trúc.',
      );
    }
    await _prefs.setString(_liveQuotesUrlKey, fresh);
    return parseGiacapheLiveQuotes(
      await _http.get(_liveQuotesUri(fresh), headers: _liveQuotesHeaders),
    );
  }

  Future<CoffeeFuturesBoard?> cachedCoffeeFutures() async {
    final remembered =
        await _prefs.getString(_liveQuotesUrlKey) ?? _defaultLiveQuotesUrl;
    final body = await _http.cached(_liveQuotesUri(remembered));
    return body == null ? null : parseGiacapheLiveQuotes(body);
  }

  /// Giá chốt ngày ~1 năm của hợp đồng GẦN NHẤT trên sàn ICE. Đường giá là
  /// của MỘT kỳ hạn (không nối kỳ) — đúng thứ sàn công bố.
  Future<({String strip, List<PricePoint> points})> coffeeHistory(
    CoffeeExchange exchange,
  ) async {
    final contracts = parseIceContracts(
      await _getOrCached(
        iceContractsUri(productId: exchange.productId, hubId: exchange.hubId),
      ),
    );
    if (contracts.isEmpty) {
      throw const MarketFetchException('Sàn ICE chưa có hợp đồng nào.');
    }
    final front = contracts.first;
    return (
      strip: front.strip,
      points: parseIceHistory(
        await _getOrCached(iceHistoryUri(front.marketId)),
      ),
    );
  }

  Future<String> _getOrCached(Uri uri) async {
    try {
      return await _http.get(uri);
    } on MarketFetchException {
      final cached = await _http.cached(uri);
      if (cached == null) rethrow;
      return cached;
    }
  }
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
