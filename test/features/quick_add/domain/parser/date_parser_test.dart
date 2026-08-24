import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/quick_add/domain/parser/date_parser.dart';
import 'package:tonyfino/features/quick_add/domain/parser/parse_result.dart';
import 'package:tonyfino/features/quick_add/domain/parser/tokenizer.dart';

void main() {
  // 2026-08-21 là Thứ Sáu (ISO weekday 5).
  final frozen = Clock.fixed(DateTime(2026, 8, 21));

  DateMatch? parse(String text) => findDate(tokenize(text), clock: frozen);

  group('date_parser — tương đối', () {
    test('hôm nay', () {
      final m = parse('hôm nay')!;
      expect(m.date.date, DateTime(2026, 8, 21));
      expect(m.date.explicit, isTrue);
    });

    test('hôm qua', () {
      expect(parse('hôm qua')!.date.date, DateTime(2026, 8, 20));
    });

    test('hôm kia', () {
      expect(parse('hôm kia')!.date.date, DateTime(2026, 8, 19));
    });

    test('ngày mai', () {
      expect(parse('ngày mai')!.date.date, DateTime(2026, 8, 22));
    });
  });

  group('date_parser — thứ trong tuần lệch 1 so với ISO', () {
    test('thứ 2 = Monday (2026-08-17, thứ Sáu gần nhất lùi về)', () {
      expect(parse('thứ 2')!.date.date, DateTime(2026, 8, 17));
    });

    test('thứ 6 = hôm nay (chính là thứ Sáu 21/8)', () {
      expect(parse('thứ 6')!.date.date, DateTime(2026, 8, 21));
    });

    test('thứ Tư (spelled) = 2026-08-19', () {
      expect(parse('thứ tư')!.date.date, DateTime(2026, 8, 19));
    });

    test('chủ nhật = 2026-08-16 (Chủ Nhật gần nhất)', () {
      expect(parse('chủ nhật')!.date.date, DateTime(2026, 8, 16));
    });

    test('thứ 3 tuần trước lùi thêm đúng 7 ngày', () {
      final thisWeek = parse('thứ 3')!.date.date;
      final lastWeek = parse('thứ 3 tuần trước')!.date.date;
      expect(thisWeek.difference(lastWeek).inDays, 7);
    });
  });

  group('date_parser — DD/MM', () {
    test('12/3 = ngày 12 tháng 3, KHÔNG PHẢI 3 tháng 12', () {
      expect(parse('12/3')!.date.date, DateTime(2026, 3, 12));
    });

    test('có năm tường minh', () {
      expect(parse('9/6/2025')!.date.date, DateTime(2025, 6, 9));
    });

    test('tháng/ngày vô lý (32/13) không khớp — không ném lỗi', () {
      expect(() => parse('32/13'), returnsNormally);
      expect(parse('32/13'), isNull);
    });
  });

  group('date_parser — không lẫn với từ khoá danh mục', () {
    test('"sáng" đứng một mình (trong "ăn sáng") KHÔNG bị bắt làm ngày', () {
      // Đây là ranh giới cố ý: chỉ "sáng nay"/"sáng qua" mới là tín hiệu
      // ngày — "sáng" đứng một mình phải nhường cho category_matcher.
      expect(parse('ăn sáng'), isNull);
    });

    test('"sáng nay" là tín hiệu ngày + buổi', () {
      final m = parse('sáng nay')!;
      expect(m.date.date, DateTime(2026, 8, 21));
      expect(m.date.timeOfDayLabel, TimeOfDayLabel.morning);
    });
  });

  test('không có cụm ngày nào → null', () {
    expect(parse('cà phê 35k'), isNull);
  });
}
