/// Token hoá thủ công (quét ký tự, KHÔNG regex) chuỗi tiếng Việt đã chuẩn
/// hoá (`normalizer.dart`) thành một danh sách [Token] — nền cho
/// `amount_evaluator.dart`/`date_parser.dart` đệ quy xuống trên token thay
/// vì khớp mẫu trên toàn chuỗi.
library;

enum TokenType {
  /// Một dãy chữ số, đã gộp nhóm phân cách nghìn `.`/`,` nếu có
  /// (`"35.000"` → MỘT token `number` giá trị 35000, không phải ba token).
  number,

  /// Một dãy ký tự chữ (chữ cái Unicode, gồm cả dấu tiếng Việt) — vd
  /// `"triệu"`, `"k"`, `"và"`.
  word,

  slash,
  dash,
  comma,
  semicolon,
  newline,
}

class Token {
  const Token(this.type, this.text, {this.value});

  final TokenType type;

  /// Chữ gốc (đã lowercase từ normalizer), dùng để so khớp từ khoá ngữ
  /// pháp/danh mục.
  final String text;

  /// Chỉ khác `null` với [TokenType.number] — giá trị số nguyên đã gộp
  /// nhóm phân cách.
  final int? value;

  @override
  String toString() => value != null ? '$type($text=$value)' : '$type($text)';
}

bool _isDigit(String ch) =>
    ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;

bool _isWhitespace(String ch) => ch == ' ' || ch == '\t';

/// Chữ cái "thuộc về một từ" theo nghĩa rộng: chữ cái Unicode (kể cả có dấu
/// tiếng Việt). Loại trừ chữ số và các ký tự dấu câu được nhận dạng riêng.
bool _isWordChar(String ch) {
  final code = ch.codeUnitAt(0);
  final isAsciiLetter =
      (code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a);
  if (isAsciiLetter) return true;
  if (_isDigit(ch)) return false;
  const reserved = {'/', '-', ',', ';', '\n', ' ', '\t', '.'};
  if (reserved.contains(ch)) return false;
  // Mọi thứ còn lại trong dải Latin Extended (nguyên âm/phụ âm có dấu tiếng
  // Việt, đ/Đ) coi là ký tự thuộc từ — an toàn hơn liệt kê từng dấu một.
  return code > 0x7f;
}

List<Token> tokenize(String normalizedDiacritics) {
  final tokens = <Token>[];
  final chars = normalizedDiacritics.characters().toList();
  var i = 0;

  while (i < chars.length) {
    final ch = chars[i];

    if (_isWhitespace(ch)) {
      i++;
      continue;
    }

    if (ch == '\n') {
      tokens.add(const Token(TokenType.newline, '\n'));
      i++;
      continue;
    }

    if (_isDigit(ch)) {
      final buffer = StringBuffer();
      while (i < chars.length && _isDigit(chars[i])) {
        buffer.write(chars[i]);
        i++;
      }
      // Gộp nhóm phân cách nghìn: `.`/`,` theo sau bởi ĐÚNG 3 chữ số, lặp
      // lại nhiều lần ("1.234.567"). Nếu nhóm sau không đúng 3 chữ số (vd.
      // ngày "12.3" hiếm gặp hoặc số thập phân) thì DỪNG — không đoán.
      while (i < chars.length &&
          (chars[i] == '.' || chars[i] == ',') &&
          i + 3 < chars.length &&
          _isDigit(chars[i + 1]) &&
          _isDigit(chars[i + 2]) &&
          _isDigit(chars[i + 3]) &&
          (i + 4 >= chars.length || !_isDigit(chars[i + 4]))) {
        i++; // bỏ dấu phân cách
        buffer.write(chars[i]);
        buffer.write(chars[i + 1]);
        buffer.write(chars[i + 2]);
        i += 3;
      }
      final text = buffer.toString();
      tokens.add(Token(TokenType.number, text, value: int.parse(text)));
      continue;
    }

    if (ch == '/') {
      tokens.add(const Token(TokenType.slash, '/'));
      i++;
      continue;
    }
    if (ch == '-') {
      tokens.add(const Token(TokenType.dash, '-'));
      i++;
      continue;
    }
    if (ch == ',') {
      tokens.add(const Token(TokenType.comma, ','));
      i++;
      continue;
    }
    if (ch == ';') {
      tokens.add(const Token(TokenType.semicolon, ';'));
      i++;
      continue;
    }
    if (ch == '.') {
      // Dấu chấm không thuộc nhóm phân cách số (đã xử lý ở nhánh digit) —
      // coi là dấu câu vô nghĩa với ngữ pháp, bỏ qua.
      i++;
      continue;
    }

    if (_isWordChar(ch)) {
      final buffer = StringBuffer();
      while (i < chars.length && _isWordChar(chars[i])) {
        buffer.write(chars[i]);
        i++;
      }
      tokens.add(Token(TokenType.word, buffer.toString()));
      continue;
    }

    // Ký tự lạ không thuộc ngữ pháp nào (emoji, ký hiệu khác) — bỏ qua, ăn
    // 1 ký tự để tránh vòng lặp vô hạn (an toàn cho fuzz test).
    i++;
  }

  return tokens;
}

extension on String {
  /// Danh sách các "ký tự" 1-code-unit — đủ dùng ở đây vì bảng chữ tiếng
  /// Việt (kể cả tổ hợp dấu) nằm trong BMP, không cần xử lý surrogate pair
  /// (emoji hiếm khi xuất hiện trong ghi chú chi tiêu, và nếu có thì nhánh
  /// "ký tự lạ" ở trên vẫn ăn an toàn từng code unit một, không ném lỗi).
  List<String> characters() => split('');
}
