import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/quick_add/domain/parser/normalizer.dart';

void main() {
  group('normalize — luồng ascii', () {
    test('đ/Đ map tường minh, độc lập với package diacritic', () {
      final result = normalize('Đồng, đường, cà phê, phở, 35.000đ');
      expect(result.ascii, 'dong, duong, ca phe, pho, 35.000d');
    });

    test('giữ nguyên dấu ở luồng diacritics', () {
      final result = normalize('Cà Phê Sữa Đá');
      expect(result.diacritics, 'cà phê sữa đá');
    });
  });

  group('normalize — khoảng trắng', () {
    test('gộp nhiều khoảng trắng liên tiếp', () {
      final result = normalize('cà   phê    35k');
      expect(result.diacritics, 'cà phê 35k');
    });

    test('trim hai đầu', () {
      final result = normalize('  cà phê 35k  ');
      expect(result.diacritics, 'cà phê 35k');
    });
  });

  group('normalize — teencode', () {
    test('mở rộng "dc" thành "được"', () {
      expect(normalize('ăn ngon dc lắm').diacritics, contains('được'));
    });

    test('không đụng vào token ngữ pháp số tiền ("k"/"tr")', () {
      // "k" và "tr" KHÔNG nằm trong bảng teencode — phải giữ nguyên để
      // amount_evaluator còn nhận ra đơn vị.
      expect(normalize('cà phê 35k').diacritics, contains('35k'));
      expect(normalize('mua đồ 2tr5').diacritics, contains('2tr5'));
    });

    test('không mở rộng khi teencode dính liền số (không phải từ riêng)', () {
      // "2tr5" không khớp bất cứ khoá teencode nào (so khớp CẢ TỪ).
      expect(expandTeencode('2tr5'), '2tr5');
    });
  });
}
