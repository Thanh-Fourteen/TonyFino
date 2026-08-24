import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/quick_add/domain/parser/segmenter.dart';

void main() {
  test('một khoản → một đoạn', () {
    expect(segmentMessage('cà phê 35k'), ['cà phê 35k']);
  });

  test('phẩy tách hai khoản (ví dụ của Tony)', () {
    expect(segmentMessage('Café 30k, xem phim 100k'), [
      'Café 30k',
      'xem phim 100k',
    ]);
  });

  test('KHÔNG tách bên trong số có phẩy phân cách nghìn', () {
    expect(segmentMessage('ăn trưa 30,000'), ['ăn trưa 30,000']);
  });

  test('chấm phẩy tách nhiều khoản', () {
    expect(segmentMessage('a 1;b 2;c 3'), ['a 1', 'b 2', 'c 3']);
  });

  test('xuống dòng tách đoạn', () {
    expect(segmentMessage('a 1\nb 2'), ['a 1', 'b 2']);
  });

  test('từ "và" đứng một mình tách đoạn', () {
    expect(segmentMessage('cà phê 35k và xăng 50k'), [
      'cà phê 35k',
      'xăng 50k',
    ]);
  });

  test('không tách nhầm từ chứa "và" bên trong', () {
    // "vàng" không phải "và" đứng một mình.
    expect(segmentMessage('mua vàng 5tr'), ['mua vàng 5tr']);
  });

  test('bỏ đoạn rỗng do dấu phẩy liền nhau/ở đầu-cuối', () {
    expect(segmentMessage(',, cà phê 35k ,,'), ['cà phê 35k']);
  });

  test('chuỗi rỗng → danh sách rỗng, không ném lỗi', () {
    expect(segmentMessage(''), isEmpty);
    expect(segmentMessage('   '), isEmpty);
  });
}
