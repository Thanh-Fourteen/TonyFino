import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/transactions/domain/entry_streak.dart';

void main() {
  group('computeEntryStreakDays', () {
    test('không có giao dịch nào → 0', () {
      expect(
        computeEntryStreakDays(occurredDates: [], today: DateTime(2026, 8, 22)),
        0,
      );
    });

    test('có giao dịch hôm nay, 3 ngày liên tiếp → 3', () {
      final today = DateTime(2026, 8, 22);
      final dates = [
        DateTime(2026, 8, 22, 8, 30),
        DateTime(2026, 8, 21, 19),
        DateTime(2026, 8, 20, 7),
      ];
      expect(computeEntryStreakDays(occurredDates: dates, today: today), 3);
    });

    test('nhiều giao dịch CÙNG NGÀY chỉ đếm 1 ngày, không nhân đôi streak', () {
      final today = DateTime(2026, 8, 22);
      final dates = [
        DateTime(2026, 8, 22, 8),
        DateTime(2026, 8, 22, 12),
        DateTime(2026, 8, 22, 20),
        DateTime(2026, 8, 21, 8),
      ];
      expect(computeEntryStreakDays(occurredDates: dates, today: today), 2);
    });

    test(
      'chưa có giao dịch hôm nay nhưng có hôm qua → streak vẫn tính (chưa đứt)',
      () {
        final today = DateTime(2026, 8, 22);
        final dates = [DateTime(2026, 8, 21), DateTime(2026, 8, 20)];
        expect(computeEntryStreakDays(occurredDates: dates, today: today), 2);
      },
    );

    test('ngày gần nhất xa hơn hôm qua → streak đã đứt, trả về 0', () {
      final today = DateTime(2026, 8, 22);
      final dates = [DateTime(2026, 8, 19), DateTime(2026, 8, 18)];
      expect(computeEntryStreakDays(occurredDates: dates, today: today), 0);
    });

    test('có lỗ hổng giữa chừng → streak dừng lại đúng chỗ đứt', () {
      final today = DateTime(2026, 8, 22);
      final dates = [
        DateTime(2026, 8, 22),
        DateTime(2026, 8, 21),
        // 8/20 THIẾU — lỗ hổng.
        DateTime(2026, 8, 19),
        DateTime(2026, 8, 18),
      ];
      expect(computeEntryStreakDays(occurredDates: dates, today: today), 2);
    });

    test(
      '🚨 tính theo ngày GIAO DỊCH (occurredAt), không phải thứ tự nhập — '
      'nhập bù một ngày CŨ trong danh sách không làm streak sai/lẫn lộn với '
      'ngày hôm nay, vì hàm chỉ nhận occurredAt, không có khái niệm "lúc nhập"',
      () {
        final today = DateTime(2026, 8, 22);
        // Giả lập: hôm nay nhập bù một giao dịch của NGÀY 20/8 (backfill),
        // rồi mới nhập một giao dịch thật của hôm nay — thứ tự trong list
        // (giả lập thứ tự chèn) không ảnh hưởng gì tới streak, chỉ NGÀY của
        // từng giao dịch mới có ý nghĩa.
        final backfilledThenToday = [
          DateTime(2026, 8, 20), // nhập bù lúc 22/8, nhưng NGÀY GIAO DỊCH=20
          DateTime(2026, 8, 22),
          DateTime(2026, 8, 21),
        ];
        expect(
          computeEntryStreakDays(
            occurredDates: backfilledThenToday,
            today: today,
          ),
          3,
        );
      },
    );

    test('vượt qua ranh giới tháng vẫn đếm đúng', () {
      final today = DateTime(2026, 9, 1);
      final dates = [DateTime(2026, 9, 1), DateTime(2026, 8, 31)];
      expect(computeEntryStreakDays(occurredDates: dates, today: today), 2);
    });

    test('giờ trong ngày không ảnh hưởng — chỉ NGÀY mới có ý nghĩa', () {
      final today = DateTime(2026, 8, 22, 23, 59);
      final dates = [DateTime(2026, 8, 22, 0, 1)];
      expect(computeEntryStreakDays(occurredDates: dates, today: today), 1);
    });
  });
}
