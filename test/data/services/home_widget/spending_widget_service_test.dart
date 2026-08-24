import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/data/services/home_widget/spending_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  final calls = <String>[];

  void handleWith(Future<Object?>? Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call.method);
          return handler(call);
        });
  }

  setUp(calls.clear);
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const summary = MonthSummary(
    expense: Money.vnd(-35000),
    income: Money.vnd(15000000),
  );

  test('đường bình thường: lưu 2 khoá rồi gọi updateWidget', () async {
    handleWith((_) async => true);
    await const SpendingWidgetService().sync(
      summary,
      updatedAt: DateTime(2026, 8, 23, 9, 5, 7),
    );
    expect(calls, ['saveWidgetData', 'saveWidgetData', 'updateWidget']);
  });

  test('widget màn hình chính hỏng → KHÔNG ném ra ngoài (sổ vẫn đúng, người '
      'dùng vừa bấm Lưu không được nhận một exception vào mặt)', () async {
    // Đúng lỗi thật gặp trên máy: bản debug có `applicationIdSuffix .dev`
    // nên `home_widget` tìm class `dev.tony.tonyfino.dev.
    // SpendingWidgetProvider` — không tồn tại. Trước khi sửa, đây là
    // `Unhandled Exception` mỗi lần lưu giao dịch.
    handleWith((call) async {
      if (call.method == 'updateWidget') {
        throw PlatformException(
          code: '-3',
          message: 'No Widget found with Name SpendingWidgetProvider',
        );
      }
      return true;
    });

    await expectLater(
      const SpendingWidgetService().sync(
        summary,
        updatedAt: DateTime(2026, 8, 23, 9, 5, 7),
      ),
      completes,
    );
    expect(calls, contains('updateWidget'));
  });

  test('lưu dữ liệu hỏng ngay từ bước đầu cũng không ném ra ngoài', () async {
    handleWith((_) async {
      throw PlatformException(code: '-1', message: 'no shared prefs');
    });
    await expectLater(
      const SpendingWidgetService().sync(
        summary,
        updatedAt: DateTime(2026, 8, 23, 9, 5, 7),
      ),
      completes,
    );
  });
}
