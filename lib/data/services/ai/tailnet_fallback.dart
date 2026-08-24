import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;

import '../../../features/quick_add/domain/ai_parse_fallback.dart';
import '../../../features/quick_add/domain/parser/parse_result.dart';
import '../../db/database.dart';

/// Bản thật của [AiParseFallback] (Phase 23, D8) — gọi proxy tự host trên
/// tailnet (KHÔNG bao giờ gọi thẳng Gemini từ APK: khoá API không đóng gói
/// trong app, chỉ sống trên proxy). `baseUrl`/danh sách danh mục được
/// `aiParseFallbackProvider` inject mỗi lần rebuild — class này không tự đọc
/// Settings/DB, giữ đúng ranh giới `data/services/` thuần (Luật #4).
class TailnetFallback implements AiParseFallback {
  TailnetFallback({
    required this.baseUrl,
    required this.categories,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final List<Category> categories;
  final Duration timeout;
  final http.Client _client;

  /// Bọc TOÀN BỘ lời gọi mạng trong MỘT try/catch — đúng hợp đồng có sẵn của
  /// `AiParseFallback` (`null` = "không cải thiện được gì", tầng gọi giữ
  /// nguyên kết quả cục bộ). "Fallback không với tới được là chuyện bình
  /// thường, không phải lỗi" (yêu cầu tường minh của Phase 23) — không throw
  /// ra ngoài trong bất kỳ trường hợp nào (mạng lỗi/timeout/proxy tắt/JSON
  /// hỏng), kể cả khi ở chế độ máy bay.
  @override
  Future<List<ParsedDraft>?> tryParse(
    String rawMessage, {
    required Clock clock,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse(baseUrl),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'message': rawMessage,
              'todayIso': _isoDate(clock.now()),
              'categories': [
                for (final c in categories)
                  {'id': c.id.toString(), 'name': _displayName(c)},
              ],
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final draft = _toDraft(rawMessage, decoded);
      return draft == null ? null : [draft];
    } catch (_) {
      return null;
    }
  }

  /// "Ăn uống → Tiêu vặt" cho danh mục con, "Ăn uống" cho danh mục gốc — giúp
  /// Gemini phân biệt các danh mục con trùng tên dưới cha khác nhau (dữ liệu
  /// thật của Tony có "Phát sinh" dưới cả "Giao thông" lẫn "Mua sắm", xem
  /// addendum sau Phase 20).
  String _displayName(Category category) {
    if (category.parentCategoryId == null) return category.name;
    final parent = categories
        .where((c) => c.id == category.parentCategoryId)
        .firstOrNull;
    return parent == null ? category.name : '${parent.name} → ${category.name}';
  }

  ParsedDraft? _toDraft(String rawMessage, Map<String, dynamic> json) {
    final amountFound = json['amountFound'];
    final amountMinor = json['amountMinor'];
    final confident = json['confident'];
    final dateIso = json['dateIso'];
    final dateExplicit = json['dateExplicit'];
    final categoryId = json['categoryId'];
    final note = json['note'];
    if (amountFound is! bool ||
        amountMinor is! int ||
        confident is! bool ||
        dateIso is! String ||
        dateExplicit is! bool ||
        note is! String) {
      return null;
    }
    final date = DateTime.tryParse(dateIso);
    if (date == null) return null;

    // Phòng thủ lớp thứ hai — proxy đã kiểm tra `categoryId` nằm trong danh
    // sách đã gửi, nhưng không tin tưởng riêng một tầng qua mạng: nếu id lạ
    // lọt qua (proxy cũ/lỗi lạ), coi như "chưa phân loại" thay vì gán bừa.
    final validIds = {for (final c in categories) c.id.toString()};
    final matchedCategoryId =
        (categoryId is String && validIds.contains(categoryId))
        ? categoryId
        : null;

    return ParsedDraft(
      rawText: rawMessage,
      leftoverText: note,
      amount: amountFound
          ? ParsedAmount(minorUnits: amountMinor, confident: confident)
          : null,
      date: ParsedDate(date: date, explicit: dateExplicit),
      category: matchedCategoryId == null
          ? null
          : CategoryMatch(categoryKey: matchedCategoryId, score: 1.0),
    );
  }

  String _isoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
