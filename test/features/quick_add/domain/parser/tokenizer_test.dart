import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/quick_add/domain/parser/tokenizer.dart';

void main() {
  group('tokenize — số', () {
    test('gộp nhóm phân cách nghìn bằng dấu chấm', () {
      final tokens = tokenize('35.000');
      expect(tokens, hasLength(1));
      expect(tokens.single.type, TokenType.number);
      expect(tokens.single.value, 35000);
    });

    test('gộp nhóm phân cách nghìn bằng dấu phẩy', () {
      final tokens = tokenize('1,234,567');
      expect(tokens, hasLength(1));
      expect(tokens.single.value, 1234567);
    });

    test('không gộp khi nhóm sau không đủ 3 chữ số', () {
      final tokens = tokenize('35.00');
      // "35" và ".00" không khớp luật gộp (chỉ 2 chữ số) → tách rời, "." bị
      // bỏ qua (không thuộc ngữ pháp nào), còn lại 2 token số.
      expect(tokens.where((t) => t.type == TokenType.number).length, 2);
    });
  });

  group('tokenize — dính liền chữ/số', () {
    test('"2tr5" tách thành 3 token: số, chữ, số', () {
      final tokens = tokenize('2tr5');
      expect(tokens, hasLength(3));
      expect(tokens[0].type, TokenType.number);
      expect(tokens[0].value, 2);
      expect(tokens[1].type, TokenType.word);
      expect(tokens[1].text, 'tr');
      expect(tokens[2].type, TokenType.number);
      expect(tokens[2].value, 5);
    });

    test('"35000đ" tách thành số + chữ (đ là chữ cái Unicode)', () {
      final tokens = tokenize('35000đ');
      expect(tokens, hasLength(2));
      expect(tokens[0].value, 35000);
      expect(tokens[1].text, 'đ');
    });
  });

  group('tokenize — dấu câu ngữ pháp', () {
    test('nhận diện / - , ; riêng lẻ khi không thuộc số', () {
      final tokens = tokenize('12/3, mua và bán; xong');
      final types = tokens.map((t) => t.type).toList();
      expect(types, contains(TokenType.slash));
      expect(types, contains(TokenType.comma));
      expect(types, contains(TokenType.semicolon));
    });
  });

  group('tokenize — không ném lỗi', () {
    test('chuỗi rỗng ra danh sách rỗng', () {
      expect(tokenize(''), isEmpty);
    });

    test('ký tự lạ/emoji bị bỏ qua an toàn', () {
      expect(() => tokenize('🎉🎊 cà phê 35k'), returnsNormally);
      final tokens = tokenize('🎉 35k');
      expect(tokens.any((t) => t.value == 35), isTrue);
    });
  });
}
