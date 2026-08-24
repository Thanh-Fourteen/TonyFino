import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Nhận dạng chữ trên ảnh hoá đơn — 100% cục bộ qua Google ML Kit (Play
/// Services), KHÔNG mạng. `TextRecognitionScript.latin` đủ cho tiếng Việt có
/// dấu — xác nhận trực tiếp từ trang "Supported languages" của Google
/// (tiếng Việt nằm trong 44 ngôn ngữ script Latin có bộ nhận dạng riêng,
/// KHÔNG cần gói ngôn ngữ phụ như Chinese/Devanagari/Japanese/Korean), xem
/// docs/decisions.md § Phase 18.
///
/// Chỉ trả văn bản THÔ — trích số tiền/merchant là việc của
/// `receipt_ocr_parser.dart` (thuần Dart, tách biệt engine khỏi luật trích
/// xuất, cùng kỷ luật `category_matcher.dart` Phase 7).
class ReceiptOcrService {
  const ReceiptOcrService();

  Future<String> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
