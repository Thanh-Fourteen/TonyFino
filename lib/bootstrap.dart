import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/database_providers.dart';
import 'data/db/open_database.dart';
import 'data/services/backup/auto_backup_worker.dart';

/// Khởi tạo chung trước khi chạy app. Gọi từ main().
Future<Widget> bootstrap(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge (Android 15+ cưỡng chế). System bar trong suốt, KHÔNG set màu
  // nền cho chúng — set màu là deprecated trên Android 15+ và Play cảnh báo.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Mở DB (mã hoá qua sqlite3mc, khoá từ flutter_secure_storage — Phase 4)
  // MỘT LẦN ở đây, TRƯỚC runApp() — mọi provider phía dưới đồng bộ.
  final db = await openAppDatabase();

  // Đăng ký tác vụ nền hàng ngày (Phase 12) — idempotent
  // (`ExistingPeriodicWorkPolicy.keep`), an toàn gọi lại mỗi lần khởi động.
  // Bọc try/catch: đăng ký thất bại (vd. Play services thiếu trên một số
  // emulator) không được phép chặn app khởi động — health-check lúc resume
  // vẫn là lưới an toàn chính, `workmanager` chỉ là "đai an toàn thêm" (D5).
  try {
    await const AutoBackupScheduler().initialize();
  } catch (_) {
    // Không có nơi nào hợp lý để báo lỗi này TRƯỚC khi UI tồn tại — health
    // banner (nếu Tony đã bật auto-backup) sẽ tự lộ ra ở lần resume kế tiếp.
  }

  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: app,
  );
}
