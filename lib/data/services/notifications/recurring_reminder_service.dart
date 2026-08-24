import 'package:clock/clock.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/money/money.dart';
import '../../db/database.dart';

/// Giờ nhắc mặc định trong ngày đến hạn — 9 giờ sáng LOCAL. Hàm THUẦN, tách
/// riêng khỏi mọi thứ đụng platform channel để test được bằng `Clock` đóng
/// băng, không cần plugin thật (xem docs/decisions.md § Phase 12).
DateTime reminderMoment(DateTime occurrenceDate) {
  return DateTime(
    occurrenceDate.year,
    occurrenceDate.month,
    occurrenceDate.day,
    9,
  );
}

/// Lịch nhắc giao dịch định kỳ, qua `flutter_local_notifications`. CHỈ nhắc,
/// KHÔNG BAO GIỜ tự tạo giao dịch (xem docs/decisions.md § Phase 12 "Nhắc
/// định kỳ CHỈ là thông báo") — id thông báo = id dòng `recurring_transactions`
/// nên lên lịch lại một dòng tự động THAY THẾ lịch cũ của chính nó, không
/// cần huỷ tay trước.
///
/// `AndroidScheduleMode.inexactAllowWhileIdle` có chủ đích — KHÔNG dùng mode
/// "exact" (đòi quyền `SCHEDULE_EXACT_ALARM`) cho một tính năng chỉ là NHẮC,
/// không phải báo thức (xem docs/decisions.md § Phase 12 "Auto-backup: KHÔNG
/// hứa chạy đúng giờ").
class RecurringReminderService {
  RecurringReminderService({Clock clock = const Clock()}) : _clock = clock;

  final Clock _clock;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // Cả app giả định Asia/Ho_Chi_Minh (điện thoại Tony + máy dev đều đặt múi
    // giờ này — xem gotcha "drift UTC-vs-local" trong memory dự án); không
    // kéo thêm package `flutter_timezone` chỉ để đọc lại đúng giá trị này.
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  /// Lên lịch lại thông báo cho MỌI dòng đang active — gọi mỗi lần app
  /// resume và mỗi lần tác vụ nền hàng ngày chạy (`AutoBackupWorker`), để
  /// dòng vừa thêm/sửa luôn có lịch đúng mà không cần theo dõi diff.
  Future<void> rescheduleAll(List<RecurringTransaction> active) async {
    await initialize();
    final now = _clock.now();
    for (final row in active) {
      final moment = reminderMoment(row.nextOccurrenceDate);
      if (moment.isBefore(now)) {
        await _plugin.cancel(id: row.id);
        continue;
      }
      final amount = Money(
        minorUnits: row.amountMinor,
        currency: row.currency,
        currencyScale: row.currencyScale,
      );
      await _plugin.zonedSchedule(
        id: row.id,
        title: 'Đến hạn giao dịch định kỳ',
        body: '${amount.format()}${row.note == null ? '' : ' · ${row.note}'}',
        scheduledDate: tz.TZDateTime.from(moment, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'tonyfino_recurring_reminders',
            'Nhắc giao dịch định kỳ',
            channelDescription: 'Nhắc khi một giao dịch định kỳ đến hạn',
            importance: Importance.defaultImportance,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
