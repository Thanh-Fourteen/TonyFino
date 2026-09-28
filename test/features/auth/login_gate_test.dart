// Màn Đăng nhập riêng, chặn trước app — Tony 2026-09-28: "lần đầu phải
// đăng nhập rồi mới vào app, chứ không phải cứ vào trang cài đặt là load
// đăng nhập".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonyfino/core/lifecycle/login_gate.dart';
import 'package:tonyfino/core/result/result.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/services/google/google_account.dart';
import 'package:tonyfino/data/services/google/google_providers.dart';
import 'package:tonyfino/data/services/google/google_sign_in_service.dart';
import 'package:tonyfino/features/auth/auth_controller.dart';

import '../../support/fake_google_sign_in.dart';
import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

const _account = GoogleAccount(email: 'tony@example.com', displayName: 'Tony');

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<void> pumpGate(
    WidgetTester tester,
    FakeGoogleSignInService google,
  ) async {
    await pumpApp(
      tester,
      db: db,
      child: const LoginGate(child: Text('Nội dung app thật')),
      extraOverrides: [googleSignInServiceProvider.overrideWithValue(google)],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lần đầu mở app → chỉ thấy màn Đăng nhập, không lọt vào app', (
    tester,
  ) async {
    await pumpGate(tester, FakeGoogleSignInService());
    expect(find.text('Đăng nhập TonyFino'), findsOneWidget);
    expect(find.text('Nội dung app thật'), findsNothing);
    // Chưa hỏng lần nào thì KHÔNG có lối vào không tài khoản.
    expect(find.textContaining('Vào app không tài khoản'), findsNothing);
  });

  testWidgets('đăng nhập thành công → vào app, và lần mở sau đi thẳng vào '
      '(không hỏi Google lại — mở lúc mất mạng vẫn được)', (tester) async {
    final google = FakeGoogleSignInService(
      results: [const Result.ok(_account)],
    );
    await pumpGate(tester, google);
    await tester.tap(find.text('Đăng nhập bằng Google'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung app thật'), findsOneWidget);
    expect(
      await SharedPreferencesAsync().getString('tonyfino_auth_email'),
      'tony@example.com',
    );

    // "Mở lại app": cây mới, cùng prefs.
    await tester.pumpWidget(const SizedBox());
    final fresh = FakeGoogleSignInService();
    await pumpGate(tester, fresh);
    expect(find.text('Nội dung app thật'), findsOneWidget);
    expect(fresh.signInCalls, 0);
  });

  testWidgets('🚨 huỷ bảng chọn tài khoản CŨNG mở lối vào — trên máy ảo, '
      'luồng Google tự hỏng thì Back là đường thoát duy nhất và plugin báo '
      '"huỷ"', (tester) async {
    final google = FakeGoogleSignInService(
      results: [const Result.err(GoogleSignInCanceled())],
    );
    await pumpGate(tester, google);
    await tester.tap(find.text('Đăng nhập bằng Google'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập TonyFino'), findsOneWidget);
    expect(find.text('Đã huỷ đăng nhập Google.'), findsOneWidget);
    expect(find.textContaining('Vào app không tài khoản'), findsOneWidget);
  });

  testWidgets('bỏ qua được nhớ: mở lại app không hỏi đăng nhập nữa', (
    tester,
  ) async {
    final google = FakeGoogleSignInService(
      results: [const Result.err(GoogleSignInCanceled())],
    );
    await pumpGate(tester, google);
    await tester.tap(find.text('Đăng nhập bằng Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Vào app không tài khoản'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await pumpGate(tester, FakeGoogleSignInService());
    expect(find.text('Nội dung app thật'), findsOneWidget);
  });

  testWidgets('🚨 đăng nhập hỏng THẬT → có lối vào app, không khoá Tony ngoài '
      'sổ của chính mình', (tester) async {
    final google = FakeGoogleSignInService(
      results: [
        const Result.err(
          AppError('Đăng nhập Google thất bại: no Play Services'),
        ),
      ],
    );
    await pumpGate(tester, google);
    await tester.tap(find.text('Đăng nhập bằng Google'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no Play Services'), findsOneWidget);

    await tester.tap(find.textContaining('Vào app không tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung app thật'), findsOneWidget);
  });

  testWidgets('đăng xuất → quay về màn Đăng nhập', (tester) async {
    await SharedPreferencesAsync().setString(
      'tonyfino_auth_email',
      'tony@example.com',
    );
    final google = FakeGoogleSignInService();
    await pumpGate(tester, google);
    expect(find.text('Nội dung app thật'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LoginGate)),
    );
    await container.read(authControllerProvider.notifier).signOut();
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập TonyFino'), findsOneWidget);
    expect(google.signOutCalls, 1);
  });
}
