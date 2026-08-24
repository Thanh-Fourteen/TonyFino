// Unit test HTTP client giả — checklist bắt buộc của Phase 23: thành công /
// timeout / JSON hỏng / category ngoài enum. "Chế độ máy bay" tương ứng với
// case "kết nối lỗi/không với tới proxy" — không thể thật sự bật airplane
// mode trong `flutter test`, nhưng hành vi PHẦN MỀM giống hệt: mọi lỗi mạng
// đều rơi vào cùng nhánh try/catch, trả `null` im lặng (xem docs/decisions.md
// § Phase 23). Bài kiểm tra bắt buộc còn lại — bật thật airplane mode trên
// máy/emulator, xác nhận app vẫn dùng được đầy đủ — làm trực tiếp trên thiết
// bị, ghi lại trong TODOS.md § Phase 23 "Kết quả", không lặp lại được ở đây.
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/services/ai/tailnet_fallback.dart';

void main() {
  final now = DateTime(2026, 8, 22);
  final clock = Clock.fixed(now);

  Category category({
    required int id,
    required String name,
    int? parentCategoryId,
  }) {
    return Category(
      id: id,
      name: name,
      kind: 'expense',
      categoryColorId: 0,
      iconCode: 'restaurant',
      isArchived: false,
      createdAt: now,
      // Ví bất kỳ — test này chỉ dựng đối tượng `Category` trong bộ nhớ để
      // đưa cho parser, không chạm DB nên id ví không có ý nghĩa gì.
      walletId: 1,
      parentCategoryId: parentCategoryId,
      sortOrder: 0,
    );
  }

  final anUong = category(id: 5, name: 'Ăn uống');
  final tieuVat = category(id: 12, name: 'Tiêu vặt', parentCategoryId: 5);
  final categories = [anUong, tieuVat];

  test(
    'thành công: JSON hợp lệ → ParsedDraft khớp categoryKey = id thật',
    () async {
      final fallback = TailnetFallback(
        baseUrl: 'https://tony.tailfcdcfc.ts.net/tonyfino-ai/',
        categories: categories,
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['message'], 'cf sáng 20k');
          expect(body['todayIso'], '2026-08-22');
          expect(body['categories'], [
            {'id': '5', 'name': 'Ăn uống'},
            {'id': '12', 'name': 'Ăn uống → Tiêu vặt'},
          ]);
          return http.Response(
            jsonEncode({
              'amountFound': true,
              'amountMinor': 20000,
              'confident': true,
              'dateIso': '2026-08-22',
              'dateExplicit': false,
              'categoryId': '12',
              'note': 'cf sáng',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await fallback.tryParse('cf sáng 20k', clock: clock);
      expect(result, hasLength(1));
      final draft = result!.first;
      expect(draft.amount?.minorUnits, 20000);
      expect(draft.amount?.confident, isTrue);
      expect(draft.category?.categoryKey, '12');
      expect(draft.leftoverText, 'cf sáng');
    },
  );

  test('timeout: trả null, không throw', () async {
    final fallback = TailnetFallback(
      baseUrl: 'https://tony.tailfcdcfc.ts.net/tonyfino-ai/',
      categories: categories,
      timeout: const Duration(milliseconds: 10),
      client: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      }),
    );

    expect(await fallback.tryParse('câu gì đó', clock: clock), isNull);
  });

  test('JSON hỏng: trả null, không throw', () async {
    final fallback = TailnetFallback(
      baseUrl: 'https://tony.tailfcdcfc.ts.net/tonyfino-ai/',
      categories: categories,
      client: MockClient((request) async {
        return http.Response(
          'không phải json {{{',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(await fallback.tryParse('câu gì đó', clock: clock), isNull);
  });

  test(
    'category ngoài danh sách gửi (proxy lỗi/model bịa): categoryKey/category về null',
    () async {
      final fallback = TailnetFallback(
        baseUrl: 'https://tony.tailfcdcfc.ts.net/tonyfino-ai/',
        categories: categories,
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'amountFound': true,
              'amountMinor': 20000,
              'confident': true,
              'dateIso': '2026-08-22',
              'dateExplicit': false,
              'categoryId': '999-khong-ton-tai',
              'note': 'cf sáng',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await fallback.tryParse('cf sáng 20k', clock: clock);
      expect(result, hasLength(1));
      expect(result!.first.category, isNull);
    },
  );

  test(
    'proxy không với tới được (kết nối lỗi) — tương đương chế độ máy bay: trả null',
    () async {
      final fallback = TailnetFallback(
        baseUrl: 'https://tony.tailfcdcfc.ts.net/tonyfino-ai/',
        categories: categories,
        client: MockClient((request) async {
          throw http.ClientException('Connection refused');
        }),
      );

      expect(await fallback.tryParse('câu gì đó', clock: clock), isNull);
    },
  );

  test('status khác 200 (proxy trả lỗi): trả null', () async {
    final fallback = TailnetFallback(
      baseUrl: 'https://tony.tailfcdcfc.ts.net/tonyfino-ai/',
      categories: categories,
      client: MockClient((request) async {
        return http.Response('bad gateway', 502);
      }),
    );

    expect(await fallback.tryParse('câu gì đó', clock: clock), isNull);
  });

  test(
    'amountFound=false: category không tìm thấy số tiền → giống thẻ lỗi cục bộ',
    () async {
      final fallback = TailnetFallback(
        baseUrl: 'https://tony.tailfcdcfc.ts.net/tonyfino-ai/',
        categories: categories,
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'amountFound': false,
              'amountMinor': 0,
              'confident': false,
              'dateIso': '2026-08-22',
              'dateExplicit': false,
              'categoryId': 'none',
              'note': '',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await fallback.tryParse('câu vô nghĩa', clock: clock);
      expect(result, hasLength(1));
      expect(result!.first.amount, isNull);
      expect(result.first.isUnderstood, isFalse);
    },
  );
}
