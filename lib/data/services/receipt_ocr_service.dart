import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../features/transactions/domain/receipt_ocr_layout.dart';

/// Nhận dạng chữ trên ảnh hoá đơn — 100% cục bộ qua Google ML Kit (Play
/// Services), KHÔNG mạng. `TextRecognitionScript.latin` đủ cho tiếng Việt có
/// dấu — xác nhận trực tiếp từ trang "Supported languages" của Google
/// (tiếng Việt nằm trong 44 ngôn ngữ script Latin có bộ nhận dạng riêng,
/// KHÔNG cần gói ngôn ngữ phụ như Chinese/Devanagari/Japanese/Korean), xem
/// docs/decisions.md § Phase 18.
///
/// Trả văn bản đã GHÉP THEO HÀNG (`arrangeIntoRows` — xem lý do ở đó),
/// không phải `RecognizedText.text` đọc theo khối. Trích số tiền/merchant/
/// ngày là việc của `receipt_ocr_parser.dart` (thuần Dart, tách biệt engine
/// khỏi luật trích xuất, cùng kỷ luật `category_matcher.dart` Phase 7).
final receiptOcrServiceProvider = Provider<ReceiptOcrService>(
  (ref) => const ReceiptOcrService(),
);

class ReceiptOcrService {
  const ReceiptOcrService();

  Future<String> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      return arrangeIntoRows([
        for (final block in result.blocks)
          for (final line in block.lines) _toBox(line),
      ]);
    } finally {
      await recognizer.close();
    }
  }
}

/// Bốn góc thật của dòng (xem lý do ở `OcrLineBox`); thiếu góc (iOS/bản cũ
/// không gửi `points`) thì lùi về khung chữ nhật — mất phần nắn nghiêng,
/// vẫn ghép hàng được.
OcrLineBox _toBox(TextLine line) {
  final c = line.cornerPoints;
  if (c.length != 4) {
    final r = line.boundingBox;
    return OcrLineBox.axisAligned(
      text: line.text,
      left: r.left,
      top: r.top,
      right: r.right,
      bottom: r.bottom,
    );
  }
  Point<double> p(Point<int> q) => Point(q.x.toDouble(), q.y.toDouble());
  return OcrLineBox(
    text: line.text,
    topLeft: p(c[0]),
    topRight: p(c[1]),
    bottomRight: p(c[2]),
    bottomLeft: p(c[3]),
  );
}
