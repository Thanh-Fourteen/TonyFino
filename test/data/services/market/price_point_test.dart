import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/services/market/price_point.dart';

void main() {
  final points = [
    for (var d = 1; d <= 30; d++) PricePoint(DateTime(2026, 9, d, 13), d * 1.0),
  ];

  test('nút có sẵn: tính NGƯỢC từ điểm mới nhất', () {
    final week = pointsInWindow(points, const ChartWindow.preset(ChartSpan.week));
    expect(week.first.time.day, 23);
    expect(week.last.time.day, 30);
  });

  test('khoảng tự chọn: tính cả hai đầu, so theo NGÀY không theo giờ', () {
    // Điểm lúc 13:00 ngày 10 và 20 vẫn thuộc khoảng 10/9 00:00 – 20/9 00:00.
    final picked = pointsInWindow(
      points,
      ChartWindow.custom(DateTime(2026, 9, 10), DateTime(2026, 9, 20)),
    );
    expect(picked.first.time.day, 10);
    expect(picked.last.time.day, 20);
    expect(picked.length, 11);
  });

  test('hai khoảng giống nhau thì bằng nhau (không vẽ lại vô cớ)', () {
    expect(
      ChartWindow.custom(DateTime(2026, 9, 1), DateTime(2026, 9, 5)),
      ChartWindow.custom(DateTime(2026, 9, 1), DateTime(2026, 9, 5)),
    );
    expect(
      const ChartWindow.preset(ChartSpan.month),
      isNot(const ChartWindow.preset(ChartSpan.week)),
    );
  });
}
