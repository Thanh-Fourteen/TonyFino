// Phase 22 § Xác minh: đo hiệu năng cuộn danh sách giao dịch dài (1000+
// dòng) TRƯỚC và SAU khi thêm nền động ở hero card — số cụ thể, không phải
// cảm giác. Chạy thật (không phải fake-async của `flutter test` thường) vì
// `SchedulerBinding.addTimingsCallback`/`FrameTiming` cần engine thật render
// frame thật — cùng khuôn `integration_test/sqlite3mc_device_test.dart`
// (Phase 3), tests dưới `integration_test/` chạy trên thiết bị/emulator
// thật, không phải `flutter test` thường.
//
// So sánh CÙNG MỘT danh sách 1000 giao dịch thật, cuộn CÙNG một quãng đường,
// bật/tắt animation của hero card qua `disableAnimations` (cờ trợ năng có
// thật — xem `AppMascot`/`HeroGradientBackground`, cả hai đều tự tắt
// `repeat()` khi cờ này bật) — cô lập đúng chi phí THÊM VÀO bởi animation
// mới, loại trừ nhiễu từ phần còn lại của app không đổi giữa hai lần đo.
//
// 🚨 KHÔNG dùng `pumpAndSettle()` ở đây — pass "CÓ animation" cố ý để
// `HeroGradientBackground`/`AppMascot` lặp animation vô hạn (đó chính là
// điều đang đo), nên `pumpAndSettle()` treo mãi mãi chờ animation dừng hẳn,
// điều nó sẽ không bao giờ làm. Dùng số lượng `pump()` CỐ ĐỊNH cho cả hai
// lượt đo để công bằng.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tonyfino/core/providers/database_providers.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/transactions/transactions_screen.dart';
import 'package:tonyfino/theme/app_theme.dart';

const _kTransactionCount = 1000;

AppDatabase _openDb() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

/// Chèn thẳng qua `db.batch()` (không qua `TransactionRepository.insert`) —
/// mục tiêu bài test là hiệu năng CUỘN, không phải hiệu năng ghi; batch
/// insert đưa 1000 dòng vào DB trong một giao dịch SQL duy nhất, nhanh hơn
/// nhiều bậc so với 1000 lần `await` tuần tự qua tầng repository (đã đo
/// thấy chậm không cần thiết — 1000 insert tuần tự từng cái một chiếm phần
/// lớn thời gian chạy test, không phải phần đang muốn đo).
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

Future<FrameTimingSummary> _measureScroll(
  WidgetTester tester,
  AppDatabase db,
) async {
  await tester.pumpWidget(_TestApp(db: db));
  // Bơm cố định (không `pumpAndSettle`) — đủ để layout ổn định trên 1000
  // dòng mà không phụ thuộc animation có dừng hẳn hay không.
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }

  final listFinder = find.byType(Scrollable).first;
  final frameTimings = <FrameTiming>[];
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  final watcher = frameTimings.addAll;
  binding.addTimingsCallback(watcher);

  // 8 cú vuốt dài liên tiếp — đủ để cuộn qua phần lớn 1000 dòng. Mỗi lần
  // vuốt xong bơm thêm vài khung để chụp cả phần "đang giảm tốc"
  // (deceleration) của cuộn, không chỉ khung lúc thả tay.
  for (var i = 0; i < 8; i++) {
    await tester.fling(listFinder, const Offset(0, -2000), 3000);
    for (var j = 0; j < 12; j++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  binding.removeTimingsCallback(watcher);
  return FrameTimingSummary.from(frameTimings);
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

class _TestApp extends StatelessWidget {
  const _TestApp({required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: lightTheme, home: const TransactionsScreen()),
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Cuộn 1000 giao dịch: SO SÁNH có/không animation hero card (nền động + '
    'mascot streak) — số đo thật, không phải cảm giác',
    (tester) async {
      final db = await _seedDatabase();
      addTearDown(db.close);

      // BẬT animation (hành vi sản xuất thật) — cờ trợ năng TẮT.
      binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      final withAnimation = await _measureScroll(tester, db);

      // TẮT animation (mô phỏng "trước Phase 22", hero card tĩnh) — dùng
      // ĐÚNG cơ chế `disableAnimations` mà `HeroGradientBackground`/
      // `AppMascot` tự kiểm tra để không lặp animation vô hạn.
      binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      final withoutAnimation = await _measureScroll(tester, db);

      // ignore: avoid_print
      print('[Phase 22 scroll perf] CÓ animation:    $withAnimation');
      // ignore: avoid_print
      print('[Phase 22 scroll perf] KHÔNG animation: $withoutAnimation');

      binding.reportData = {
        'withAnimation': {
          'frameCount': withAnimation.frameCount,
          'avgBuildMs': withAnimation.avgBuildMs,
          'worstBuildMs': withAnimation.worstBuildMs,
          'avgRasterMs': withAnimation.avgRasterMs,
          'worstRasterMs': withAnimation.worstRasterMs,
        },
        'withoutAnimation': {
          'frameCount': withoutAnimation.frameCount,
          'avgBuildMs': withoutAnimation.avgBuildMs,
          'worstBuildMs': withoutAnimation.worstBuildMs,
          'avgRasterMs': withoutAnimation.avgRasterMs,
          'worstRasterMs': withoutAnimation.worstRasterMs,
        },
      };

      expect(withAnimation.frameCount, greaterThan(0));
      expect(withoutAnimation.frameCount, greaterThan(0));
    },
  );
}
