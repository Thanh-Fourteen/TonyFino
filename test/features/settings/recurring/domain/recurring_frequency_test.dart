import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/settings/recurring/domain/recurring_frequency.dart';

void main() {
  group('computeNextOccurrence — daily/weekly', () {
    test('daily: +1 ngày, giữ nguyên giờ', () {
      final next = computeNextOccurrence(
        DateTime(2026, 8, 21, 9, 30),
        RecurringFrequency.daily,
      );
      expect(next, DateTime(2026, 8, 22, 9, 30));
    });

    test('weekly: +7 ngày', () {
      final next = computeNextOccurrence(
        DateTime(2026, 8, 21, 9, 30),
        RecurringFrequency.weekly,
      );
      expect(next, DateTime(2026, 8, 28, 9, 30));
    });
  });

  group(
    'computeNextOccurrence — monthly, kẹp ngày cuối tháng thay vì tràn',
    () {
      test(
        '31/1 hàng tháng → kỳ tới là 28/2 (2026 không nhuận), KHÔNG phải 3/3',
        () {
          final next = computeNextOccurrence(
            DateTime(2026, 1, 31, 9),
            RecurringFrequency.monthly,
          );
          expect(next, DateTime(2026, 2, 28, 9));
        },
      );

      test('31/1 hàng tháng, năm nhuận → kỳ tới là 29/2/2024', () {
        final next = computeNextOccurrence(
          DateTime(2024, 1, 31, 9),
          RecurringFrequency.monthly,
        );
        expect(next, DateTime(2024, 2, 29, 9));
      });

      test('🚨 ranh giới năm: 15/12 hàng tháng → kỳ tới là 15/1 năm SAU', () {
        final next = computeNextOccurrence(
          DateTime(2026, 12, 15, 9),
          RecurringFrequency.monthly,
        );
        expect(next, DateTime(2027, 1, 15, 9));
      });

      test('ngày giữa tháng không bị kẹp (15/8 → 15/9)', () {
        final next = computeNextOccurrence(
          DateTime(2026, 8, 15, 9),
          RecurringFrequency.monthly,
        );
        expect(next, DateTime(2026, 9, 15, 9));
      });
    },
  );

  group('computeNextOccurrence — yearly, kẹp 29/2 năm không nhuận', () {
    test(
      '29/2/2024 (nhuận) → kỳ tới 28/2/2025 (không nhuận), KHÔNG tràn sang 1/3',
      () {
        final next = computeNextOccurrence(
          DateTime(2024, 2, 29, 9),
          RecurringFrequency.yearly,
        );
        expect(next, DateTime(2025, 2, 28, 9));
      },
    );

    test('ngày thường +1 năm không đổi tháng/ngày', () {
      final next = computeNextOccurrence(
        DateTime(2026, 8, 21, 9),
        RecurringFrequency.yearly,
      );
      expect(next, DateTime(2027, 8, 21, 9));
    });
  });

  group('RecurringFrequency.fromDbValue', () {
    test('round-trip đúng cho cả 4 giá trị', () {
      for (final f in RecurringFrequency.values) {
        expect(RecurringFrequency.fromDbValue(f.dbValue), f);
      }
    });

    test('giá trị lạ ném lỗi rõ ràng thay vì âm thầm rơi về mặc định', () {
      expect(
        () => RecurringFrequency.fromDbValue('hourly'),
        throwsArgumentError,
      );
    });
  });
}
