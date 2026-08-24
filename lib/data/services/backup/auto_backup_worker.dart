import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../db/database.dart';
import '../../db/open_database.dart';
import '../../repositories/recurring_transaction_repository.dart';
import '../notifications/recurring_reminder_service.dart';
import 'android_saf_destination.dart';
import 'backup_service.dart';

const autoBackupUniqueName = 'tonyfino-daily-maintenance';
const _lastBackupAtKey = 'tonyfino_last_backup_at';

/// Chạy trong ISOLATE RIÊNG do WorkManager tạo (không phải isolate chính của
/// app, không có `ProviderScope`) — mọi thứ nó cần (DB, secure storage,
/// shared_preferences) phải tự mở lại từ đầu, giống hệt `bootstrap.dart`
/// làm cho isolate chính.
@pragma('vm:entry-point')
void backupCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final db = await openAppDatabase();
    try {
      final destination = AndroidSafDestination();
      // KHÔNG gọi thẳng `destination.write()` nếu chưa có thư mục đã cấp —
      // nhánh đó tự mở hộp thoại chọn thư mục, không thể làm khi không có
      // Activity foreground nào đang hiển thị (đang chạy nền).
      if (await destination.hasGrantedDirectory()) {
        final backupService = BackupService(db);
        final now = clock.now();
        final bytes = await backupService.exportToJson(exportedAt: now);
        final result = await destination.write('tonyfino_backup.json', bytes);
        if (result.isOk) {
          await SharedPreferencesAsync().setString(
            _lastBackupAtKey,
            now.toIso8601String(),
          );
        }
      }

      final reminderService = RecurringReminderService();
      final recurringRepo = RecurringTransactionRepository(db);
      final active = await recurringRepo.watchActive().first;
      await reminderService.rescheduleAll(active);

      return true;
    } catch (e, stack) {
      // 🚨 GHI LẠI lý do, đừng nuốt.
      //
      // `catch (_) { return false; }` biến mọi hỏng hóc thành một dấu hỏi:
      // Tony chỉ thấy "sao lưu tự động bị lỗi" mà không ai — kể cả tôi —
      // biết hỏng ở đâu. Ghi vào `app_events` (bảng vẫn còn sống trong
      // isolate này vì `db` mở ở trên) để lần sau soi được.
      try {
        await db
            .into(db.appEvents)
            .insert(
              AppEventsCompanion.insert(
                level: 'error',
                message: 'auto_backup_failed',
                contextJson: Value('{"error":"$e","stack":"$stack"}'),
              ),
            );
      } on Object {
        // Ghi log mà cũng hỏng thì thôi — không để nó che mất lỗi gốc.
      }
      return false;
    } finally {
      await db.close();
    }
  });
}

/// Đăng ký/huỷ tác vụ nền — gọi từ `bootstrap.dart` (đăng ký, idempotent qua
/// `ExistingPeriodicWorkPolicy.keep`) và từ Settings khi Tony tắt cờ sao lưu
/// tự động. `frequency: 24h` là XIN, không phải HỨA — xem docs/decisions.md
/// § Phase 12 "Auto-backup: KHÔNG hứa chạy đúng giờ mỗi ngày".
class AutoBackupScheduler {
  const AutoBackupScheduler();

  Future<void> initialize() async {
    await Workmanager().initialize(backupCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      autoBackupUniqueName,
      autoBackupUniqueName,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.notRequired),
      // Phase 24 — WorkManager có thể chạy lần đầu gần như NGAY sau khi
      // đăng ký (không mặc định đợi hết `frequency`) — trên một lần cài
      // MỚI, điều đó khiến isolate nền này đua với isolate chính để tạo
      // schema DB lần đầu trên CÙNG một file, bắt được sống qua diễn tập
      // backup→gỡ cài→restore (xem `PRAGMA busy_timeout` mới thêm ở
      // `open_database.dart` — sửa gốc rễ; delay này chỉ giảm khả năng va
      // chạm xảy ra ngay từ đầu, không phải sửa chính).
      initialDelay: const Duration(minutes: 1),
    );
  }

  Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(autoBackupUniqueName);
  }
}
