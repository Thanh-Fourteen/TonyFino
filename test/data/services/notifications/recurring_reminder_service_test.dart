import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/services/notifications/recurring_reminder_service.dart';

void main() {
  group('reminderMoment — 9h sáng LOCAL ngày đến hạn', () {
    test('giữ nguyên ngày/tháng/năm, chốt giờ về 9:00:00', () {
      expect(
        reminderMoment(DateTime(2026, 8, 21, 23, 59, 59)),
        DateTime(2026, 8, 21, 9),
      );
    });

    test(
      '🚨 ranh giới tháng: ngày đến hạn là 1/9 → nhắc đúng 9h sáng 1/9, không lệch sang 31/8',
      () {
        expect(reminderMoment(DateTime(2026, 9, 1)), DateTime(2026, 9, 1, 9));
      },
    );

    test('🚨 ranh giới năm: ngày đến hạn là 1/1 năm sau', () {
      expect(reminderMoment(DateTime(2027, 1, 1)), DateTime(2027, 1, 1, 9));
    });
  });
}
