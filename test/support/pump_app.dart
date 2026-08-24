import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/providers/database_providers.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/theme/app_theme.dart';

/// Bọc [child] bằng `ProviderScope` (override DB bằng [db], thường là
/// `openTestDatabase()`) + `MaterialApp` dùng `lightTheme`/`darkTheme` thật
/// — không dựng go_router, vì các màn hình test riêng lẻ không tự
/// `context.push`, chỉ `AppShell` mới cần router thật. [extraOverrides] cho
/// những test cần đóng băng `clockProvider` (Phase 8: ngày tương đối như
/// "hôm qua" phải xác định được).
Future<void> pumpApp(
  WidgetTester tester, {
  required AppDatabase db,
  required Widget child,
  Brightness brightness = Brightness.light,
  // `dynamic` cố ý, không phải cẩu thả: `Override` (kiểu thật của
  // `ProviderScope.overrides`) không resolve được qua compiler CFE mà
  // `flutter test` dùng khi import qua bất kỳ barrel công khai nào của
  // `flutter_riverpod`/`riverpod` 3.4.2 ("Type 'Override' not found") — dù
  // `flutter analyze` (dùng package `analyzer`, khác CFE) lại thấy được và
  // đòi đúng kiểu đó. Đã thử: import trực tiếp `flutter_riverpod.dart`,
  // `riverpod.dart` — đều lỗi ở CFE; chỉ `package:riverpod/src/framework.dart`
  // (nội bộ, không nên phụ thuộc) mới resolve được. `dynamic` + spread vào
  // literal đích `List<Override>` vẫn đúng lúc CHẠY (ép kiểu ngầm qua từng
  // phần tử) — chỉ `flutter analyze` phàn nàn tĩnh, đã tắt đúng dòng đó.
  List<dynamic> extraOverrides = const [],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        // ignore: list_element_type_not_assignable
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        home: child,
      ),
    ),
  );
}
