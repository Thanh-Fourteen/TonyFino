import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tonyfino/data/services/market/coffee_prices.dart';
import 'package:tonyfino/data/services/market/market_http.dart';
import 'package:tonyfino/data/services/market/market_repository.dart';
import 'package:tonyfino/features/market/widgets/market_widgets.dart';

import '../../../support/fake_shared_preferences.dart';

String _fixture(String name) =>
    File('test/fixtures/market/$name').readAsStringSync();

void main() {
  setUp(installFakeSharedPreferences);

  test('🚨 nguồn chỉ có 7 ngày → app tự CỘNG DỒN lịch sử qua các lần tải',
      () async {
    var html = _fixture('giacaphe_lam-dong.html');
    final repo = MarketRepository(
      MarketHttp(
        client: MockClient(
          (_) async => http.Response.bytes(utf8.encode(html), 200),
        ),
      ),
    );
    final first = await repo.domesticCoffee();
    final lamDong = first.firstWhere(
      (p) => p.province == CoffeeProvince.lamDong,
    );
    expect(lamDong.history.length, 7);

    // Hôm sau: trang trượt thêm một ngày mới (29/09), ngày cũ nhất rơi khỏi
    // trang — app vẫn phải nhớ nó.
    html = html.replaceFirst(
      '<td>28/09/2026</td>',
      '<td>29/09/2026</td>\n<td class="gnd-gia">94,000</td>\n'
          '<td data-price="1000" class="price_change">1000</td>\n</tr>\n<tr>\n'
          '<td>28/09/2026</td>',
    );
    final second = await repo.domesticCoffee();
    final again = second.firstWhere(
      (p) => p.province == CoffeeProvince.lamDong,
    );
    expect(again.latest.price, 94000);
    expect(again.history.length, 8);
    expect(again.history.last.time, DateTime(2026, 9, 29));
    expect(again.history.first.time, lamDong.history.first.time);
  });

  test('mất mạng hẳn → domesticCoffee báo lỗi tiếng Việt, không crash', () {
    final repo = MarketRepository(
      MarketHttp(
        client: MockClient((_) async => throw const SocketException('x')),
      ),
    );
    expect(repo.domesticCoffee(), throwsA(isA<MarketFetchException>()));
  });

  test('định dạng số kiểu Việt Nam', () {
    expect(formatDecimal(3367, digits: 0), '3.367');
    expect(formatDecimal(4182.2, digits: 1), '4.182,2');
    expect(formatThousands(143400000), '143.400');
    expect(formatVndFull(93600), '93.600');
    expect(formatCompactVnd(143400000), '143,4tr');
  });
}
