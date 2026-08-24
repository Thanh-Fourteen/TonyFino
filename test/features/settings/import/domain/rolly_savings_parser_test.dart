// Phase 19 — parser tiết kiệm Rolly, dữ liệu test khớp ĐÚNG hình dạng thật
// quan sát từ raw_rolly/savings_with_total.json + raw_rolly/input.json (đã
// ẩn danh id/user_id), không đoán field.
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_savings_parser.dart';

void main() {
  group('parseRollySavingsGoals', () {
    test(
      'mục tiêu hợp lệ (savings_with_total.json) → ánh xạ đủ field, total_amount là oracle',
      () {
        final result = parseRollySavingsGoals([
          {
            'id': 49755,
            'created_at': '2026-06-05T03:40:46.470716+00:00',
            'title': 'CCTG',
            'achieve_amount': 30000000.0,
            'achieve_date': '2026-08-22',
            'user_id': '00000000-0000-0000-0000-000000000000',
            'currency_code': 'VND',
            'currency_symbol': '₫',
            'badge_rewarded': true,
            'completed': true,
            'type': 'one-off',
            'recurrence': null,
            'completed_at': '2026-08-05T10:10:15.999249+00:00',
            'total_amount': 43200000.0,
          },
        ]);

        expect(result.issues, isEmpty);
        final goal = result.goals.single;
        expect(goal.sourceId, 'rolly-savings:49755');
        expect(goal.rollyGoalId, 49755);
        expect(goal.name, 'CCTG');
        expect(goal.targetAmountMinor, 30000000);
        expect(goal.currency, 'VND');
        expect(goal.currencyScale, 0);
        expect(goal.targetDate, DateTime(2026, 8, 22));
        expect(goal.isArchived, isTrue); // completed: true → lưu trữ ngay.
        expect(goal.totalContributedMinor, 43200000);
      },
    );

    test(
      'savings.json (không có total_amount) → totalContributedMinor null, vẫn parse được',
      () {
        final result = parseRollySavingsGoals([
          {
            'id': 49755,
            'title': 'CCTG',
            'achieve_amount': 30000000.0,
            'achieve_date': '2026-08-22',
            'currency_code': 'VND',
            'completed': true,
          },
        ]);
        expect(result.goals.single.totalContributedMinor, isNull);
      },
    );

    test('mục tiêu chưa đạt (completed: false) → isArchived false', () {
      final result = parseRollySavingsGoals([
        {
          'id': 1,
          'title': 'Xe máy',
          'achieve_amount': 5000000.0,
          'achieve_date': '2026-12-31',
          'currency_code': 'VND',
          'completed': false,
        },
      ]);
      expect(result.goals.single.isArchived, isFalse);
    });

    test('achieve_date null → targetDate null, không crash', () {
      final result = parseRollySavingsGoals([
        {
          'id': 1,
          'title': 'Không hạn',
          'achieve_amount': 1000000.0,
          'achieve_date': null,
          'currency_code': 'VND',
          'completed': false,
        },
      ]);
      expect(result.goals.single.targetDate, isNull);
    });

    test(
      'currency_code khác VND → báo issue, bỏ qua, KHÔNG đoán currencyScale',
      () {
        final result = parseRollySavingsGoals([
          {
            'id': 1,
            'title': 'USD goal',
            'achieve_amount': 1000.0,
            'achieve_date': '2026-12-31',
            'currency_code': 'USD',
            'completed': false,
          },
        ]);
        expect(result.goals, isEmpty);
        expect(result.issues.single, contains('USD'));
      },
    );

    test('achieve_amount âm hoặc không nguyên → báo issue, bỏ qua', () {
      final result = parseRollySavingsGoals([
        {
          'id': 1,
          'title': 'Âm',
          'achieve_amount': -1000.0,
          'achieve_date': '2026-12-31',
          'currency_code': 'VND',
          'completed': false,
        },
        {
          'id': 2,
          'title': 'Lẻ',
          'achieve_amount': 1000.5,
          'achieve_date': '2026-12-31',
          'currency_code': 'VND',
          'completed': false,
        },
      ]);
      expect(result.goals, isEmpty);
      expect(result.issues, hasLength(2));
    });

    test('title rỗng/null → báo issue, bỏ qua', () {
      final result = parseRollySavingsGoals([
        {
          'id': 1,
          'title': '  ',
          'achieve_amount': 1000000.0,
          'achieve_date': '2026-12-31',
          'currency_code': 'VND',
          'completed': false,
        },
      ]);
      expect(result.goals, isEmpty);
      expect(result.issues, isNotEmpty);
    });
  });

  group('mapSavingsContributionSourceIds', () {
    test(
      '4 cặp Savings thật (input.json) → nhóm đúng 4 sourceId walletLeg vào goal 49755',
      () {
        // Đúng 8 dòng type=Savings quan sát thật trong raw_rolly/input.json —
        // 4 cặp, mỗi cặp một dòng walletLeg (wallet_id khác null,
        // linking_savings_id=49755) + một dòng ghép (wallet_id null,
        // linking_savings_id null).
        final map = mapSavingsContributionSourceIds([
          {
            'id': 12450889,
            'type': 'Savings',
            'wallet_id': 651423,
            'linking_savings_id': 49755,
          },
          {
            'id': 12450888,
            'type': 'Savings',
            'wallet_id': null,
            'linking_savings_id': null,
          },
          {
            'id': 13061034,
            'type': 'Savings',
            'wallet_id': 651423,
            'linking_savings_id': 49755,
          },
          {
            'id': 13061033,
            'type': 'Savings',
            'wallet_id': null,
            'linking_savings_id': null,
          },
          {
            'id': 13381944,
            'type': 'Savings',
            'wallet_id': 651423,
            'linking_savings_id': 49755,
          },
          {
            'id': 13381943,
            'type': 'Savings',
            'wallet_id': null,
            'linking_savings_id': null,
          },
          {
            'id': 11916359,
            'type': 'Savings',
            'wallet_id': 651423,
            'linking_savings_id': 49755,
          },
          {
            'id': 11916358,
            'type': 'Savings',
            'wallet_id': null,
            'linking_savings_id': null,
          },
          // Giao dịch Expense bình thường xen giữa — phải bị bỏ qua hoàn toàn.
          {
            'id': 99999,
            'type': 'Expense',
            'wallet_id': 651423,
            'linking_savings_id': null,
          },
        ]);

        expect(map.keys, [49755]);
        expect(
          map[49755],
          unorderedEquals([
            'rolly:12450889',
            'rolly:13061034',
            'rolly:13381944',
            'rolly:11916359',
          ]),
        );
      },
    );

    test('không có dòng Savings nào → map rỗng', () {
      final map = mapSavingsContributionSourceIds([
        {
          'id': 1,
          'type': 'Expense',
          'wallet_id': 1,
          'linking_savings_id': null,
        },
      ]);
      expect(map, isEmpty);
    });
  });
}
