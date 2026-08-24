import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/quick_add/domain/parser/parser.dart';

import '../../../../support/parser_test_keywords.dart';

/// Hai xác minh bắt buộc còn lại của Phase 7 (ngoài corpus): fuzz 10.000
/// chuỗi ngẫu nhiên KHÔNG ĐƯỢC ném lỗi/không số âm, và property test
/// `parse(format(n)) == n`. Seed cố định (`Random(1234567)`) — fuzz thất
/// bại phải tái hiện lại được, không được flaky.
void main() {
  final frozen = Clock.fixed(DateTime(2026, 8, 21));
  final keywords = testCategoryKeywords();

  group('Fuzz — 10.000 chuỗi ngẫu nhiên', () {
    const vocabulary = [
      'cà phê',
      'ăn trưa',
      'xăng',
      'lương',
      'thứ',
      'triệu',
      'nghìn',
      'k',
      'tr',
      'đ',
      'vnd',
      'rưỡi',
      'củ',
      'trăm',
      'linh',
      'lẻ',
      'hôm',
      'qua',
      'nay',
      'mai',
      'tuần',
      'trước',
      'sau',
      'và',
      'chủ',
      'nhật',
      'dc',
      'ko',
      '2tr5',
      '1tr250',
      'mười',
      'mươi',
      'một',
      'hai',
      'năm',
      'lăm',
      'tư',
      'bốn',
      '/',
      '-',
      ',',
      ';',
      '.',
      '\n',
      '   ',
      'đường',
      'đồng',
      '🎉',
      '中文',
      'ăêôơưđ',
      'ĐĐĐ',
    ];

    test('không ném lỗi, không số âm, kể cả trên chuỗi rác/emoji/rỗng', () {
      final random = Random(1234567);
      var totalDrafts = 0;

      for (var i = 0; i < 10000; i++) {
        final wordCount = random.nextInt(8);
        final buffer = StringBuffer();
        for (var w = 0; w < wordCount; w++) {
          if (w > 0) buffer.write(' ');
          if (random.nextInt(5) == 0) {
            // thỉnh thoảng chèn một số nguyên ngẫu nhiên thay vì từ vựng.
            buffer.write(random.nextInt(100000000));
          } else {
            buffer.write(vocabulary[random.nextInt(vocabulary.length)]);
          }
        }
        final input = buffer.toString();

        List<ParsedDraft> drafts;
        try {
          drafts = parseMessage(
            input,
            clock: frozen,
            categoryKeywords: keywords,
          );
        } catch (e, st) {
          fail('parseMessage ném lỗi với input #$i "$input": $e\n$st');
        }

        for (final draft in drafts) {
          final minorUnits = draft.amount?.minorUnits;
          if (minorUnits != null) {
            expect(
              minorUnits,
              greaterThanOrEqualTo(0),
              reason: 'số tiền âm cho input #$i "$input" → "${draft.rawText}"',
            );
          }
          totalDrafts++;
        }
      }

      // Không phải assertion — chỉ để chắc chắn vòng lặp thật sự chạy qua
      // parser (không phải no-op do lỗi setup nào đó im lặng nuốt hết input).
      expect(totalDrafts, greaterThan(0));
    });

    test('chuỗi rất dài không ném lỗi', () {
      final longInput = List.filled(2000, 'cà phê 35k, ').join();
      expect(
        () =>
            parseMessage(longInput, clock: frozen, categoryKeywords: keywords),
        returnsNormally,
      );
    });

    test('chỉ toàn ký tự đặc biệt/emoji không ném lỗi', () {
      for (final input in [
        '🎉🎊💰💸',
        '!!!???...',
        '\n\n\n\t\t',
        '——//..,,;;',
        '中文测试字符串',
      ]) {
        expect(
          () => parseMessage(input, clock: frozen, categoryKeywords: keywords),
          returnsNormally,
          reason: 'input: $input',
        );
      }
    });
  });

  group('Property — parse(format(n)) == n', () {
    test('số trần kèm "đ" luôn parse lại đúng giá trị gốc', () {
      final random = Random(987654321);
      for (var i = 0; i < 500; i++) {
        final n = random.nextInt(999999999) + 1; // 1..999,999,999
        final formatted = '$nđ';
        final drafts = parseMessage(
          formatted,
          clock: frozen,
          categoryKeywords: keywords,
        );
        expect(drafts.length, 1, reason: 'formatted="$formatted"');
        expect(
          drafts.first.amount?.minorUnits,
          n,
          reason: 'parse(format($n)) phải bằng $n, formatted="$formatted"',
        );
      }
    });

    test('số trần ≥1000 không kèm ký hiệu tiền tệ vẫn parse lại đúng', () {
      final random = Random(555);
      for (var i = 0; i < 200; i++) {
        final n = random.nextInt(999999999) + 1000; // luôn ≥4 chữ số
        final formatted = '$n';
        final drafts = parseMessage(
          formatted,
          clock: frozen,
          categoryKeywords: keywords,
        );
        expect(drafts.length, 1, reason: 'formatted="$formatted"');
        expect(drafts.first.amount?.minorUnits, n);
      }
    });
  });
}
