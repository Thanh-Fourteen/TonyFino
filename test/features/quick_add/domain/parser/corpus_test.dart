import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/quick_add/domain/parser/parser.dart';

import '../../../../support/parser_test_keywords.dart';

/// Test tham số hoá trên `test/fixtures/parser/corpus.jsonl` — 300+ cặp
/// input→expected sinh bởi `tool/generate_parser_corpus.dart`, giá trị mong
/// đợi tính bằng công thức ĐỘC LẬP với parser thật (xem doc comment ở đó).
/// Đây là test ROI cao nhất codebase: cho phép refactor parser trong nhiều
/// tháng tới mà không sợ hỏng âm thầm.
///
/// Đồng hồ đóng băng ở `2026-08-21` (Thứ Sáu) — PHẢI khớp `_fixedToday`
/// trong generator, nếu không mọi ca liên quan tới ngày tương đối sẽ sai.
void main() {
  final frozen = Clock.fixed(DateTime(2026, 8, 21));
  final keywords = testCategoryKeywords();

  final lines = File(
    'test/fixtures/parser/corpus.jsonl',
  ).readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();

  test('corpus.jsonl có ít nhất 300 ca', () {
    expect(lines.length, greaterThanOrEqualTo(300));
  });

  for (var i = 0; i < lines.length; i++) {
    final row = jsonDecode(lines[i]) as Map<String, dynamic>;
    final input = row['input'] as String;
    final expectedList = (row['expected'] as List).cast<Map<String, dynamic>>();

    test('corpus[$i]: "$input"', () {
      final drafts = parseMessage(
        input,
        clock: frozen,
        categoryKeywords: keywords,
      );

      expect(
        drafts.length,
        expectedList.length,
        reason:
            'số draft không khớp cho "$input": '
            'nhận ${drafts.map((d) => d.rawText).toList()}',
      );

      for (var d = 0; d < expectedList.length; d++) {
        final expected = expectedList[d];
        final draft = drafts[d];

        expect(
          draft.amount?.minorUnits,
          expected['amountMinor'],
          reason: 'amountMinor sai cho draft $d của "$input"',
        );
        if (expected['amountMinor'] != null) {
          expect(
            draft.amount?.confident,
            expected['amountConfident'],
            reason: 'amountConfident sai cho draft $d của "$input"',
          );
        }
        expect(
          draft.category?.categoryKey,
          expected['categoryKey'],
          reason: 'categoryKey sai cho draft $d của "$input"',
        );
        expect(
          draft.date.date.toIso8601String().substring(0, 10),
          expected['dateIso'],
          reason: 'dateIso sai cho draft $d của "$input"',
        );
        expect(
          draft.date.explicit,
          expected['dateExplicit'],
          reason: 'dateExplicit sai cho draft $d của "$input"',
        );
      }
    });
  }
}
