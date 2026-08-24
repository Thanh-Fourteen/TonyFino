/// Đọc số tiền từ dãy [Token] bằng **đệ quy xuống** (recursive descent),
/// KHÔNG regex — regex một khối chết ngay ở `"1 triệu 2 trăm 50 nghìn"` vì
/// độ sâu lồng ghép của các nhóm (tỷ > triệu > nghìn > trăm > chục > đơn vị)
/// không cố định.
///
/// 🔴 **Luật giá trị nhất toàn parser:** khi một hệ số "mồ côi" (không có từ
/// đơn vị theo sau, vd `2tr5` → hệ số `5` không có `nghìn`/`k` theo sau) xuất
/// hiện NGAY SAU một nhóm đã có đơn vị, nó là **phân số của đơn vị THẤP HƠN
/// KẾ TIẾP** — tính bằng `hệ_số × (đơn_vị_trước / 10^số_chữ_số_hệ_số)`.
///   `2tr5`   → 2×1.000.000 + 5×(1.000.000/10¹)   = 2.000.000 + 500.000   = 2.500.000
///   `1tr250` → 1×1.000.000 + 250×(1.000.000/10³) = 1.000.000 + 250.000  = 1.250.000
///   `1 triệu 2` cũng đúng công thức này (hệ số spelled "hai" cũng 1 chữ số).
library;

import 'parse_result.dart';
import 'tokenizer.dart';

const Map<String, int> _onesWords = {
  'không': 0,
  'một': 1,
  'mốt': 1,
  'hai': 2,
  'ba': 3,
  'bốn': 4,
  'tư': 4,
  'năm': 5,
  'lăm': 5,
  'sáu': 6,
  'bảy': 7,
  'tám': 8,
  'chín': 9,
};

const Map<String, int> _tensWords = {
  'hai': 2,
  'ba': 3,
  'bốn': 4,
  'năm': 5,
  'sáu': 6,
  'bảy': 7,
  'tám': 8,
  'chín': 9,
};

/// Từ đơn vị — `trăm` NẰM CHUNG bảng này (scale = 100) vì công thức phân số
/// mồ côi ở trên áp dụng ĐÚNG cho cả `trăm` (vd `năm trăm ba` = 500 + 3×10 =
/// 530), không cần luật riêng.
const Map<String, int> _scaleWords = {
  'trăm': 100,
  'nghìn': 1000,
  'ngàn': 1000,
  'k': 1000,
  'triệu': 1000000,
  'tr': 1000000,
  'củ': 1000000,
  'tỷ': 1000000000,
};

const Set<String> _currencySuffixes = {'đ', 'd', 'vnd', 'vnđ', 'đồng', 'dong'};

int _pow10(int n) {
  var v = 1;
  for (var i = 0; i < n; i++) {
    v *= 10;
  }
  return v;
}

/// `(giá trị, số token đã ăn)` — dùng nội bộ, không lộ ra ngoài file.
typedef _Coef = ({int value, int consumed});

_Coef? _tryParseBareDigit(List<Token> tokens, int idx) {
  if (idx >= tokens.length) return null;
  final t = tokens[idx];
  if (t.type == TokenType.number && t.value! <= 9) {
    return (value: t.value!, consumed: 1);
  }
  if (t.type == TokenType.word && _onesWords.containsKey(t.text)) {
    return (value: _onesWords[t.text]!, consumed: 1);
  }
  return null;
}

/// Phần "chục-đơn vị" (0-99) — chấp nhận CẢ một token số trực tiếp
/// (`"50"` → 50, dùng khi người viết gõ số thay vì đánh vần) LẪN chữ viết
/// ("năm mươi", "mười lăm", một chữ số đơn "năm"). Tổng quát hoá "chấp nhận
/// token số" này là thứ khiến `"2 trăm 50 nghìn"` (trộn số + chữ) ra đúng
/// 250.000 thay vì bị tách thành hai nhóm cộng độc lập `200 + 50.000`.
_Coef? _tryParseTensOnes(List<Token> tokens, int idx) {
  if (idx >= tokens.length) return null;

  final direct = tokens[idx];
  if (direct.type == TokenType.number) {
    if (direct.value! <= 99) return (value: direct.value!, consumed: 1);
    return null;
  }
  if (direct.type != TokenType.word) return null;
  final w = direct.text;

  if (w == 'mười') {
    if (idx + 1 < tokens.length && tokens[idx + 1].type == TokenType.word) {
      final ones = _onesWords[tokens[idx + 1].text];
      if (ones != null && tokens[idx + 1].text != 'không') {
        return (value: 10 + ones, consumed: 2);
      }
    }
    return (value: 10, consumed: 1);
  }

  if (_tensWords.containsKey(w) &&
      idx + 1 < tokens.length &&
      tokens[idx + 1].type == TokenType.word &&
      tokens[idx + 1].text == 'mươi') {
    final tens = _tensWords[w]! * 10;
    if (idx + 2 < tokens.length && tokens[idx + 2].type == TokenType.word) {
      final ones = _onesWords[tokens[idx + 2].text];
      if (ones != null && ones != 0) {
        return (value: tens + ones, consumed: 3);
      }
    }
    return (value: tens, consumed: 2);
  }

  if (_onesWords.containsKey(w)) {
    return (value: _onesWords[w]!, consumed: 1);
  }
  return null;
}

/// Phần "trăm" (0-999) — hàng trăm chấp nhận CẢ token số (`"2"`) LẪN chữ
/// ("hai"); phần chục-đơn vị theo sau cũng trộn được hai dạng qua
/// [_tryParseTensOnes] đã tổng quát hoá ở trên. Đây là điểm mấu chốt xử lý
/// đúng `"1 triệu 2 trăm 50 nghìn"` — ví dụ Tony chỉ đích danh là nơi regex
/// chết vì độ sâu lồng ghép không cố định.
_Coef? _tryParseCompoundNumber(List<Token> tokens, int idx) {
  if (idx >= tokens.length) return null;
  final t0 = tokens[idx];

  int? hundredsDigit;
  if (t0.type == TokenType.number && t0.value! >= 1 && t0.value! <= 9) {
    hundredsDigit = t0.value;
  } else if (t0.type == TokenType.word && _onesWords.containsKey(t0.text)) {
    hundredsDigit = _onesWords[t0.text];
  }

  final hasHundreds =
      hundredsDigit != null &&
      idx + 1 < tokens.length &&
      tokens[idx + 1].type == TokenType.word &&
      tokens[idx + 1].text == 'trăm';
  if (!hasHundreds) return _tryParseTensOnes(tokens, idx);

  final hundreds = hundredsDigit * 100;
  const consumed = 2;

  if (idx + 2 < tokens.length &&
      tokens[idx + 2].type == TokenType.word &&
      (tokens[idx + 2].text == 'linh' || tokens[idx + 2].text == 'lẻ')) {
    final ones = _tryParseBareDigit(tokens, idx + 3);
    if (ones != null) {
      return (value: hundreds + ones.value, consumed: 3 + ones.consumed);
    }
    return (value: hundreds, consumed: consumed);
  }

  final rest = _tryParseTensOnes(tokens, idx + 2);
  if (rest != null) {
    return (value: hundreds + rest.value, consumed: consumed + rest.consumed);
  }
  return (value: hundreds, consumed: consumed);
}

/// `isRawDigits`: hệ số đến từ MỘT token số trần không kèm "trăm" (`"250"`)
/// hay từ một tổ hợp có chữ ("hai trăm năm mươi", hoặc trộn "2 trăm 50") —
/// cả hai đều hợp lệ làm hệ số cho từ đơn vị theo sau hoặc cho luật phân số
/// mồ côi, nhưng chỉ dạng ĐẦU mở khoá luật "số ≥4 chữ số tự đủ tin cậy".
({int value, int consumed, bool isRawDigits, int rawDigitTextLength})?
_tryParseCoefficient(List<Token> tokens, int idx) {
  if (idx < tokens.length && tokens[idx].type == TokenType.number) {
    final followedByTram =
        idx + 1 < tokens.length &&
        tokens[idx + 1].type == TokenType.word &&
        tokens[idx + 1].text == 'trăm';
    if (!followedByTram) {
      final t = tokens[idx];
      return (
        value: t.value!,
        consumed: 1,
        isRawDigits: true,
        rawDigitTextLength: t.text.length,
      );
    }
  }
  final compound = _tryParseCompoundNumber(tokens, idx);
  if (compound != null) {
    return (
      value: compound.value,
      consumed: compound.consumed,
      isRawDigits: false,
      rawDigitTextLength: compound.value.toString().length,
    );
  }
  return null;
}

class AmountMatch {
  const AmountMatch({
    required this.amount,
    required this.startIndex,
    required this.endIndex,
  });

  final ParsedAmount amount;

  /// Khoảng token `[startIndex, endIndex)` đã bị khoản tiền này "ăn" — dùng
  /// để tính phần chữ còn lại (`leftoverText`) và để `segmenter` không cắt
  /// nhầm bên trong một cụm số.
  final int startIndex;
  final int endIndex;
}

/// Thử đọc một khoản tiền BẮT ĐẦU đúng tại `start`. `null` nếu vị trí này
/// không mở đầu một cụm số hợp lệ.
AmountMatch? _tryParseAmountAt(List<Token> tokens, int start) {
  var idx = start;
  var total = 0;
  int? lastScale;
  var consumedAny = false;
  var strongSignal = false; // đơn vị/nhóm phân cách/ký hiệu tiền tệ tường minh
  var currencyConsumed = false;

  while (idx < tokens.length) {
    final coef = _tryParseCoefficient(tokens, idx);
    if (coef == null) break;

    final scaleTok = idx + coef.consumed < tokens.length
        ? tokens[idx + coef.consumed]
        : null;
    final scaleValue = (scaleTok?.type == TokenType.word)
        ? _scaleWords[scaleTok!.text]
        : null;

    if (scaleValue != null) {
      total += coef.value * scaleValue;
      lastScale = scaleValue;
      idx += coef.consumed + 1;
      consumedAny = true;
      strongSignal = true;

      final maybeRuoi = idx < tokens.length ? tokens[idx] : null;
      if (maybeRuoi?.type == TokenType.word && maybeRuoi!.text == 'rưỡi') {
        total += lastScale ~/ 2;
        idx += 1;
        break; // "rưỡi" luôn là từ cuối của cụm số trong mọi ca yêu cầu.
      }
      continue; // thử đọc thêm một nhóm nữa (vd "1 triệu 2 trăm 50 nghìn").
    }

    // Không có từ đơn vị theo ngay sau hệ số này.
    if (lastScale != null && consumedAny) {
      // Hệ số mồ côi ngay sau một nhóm đã có đơn vị → luật phân số.
      final digitCount = coef.rawDigitTextLength;
      final divisor = _pow10(digitCount);
      if (divisor <= lastScale && divisor > 0) {
        total += coef.value * (lastScale ~/ divisor);
        idx += coef.consumed;
        consumedAny = true;
      }
      // Dù khớp hay không, cụm số kết thúc ở đây — hệ số mồ côi chỉ có
      // nghĩa ngay sau một đơn vị, không lồng thêm được nữa.
      break;
    }

    // Nhóm ĐẦU TIÊN, không có từ đơn vị theo sau — chỉ chấp nhận nếu có ký
    // hiệu tiền tệ theo ngay sau, hoặc bản thân là một dãy số đủ lớn
    // (≥4 chữ số, vd "35000"/"35.000" đã gộp nhóm ở tokenizer).
    final afterCoef = idx + coef.consumed < tokens.length
        ? tokens[idx + coef.consumed]
        : null;
    final peekCurrency =
        afterCoef?.type == TokenType.word &&
        _currencySuffixes.contains(afterCoef!.text);
    final bigBareNumber = coef.isRawDigits && coef.rawDigitTextLength >= 4;

    if (peekCurrency || bigBareNumber) {
      total += coef.value;
      idx += coef.consumed;
      consumedAny = true;
      strongSignal = bigBareNumber || peekCurrency;
      if (peekCurrency) {
        idx += 1;
        currencyConsumed = true;
      }
    }
    break; // số trần luôn là nhóm cuối — không có gì hợp lý theo sau nó.
  }

  if (!consumedAny) return null;

  if (!currencyConsumed &&
      idx < tokens.length &&
      tokens[idx].type == TokenType.word &&
      _currencySuffixes.contains(tokens[idx].text)) {
    idx += 1;
    currencyConsumed = true;
    strongSignal = true;
  }

  return AmountMatch(
    amount: ParsedAmount(
      minorUnits: total,
      confident: strongSignal || currencyConsumed,
    ),
    startIndex: start,
    endIndex: idx,
  );
}

/// Tìm khoản tiền ĐẦU TIÊN (trái nhất) trong dãy token — quét từng vị trí
/// bắt đầu cho tới khi tìm được một cụm hợp lệ. `null` nếu không có khoản
/// tiền nào trong toàn bộ dãy.
AmountMatch? findAmount(List<Token> tokens) {
  for (var i = 0; i < tokens.length; i++) {
    final match = _tryParseAmountAt(tokens, i);
    if (match != null) return match;
  }
  return null;
}
