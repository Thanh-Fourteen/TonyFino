import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:tonyfino/core/lifecycle/app_lock_gate.dart';
import 'package:tonyfino/core/lifecycle/app_lock_session.dart';
import 'package:tonyfino/features/settings/settings_controller.dart';
import 'package:tonyfino/theme/app_theme.dart';

import '../../support/fake_shared_preferences.dart';

/// Đếm SỐ LẦN app gọi xác thực — thứ duy nhất chứng minh được bug "bấm vào
/// là đứng luôn": mỗi lần huỷ, màn khoá gọi lại ngay lập tức.
class _CountingLocalAuth extends LocalAuthPlatform {
  int calls = 0;
  bool result = false;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    calls++;
    return result;
  }
}

void main() {
  late _CountingLocalAuth auth;

  setUp(() {
    installFakeSharedPreferences();
    auth = _CountingLocalAuth();
    LocalAuthPlatform.instance = auth;
  });

  Future<void> pumpLocked(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsProvider.overrideWith(() => _LockedSettings())],
        child: MaterialApp(
          // Dùng theme THẬT: `_LockScreen` đọc `context.colors`/`context.text`
          // từ ThemeExtension, `MaterialApp` trần sẽ ném TypeError.
          theme: lightTheme,
          home: const AppLockGate(child: Text('NỘI DUNG APP')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    '🚨 xác thực THẤT BẠI/bị huỷ → KHÔNG tự gọi lại vô hạn, và nút "Mở khoá" '
    'phải bấm được lại',
    (tester) async {
      auth.result = false;
      await pumpLocked(tester);

      // Đúng MỘT lần tự động lúc vào màn khoá. Trước khi sửa, `build()` lên
      // lịch `_tryUnlock()` mỗi lần dựng lại khi không đang xác thực — huỷ
      // một lần là nó bật lại ngay, người dùng kẹt cứng không thoát nổi.
      expect(auth.calls, 1, reason: 'chỉ được tự xác thực MỘT lần, không lặp');

      // Bơm thêm nhiều khung hình: nếu còn vòng lặp, số lần gọi sẽ tăng.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(auth.calls, 1, reason: 'không được tự gọi thêm sau khi thất bại');

      // Vẫn ở màn khoá, và nút bấm lại được (không bị vô hiệu vĩnh viễn).
      expect(find.text('NỘI DUNG APP'), findsNothing);
      final button = find.widgetWithText(FilledButton, 'Thử lại');
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

      // Bấm tay thì mới xác thực lần nữa — và lần này thành công thì vào app.
      auth.result = true;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(auth.calls, 2);
      expect(find.text('NỘI DUNG APP'), findsOneWidget);
    },
  );

  testWidgets('xác thực thành công ngay lần đầu → vào thẳng app', (
    tester,
  ) async {
    auth.result = true;
    await pumpLocked(tester);
    expect(auth.calls, 1);
    expect(find.text('NỘI DUNG APP'), findsOneWidget);
  });

  testWidgets('🚨 KHỞI ĐỘNG LẠNH vẫn khoá, kể cả khi cờ cài đặt bật lên MUỘN', (
    tester,
  ) async {
    // Bẫy đã dính một lần: cài đặt nạp từ prefs bất đồng bộ, nên mỗi lần
    // khởi động lạnh `biometricLockEnabled` đi từ `false` (mặc định) lên
    // `true` (giá trị đã lưu). Bản sửa cũ bắt đúng chuyển dịch đó để coi
    // là "người dùng vừa bật công tắc" → app KHÔNG BAO GIỜ khoá nữa,
    // trong khi Cài đặt vẫn báo đã bật. Mất hẳn tính năng bảo mật mà
    // không có dấu hiệu nào.
    auth.result = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(() => _LateLockedSettings()),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: const AppLockGate(child: Text('NỘI DUNG APP')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NỘI DUNG APP'), findsNothing);
    expect(find.text('TonyFino đã khoá'), findsOneWidget);
  });

  testWidgets(
    'BẬT công tắc trong Cài đặt → phiên đang dùng KHÔNG bị ném ra màn khoá',
    (tester) async {
      auth.result = false;
      final container = ProviderContainer(
        overrides: [
          appSettingsProvider.overrideWith(() => _UnlockedSettings()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: lightTheme,
            home: const AppLockGate(child: Text('NỘI DUNG APP')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NỘI DUNG APP'), findsOneWidget);

      // Đúng thứ tự màn Cài đặt làm: tin phiên trước, rồi mới bật cờ.
      container.read(appLockSessionProvider.notifier).trust();
      container
          .read(appSettingsProvider.notifier)
          .setBiometricLockEnabled(true);
      await tester.pumpAndSettle();

      expect(find.text('NỘI DUNG APP'), findsOneWidget);
      expect(auth.calls, 0);
    },
  );
}

/// Cài đặt bật khoá NGAY từ `build()` nhưng mô phỏng đúng đường đi thật:
/// khung hình đầu là mặc định (tắt), khung sau mới có giá trị đã lưu.
class _LateLockedSettings extends AppSettingsController {
  @override
  AppSettings build() {
    Future.microtask(
      () => state = AppSettings.initial.copyWith(biometricLockEnabled: true),
    );
    return AppSettings.initial;
  }
}

/// Cài đặt TẮT khoá, nhưng cho phép bật qua `setBiometricLockEnabled`.
class _UnlockedSettings extends AppSettingsController {
  @override
  AppSettings build() => AppSettings.initial;

  @override
  Future<void> setBiometricLockEnabled(bool value) async {
    state = state.copyWith(biometricLockEnabled: value);
  }
}

/// Settings với khoá sinh trắc học BẬT sẵn.
class _LockedSettings extends AppSettingsController {
  @override
  AppSettings build() =>
      AppSettings.initial.copyWith(biometricLockEnabled: true);
}
