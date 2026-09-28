// Parser giá vàng — chạy trên phản hồi THẬT của vang.today (chụp
// 2026-09-28), không phải JSON tự dựng.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/services/market/gold_prices.dart';

String _fixture(String name) =>
    File('test/fixtures/market/$name').readAsStringSync();

void main() {
  test('bảng giá: đủ doanh nghiệp, đồng/lượng, SJC đứng đầu, thế giới tách '
      'riêng', () {
    final board = parseVangTodayCurrent(_fixture('vangtoday_current.json'));
    expect(board.quotes.length, 11);
    final sjc = board.quotes.first;
    expect(sjc.code, 'SJL1L10', reason: 'vàng miếng SJC là giá tham chiếu');
    final mieng = board.quotes.firstWhere((q) => q.code == 'SJL1L10');
    expect(mieng.buy, 140400000);
    expect(mieng.sell, 143400000);
    expect(mieng.spread, 3000000);
    expect(mieng.changeSell, -1000000);
    expect(board.quotes.any((q) => q.brand == 'DOJI Hà Nội'), isTrue);
    expect(board.quotes.any((q) => q.brand == 'Bảo Tín Minh Châu'), isTrue);
    // XAU/USD không lẫn vào bảng trong nước.
    expect(board.quotes.any((q) => q.code == 'XAUUSD'), isFalse);
    expect(board.world!.usdPerOunce, 4182.2);
    expect(board.world!.change, -10.5);
    expect(board.updatedAt.year, 2026);
  });

  test('lịch sử: mỗi ngày một điểm, tăng dần theo thời gian', () {
    final h = parseVangTodayHistory(
      _fixture('vangtoday_history_SJL1L10_30d.json'),
      code: 'SJL1L10',
    );
    final points = h.sell;
    expect(points.length, greaterThan(20));
    for (var i = 1; i < points.length; i++) {
      expect(points[i].time.isAfter(points[i - 1].time), isTrue);
    }
    expect(points.last.value, 143400000);
    // Cả đường MUA VÀO, cùng số ngày.
    expect(h.buy.length, points.length);
    expect(h.buy.last.value, 140400000);
  });

  test('lịch sử thế giới: chỉ một giá (buy), sell = 0 không thành điểm', () {
    final h = parseVangTodayHistory(
      _fixture('vangtoday_history_XAUUSD_30d.json'),
      code: 'XAUUSD',
    );
    expect(h.buy, isNotEmpty);
    expect(h.buy.last.value, 4182.2);
    expect(h.sell, isEmpty);
  });

  test('quy giá thế giới ra đồng/lượng', () {
    // 4000 USD/oz × 25.000 đ/USD × 37,5/31,1034768 ≈ 120.566.000 đ/lượng.
    final v = worldGoldVndPerLuong(usdPerOunce: 4000, vndPerUsd: 25000);
    expect(v, closeTo(120565920, 1000));
  });
}
