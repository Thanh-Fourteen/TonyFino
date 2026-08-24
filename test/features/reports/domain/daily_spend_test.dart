import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/reports/domain/daily_spend.dart';

void main() {
  group('spendLevel', () {
    test('0 đồng hoặc không có ngày chi nào trong khoảng → bậc 0', () {
      expect(spendLevel(0, 100000), 0);
      expect(spendLevel(50000, 0), 0);
    });

    test('4 bậc theo tỉ lệ so với ngày chi nhiều nhất', () {
      const max = 100000;
      expect(spendLevel(10000, max), 1); // 10% ≤ 25%
      expect(spendLevel(40000, max), 2); // 40% ≤ 50%
      expect(spendLevel(60000, max), 3); // 60% ≤ 75%
      expect(spendLevel(100000, max), 4); // 100%
    });

    test('nhận cả hai chiều dấu (âm/dương) — luôn lấy trị tuyệt đối', () {
      expect(spendLevel(-100000, -100000), 4);
    });
  });

  group('buildHeatmapWeeks', () {
    test(
      'lưới luôn tròn tuần Thứ Hai→Chủ Nhật, đệm ô ngoài khoảng bằng cell trống',
      () {
        // 2026-08-21 là Thứ Sáu — khoảng lọc CHỈ một ngày.
        final weeks = buildHeatmapWeeks(
          [DailySpend(date: DateTime(2026, 8, 21), expenseMinor: -35000)],
          rangeStart: DateTime(2026, 8, 21),
          rangeEnd: DateTime(2026, 8, 22),
        );

        expect(weeks, hasLength(1));
        expect(weeks.single, hasLength(7));

        // Cột thứ 5 (chỉ số 4) = Thứ Sáu — đúng ngày có dữ liệu, bậc cao nhất
        // vì đây là ngày chi duy nhất (max = chính nó).
        final fridayCell = weeks.single[4];
        expect(fridayCell.date, DateTime(2026, 8, 21));
        expect(fridayCell.expenseMinor, -35000);
        expect(fridayCell.level, 4);

        // Mọi cột khác trong tuần là ô đệm — date null, không tính bậc.
        for (var i = 0; i < 7; i++) {
          if (i == 4) continue;
          expect(weeks.single[i].date, isNull);
        }
      },
    );

    test(
      'ngày không có giao dịch trong khoảng vẫn có cell (level 0), không bị bỏ qua',
      () {
        final weeks = buildHeatmapWeeks(
          [
            DailySpend(date: DateTime(2026, 8, 17), expenseMinor: -20000),
          ], // Thứ Hai
          rangeStart: DateTime(2026, 8, 17),
          rangeEnd: DateTime(2026, 8, 19), // 17, 18 — 18 không có giao dịch
        );

        expect(weeks, hasLength(1));
        final monday = weeks.single[0];
        final tuesday = weeks.single[1];
        expect(monday.level, 4);
        expect(tuesday.date, DateTime(2026, 8, 18));
        expect(tuesday.expenseMinor, 0);
        expect(tuesday.level, 0);
      },
    );
  });
}
