import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/home/domain/tet_season.dart';

void main() {
  group('isTetSeason', () {
    test('đúng mồng Một Tết 2027 (6/2/2027) → true', () {
      expect(isTetSeason(DateTime(2027, 2, 6)), isTrue);
    });

    test('3 ngày trước Tết 2027 (cận biên dưới) → true', () {
      expect(isTetSeason(DateTime(2027, 2, 3)), isTrue);
    });

    test('4 ngày sau Tết 2027 (cận biên trên) → true', () {
      expect(isTetSeason(DateTime(2027, 2, 10)), isTrue);
    });

    test('4 ngày trước Tết 2027 — NGOÀI khoảng → false', () {
      expect(isTetSeason(DateTime(2027, 2, 2)), isFalse);
    });

    test('5 ngày sau Tết 2027 — NGOÀI khoảng → false', () {
      expect(isTetSeason(DateTime(2027, 2, 11)), isFalse);
    });

    test('giữa năm, xa Tết → false', () {
      expect(isTetSeason(DateTime(2027, 7, 15)), isFalse);
    });

    test('Tết 2028 rơi cuối tháng 1 — trừ 3 ngày vẫn cùng năm, tính đúng', () {
      // Tết 2028 = 26/1/2028; 23/1/2028 là cận biên dưới.
      expect(isTetSeason(DateTime(2028, 1, 23)), isTrue);
      expect(isTetSeason(DateTime(2028, 1, 22)), isFalse);
    });

    test('năm chưa có trong bảng tra → luôn false, không đoán', () {
      expect(isTetSeason(DateTime(2040, 2, 1)), isFalse);
    });

    test('giờ trong ngày không ảnh hưởng — chỉ NGÀY mới có ý nghĩa', () {
      expect(isTetSeason(DateTime(2027, 2, 6, 23, 59)), isTrue);
    });
  });
}
