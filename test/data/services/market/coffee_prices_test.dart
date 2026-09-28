// Parser giá cà phê + tỷ giá — trên phản hồi THẬT chụp 2026-09-28 (HTML đã
// cắt còn phần CSS + bảng giá, giữ nguyên cấu trúc).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/services/market/coffee_prices.dart';
import 'package:tonyfino/data/services/market/gold_prices.dart';

String _fixture(String name) =>
    File('test/fixtures/market/$name').readAsStringSync();

void main() {
  test('trang tỉnh thường (Lâm Đồng): 7 ngày, mới nhất trước, đ/kg', () {
    final rows = parseGiacapheProvincePage(_fixture('giacaphe_lam-dong.html'));
    expect(rows.length, 7);
    expect(rows.first.date, DateTime(2026, 9, 28));
    expect(rows.first.price, 93000);
    expect(rows.first.change, 0);
    expect(rows[1].price, 93000);
    expect(rows[1].change, 1000);
    expect(rows[2].change, -200);
  });

  test('🚨 trang Đắk Lắk GIẤU số trong CSS ::after với class ngẫu nhiên — '
      'vẫn giải ra đúng', () {
    final rows = parseGiacapheProvincePage(_fixture('giacaphe_dak-lak.html'));
    expect(rows.length, 7);
    expect(rows[0].price, 93600);
    expect(rows[0].change, 0);
    expect(rows[1].date, DateTime(2026, 9, 26));
    expect(rows[1].price, 93600);
    expect(rows[1].change, 1100);
    expect(rows[2].price, 92500);
    expect(rows[2].change, -300);
  });

  test(
    'trang đổi bố cục (không còn bảng) → báo lỗi, không lặng lẽ ra rỗng',
    () {
      expect(
        () => parseGiacapheProvincePage('<html><body>Bảo trì</body></html>'),
        throwsFormatException,
      );
    },
  );

  test(
    'live-quotes: Robusta USD/tấn, Arabica cent/lb, kỳ hạn gần nhất trước',
    () {
      final board = parseGiacapheLiveQuotes(
        _fixture('giacaphe_livequotes_coffee.json'),
      );
      expect(board.robusta.first.code, 'RMX26');
      expect(board.robusta.first.month, '11/26');
      expect(board.robusta.first.last, 3367);
      expect(board.robusta.first.change, 77);
      expect(board.robusta.first.changePercent, 2.34);
    expect(board.robusta.first.open, 3292);
    expect(board.robusta.first.openInterest, 44701);
    expect(board.robusta.first.volume, 10598);
      expect(board.arabica.first.code, 'KCZ26');
      expect(board.arabica.first.last, 278.6);
    },
  );

  test('live-quotes trả HTML/lỗi (tên file đổi) → FormatException để nơi '
      'gọi đi tìm địa chỉ mới', () {
    expect(
      () => parseGiacapheLiveQuotes('{"error":"Invalid"}'),
      throwsFormatException,
    );
    expect(
      parseLiveQuotesUrl(_fixture('giacaphe_tructuyen.html')),
      'https://giacaphe.com/live-quotes/quotes-update-nOsjt.php',
    );
  });

  test('ICE: hợp đồng gần nhất + lịch sử chốt ngày ~1 năm', () {
    final contracts = parseIceContracts(_fixture('ice_robusta_contracts.json'));
    expect(contracts.first.marketId, 8185479);
    expect(contracts.first.strip, 'Nov26');
    final history = parseIceHistory(_fixture('ice_robusta_hist_span2_1y.json'));
    expect(history.length, greaterThan(200));
    expect(history.first.time, DateTime(2025, 9, 29));
    expect(history.first.value, 4001);
    expect(history.last.time, DateTime(2026, 9, 25));
    expect(history.last.value, 3367);
  });

  test('tỷ giá Vietcombank: USD mua chuyển khoản / bán ra', () {
    final rate = parseVcbUsdRate(_fixture('vcb_api.json'));
    expect(rate.buyTransfer, 25770);
    expect(rate.sell, 26150);
    expect(rate.updatedAt.day, 28);
  });

  test('PNJ dự phòng: nghìn đồng/chỉ → đồng/lượng, bỏ dòng thiếu giá', () {
    final board = parsePnjGold(_fixture('pnj.json'));
    final sjc = board.quotes.firstWhere((q) => q.code == 'PNJ:SJC');
    expect(sjc.sell, 143400000);
    expect(sjc.buy, 140400000);
    expect(board.quotes.any((q) => q.code == 'PNJ:RAW_9999'), isFalse);
    expect(board.updatedAt, DateTime(2026, 9, 28, 8, 44));
  });
}
