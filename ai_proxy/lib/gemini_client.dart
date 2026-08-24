import 'dart:convert';

import 'package:http/http.dart' as http;

import 'parse_types.dart';

/// `generateContent`, KHÔNG phải Interactions API mới (`v1beta2/interactions`)
/// — đây là một cuộc gọi ĐƠN, KHÔNG TRẠNG THÁI (không lịch sử hội thoại,
/// không tool, không tác vụ nền), đúng những gì `generateContent` được thiết
/// kế cho, còn 4 lý do Google đưa ra để chọn Interactions API (server-side
/// history, observable steps, tool use, tác vụ nền dài) không áp dụng ở đây
/// — Google TỰ xác nhận `generateContent` "vẫn được hỗ trợ đầy đủ", không
/// phải một API cũ đang chết. Xem docs/decisions.md § Phase 23 cho nguồn.
const _apiBase = 'https://generativelanguage.googleapis.com/v1beta/models';

/// Chọn TẠI THỜI ĐIỂM CODE (2026-08-22), xác nhận qua docs sống của Google —
/// KHÔNG dùng model nào thuộc họ Gemini 2.5 dù giá per-token thấy rẻ hơn một
/// chút, vì cả họ 2.5 đã deprecated, dự kiến retire 10/2026. `flash-lite` vì
/// đây là hạng "cost-sensitive workhorse" Google tự khuyến nghị cho việc
/// khối lượng lớn/giá rẻ — đúng vị trí "fallback-của-fallback" của tính năng
/// này (~10% số câu). Xem docs/decisions.md § Phase 23.
const defaultModel = 'gemini-3.5-flash-lite';

/// JSON schema PHẲNG (không object/array lồng) theo đúng yêu cầu của phase —
/// 7 field vô hướng. `category_id` ép bằng `enum` xây ĐỘNG từ danh sách danh
/// mục thật của app mỗi request (không hardcode danh mục ở proxy) — Gemini
/// không thể trả một danh mục ngoài danh sách này ở tầng schema, không chỉ
/// nhờ dặn trong prompt.
Map<String, dynamic> buildResponseSchema(List<CategoryOption> categories) {
  return {
    'type': 'object',
    'properties': {
      'amount_found': {
        'type': 'boolean',
        'description': 'false nếu câu không hề chứa số tiền nào',
      },
      'amount_minor': {
        'type': 'integer',
        'description':
            'Số tiền, đơn vị VNĐ nguyên (không thập phân). 0 nếu amount_found=false.',
      },
      'confident': {
        'type': 'boolean',
        'description':
            'true nếu số tiền có tín hiệu rõ ràng, không phải đoán mò',
      },
      'date_iso': {
        'type': 'string',
        'description': 'Ngày giao dịch, định dạng YYYY-MM-DD',
      },
      'date_explicit': {
        'type': 'boolean',
        'description':
            'true nếu câu có nêu rõ một cụm ngày, false nếu suy ra mặc định hôm nay',
      },
      'category_id': {
        'type': 'string',
        'enum': [for (final c in categories) c.id, 'none'],
        'description': '"none" nếu không rõ danh mục nào phù hợp',
      },
      'note': {
        'type': 'string',
        'description':
            'Phần mô tả ngắn còn lại sau khi trừ số tiền/ngày, giữ nguyên tiếng Việt có dấu',
      },
    },
    'required': [
      'amount_found',
      'amount_minor',
      'confident',
      'date_iso',
      'date_explicit',
      'category_id',
      'note',
    ],
  };
}

String buildPrompt(ParseRequest request) {
  final categoryLines = request.categories.isEmpty
      ? '(không có danh mục nào — luôn trả category_id="none")'
      : request.categories.map((c) => '${c.id}: ${c.name}').join('\n');
  return '''
Bạn là bộ phân tích giao dịch chi tiêu cá nhân tiếng Việt. Đọc MỘT câu nhắn
ngắn của người dùng và trích xuất thông tin giao dịch theo schema đã cho.

Hôm nay: ${request.todayIso}

Danh sách danh mục hợp lệ (id: tên) — CHỈ được chọn category_id từ danh sách
này hoặc "none", KHÔNG được bịa ra danh mục khác:
$categoryLines

Câu cần phân tích: "${request.message}"

Quy tắc:
- Nếu câu không chứa số tiền nào, đặt amount_found=false, amount_minor=0.
- Ngày: suy luận từ các cụm như "hôm qua", "hôm kia", "thứ Hai tuần trước",
  "12/3" — nếu câu không nêu ngày, dùng hôm nay và đặt date_explicit=false.
- category_id: chọn danh mục khớp ý nghĩa nhất với phần còn lại của câu sau
  khi trừ số tiền/ngày; "none" nếu không chắc.
- note: phần mô tả ngắn còn lại (vd. tên quán, mục đích chi tiêu), giữ dấu
  tiếng Việt, không thêm số tiền/ngày vào đây.
''';
}

Map<String, dynamic> buildGeminiRequestBody(ParseRequest request) {
  return {
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': buildPrompt(request)},
        ],
      },
    ],
    'generationConfig': {
      'responseMimeType': 'application/json',
      'responseSchema': buildResponseSchema(request.categories),
    },
  };
}

/// Rút text JSON thô từ hình dạng response chuẩn của `generateContent` —
/// `candidates[0].content.parts[0].text`. `null` nếu hình dạng không đúng kỳ
/// vọng (lỗi/bị chặn an toàn/…) — tầng gọi coi như "không cải thiện được gì".
String? extractGeminiText(Map<String, dynamic> geminiResponse) {
  final candidates = geminiResponse['candidates'];
  if (candidates is! List || candidates.isEmpty) return null;
  final content = (candidates.first as Map<String, dynamic>)['content'];
  if (content is! Map<String, dynamic>) return null;
  final parts = content['parts'];
  if (parts is! List || parts.isEmpty) return null;
  final text = (parts.first as Map<String, dynamic>)['text'];
  return text is String ? text : null;
}

/// Giải mã JSON model trả về thành [ParseResult] — kiểm tra lại `category_id`
/// nằm trong danh sách đã gửi (phòng thủ lớp thứ hai, không tin riêng ràng
/// buộc `enum` của schema — model vẫn có thể trả sai hình dạng khi lỗi mạng/
/// input dị thường). `category_id` không hợp lệ hoặc `"none"` ⇒ `null`.
ParseResult? parseModelJson(String jsonText, List<CategoryOption> categories) {
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;

  final amountFound = decoded['amount_found'];
  final amountMinor = decoded['amount_minor'];
  final confident = decoded['confident'];
  final dateIso = decoded['date_iso'];
  final dateExplicit = decoded['date_explicit'];
  final categoryIdRaw = decoded['category_id'];
  final note = decoded['note'];
  if (amountFound is! bool ||
      amountMinor is! int ||
      confident is! bool ||
      dateIso is! String ||
      dateExplicit is! bool ||
      categoryIdRaw is! String ||
      note is! String) {
    return null;
  }

  final validIds = {for (final c in categories) c.id};
  final categoryId = validIds.contains(categoryIdRaw) ? categoryIdRaw : null;

  return ParseResult(
    amountFound: amountFound,
    amountMinor: amountMinor,
    confident: confident,
    dateIso: dateIso,
    dateExplicit: dateExplicit,
    categoryId: categoryId,
    note: note,
  );
}

/// Gọi Gemini thật qua REST — `http.Client` inject được cho test (xem
/// `test/gemini_client_test.dart`).
class GeminiClient {
  GeminiClient({
    required this.apiKey,
    http.Client? httpClient,
    this.model = defaultModel,
    this.timeout = const Duration(seconds: 15),
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final Duration timeout;
  final http.Client _http;

  /// Bọc TOÀN BỘ lời gọi mạng (kết nối/timeout/JSON hỏng) trong một
  /// try/catch — `null` là kết quả "bình thường" của mọi lỗi mạng, không
  /// phải một trường hợp cá biệt phải xử lý riêng ở tầng gọi. `server.dart`
  /// vẫn có try/catch riêng của nó (bảo vệ TIẾN TRÌNH proxy khỏi lỗi không
  /// lường trước), lớp ở đây bảo vệ HỢP ĐỒNG của chính `parse()`.
  Future<ParseResult?> parse(ParseRequest request) async {
    try {
      final uri = Uri.parse('$_apiBase/$model:generateContent?key=$apiKey');
      final response = await _http
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode(buildGeminiRequestBody(request)),
          )
          .timeout(timeout);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final text = extractGeminiText(decoded);
      if (text == null) return null;
      return parseModelJson(text, request.categories);
    } catch (_) {
      return null;
    }
  }
}
