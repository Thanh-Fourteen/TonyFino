// Widget test qua cây sản xuất thật (`SettingsScreen`) — cùng kỷ luật đã
// dùng cho `BudgetsScreen` (Phase 11). KHÔNG chạm nút "Sao lưu ngay"/"Khôi
// phục" thật (cần `flutter_secure_storage` + MethodChannel SAF, không có
// trong `flutter_test`) — chỉ xác nhận UI hiện đúng và toggle khoá vân tay
// hoạt động qua `LocalAuthPlatform` giả (xem docs/decisions.md § Phase 12).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/settings/settings_screen.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

class _FakeLocalAuthPlatform extends LocalAuthPlatform {
  _FakeLocalAuthPlatform({required this.supported});
  final bool supported;

  @override
  Future<bool> isDeviceSupported() async => supported;
}

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<void> pumpSettings(WidgetTester tester) async {
    await pumpApp(tester, db: db, child: const SettingsScreen());
    await tester.pumpAndSettle();
  }

  /// Cuộn tới một mục rồi mới kiểm.
  ///
  /// Cài đặt dài thêm sau mỗi nhóm mới (nhóm "Trang chủ" đẩy khoá vân tay
  /// xuống dưới nếp gấp) — `ListView` dựng lười nên mục chưa hiện thì
  /// `find` trả về 0, test hỏng vì lý do vô can.
  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      80,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'máy hỗ trợ sinh trắc học → toggle khoá vân tay hiện và bật được',
    (tester) async {
      LocalAuthPlatform.instance = _FakeLocalAuthPlatform(supported: true);
      await pumpSettings(tester);
      await scrollTo(tester, 'Khoá vân tay / khuôn mặt');

      final toggleFinder = find.widgetWithText(
        SwitchListTile,
        'Khoá vân tay / khuôn mặt',
      );
      expect(toggleFinder, findsOneWidget);
      var toggle = tester.widget<SwitchListTile>(toggleFinder);
      expect(toggle.onChanged, isNotNull);
      expect(toggle.value, isFalse);

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      toggle = tester.widget<SwitchListTile>(toggleFinder);
      expect(toggle.value, isTrue);
    },
  );

  testWidgets(
    'máy KHÔNG hỗ trợ sinh trắc học → toggle hiện nhưng bị vô hiệu hoá',
    (tester) async {
      LocalAuthPlatform.instance = _FakeLocalAuthPlatform(supported: false);
      await pumpSettings(tester);
      await scrollTo(tester, 'Khoá vân tay / khuôn mặt');

      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Khoá vân tay / khuôn mặt'),
      );
      expect(toggle.onChanged, isNull);
      expect(
        find.text('Máy này không hỗ trợ hoặc chưa đăng ký sinh trắc học'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'mục Sao lưu hiện đúng trạng thái "chưa sao lưu lần nào" và các nút thao tác',
    (tester) async {
      LocalAuthPlatform.instance = _FakeLocalAuthPlatform(supported: true);
      await pumpSettings(tester);
      await scrollTo(tester, 'Sao lưu');

      expect(find.text('Chưa sao lưu lần nào'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sao lưu ngay'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Khôi phục'), findsOneWidget);
      // Phase 17 thêm toggle "Màu động..." phía trên đẩy mục này xuống ngoài
      // viewport mặc định — cùng gotcha `ListView` lazy-render đã gặp ở Phase
      // 13 (`CategoriesScreen`/`WalletsScreen`), không phải lỗi mới.
      await tester.scrollUntilVisible(
        find.text('Sao lưu tự động hàng ngày'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.widgetWithText(SwitchListTile, 'Sao lưu tự động hàng ngày'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '🚨 Phase 15: đổi "Kỳ ngân sách bắt đầu ngày" lưu đúng giá trị mới, mặc định là 1',
    (tester) async {
      LocalAuthPlatform.instance = _FakeLocalAuthPlatform(supported: true);
      await pumpSettings(tester);

      // Cuộn từng đoạn ngắn: mục nằm dưới nếp gấp nên chưa được dựng,
      // `ensureVisible` không tìm thấy gì để cuộn tới.
      await tester.scrollUntilVisible(
        find.text('Kỳ tháng bắt đầu ngày'),
        80,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      final dropdownFinder = find.byType(DropdownButton<int>);
      expect(tester.widget<DropdownButton<int>>(dropdownFinder).value, 1);

      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();
      // Chọn "2" (gần đầu danh sách 1–31) — menu dropdown dựng lười theo
      // viewport giống `ListView` thường (xem [[project_tonyfino_gotchas]] §
      // Phase 13), một giá trị sâu như "25" có thể chưa được build. Dùng
      // `last` vì cả nút dropdown đóng lẫn item menu đều khớp text "2".
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();

      expect(tester.widget<DropdownButton<int>>(dropdownFinder).value, 2);
    },
  );

  testWidgets(
    '🚨 Phase 17: toggle "Màu động theo hệ thống" mặc định TẮT, bật được',
    (tester) async {
      LocalAuthPlatform.instance = _FakeLocalAuthPlatform(supported: true);
      await pumpSettings(tester);

      final toggleFinder = find.widgetWithText(
        SwitchListTile,
        'Màu động theo hệ thống (Material You)',
      );
      expect(toggleFinder, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggleFinder).value, isFalse);

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(toggleFinder).value, isTrue);
    },
  );

  testWidgets(
    '🚨 Phase 23: toggle "Dùng AI khi câu quá mơ hồ" mặc định TẮT, bật được',
    (tester) async {
      LocalAuthPlatform.instance = _FakeLocalAuthPlatform(supported: true);
      await pumpSettings(tester);

      await tester.scrollUntilVisible(
        find.text('Dùng AI khi câu quá mơ hồ'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final toggleFinder = find.widgetWithText(
        SwitchListTile,
        'Dùng AI khi câu quá mơ hồ',
      );
      // `scrollUntilVisible` dừng ngay khi finder khớp (một pixel lọt viewport
      // là đủ) — chưa chắc hit-test được ở tâm widget, `ensureVisible` cuộn
      // thêm cho chắc trước khi chạm (gotcha đã ghi nhiều lần, xem
      // [[project_tonyfino_gotchas]]).
      await tester.ensureVisible(toggleFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggleFinder).value, isFalse);

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(toggleFinder).value, isTrue);
    },
  );

  testWidgets('🚨 Phase 23: "Đổi địa chỉ proxy" mở dialog, lưu URL mới', (
    tester,
  ) async {
    LocalAuthPlatform.instance = _FakeLocalAuthPlatform(supported: true);
    await pumpSettings(tester);

    await tester.scrollUntilVisible(
      find.text('Đổi địa chỉ proxy'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Đổi địa chỉ proxy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi địa chỉ proxy'));
    await tester.pumpAndSettle();

    expect(
      find.text('https://tony.tailfcdcfc.ts.net/tonyfino-ai/'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField),
      'https://example.ts.net/tonyfino-ai/',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đổi địa chỉ proxy'));
    await tester.pumpAndSettle();
    expect(find.text('https://example.ts.net/tonyfino-ai/'), findsOneWidget);
  });

  testWidgets(
    '🚨 nhóm "Quản lý" đã DỜI sang màn Quản lý — Cài đặt không giữ bản sao',
    (tester) async {
      LocalAuthPlatform.instance = _FakeLocalAuthPlatform(supported: true);
      await pumpSettings(tester);

      // Cuộn TỚI ĐÁY rồi mới kết luận: ListView dựng lười nên "không thấy ở
      // khung hình đầu" chưa chứng minh được gì.
      await tester.scrollUntilVisible(
        find.text('Phiên bản'),
        80,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản lý'), findsNothing);
      expect(find.text('Mẫu giao dịch'), findsNothing);
      expect(find.text('Thẻ'), findsNothing);
    },
  );
}
