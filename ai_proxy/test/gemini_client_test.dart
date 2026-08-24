import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tonyfino_ai_proxy/gemini_client.dart';
import 'package:tonyfino_ai_proxy/parse_types.dart';

void main() {
  const categories = [
    CategoryOption(id: '5', name: 'Ăn uống'),
    CategoryOption(id: '12', name: 'Ăn uống → Tiêu vặt'),
  ];
  final request = ParseRequest(
    message: 'cf sáng 20k',
    todayIso: '2026-08-22',
    categories: categories,
  );

  Map<String, dynamic> geminiEnvelope(Map<String, dynamic> modelJson) => {
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': jsonEncode(modelJson)},
          ],
        },
      },
    ],
  };

  test(
    'buildResponseSchema ép enum category_id từ đúng danh sách đã gửi + "none"',
    () {
      final schema = buildResponseSchema(categories);
      final properties = schema['properties'] as Map<String, dynamic>;
      final categoryIdField = properties['category_id'] as Map<String, dynamic>;
      expect(categoryIdField['enum'], ['5', '12', 'none']);
    },
  );

  test('thành công: parse JSON hợp lệ từ Gemini', () async {
    final client = GeminiClient(
      apiKey: 'fake-key',
      httpClient: MockClient((req) async {
        return http.Response(
          jsonEncode(
            geminiEnvelope({
              'amount_found': true,
              'amount_minor': 20000,
              'confident': true,
              'date_iso': '2026-08-22',
              'date_explicit': false,
              'category_id': '12',
              'note': 'cf sáng',
            }),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.parse(request);
    expect(result, isNotNull);
    expect(result!.amountFound, isTrue);
    expect(result.amountMinor, 20000);
    expect(result.categoryId, '12');
    expect(result.note, 'cf sáng');
  });

  test('timeout: trả null, không throw', () async {
    final client = GeminiClient(
      apiKey: 'fake-key',
      timeout: const Duration(milliseconds: 10),
      httpClient: MockClient((req) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      }),
    );

    expect(await client.parse(request), isNull);
  });

  test('JSON hỏng từ Gemini: trả null, không throw', () async {
    final client = GeminiClient(
      apiKey: 'fake-key',
      httpClient: MockClient((req) async {
        return http.Response(
          'not valid json {{{',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(await client.parse(request), isNull);
  });

  test(
    'model text không phải JSON hợp lệ (dù bọc ngoài đúng hình dạng candidates): trả null',
    () async {
      final client = GeminiClient(
        apiKey: 'fake-key',
        httpClient: MockClient((req) async {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'không phải JSON'},
                    ],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(await client.parse(request), isNull);
    },
  );

  test(
    'category ngoài enum (model "bịa" id lạ): categoryId về null thay vì tin mù',
    () async {
      final client = GeminiClient(
        apiKey: 'fake-key',
        httpClient: MockClient((req) async {
          return http.Response(
            jsonEncode(
              geminiEnvelope({
                'amount_found': true,
                'amount_minor': 20000,
                'confident': true,
                'date_iso': '2026-08-22',
                'date_explicit': false,
                'category_id': '999-khong-ton-tai',
                'note': 'cf sáng',
              }),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.parse(request);
      expect(result, isNotNull);
      expect(result!.categoryId, isNull);
    },
  );

  test('status khác 200 (vd. quota hết): trả null', () async {
    final client = GeminiClient(
      apiKey: 'fake-key',
      httpClient: MockClient((req) async {
        return http.Response('quota exceeded', 429);
      }),
    );

    expect(await client.parse(request), isNull);
  });
}
