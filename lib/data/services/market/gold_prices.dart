import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'price_point.dart';

/// Giá MỘT sản phẩm vàng của MỘT doanh nghiệp, đồng/lượng.
@immutable
class GoldQuote {
  const GoldQuote({
    required this.code,
    required this.brand,
    required this.product,
    required this.buy,
    required this.sell,
    required this.changeBuy,
    required this.changeSell,
  });

  /// Mã của nguồn (vd `SJL1L10`) — khoá để xin lịch sử của đúng dòng này.
  final String code;
  final String brand;
  final String product;

  /// Giá doanh nghiệp MUA VÀO (mình bán ra được bấy nhiêu), đồng/lượng.
  final int buy;

  /// Giá doanh nghiệp BÁN RA (mình mua vào phải trả), đồng/lượng.
  final int sell;

  /// Thay đổi so với phiên trước, đồng/lượng.
  final int changeBuy;
  final int changeSell;

  /// Chênh lệch mua–bán: mua xong bán ngay lỗ bấy nhiêu.
  int get spread => sell - buy;
}

/// Giá vàng thế giới, USD/ounce.
@immutable
class WorldGoldQuote {
  const WorldGoldQuote({required this.usdPerOunce, required this.change});

  final double usdPerOunce;
  final double change;
}

@immutable
class GoldBoard {
  const GoldBoard({
    required this.quotes,
    required this.world,
    required this.updatedAt,
  });

  final List<GoldQuote> quotes;
  final WorldGoldQuote? world;

  /// Thời điểm nguồn cập nhật (không phải lúc app tải về).
  final DateTime updatedAt;
}

/// 1 lượng (cây) = 37,5 g; 1 ounce troy = 31,1034768 g.
const gramsPerLuong = 37.5;
const gramsPerTroyOunce = 31.1034768;

/// Quy giá thế giới ra đồng/lượng để so với giá trong nước — CHƯA gồm thuế,
/// phí gia công; phần chênh chính là "chênh lệch trong nước – thế giới" mà
/// báo chí hay nhắc.
int worldGoldVndPerLuong({
  required double usdPerOunce,
  required double vndPerUsd,
}) => (usdPerOunce * vndPerUsd * gramsPerLuong / gramsPerTroyOunce).round();

/// Tên hiển thị tiếng Việt cho các mã của vang.today. Tên gốc của API là
/// tiếng Anh viết tắt ("PNJ Hanoi" cho mã `PQHN…` của Phú Quý) — tra lại
/// theo mã và theo trang của từng doanh nghiệp. Mã lạ (nguồn thêm dòng mới)
/// vẫn hiện, bằng tên gốc của API.
const _vangTodayNames = <String, (String, String)>{
  'SJL1L10': ('SJC', 'Vàng miếng SJC'),
  'SJ9999': ('SJC', 'Nhẫn SJC 99,99'),
  'DOHNL': ('DOJI Hà Nội', 'Vàng miếng SJC'),
  'DOHCML': ('DOJI TP.HCM', 'Vàng miếng SJC'),
  'DOJINHTV': ('DOJI', 'Nhẫn Hưng Thịnh Vượng 9999'),
  'BTSJC': ('Bảo Tín Minh Châu', 'Vàng miếng SJC'),
  'BT9999NTT': ('Bảo Tín Minh Châu', 'Nhẫn tròn trơn 9999'),
  // `PQ…` KHÔNG phải Phú Quý dù hai chữ đầu gợi vậy: đối chiếu 28/9, cả
  // hai dòng khớp tới từng đồng với API riêng của PNJ (miếng SJC và nhẫn
  // trơn 24K đều 140,4/143,4 tr), còn Phú Quý khi đó là 139,4/142,4 tr.
  'PQHNVM': ('PNJ', 'Vàng miếng SJC'),
  'PQHN24NTT': ('PNJ', 'Nhẫn trơn 24K'),
  // Hai mã dưới chưa xác minh được là nhà vàng nào — giữ tên gốc của API
  // thay vì đoán.
  'VNGSJC': ('VN Gold', 'Vàng miếng SJC'),
  'VIETTINMSJC': ('Viettin', 'Vàng miếng SJC'),
};

/// Thứ tự hiện trên bảng = thứ tự khai trong [_vangTodayNames]: vàng miếng
/// SJC đầu tiên (giá tham chiếu cả nước), rồi DOJI, PNJ, Bảo Tín Minh Châu;
/// mã lạ xếp cuối.
int _rank(String code) {
  final i = _vangTodayNames.keys.toList().indexOf(code);
  return i < 0 ? _vangTodayNames.length : i;
}

/// Đọc `GET https://www.vang.today/api/prices` — xem fixture
/// `test/fixtures/market/vangtoday_current.json`.
GoldBoard parseVangTodayCurrent(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  if (json['success'] != true) {
    throw const FormatException('vang.today trả success != true');
  }
  final prices = json['prices'] as Map<String, dynamic>;
  final quotes = <GoldQuote>[];
  WorldGoldQuote? world;
  prices.forEach((code, raw) {
    final p = raw as Map<String, dynamic>;
    if (p['currency'] == 'USD') {
      if (code == 'XAUUSD') {
        world = WorldGoldQuote(
          usdPerOunce: (p['buy'] as num).toDouble(),
          change: (p['change_buy'] as num? ?? 0).toDouble(),
        );
      }
      return;
    }
    final names = _vangTodayNames[code];
    quotes.add(
      GoldQuote(
        code: code,
        brand: names?.$1 ?? (p['name'] as String? ?? code),
        product: names?.$2 ?? '',
        buy: (p['buy'] as num).round(),
        sell: (p['sell'] as num).round(),
        changeBuy: (p['change_buy'] as num? ?? 0).round(),
        changeSell: (p['change_sell'] as num? ?? 0).round(),
      ),
    );
  });
  quotes.sort((a, b) {
    final byRank = _rank(a.code).compareTo(_rank(b.code));
    return byRank != 0 ? byRank : a.code.compareTo(b.code);
  });
  final ts = json['timestamp'] as num?;
  return GoldBoard(
    quotes: quotes,
    world: world,
    updatedAt: ts == null
        ? DateTime.parse(json['date'] as String)
        : DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000),
  );
}

/// Lịch sử một dòng giá vàng: hai đường MUA VÀO và BÁN RA (Tony muốn thấy
/// cả hai trên cùng biểu đồ — khoảng giữa hai đường chính là chênh lệch
/// mua–bán). Vàng thế giới chỉ có một giá → [sell] rỗng.
@immutable
class GoldHistory {
  const GoldHistory({required this.buy, required this.sell});

  final List<PricePoint> buy;
  final List<PricePoint> sell;
}

/// Đọc `GET https://www.vang.today/api/prices?type=<mã>&days=<n>` — mỗi
/// ngày một điểm (giá chốt của ngày), mới nhất trước trong phản hồi; trả
/// về tăng dần theo thời gian. Ô giá bằng 0 (vàng thế giới có `sell: 0`)
/// không thành điểm.
GoldHistory parseVangTodayHistory(String body, {required String code}) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final history = json['history'] as List<dynamic>? ?? const [];
  final buy = <PricePoint>[];
  final sell = <PricePoint>[];
  for (final day in history) {
    final d = day as Map<String, dynamic>;
    final p =
        (d['prices'] as Map<String, dynamic>)[code] as Map<String, dynamic>?;
    if (p == null) continue;
    final date = DateTime.parse(d['date'] as String);
    final b = p['buy'] as num? ?? 0;
    final s = p['sell'] as num? ?? 0;
    if (b != 0) buy.add(PricePoint(date, b.toDouble()));
    if (s != 0) sell.add(PricePoint(date, s.toDouble()));
  }
  int byTime(PricePoint a, PricePoint b) => a.time.compareTo(b.time);
  return GoldHistory(buy: buy..sort(byTime), sell: sell..sort(byTime));
}

/// Dự phòng khi vang.today hỏng: bảng giá của riêng PNJ,
/// `GET https://edge-api.pnj.io/ecom-frontend/v1/get-gold-price?zone=00`.
///
/// 🚨 Đơn vị NGHÌN ĐỒNG/CHỈ (`14340` = 14.340.000 đ/chỉ = 143.400.000
/// đ/lượng) — nhân 10.000 để về cùng đơn vị đồng/lượng với phần còn lại. Ô
/// giá có thể là chuỗi rỗng ("liên hệ") — dòng đó bỏ qua. Không có "thay
/// đổi so với hôm qua".
GoldBoard parsePnjGold(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final data = json['data'] as List<dynamic>? ?? const [];
  int? perLuong(Object? v) {
    final n = num.tryParse('${v ?? ''}');
    return n == null || n == 0 ? null : (n * 10000).round();
  }

  final quotes = <GoldQuote>[];
  for (final raw in data) {
    final e = raw as Map<String, dynamic>;
    final buy = perLuong(e['giamua']);
    final sell = perLuong(e['giaban']);
    if (buy == null || sell == null) continue;
    quotes.add(
      GoldQuote(
        code: 'PNJ:${e['masp']}',
        brand: 'PNJ',
        product: e['tensp'] as String? ?? '',
        buy: buy,
        sell: sell,
        changeBuy: 0,
        changeSell: 0,
      ),
    );
  }
  if (quotes.isEmpty) throw const FormatException('PNJ: bảng giá rỗng');
  // "28/09/2026 08:44:28", giờ Việt Nam.
  final m = RegExp(
    r'(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})',
  ).firstMatch(json['updateDate'] as String? ?? '');
  return GoldBoard(
    quotes: quotes,
    world: null,
    updatedAt: m == null
        ? DateTime(2000)
        : DateTime(
            int.parse(m.group(3)!),
            int.parse(m.group(2)!),
            int.parse(m.group(1)!),
            int.parse(m.group(4)!),
            int.parse(m.group(5)!),
          ),
  );
}
