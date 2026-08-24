import 'package:clock/clock.dart';

import 'parser/parser.dart';

/// Chỗ cắm cho AI fallback thật (`TailnetFallback`, Phase 23, host trên
/// tailnet — D8). Chỉ
/// được gọi khi parser cục bộ (Phase 7) KHÔNG chắc — `amount == null` hoặc
/// `amount.confident == false` — không bao giờ gọi cho mọi tin nhắn, để
/// giữ đúng "zero độ trễ, zero LLM" cho trường hợp phổ biến (đã parse chắc
/// chắn cục bộ).
///
/// Trả `null` nghĩa là "không cải thiện được gì" — tầng gọi giữ nguyên kết
/// quả cục bộ (kể cả khi đó là thẻ lỗi "Mình chưa hiểu").
abstract interface class AiParseFallback {
  Future<List<ParsedDraft>?> tryParse(
    String rawMessage, {
    required Clock clock,
  });
}

/// Bản mặc định khi `cloudFallbackEnabled == false` (D8, mặc định TẮT — xem
/// `aiParseFallbackProvider`). Luôn trả `null` ngay lập tức, không mạng,
/// không I/O — an toàn để gọi vô điều kiện mà không cần kiểm tra cấu hình
/// trước ở tầng gọi.
class NoopFallback implements AiParseFallback {
  const NoopFallback();

  @override
  Future<List<ParsedDraft>?> tryParse(
    String rawMessage, {
    required Clock clock,
  }) async => null;
}
