/// Tách một tin nhắn thành NHIỀU đoạn, mỗi đoạn ứng với một
/// [ParsedDraft] tiềm năng — đây là điểm Rolly quảng cáo được nhưng review
/// thật cho thấy chỉ nhận ra MỘT khoản (`"Café 30k, xem phim 100k"` phải ra
/// 2 đoạn, không phải 1).
///
/// Cắt trên CHUỖI THÔ (trước khi token hoá), giữ nguyên nguyên văn từng đoạn
/// — Luật bố cục Phase 8 yêu cầu thẻ lỗi "giữ nguyên chữ gốc trong ô sửa
/// được", nên đoạn văn đưa ra ở đây phải là substring thật của tin nhắn gốc,
/// không phải ghép lại từ token.
///
/// Dấu phẩy/chấm phẩy dùng làm ranh giới đoạn KHÔNG xung đột với dấu phẩy
/// phân cách nghìn (`"30.000"`/`"30,000"`) — bộ token hoá (`tokenizer.dart`)
/// chỉ gộp `,`/`.` vào MỘT token số khi có đúng 3 chữ số theo sau, nên
/// `segmenter` không cần biết gì về ngữ pháp số; bất cứ dấu phẩy nào còn
/// đứng lẻ ở tầng ký tự (không kẹp giữa hai nhóm 3-chữ-số) chắc chắn là ranh
/// giới đoạn thật.
library;

bool _isDigit(String ch) =>
    ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;

/// `true` nếu ký tự tại `i` là dấu phân cách ranh giới đoạn THẬT — tức
/// KHÔNG phải dấu phẩy đang làm nhóm phân cách nghìn bên trong một số
/// (`"30,000"`). Soi cùng điều kiện với `tokenizer.dart`: đứng ngay sau một
/// chữ số, VÀ đúng 3 chữ số theo sau, VÀ ký tự kế tiếp (nếu có) không phải
/// chữ số — nếu không khớp đủ ba điều kiện này thì dấu phẩy chắc chắn là
/// ranh giới đoạn.
bool _isDelimiterChar(String text, int i) {
  final ch = text[i];
  if (ch == ';' || ch == '\n') return true;
  if (ch != ',') return false;

  final precededByDigit = i > 0 && _isDigit(text[i - 1]);
  final hasThreeDigitGroup =
      i + 3 < text.length &&
      _isDigit(text[i + 1]) &&
      _isDigit(text[i + 2]) &&
      _isDigit(text[i + 3]) &&
      (i + 4 >= text.length || !_isDigit(text[i + 4]));
  return !(precededByDigit && hasThreeDigitGroup);
}

/// `true` nếu vị trí `[start, start+2)` là từ "và" ĐỨNG MỘT MÌNH (biên
/// khoảng trắng hoặc đầu/cuối chuỗi hai bên) — tránh cắt nhầm một từ tình cờ
/// chứa "và" bên trong.
bool _isStandaloneVaAt(String text, int start) {
  if (start + 2 > text.length) return false;
  if (text.substring(start, start + 2) != 'và') return false;
  final beforeOk = start == 0 || text[start - 1] == ' ';
  final afterOk = start + 2 == text.length || text[start + 2] == ' ';
  return beforeOk && afterOk;
}

List<String> segmentMessage(String normalizedDiacritics) {
  final rawPieces = <String>[];
  final buffer = StringBuffer();
  for (var i = 0; i < normalizedDiacritics.length; i++) {
    if (_isDelimiterChar(normalizedDiacritics, i)) {
      rawPieces.add(buffer.toString());
      buffer.clear();
      continue;
    }
    if (_isStandaloneVaAt(normalizedDiacritics, i)) {
      rawPieces.add(buffer.toString());
      buffer.clear();
      i += 1; // bỏ qua ký tự thứ hai của "và"
      continue;
    }
    buffer.write(normalizedDiacritics[i]);
  }
  rawPieces.add(buffer.toString());

  return rawPieces
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList(growable: false);
}
