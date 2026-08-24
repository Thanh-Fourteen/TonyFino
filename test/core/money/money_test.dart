import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';

void main() {
  group('Money — cùng loại tiền', () {
    test('cộng', () {
      expect(
        const Money.vnd(20000) + const Money.vnd(15000),
        const Money.vnd(35000),
      );
    });

    test('trừ', () {
      expect(
        const Money.vnd(50000) - const Money.vnd(15000),
        const Money.vnd(35000),
      );
    });

    test('phủ định', () {
      expect(-const Money.vnd(35000), const Money.vnd(-35000));
    });

    test('so sánh', () {
      expect(const Money.vnd(10000) < const Money.vnd(20000), isTrue);
      expect(const Money.vnd(20000) > const Money.vnd(10000), isTrue);
      expect(const Money.vnd(10000) <= const Money.vnd(10000), isTrue);
    });
  });

  group('Money — khác loại tiền phải ném lỗi', () {
    test('cộng', () {
      const vnd = Money.vnd(35000);
      const usd = Money(minorUnits: 100, currency: 'USD', currencyScale: 2);
      expect(() => vnd + usd, throwsA(isA<CurrencyMismatchError>()));
    });

    test('trừ', () {
      const vnd = Money.vnd(35000);
      const usd = Money(minorUnits: 100, currency: 'USD', currencyScale: 2);
      expect(() => vnd - usd, throwsA(isA<CurrencyMismatchError>()));
    });

    test('so sánh', () {
      const vnd = Money.vnd(35000);
      const usd = Money(minorUnits: 100, currency: 'USD', currencyScale: 2);
      expect(() => vnd < usd, throwsA(isA<CurrencyMismatchError>()));
    });

    test('khác currencyScale cùng currency cũng ném lỗi', () {
      const a = Money(minorUnits: 100, currency: 'VND', currencyScale: 0);
      const b = Money(minorUnits: 100, currency: 'VND', currencyScale: 2);
      expect(() => a + b, throwsA(isA<CurrencyMismatchError>()));
    });
  });

  group('Money — format vi_VN', () {
    // NumberFormat.currency chèn U+00A0 (NBSP) trước ký hiệu tiền tệ, không
    // phải dấu cách thường (U+0020) — đã xác nhận bằng codeUnits thật, không
    // đoán bằng mắt (dễ nhầm vì hai ký tự trông giống hệt nhau trên terminal).
    const nbsp = ' ';

    test('35.000 ₫ — dấu "." phân cách nghìn, không thập phân', () {
      expect(const Money.vnd(35000).format(), '35.000$nbsp₫');
    });

    test('số âm', () {
      expect(const Money.vnd(-35000).format(), '-35.000$nbsp₫');
    });

    test('số 0', () {
      expect(const Money.vnd(0).format(), '0$nbsp₫');
    });

    test('số lớn nhiều nhóm nghìn', () {
      expect(const Money.vnd(1250000).format(), '1.250.000$nbsp₫');
    });
  });

  group('Money — thuộc tính', () {
    test('isNegative / isPositive / isZero', () {
      expect(const Money.vnd(-1).isNegative, isTrue);
      expect(const Money.vnd(1).isPositive, isTrue);
      expect(const Money.vnd(0).isZero, isTrue);
    });

    test('abs', () {
      expect(const Money.vnd(-35000).abs, const Money.vnd(35000));
      expect(const Money.vnd(35000).abs, const Money.vnd(35000));
    });

    test('bất biến: hai Money cùng giá trị bằng nhau', () {
      expect(const Money.vnd(1000), const Money.vnd(1000));
    });
  });
}
