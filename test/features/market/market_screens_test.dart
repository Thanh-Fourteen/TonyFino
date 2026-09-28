// Hai trang Giá vàng / Giá cà phê — HTTP giả phát lại phản hồi THẬT (fixture
// chụp 2026-09-28), không gọi mạng.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:clock/clock.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/services/market/market_http.dart';
import 'package:tonyfino/features/market/coffee_price_screen.dart';
import 'package:tonyfino/features/market/gold_price_screen.dart';
import 'package:tonyfino/features/market/market_snapshot.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

String _fixture(String name) =>
    File('test/fixtures/market/$name').readAsStringSync();

http.Response _ok(String body) => http.Response.bytes(
  body.codeUnits.any((c) => c > 127) ? _utf8(body) : body.codeUnits,
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

List<int> _utf8(String s) => const Utf8Codec().encode(s);

/// Trả fixture theo host/đường dẫn; [offline] = mọi request đều hỏng mạng.
MockClient _client({bool offline = false, Set<String> failHosts = const {}}) =>
    MockClient((request) async {
      final u = request.url;
      if (offline || failHosts.contains(u.host)) {
        throw const SocketException('offline');
      }
      if (u.host == 'www.vang.today') {
        final type = u.queryParameters['type'];
        if (type == null) return _ok(_fixture('vangtoday_current.json'));
        if (type == 'XAUUSD') {
          return _ok(_fixture('vangtoday_history_XAUUSD_30d.json'));
        }
        return _ok(_fixture('vangtoday_history_SJL1L10_30d.json'));
      }
      if (u.host == 'edge-api.pnj.io') return _ok(_fixture('pnj.json'));
      if (u.host == 'www.vietcombank.com.vn') {
        return _ok(_fixture('vcb_api.json'));
      }
      if (u.host == 'giacaphe.com') {
        if (u.path.contains('live-quotes')) {
          return _ok(_fixture('giacaphe_livequotes_coffee.json'));
        }
        if (u.path.contains('dak-lak')) {
          return _ok(_fixture('giacaphe_dak-lak.html'));
        }
        return _ok(_fixture('giacaphe_lam-dong.html'));
      }
      if (u.host == 'www.ice.com') {
        if (u.path.contains('contract-data')) {
          return _ok(_fixture('ice_robusta_contracts.json'));
        }
        return _ok(_fixture('ice_robusta_hist_span2_1y.json'));
      }
      return http.Response('not found', 404);
    });

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen, MockClient client) async {
    await tester.binding.setSurfaceSize(const Size(420, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      db: db,
      child: screen,
      extraOverrides: [
        marketHttpProvider.overrideWithValue(MarketHttp(client: client)),
        clockProvider.overrideWithValue(Clock.fixed(DateTime(2026, 9, 28, 14))),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    // Rời trang: provider autoDispose huỷ hẹn giờ tự tải lại.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('Giá vàng: bảng nhiều doanh nghiệp, thế giới quy ra đ/lượng, '
      'biểu đồ', (tester) async {
    await pump(tester, const GoldPriceScreen(), _client());

    expect(find.text('Vàng thế giới (XAU/USD)'), findsOneWidget);
    expect(find.textContaining('4.182,2 USD/oz'), findsOneWidget);
    // 4182,2 × 26.150 × 37,5 / 31,1034768 ≈ 131.851 nghìn đ/lượng.
    expect(find.textContaining('nghìn đ/lượng (tỷ giá 26.150'), findsOneWidget);
    expect(find.text('DOJI Hà Nội'), findsOneWidget);
    expect(find.text('Bảo Tín Minh Châu'), findsWidgets);
    // SJC miếng: mua 140.400 / bán 143.400 nghìn đ/lượng.
    expect(find.text('143.400'), findsWidgets);
    expect(find.text('Tính giá trị vàng'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('máy tính: 1 chỉ SJC bán được 14.040.000, mua 14.340.000', (
    tester,
  ) async {
    await pump(tester, const GoldPriceScreen(), _client());
    expect(find.text('14.040.000 đ'), findsOneWidget);
    expect(find.text('14.340.000 đ'), findsOneWidget);
    expect(find.text('300.000 đ'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('vang.today hỏng → tự dùng bảng giá PNJ', (tester) async {
    await pump(
      tester,
      const GoldPriceScreen(),
      _client(failHosts: {'www.vang.today'}),
    );
    expect(find.text('PNJ'), findsWidgets);
    expect(find.text('Vàng miếng SJC 999.9'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('🚨 mất mạng sau lần tải trước → vẫn hiện số cũ + báo lỗi', (
    tester,
  ) async {
    await pump(tester, const GoldPriceScreen(), _client());
    await unmount(tester);

    await pump(tester, const GoldPriceScreen(), _client(offline: true));
    expect(find.text('DOJI Hà Nội'), findsOneWidget);
    expect(find.textContaining('Đang xem số lần trước'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Giá cà phê: 4 tỉnh (Đắk Lắk giải mã CSS), Robusta/Arabica, '
      'quy đổi đ/kg', (tester) async {
    await pump(tester, const CoffeePriceScreen(), _client());

    expect(find.text('Đắk Lắk'), findsOneWidget);
    expect(find.text('Lâm Đồng'), findsOneWidget);
    expect(find.text('93.600'), findsWidgets);
    expect(find.text('Robusta London'), findsOneWidget);
    expect(find.text('Arabica New York'), findsOneWidget);
    expect(find.text('3.367'), findsWidgets);
    // 3.367 USD/tấn × 26.150 / 1000 ≈ 88.047 đ/kg.
    expect(find.textContaining('88.047 đ/kg quy đổi'), findsOneWidget);
    await unmount(tester);
  });
}
