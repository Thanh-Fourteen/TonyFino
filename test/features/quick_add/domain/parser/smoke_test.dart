import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/quick_add/domain/parser/parser.dart';

import '../../../../support/parser_test_keywords.dart';

void main() {
  final frozen = Clock.fixed(DateTime(2026, 8, 21)); // Thứ Sáu
  final keywords = testCategoryKeywords();

  ParsedDraft parseOne(String text) {
    final drafts = parseMessage(
      text,
      clock: frozen,
      categoryKeywords: keywords,
    );
    expect(drafts.length, 1, reason: 'expected exactly 1 draft for "$text"');
    return drafts.first;
  }

  test('35k', () {
    expect(parseOne('cà phê 35k').amount?.minorUnits, 35000);
  });

  test('2tr5', () {
    expect(parseOne('mua đồ 2tr5').amount?.minorUnits, 2500000);
  });

  test('1tr250', () {
    expect(parseOne('mua đồ 1tr250').amount?.minorUnits, 1250000);
  });

  test('1 triệu 2', () {
    expect(parseOne('mua đồ 1 triệu 2').amount?.minorUnits, 1200000);
  });

  test('1 triệu 2 trăm 50 nghìn', () {
    expect(
      parseOne('mua đồ 1 triệu 2 trăm 50 nghìn').amount?.minorUnits,
      1250000,
    );
  });

  test('35 củ', () {
    expect(parseOne('mua xe 35 củ').amount?.minorUnits, 35000000);
  });

  test('một triệu rưỡi', () {
    expect(parseOne('lương một triệu rưỡi').amount?.minorUnits, 1500000);
  });

  test('35tr rưỡi', () {
    expect(parseOne('mua xe 35tr rưỡi').amount?.minorUnits, 35500000);
  });

  test('35.000', () {
    expect(parseOne('ăn trưa 35.000').amount?.minorUnits, 35000);
  });

  test('35,000', () {
    expect(parseOne('ăn trưa 35,000').amount?.minorUnits, 35000);
  });

  test('35000đ', () {
    expect(parseOne('ăn trưa 35000đ').amount?.minorUnits, 35000);
  });

  test('35000 vnd', () {
    expect(parseOne('ăn trưa 35000 vnd').amount?.minorUnits, 35000);
  });

  test('hai trăm ngàn', () {
    expect(parseOne('mua đồ hai trăm ngàn').amount?.minorUnits, 200000);
  });

  test('segmenter — hai khoản', () {
    final drafts = parseMessage(
      'Café 30k, xem phim 100k',
      clock: frozen,
      categoryKeywords: keywords,
    );
    expect(drafts.length, 2);
    expect(drafts[0].amount?.minorUnits, 30000);
    expect(drafts[1].amount?.minorUnits, 100000);
  });

  test('date — hôm qua', () {
    final d = parseOne('cà phê 35k hôm qua');
    expect(d.date.date, DateTime(2026, 8, 20));
    expect(d.date.explicit, isTrue);
  });

  test('date — thứ 2 = Monday', () {
    final d = parseOne('cà phê 35k thứ 2');
    // 2026-08-21 là Thứ Sáu (ISO weekday 5). Thứ Hai gần nhất trước đó là
    // 2026-08-17.
    expect(d.date.date, DateTime(2026, 8, 17));
  });

  test('date — thứ 3 tuần trước', () {
    final d = parseOne('cà phê 35k thứ 3 tuần trước');
    // Thứ Ba của TUẦN NÀY (chứa 21/8 thứ Sáu) là 2026-08-18; tuần trước lùi
    // thêm 7 ngày = 2026-08-11.
    expect(d.date.date, DateTime(2026, 8, 11));
  });

  test('date — 12/3 = ngày 12 tháng 3 (DD/MM)', () {
    final d = parseOne('cà phê 35k 12/3');
    expect(d.date.date, DateTime(2026, 3, 12));
  });

  test('date — mặc định hôm nay khi không có cụm ngày', () {
    final d = parseOne('cà phê 35k');
    expect(d.date.date, DateTime(2026, 8, 21));
    expect(d.date.explicit, isFalse);
  });

  test('category — cà phê khớp Ăn uống', () {
    final d = parseOne('cà phê 35k');
    expect(d.category?.categoryKey, 'an_uong');
  });

  test('không hiểu — không có số tiền', () {
    final d = parseOne('đi chơi với bạn');
    expect(d.amount, isNull);
    expect(d.isUnderstood, isFalse);
    expect(d.rawText, 'đi chơi với bạn');
  });

  test('teencode — dc mở rộng thành được', () {
    final d = parseOne('mua đồ ăn ngon lắm dc 35k');
    expect(d.leftoverText.contains('được'), isTrue);
  });
}
