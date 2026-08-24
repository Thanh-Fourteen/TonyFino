import 'package:drift_flutter/drift_flutter.dart';

import 'database.dart';
import 'database_key_store.dart';

/// Mở `AppDatabase` thật cho app chạy: giải/tạo khoá từ secure storage rồi
/// mã hoá tại chỗ bằng sqlite3mc (`PRAGMA key`, Spike F1). Không dùng trong
/// test — test dùng `NativeDatabase.memory(closeStreamsSynchronously: true)`
/// trực tiếp để khỏi phụ thuộc platform channel của `flutter_secure_storage`.
Future<AppDatabase> openAppDatabase({DatabaseKeyStore? keyStore}) async {
  final key = await (keyStore ?? const DatabaseKeyStore()).loadOrCreate();

  final connection = driftDatabase(
    name: 'tonyfino',
    native: DriftNativeOptions(
      setup: (db) {
        db.execute("PRAGMA key = '$key';");
        // Phase 24 — bắt được SỐNG qua diễn tập backup→gỡ cài→restore: lần
        // cài mới đầu tiên, isolate chính (mở DB lúc app khởi động) VÀ
        // isolate nền của `AutoBackupScheduler` (đăng ký vô điều kiện từ
        // `bootstrap.dart`, WorkManager có thể chạy gần như ngay sau khi
        // đăng ký) cùng gọi `openAppDatabase()` gần như đồng thời, đua nhau
        // tạo schema lần đầu trên CÙNG một file DB — không có
        // `busy_timeout` thì SQLite némthẳng "database is locked" thay vì
        // đợi, sập ngay giữa `PRAGMA user_version = ...` (xem
        // docs/decisions.md § Phase 24). 5s đủ cho một lượt tạo/di chuyển
        // schema hoàn tất, không đáng chú ý với người dùng thật.
        db.execute('PRAGMA busy_timeout = 5000;');
      },
    ),
  );

  return AppDatabase(connection);
}
