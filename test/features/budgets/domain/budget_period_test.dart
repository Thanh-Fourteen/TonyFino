import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/budgets/domain/budget_period.dart';

void main() {
  group('BudgetPeriod — ranh giới tháng', () {
    test('start/end là nửa khoảng [đầu tháng, đầu tháng sau)', () {
      final period = const BudgetPeriod(year: 2026, month: 8);
      expect(period.start, DateTime(2026, 8, 1));
      expect(period.end, DateTime(2026, 9, 1));
    });

    test(
      '🚨 ranh giới chuyển năm: tháng 12 → end là 1/1 năm SAU, không lỗi/không lùi năm',
      () {
        final december = const BudgetPeriod(year: 2026, month: 12);
        expect(december.end, DateTime(2027, 1, 1));
        expect(december.next, const BudgetPeriod(year: 2027, month: 1));
      },
    );

    test('previous của tháng 1 là tháng 12 năm TRƯỚC', () {
      final january = const BudgetPeriod(year: 2027, month: 1);
      expect(january.previous, const BudgetPeriod(year: 2026, month: 12));
    });

    test('daysInMonth đúng cho tháng thường, tháng 31 ngày, và năm nhuận', () {
      expect(
        const BudgetPeriod(year: 2026, month: 2).daysInMonth,
        28,
      ); // 2026 không nhuận
      expect(
        const BudgetPeriod(year: 2024, month: 2).daysInMonth,
        29,
      ); // 2024 nhuận
      expect(const BudgetPeriod(year: 2026, month: 1).daysInMonth, 31);
      expect(const BudgetPeriod(year: 2026, month: 4).daysInMonth, 30);
    });

    test('yearMonthKey khớp định dạng cột DB (YYYY-MM, tháng đệm 0)', () {
      expect(const BudgetPeriod(year: 2026, month: 8).yearMonthKey, '2026-08');
      expect(const BudgetPeriod(year: 2026, month: 12).yearMonthKey, '2026-12');
    });

    test('contains() đúng ở biên đầu (bao gồm) và biên cuối (loại trừ)', () {
      final period = const BudgetPeriod(year: 2026, month: 8);
      expect(period.contains(DateTime(2026, 8, 1)), isTrue);
      expect(period.contains(DateTime(2026, 8, 31, 23, 59)), isTrue);
      expect(
        period.contains(DateTime(2026, 9, 1)),
        isFalse,
      ); // đầu tháng sau — KHÔNG thuộc
      expect(period.contains(DateTime(2026, 7, 31, 23, 59)), isFalse);
    });
  });

  group('BudgetPeriod.paceFraction — vị trí trong tháng cho vạch nhịp', () {
    test('ngày 10 của tháng 30 ngày → pace = 10/30', () {
      final period = const BudgetPeriod(year: 2026, month: 4); // 30 ngày
      expect(
        period.paceFraction(DateTime(2026, 4, 10)),
        closeTo(10 / 30, 1e-9),
      );
    });

    test(
      'ngày 25 của tháng 30 ngày → pace = 25/30 (ví dụ "60% ở ngày 25 là tuyệt")',
      () {
        final period = const BudgetPeriod(year: 2026, month: 4);
        expect(
          period.paceFraction(DateTime(2026, 4, 25)),
          closeTo(25 / 30, 1e-9),
        );
      },
    );

    test('kỳ đã qua hẳn (đang xem tháng trước "now") → pace = 1.0', () {
      final period = const BudgetPeriod(year: 2026, month: 6);
      expect(period.paceFraction(DateTime(2026, 8, 21)), 1.0);
    });

    test('kỳ chưa tới (đang xem tháng sau "now") → pace = 0.0', () {
      final period = const BudgetPeriod(year: 2026, month: 10);
      expect(period.paceFraction(DateTime(2026, 8, 21)), 0.0);
    });

    test(
      '🚨 ranh giới năm: xem tháng 1/2027 lúc "now" là 31/12/2026 → pace = 0.0, không âm/không NaN',
      () {
        final january = const BudgetPeriod(year: 2027, month: 1);
        expect(january.paceFraction(DateTime(2026, 12, 31, 23, 59)), 0.0);
      },
    );
  });

  // Phase 15: `anchorDay` cấu hình được — CÙNG MỨC NGHIÊM NGẶT các test
  // calendar-month ở trên, áp dụng lại cho ranh giới theo ngày neo tuỳ ý,
  // bao gồm ranh giới chuyển năm.
  group('BudgetPeriod.anchorDay — kỳ theo ngày lương (Phase 15)', () {
    test(
      'anchorDay mặc định 1 tương thích ngược TUYỆT ĐỐI với Phase 11 (start/end/label giống hệt)',
      () {
        const anchored = BudgetPeriod(year: 2026, month: 8, anchorDay: 1);
        const calendar = BudgetPeriod(year: 2026, month: 8);
        expect(anchored.start, calendar.start);
        expect(anchored.end, calendar.end);
        expect(anchored.label, calendar.label);
        expect(anchored.label, 'Tháng 8 2026');
      },
    );

    test(
      'anchorDay = 25: start/end là 25 → 25 tháng sau, KHÔNG phải 1 → 1',
      () {
        const period = BudgetPeriod(year: 2026, month: 8, anchorDay: 25);
        expect(period.start, DateTime(2026, 8, 25));
        expect(period.end, DateTime(2026, 9, 25));
      },
    );

    test(
      'anchorDay != 1: label là khoảng ngày cụ thể, không phải tên tháng lịch',
      () {
        const period = BudgetPeriod(year: 2026, month: 8, anchorDay: 25);
        expect(period.label, '25/08 – 24/09');
      },
    );

    test(
      '🚨 anchorDay = 25, ranh giới chuyển năm: kỳ tháng 12 kết thúc 25/1 năm SAU',
      () {
        const december = BudgetPeriod(year: 2026, month: 12, anchorDay: 25);
        expect(december.start, DateTime(2026, 12, 25));
        expect(december.end, DateTime(2027, 1, 25));
        expect(
          december.next,
          const BudgetPeriod(year: 2027, month: 1, anchorDay: 25),
        );
      },
    );

    test(
      '🚨 anchorDay = 25: giao dịch ĐÚNG 0h ngày neo thuộc kỳ MỚI, giao dịch trước đó (dù cùng ngày về mặt lịch) thuộc kỳ CŨ',
      () {
        const period = BudgetPeriod(year: 2026, month: 8, anchorDay: 25);
        expect(
          period.contains(DateTime(2026, 8, 25)),
          isTrue,
        ); // đúng 0h ngày neo — thuộc kỳ này
        expect(
          period.contains(DateTime(2026, 8, 24, 23, 59, 59)),
          isFalse,
        ); // trước đó — thuộc kỳ TRƯỚC
        expect(
          period.contains(DateTime(2026, 9, 24, 23, 59, 59)),
          isTrue,
        ); // cuối kỳ — vẫn thuộc
        expect(
          period.contains(DateTime(2026, 9, 25)),
          isFalse,
        ); // đầu kỳ SAU — không thuộc
      },
    );

    test(
      '🚨 kẹp neo > số ngày thực trong tháng: neo 31 vào tháng 2 (28 ngày, không nhuận) kẹp về 28',
      () {
        const february = BudgetPeriod(year: 2026, month: 2, anchorDay: 31);
        expect(february.start, DateTime(2026, 2, 28));
        // Kỳ kết thúc ở neo của tháng 3 — tháng 3 có 31 ngày nên KHÔNG kẹp.
        expect(february.end, DateTime(2026, 3, 31));
      },
    );

    test(
      '🚨 kẹp neo > số ngày thực trong tháng: neo 31 vào tháng 2 năm NHUẬN kẹp về 29',
      () {
        const february = BudgetPeriod(year: 2024, month: 2, anchorDay: 31);
        expect(february.start, DateTime(2024, 2, 29));
      },
    );

    test(
      'kẹp neo áp dụng ĐỘC LẬP cho start và end — độ dài kỳ có thể ngắn hơn ở tháng cận kề tháng 2',
      () {
        // neo 31: kỳ THÁNG 1 bắt đầu 31/1, kết thúc bị kẹp ở 28/2 (2026 không
        // nhuận) — chỉ 28 ngày, ngắn hơn một kỳ "31 ngày" thông thường.
        const january = BudgetPeriod(year: 2026, month: 1, anchorDay: 31);
        expect(january.start, DateTime(2026, 1, 31));
        expect(january.end, DateTime(2026, 2, 28));
        expect(january.end.difference(january.start).inDays, 28);
      },
    );

    test(
      'daysInMonth KHÔNG phụ thuộc anchorDay — luôn là số ngày lịch của this.month',
      () {
        const period = BudgetPeriod(year: 2026, month: 2, anchorDay: 25);
        expect(period.daysInMonth, 28);
      },
    );

    test(
      'BudgetPeriod.of: reference ĐÃ QUA ngày neo → kỳ hiện tại là tháng của reference',
      () {
        final period = BudgetPeriod.of(DateTime(2026, 8, 25), anchorDay: 25);
        expect(period, const BudgetPeriod(year: 2026, month: 8, anchorDay: 25));
      },
    );

    test(
      'BudgetPeriod.of: reference CHƯA TỚI ngày neo → kỳ hiện tại là THÁNG TRƯỚC',
      () {
        final period = BudgetPeriod.of(DateTime(2026, 8, 24), anchorDay: 25);
        expect(period, const BudgetPeriod(year: 2026, month: 7, anchorDay: 25));
      },
    );

    test(
      '🚨 BudgetPeriod.of: ranh giới chuyển năm — reference đầu tháng 1, neo 25 → kỳ hiện tại là tháng 12 năm TRƯỚC',
      () {
        final period = BudgetPeriod.of(DateTime(2027, 1, 10), anchorDay: 25);
        expect(
          period,
          const BudgetPeriod(year: 2026, month: 12, anchorDay: 25),
        );
      },
    );

    test(
      'BudgetPeriod.of mặc định anchorDay = 1 giống hệt factory Phase 11 (luôn rơi vào tháng của reference)',
      () {
        final period = BudgetPeriod.of(DateTime(2026, 8, 1));
        expect(period, const BudgetPeriod(year: 2026, month: 8));
      },
    );

    test(
      'paceFraction tổng quát cho kỳ theo ngày neo — ngày 10 của kỳ 31 ngày (25/8→25/9) → pace = 10/31',
      () {
        const period = BudgetPeriod(year: 2026, month: 8, anchorDay: 25);
        // Kỳ dài 31 ngày (25/8 → 25/9, tháng 8 có 31 ngày). Ngày thứ 10 của kỳ
        // là 3/9 (25,26,...,31/8 = 7 ngày + 3/9 = ngày thứ 10).
        expect(
          period.paceFraction(DateTime(2026, 9, 3)),
          closeTo(10 / 31, 1e-9),
        );
      },
    );

    test(
      '== / hashCode phân biệt hai kỳ CÙNG year/month nhưng KHÁC anchorDay (không phải cùng một kỳ)',
      () {
        const a = BudgetPeriod(year: 2026, month: 8, anchorDay: 1);
        const b = BudgetPeriod(year: 2026, month: 8, anchorDay: 25);
        expect(a == b, isFalse);
        expect(a.hashCode == b.hashCode, isFalse);
      },
    );
  });
}
