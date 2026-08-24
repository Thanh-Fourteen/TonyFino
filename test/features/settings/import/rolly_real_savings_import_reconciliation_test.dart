import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_savings_parser.dart';

/// Xác minh Phase 19 bằng dữ liệu THẬT (`raw_rolly/savings_with_total.json`
/// + `raw_rolly/input.json`, gitignored) — không có oracle độc lập kiểu
/// `wallet_view` cho tiết kiệm, nhưng `savings_with_total.json.total_amount`
/// (tự Rolly tính) đóng vai trò oracle: SUM 4 giao dịch walletLeg tìm được
/// từ `input.json` PHẢI khớp chính xác con số đó. Test SKIP nếu file không
/// tồn tại (checkout khác không có dữ liệu thật của Tony).
void main() {
  final savingsFile = File('raw_rolly/savings_with_total.json');
  final inputFile = File('raw_rolly/input.json');

  test(
    'import raw_rolly/savings_with_total.json thật → 1 mục tiêu "CCTG", 4 giao dịch đóng góp khớp total_amount oracle',
    () {
      if (!savingsFile.existsSync() || !inputFile.existsSync()) {
        markTestSkipped('raw_rolly/ không tồn tại trên máy này — bỏ qua.');
        return;
      }

      final savingsRows =
          jsonDecode(savingsFile.readAsStringSync()) as List<dynamic>;
      final inputRows =
          jsonDecode(inputFile.readAsStringSync()) as List<dynamic>;

      final parseResult = parseRollySavingsGoals(savingsRows);
      expect(parseResult.issues, isEmpty);
      expect(parseResult.goals, hasLength(1));

      final goal = parseResult.goals.single;
      expect(goal.name, 'CCTG');
      expect(goal.targetAmountMinor, 30000000);
      expect(goal.isArchived, isTrue);
      expect(goal.totalContributedMinor, 43200000);

      final contributionMap = mapSavingsContributionSourceIds(inputRows);
      final sourceIds = contributionMap[goal.rollyGoalId];
      expect(sourceIds, isNotNull);
      expect(sourceIds, hasLength(4));

      // Tổng amount CHÍNH XÁC của 4 dòng walletLeg tìm được trong input.json
      // (đọc trực tiếp, KHÔNG qua import) phải khớp oracle total_amount.
      final idsWanted = sourceIds!
          .map((s) => int.parse(s.split(':')[1]))
          .toSet();
      final matchedRows = inputRows.cast<Map<String, dynamic>>().where(
        (r) => idsWanted.contains(r['id'] as int),
      );
      final sum = matchedRows.fold<num>(
        0,
        (acc, r) => acc + (r['amount'] as num),
      );
      expect(sum.round(), goal.totalContributedMinor);
    },
  );
}
