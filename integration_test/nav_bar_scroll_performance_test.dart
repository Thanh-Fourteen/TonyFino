// Phase 24 § Xác minh: "đo hiệu năng cuộn 1000+ giao dịch bằng DevTools, đặc
// biệt chú ý BackdropFilter của nav bar mờ (một lượt render offscreen thật
// sự tốn GPU trên máy tầm trung)". Phase 22's `hero_scroll_performance_test.dart`
// mount thẳng `TransactionsScreen` trong một `MaterialApp` trần — KHÔNG đi
// qua `AppShell`, nên KHÔNG hề có `AppBottomNav`/`GlassSurface`/`BackdropFilter`
// trong phép đo đó. Bài test này lấp đúng khoảng đó: dựng lại CHÍNH XÁC cách
// `AppShell` bố trí — `Scaffold(extendBody: true, bottomNavigationBar:
// AppBottomNav(...))` — rồi so sánh CÙNG một cú cuộn 1000 dòng CÓ và KHÔNG
// có `GlassSurface` (chỉ khác đúng một dòng: thay `AppBottomNav` thật bằng
// một `SizedBox` cùng chiều cao, không blur) để cô lập ĐÚNG chi phí THÊM VÀO
// bởi BackdropFilter, cùng phương pháp Phase 22 đã dùng cho animation hero
// card.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tonyfino/core/providers/database_providers.dart';
import 'package:tonyfino/core/router/app_bottom_nav.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/transactions/transactions_screen.dart';
import 'package:tonyfino/theme/app_theme.dart';

const _kTransactionCount = 1000;

AppDatabase _openDb() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

Future<AppDatabase> _seedDatabase() async {
  final db = _openDb();
  final walletId = (await db.select(db.wallets).get()).first.id;
  final categoryId = (await db.select(db.categories).get()).first.id;
  final start = DateTime(2024, 1, 1);

  await db.batch((batch) {
    batch.insertAll(db.transactions, [
      for (var i = 0; i < _kTransactionCount; i++)
        TransactionsCompanion.insert(
          amountMinor: i.isEven ? -((i % 50) + 1) * 1000 : ((i % 30) + 1) * 5000,
          currency: 'VND',
          currencyScale: 0,
          occurredAt: start.add(Duration(hours: i * 6)),
          walletId: walletId,
          categoryId: Value(categoryId),
          note: Value('Giao dịch số $i'),
        ),
    ]);
  });
  return db;
}

class FrameTimingSummary {
  const FrameTimingSummary({
    required this.frameCount,
    required this.avgBuildMs,
    required this.worstBuildMs,
    required this.avgRasterMs,
    required this.worstRasterMs,
  });

  factory FrameTimingSummary.from(List<FrameTiming> timings) {
    if (timings.isEmpty) {
      return const FrameTimingSummary(
        frameCount: 0,
        avgBuildMs: 0,
        worstBuildMs: 0,
        avgRasterMs: 0,
        worstRasterMs: 0,
      );
    }
    final build = timings
        .map((t) => t.buildDuration.inMicroseconds / 1000)
        .toList();
    final raster = timings
        .map((t) => t.rasterDuration.inMicroseconds / 1000)
        .toList();
    return FrameTimingSummary(
      frameCount: timings.length,
      avgBuildMs: build.reduce((a, b) => a + b) / build.length,
      worstBuildMs: build.reduce((a, b) => a > b ? a : b),
      avgRasterMs: raster.reduce((a, b) => a + b) / raster.length,
      worstRasterMs: raster.reduce((a, b) => a > b ? a : b),
    );
  }

  final int frameCount;
  final double avgBuildMs;
  final double worstBuildMs;
  final double avgRasterMs;
  final double worstRasterMs;

  @override
  String toString() =>
      'frames=$frameCount avgBuild=${avgBuildMs.toStringAsFixed(2)}ms '
      'worstBuild=${worstBuildMs.toStringAsFixed(2)}ms '
      'avgRaster=${avgRasterMs.toStringAsFixed(2)}ms '
      'worstRaster=${worstRasterMs.toStringAsFixed(2)}ms';
}

Future<FrameTimingSummary> _measureScroll(
  WidgetTester tester,
  AppDatabase db, {
  required bool withGlassNav,
}) async {
  await tester.pumpWidget(_TestApp(db: db, withGlassNav: withGlassNav));
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }

  final listFinder = find.byType(Scrollable).first;
  final frameTimings = <FrameTiming>[];
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  final watcher = frameTimings.addAll;
  binding.addTimingsCallback(watcher);

  for (var i = 0; i < 8; i++) {
    await tester.fling(listFinder, const Offset(0, -2000), 3000);
    for (var j = 0; j < 12; j++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  binding.removeTimingsCallback(watcher);
  return FrameTimingSummary.from(frameTimings);
}

/// Dựng lại ĐÚNG bố cục `AppShell` thật (`Scaffold(extendBody: true,
/// bottomNavigationBar: ...)`) — [withGlassNav] false thay `AppBottomNav`
/// thật bằng một `SizedBox` CÙNG chiều cao (không `BackdropFilter`), giữ mọi
/// thứ khác giống hệt để phép so sánh chỉ khác đúng một biến.
class _TestApp extends StatelessWidget {
  const _TestApp({required this.db, required this.withGlassNav});
  final AppDatabase db;
  final bool withGlassNav;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          extendBody: true,
          body: const TransactionsScreen(),
          bottomNavigationBar: withGlassNav
              ? AppBottomNav(currentIndex: 1, onTap: (_) {})
              : const SizedBox(height: 88),
        ),
      ),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Cuộn 1000 giao dịch: SO SÁNH có/không GlassSurface (BackdropFilter) ở '
    'nav bar — cô lập chi phí GPU riêng của blur, không phải cảm giác',
    (tester) async {
      final db = await _seedDatabase();
      addTearDown(db.close);

      final withGlass = await _measureScroll(tester, db, withGlassNav: true);
      final withoutGlass = await _measureScroll(
        tester,
        db,
        withGlassNav: false,
      );

      // ignore: avoid_print
      print('[Phase 24 nav-bar scroll perf] CÓ GlassSurface:    $withGlass');
      // ignore: avoid_print
      print('[Phase 24 nav-bar scroll perf] KHÔNG GlassSurface: $withoutGlass');

      IntegrationTestWidgetsFlutterBinding.instance.reportData = {
        'withGlassNav': {
          'frameCount': withGlass.frameCount,
          'avgBuildMs': withGlass.avgBuildMs,
          'worstBuildMs': withGlass.worstBuildMs,
          'avgRasterMs': withGlass.avgRasterMs,
          'worstRasterMs': withGlass.worstRasterMs,
        },
        'withoutGlassNav': {
          'frameCount': withoutGlass.frameCount,
          'avgBuildMs': withoutGlass.avgBuildMs,
          'worstBuildMs': withoutGlass.worstBuildMs,
          'avgRasterMs': withoutGlass.avgRasterMs,
          'worstRasterMs': withoutGlass.worstRasterMs,
        },
      };

      expect(withGlass.frameCount, greaterThan(0));
      expect(withoutGlass.frameCount, greaterThan(0));
    },
  );
}
