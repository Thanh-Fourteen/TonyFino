import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/budgets/domain/budget_pace.dart';

void main() {
  group('computeBudgetPaceState', () {
    test(
      '🔥 ví dụ trong đặc tả: 60% ở ngày 10/30 (pace 33%) → TRÊN NHỊP (tệ)',
      () {
        final state = computeBudgetPaceState(
          progressFraction: 0.6,
          paceFraction: 10 / 30,
        );
        expect(state, BudgetPaceState.trendingOver);
      },
    );

    test(
      '🔥 ví dụ trong đặc tả: 60% ở ngày 25/30 (pace 83%) → ĐÚNG NHỊP (tốt)',
      () {
        final state = computeBudgetPaceState(
          progressFraction: 0.6,
          paceFraction: 25 / 30,
        );
        expect(state, BudgetPaceState.onTrack);
      },
    );

    test(
      'đã chi đúng bằng pace → vẫn coi là đúng nhịp (biên không nghiêng về cảnh báo)',
      () {
        final state = computeBudgetPaceState(
          progressFraction: 0.5,
          paceFraction: 0.5,
        );
        expect(state, BudgetPaceState.onTrack);
      },
    );

    test(
      'progress >= 1.0 luôn là "đã vượt", bất kể pace (kể cả mới đầu tháng)',
      () {
        expect(
          computeBudgetPaceState(progressFraction: 1.0, paceFraction: 0.05),
          BudgetPaceState.over,
        );
        expect(
          computeBudgetPaceState(progressFraction: 1.5, paceFraction: 0.9),
          BudgetPaceState.over,
        );
      },
    );

    test('progress 0, pace 0 (đầu kỳ, chưa chi gì) → đúng nhịp', () {
      expect(
        computeBudgetPaceState(progressFraction: 0, paceFraction: 0),
        BudgetPaceState.onTrack,
      );
    });
  });
}
