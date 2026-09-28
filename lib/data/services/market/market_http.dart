import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Lỗi tải giá — thông điệp tiếng Việt hiện thẳng lên màn hình.
class MarketFetchException implements Exception {
  const MarketFetchException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cổng mạng DUY NHẤT của hai trang Giá vàng / Giá cà phê.
///
/// - Hết giờ 12 giây: mạng yếu thì báo lỗi và giữ số cũ, không treo vòng
///   xoay vô tận.
/// - Mọi phản hồi thành công được cất vào prefs theo URL — mất mạng mở
///   trang vẫn thấy bảng giá lần cuối, kèm giờ cập nhật để biết là số cũ.
///   Đây là dữ liệu công khai (giá niêm yết), không phải dữ liệu của Tony,
///   nên prefs thường (không mã hoá) là đủ.
class MarketHttp {
  MarketHttp({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _prefs = SharedPreferencesAsync();

  static const _timeout = Duration(seconds: 12);

  /// Một số máy chủ (CDN chặn bot) từ chối User-Agent mặc định của Dart.
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36',
    'Accept': 'application/json, text/html;q=0.9, */*;q=0.8',
  };

  static String _cacheKey(Uri uri) => 'tonyfino_market_cache:$uri';

  Future<String> get(Uri uri, {Map<String, String> headers = const {}}) async {
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {..._headers, ...headers})
          .timeout(_timeout);
    } on TimeoutException {
      throw const MarketFetchException('Mạng chậm quá, chưa tải được giá.');
    } catch (_) {
      throw const MarketFetchException(
        'Không kết nối được — kiểm tra mạng rồi kéo xuống để tải lại.',
      );
    }
    if (response.statusCode != 200) {
      throw MarketFetchException(
        'Nguồn giá đang lỗi (HTTP ${response.statusCode}).',
      );
    }
    final body = utf8.decode(response.bodyBytes);
    unawaited(_prefs.setString(_cacheKey(uri), body));
    return body;
  }

  /// Phản hồi thành công gần nhất của [uri], `null` nếu chưa từng tải được.
  Future<String?> cached(Uri uri) => _prefs.getString(_cacheKey(uri));
}
