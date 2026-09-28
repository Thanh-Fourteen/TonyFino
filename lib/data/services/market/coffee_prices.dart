import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'price_point.dart';

/// Một ngày giá cà phê nhân xô ở một tỉnh, đồng/kg.
@immutable
class CoffeeDayPrice {
  const CoffeeDayPrice({
    required this.date,
    required this.price,
    required this.change,
  });

  final DateTime date;
  final int price;

  /// So với ngày có giá liền trước, đồng/kg.
  final int change;
}

/// Tỉnh có giá cà phê nhân trên giacaphe.com — [slug] là phần đường dẫn.
enum CoffeeProvince {
  dakLak('Đắk Lắk', 'dak-lak'),
  lamDong('Lâm Đồng', 'lam-dong'),
  giaLai('Gia Lai', 'gia-lai'),
  dakNong('Đắk Nông', 'dak-nong');

  const CoffeeProvince(this.label, this.slug);
  final String label;
  final String slug;

  Uri get uri => Uri.https('giacaphe.com', '/gia-ca-phe-$slug/');
}

final _cssContent = RegExp(
  r"""\.([A-Za-z0-9_-]+)::after\s*\{\s*content:\s*['"]([^'"]*)['"]""",
);
final _tbody = RegExp(
  r'<table class="price-table">.*?<tbody>(.*?)</tbody>',
  dotAll: true,
);
final _row = RegExp(r'<tr>(.*?)</tr>', dotAll: true);
final _cell = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
final _spanClasses = RegExp(r"""<span class=['"]([^'"]+)['"]""");
final _tags = RegExp(r'<[^>]+>');
final _date = RegExp(r'(\d{2})/(\d{2})/(\d{4})');

/// Đọc bảng 7 ngày của trang tỉnh giacaphe.com (`/gia-ca-phe-<tỉnh>/`).
///
/// Hai kiểu trang, cùng một parser:
/// - Lâm Đồng / Gia Lai / Đắk Nông: số nằm thẳng trong `<td>`.
/// - Đắk Lắk: số bị GIẤU — `<td>` chỉ có `<span class='xYz abc'>` rỗng, còn
///   chữ số nằm trong CSS `.xYz::after { content:'93,600' }`, tên class đổi
///   ngẫu nhiên mỗi lần tải. Dựng bảng class → nội dung từ CSS rồi tra.
///
/// Mới nhất trước (đúng thứ tự trang). Ném [FormatException] khi không thấy
/// bảng — trang đổi bố cục thì phải biết ngay, không lặng lẽ ra rỗng.
List<CoffeeDayPrice> parseGiacapheProvincePage(String html) {
  final css = {
    for (final m in _cssContent.allMatches(html)) m.group(1)!: m.group(2)!,
  };
  final body = _tbody.firstMatch(html)?.group(1);
  if (body == null) {
    throw const FormatException('giacaphe: không thấy bảng price-table');
  }

  String cellText(String cell) {
    final spans = _spanClasses.firstMatch(cell);
    if (spans != null) {
      for (final cls in spans.group(1)!.split(RegExp(r'\s+'))) {
        final v = css[cls];
        if (v != null) return v;
      }
    }
    return cell.replaceAll(_tags, '').trim();
  }

  final rows = <CoffeeDayPrice>[];
  for (final r in _row.allMatches(body)) {
    final cells = [for (final c in _cell.allMatches(r.group(1)!)) c.group(1)!];
    if (cells.length < 3) continue;
    final d = _date.firstMatch(cells[0]);
    final price = _parseVndInt(cellText(cells[1]));
    if (d == null || price == null) continue;
    rows.add(
      CoffeeDayPrice(
        date: DateTime(
          int.parse(d.group(3)!),
          int.parse(d.group(2)!),
          int.parse(d.group(1)!),
        ),
        price: price,
        change: _parseVndInt(cellText(cells[2])) ?? 0,
      ),
    );
  }
  if (rows.isEmpty) {
    throw const FormatException('giacaphe: bảng giá rỗng');
  }
  return rows;
}

/// "93,600" / "+1,100" / "-200" / "0" → int. Dấu phẩy là phân cách nghìn.
int? _parseVndInt(String s) {
  final cleaned = s.replaceAll(',', '').replaceAll('+', '').trim();
  return int.tryParse(cleaned);
}

/// Một kỳ hạn hợp đồng tương lai cà phê.
@immutable
class CoffeeFuture {
  const CoffeeFuture({
    required this.code,
    required this.month,
    required this.last,
    required this.change,
    required this.changePercent,
    required this.high,
    required this.low,
    required this.previous,
    required this.volume,
    required this.time,
    this.open = 0,
    this.openInterest = 0,
  });

  /// Mã sàn, vd `RMX26` (Robusta tháng 11/2026).
  final String code;

  /// Kỳ hạn "MM/YY".
  final String month;
  final double last;
  final double change;
  final double changePercent;
  final double high;
  final double low;
  final double previous;
  final int volume;

  /// Lúc khớp lệnh gần nhất.
  final DateTime time;

  /// Giá mở cửa phiên.
  final double open;

  /// Hợp đồng mở (số hợp đồng chưa tất toán).
  final int openInterest;
}

@immutable
class CoffeeFuturesBoard {
  const CoffeeFuturesBoard({required this.robusta, required this.arabica});

  /// Robusta London (ICE Europe) — USD/tấn. Kỳ hạn gần nhất trước.
  final List<CoffeeFuture> robusta;

  /// Arabica New York (ICE US) — US cent/lb. Kỳ hạn gần nhất trước.
  final List<CoffeeFuture> arabica;
}

double _d(Object? v) => double.tryParse('${v ?? ''}'.replaceAll(',', '')) ?? 0;

List<CoffeeFuture> _futures(List<dynamic>? raw) => [
  for (final e in raw ?? const [])
    if (_d((e as Map<String, dynamic>)['Last']) > 0)
      CoffeeFuture(
        code: e['Name'] as String? ?? '',
        month: e['Month'] as String? ?? '',
        last: _d(e['Last']),
        change: _d(e['Change']),
        changePercent: _d(e['PtcChange']),
        high: _d(e['High']),
        low: _d(e['Low']),
        previous: _d(e['Previous']),
        volume: _d(e['Volume']).round(),
        time: DateTime.fromMillisecondsSinceEpoch(_d(e['Time']).round() * 1000),
        open: _d(e['Open']),
        openInterest: _d(e['OpInt']).round(),
      ),
];

/// Đọc JSON "live-quotes" của giacaphe.com (trang tự làm mới 8 giây/lần).
/// `coffee_liffe` = Robusta London, `coffee_ice` = Arabica New York.
CoffeeFuturesBoard parseGiacapheLiveQuotes(String body) {
  final json = jsonDecode(body);
  if (json is! Map<String, dynamic> || json['coffee_liffe'] == null) {
    throw const FormatException('giacaphe live-quotes: thiếu coffee_liffe');
  }
  return CoffeeFuturesBoard(
    robusta: _futures(json['coffee_liffe'] as List<dynamic>?),
    arabica: _futures(json['coffee_ice'] as List<dynamic>?),
  );
}

/// Trang giá trực tuyến khai địa chỉ JSON trong
/// `quotes_data_url = '…'` — tên file đổi theo thời gian, nên khi địa chỉ
/// đang nhớ hỏng thì đọc lại từ trang.
String? parseLiveQuotesUrl(String html) => RegExp(
  r"""quotes_data_url\s*=\s*['"]([^'"]+)['"]""",
).firstMatch(html)?.group(1);

/// Hợp đồng ICE: `[{marketId, marketStrip:"Nov26", endDate}]`, gần nhất trước.
List<({int marketId, String strip})> parseIceContracts(String body) {
  final list = jsonDecode(body) as List<dynamic>;
  return [
    for (final e in list)
      (
        marketId: ((e as Map<String, dynamic>)['marketId'] as num).toInt(),
        strip: e['marketStrip'] as String? ?? '',
      ),
  ];
}

const _months = {
  'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, //
  'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
};

/// Lịch sử giá chốt ngày của một hợp đồng ICE:
/// `{"bars":[["Mon Sep 29 00:00:00 2025", 4001.0], …]}` — ngày viết kiểu
/// `java.util.Date.toString()`, chỉ lấy ngày/tháng/năm.
List<PricePoint> parseIceHistory(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final bars = json['bars'] as List<dynamic>? ?? const [];
  final points = <PricePoint>[];
  for (final b in bars) {
    final pair = b as List<dynamic>;
    final parts = (pair[0] as String).split(RegExp(r'\s+'));
    // [Thu, Sep, 25, 00:00:00, 2026] — có khi kèm múi giờ trước năm.
    final month = _months[parts.length > 1 ? parts[1] : ''];
    final day = parts.length > 2 ? int.tryParse(parts[2]) : null;
    final year = int.tryParse(parts.last);
    if (month == null || day == null || year == null) continue;
    points.add(
      PricePoint(DateTime(year, month, day), (pair[1] as num).toDouble()),
    );
  }
  points.sort((a, b) => a.time.compareTo(b.time));
  return points;
}

Uri iceContractsUri({required int productId, required int hubId}) => Uri.https(
  'www.ice.com',
  '/marketdata/api/productguide/charting/contract-data',
  {'productId': '$productId', 'hubId': '$hubId'},
);

Uri iceHistoryUri(int marketId) => Uri.https(
  'www.ice.com',
  '/marketdata/api/productguide/charting/data/historical',
  // span 2 = khoảng 1 năm giá chốt ngày.
  {'marketId': '$marketId', 'historicalSpan': '2'},
);

/// Tỷ giá USD của Vietcombank (đồng/USD).
@immutable
class UsdVndRate {
  const UsdVndRate({
    required this.buyTransfer,
    required this.sell,
    required this.updatedAt,
  });

  final double buyTransfer;
  final double sell;
  final DateTime updatedAt;
}

/// `GET https://www.vietcombank.com.vn/api/exchangerates?date=YYYY-MM-DD`.
UsdVndRate parseVcbUsdRate(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final data = json['Data'] as List<dynamic>;
  final usd = data.cast<Map<String, dynamic>>().firstWhere(
    (e) => e['currencyCode'] == 'USD',
  );
  return UsdVndRate(
    buyTransfer: _d(usd['transfer']),
    sell: _d(usd['sell']),
    updatedAt: DateTime.parse(
      (json['UpdatedDate'] ?? json['Date']) as String,
    ).toLocal(),
  );
}
