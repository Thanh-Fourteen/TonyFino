import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tonyfino_ai_proxy/gemini_client.dart';
import 'package:tonyfino_ai_proxy/parse_types.dart';

/// Proxy AI fallback — chạy TRÊN MÁY của Tony, expose ra tailnet qua
/// `tailscale serve --set-path /tonyfino-ai/ <port>` (KHÔNG bao giờ
/// `serve reset` — xem `tool/serve_ai_proxy.sh`). Bind CHỈ `127.0.0.1`: lớp
/// phòng thủ thứ hai ngoài xác thực-theo-danh-tính-thiết-bị của tailnet —
/// dù `tailscale serve` có lỡ bị tắt/reset, proxy vẫn không lộ ra mạng LAN/
/// Internet vì bản thân socket chỉ nghe loopback.
Future<void> main(List<String> args) async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln(
      'GEMINI_API_KEY chưa được set. Tạo khoá paid-tier ở Google AI Studio, '
      'rồi export GEMINI_API_KEY=... (hoặc điền vào ai_proxy/.env và chạy '
      'qua tool/serve_ai_proxy.sh, script tự source file đó).',
    );
    exitCode = 1;
    return;
  }

  final port =
      int.tryParse(Platform.environment['TONYFINO_AI_PROXY_PORT'] ?? '') ??
      8766;
  final client = GeminiClient(apiKey: apiKey);

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln(
    'tonyfino_ai_proxy nghe ở 127.0.0.1:$port (model: $defaultModel)',
  );

  await for (final request in server) {
    unawaited(_handle(request, client));
  }
}

/// Không khoá cứng đường dẫn — chỉ có MỘT việc để làm (parse một câu), nên
/// nhận bất kỳ POST nào bất kể `tailscale serve --set-path` có strip prefix
/// `/tonyfino-ai/` hay chuyển nguyên path, tránh phải đoán hành vi đó.
Future<void> _handle(HttpRequest request, GeminiClient client) async {
  try {
    if (request.method != 'POST') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final parseRequest = ParseRequest.fromJson(decoded);
    final result = await client.parse(parseRequest);
    if (result == null) {
      request.response.statusCode = HttpStatus.badGateway;
      await request.response.close();
      return;
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(result.toJson()));
    await request.response.close();
  } catch (error) {
    // KHÔNG BAO GIỜ làm sập cả server vì một request lỗi — log cục bộ (chỉ
    // stdout máy này, không gửi đi đâu, không phải analytics) rồi trả lỗi
    // sạch cho request đó.
    stderr.writeln('Lỗi xử lý request: $error');
    try {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    } catch (_) {
      // response có thể đã bị đóng — bỏ qua.
    }
  }
}
