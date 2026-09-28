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
      // Hai trang là THÂN của tab Thị trường (Scaffold nằm ở AppShell).
      child: Scaffold(body: screen),
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

  testWidgets('Giá vàng: hero = giá bán ra SJC, biểu đồ HAI đường, bảng '
      'nhóm theo doanh nghiệp, thế giới quy ra đ/lượng', (tester) async {
    await pump(tester, const GoldPriceScreen(), _client());

    // Hero: vàng miếng SJC bán ra, kèm giá mua vào + chênh lệch.
    expect(find.text('SJC · Vàng miếng SJC · bán ra'), findsOneWidget);
    expect(
      find.textContaining('Mua vào 140.400.000 · chênh 3.000.000'),
      findsOneWidget,
    );
    // Chú thích hai đường của biểu đồ.
    expect(find.text('Bán ra'), findsWidgets);
    expect(find.text('Mua vào'), findsWidgets);
    // Bảng nhóm theo doanh nghiệp; DOJI hai chi nhánh gộp một nhóm.
    expect(find.text('DOJI'), findsOneWidget);
    expect(find.text('Vàng miếng SJC · Hà Nội'), findsOneWidget);
    expect(find.text('Bảo Tín Minh Châu'), findsOneWidget);
    expect(find.text('143.400'), findsWidgets);
    // Thế giới: 4182,2 × 26.150 × 37,5 / 31,1034768.
    expect(find.text('XAU/USD'), findsOneWidget);
    expect(find.textContaining('theo tỷ giá 26.150 đ/USD'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('chạm một dòng bảng → hero đổi sang dòng đó', (tester) async {
    await pump(tester, const GoldPriceScreen(), _client());
    await tester.tap(find.text('Nhẫn tròn trơn 9999'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bảo Tín Minh Châu · Nhẫn tròn trơn 9999 · bán ra'),
      findsOneWidget,
    );
    expect(find.textContaining('144.100.000'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('máy tính (sheet): 1 chỉ SJC bán được 14.040.000, mua '
      '14.340.000', (tester) async {
    await pump(tester, const GoldPriceScreen(), _client());
    await tester.tap(find.text('Tính giá trị vàng đang giữ'));
    await tester.pumpAndSettle();
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
    // Dòng dự phòng không có lịch sử — nói thẳng, không vẽ biểu đồ rỗng.
    expect(find.textContaining('không có lịch sử giá'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('🚨 mất mạng sau lần tải trước → vẫn hiện số cũ + báo lỗi', (
    tester,
  ) async {
    await pump(tester, const GoldPriceScreen(), _client());
    await unmount(tester);

    await pump(tester, const GoldPriceScreen(), _client(offline: true));
    expect(find.text('Vàng miếng SJC · Hà Nội'), findsOneWidget);
    expect(find.textContaining('Đang xem số lần trước'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Giá cà phê: hero Đắk Lắk (giải mã CSS), 4 tỉnh, sàn Robusta '
      'mặc định + quy đổi đ/kg; đổi sang Arabica', (tester) async {
    await pump(tester, const CoffeePriceScreen(), _client());

    expect(find.text('Cà phê nhân xô · Đắk Lắk'), findsOneWidget);
    expect(find.text('93.600'), findsWidgets);
    expect(find.text('Lâm Đồng'), findsOneWidget);
    expect(find.text('Robusta London'), findsOneWidget);
    expect(find.text('Kỳ hạn 11/26 · gần nhất'), findsOneWidget);
    // 3.367 USD/tấn × 26.150 / 1000 ≈ 88.047 đ/kg.
    expect(find.textContaining('88.047 đ/kg'), findsOneWidget);
    // Lịch sử ICE: kỳ hạn "Nov26" hiện kiểu Việt "11/26".
    expect(find.textContaining('hợp đồng kỳ hạn 11/26'), findsOneWidget);

    await tester.tap(find.text('Arabica New York'));
    await tester.pumpAndSettle();
    expect(find.text('Kỳ hạn 12/26 · gần nhất'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('chạm một kỳ hạn → mở chi tiết phiên', (tester) async {
    await pump(tester, const CoffeePriceScreen(), _client());
    expect(find.textContaining('Hợp đồng mở'), findsNothing);
    await tester.tap(find.text('11/26'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hợp đồng mở 44.701'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('🚨 tab Thị trường đang ẨN (TickerMode tắt, như khi đứng ở '
      'tab khác của thanh dưới) → không một request mạng nào', (tester) async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('{}', 200);
    });
    await pump(
      tester,
      const TickerMode(enabled: false, child: GoldPriceScreen()),
      client,
    );
    await tester.pump(const Duration(minutes: 5));
    expect(requests, 0);
    await unmount(tester);
  });
}
