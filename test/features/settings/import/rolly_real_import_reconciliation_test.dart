import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_json_parser.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_reconciliation.dart';

/// XÁC MINH QUAN TRỌNG NHẤT của Phase 9 (yêu cầu tường minh trong prompt):
/// import file THẬT của Tony (`raw_rolly/input.json`, gitignored, không có
/// trên máy khác/CI) → báo cáo đối chiếu (tổng Chi/Thu từng tháng) phải khớp
/// CHÍNH XÁC oracle đã ghi ở `docs/rolly-schema.md` § Phase 2 (chính oracle
/// đó đã được đối chiếu chéo với `wallet_view` của Rolly — hai nguồn độc lập
/// trùng khớp). Test SKIP (không fail) nếu `raw_rolly/` không tồn tại — đúng
/// với các checkout khác không có dữ liệu thật của Tony.
void main() {
  final inputFile = File('raw_rolly/input.json');
  final categoryFile = File('raw_rolly/category_view.json');

  test(
    'import raw_rolly/input.json thật → đối chiếu KHỚP CHÍNH XÁC oracle docs/rolly-schema.md',
    () {
      if (!inputFile.existsSync()) {
        markTestSkipped(
          'raw_rolly/input.json không tồn tại trên máy này — bỏ qua.',
        );
        return;
      }

      final rawRows = jsonDecode(inputFile.readAsStringSync()) as List<dynamic>;
      final categoryTitleById = <int, String>{};
      if (categoryFile.existsSync()) {
        final rows =
            jsonDecode(categoryFile.readAsStringSync()) as List<dynamic>;
        for (final row in rows.cast<Map<String, dynamic>>()) {
          categoryTitleById[row['id'] as int] = row['title'] as String;
        }
      }

      final parseResult = parseRollyInputRows(
        rawRows,
        categoryTitleById: categoryTitleById,
      );

      // Không dòng nào bị bỏ qua vì bất thường — 362 bản ghi thật đều sạch
      // (đã xác nhận ở Phase 2, xem docs/rolly-schema.md).
      expect(
        parseResult.issues,
        isEmpty,
        reason: 'Có dòng bất thường không mong đợi: ${parseResult.issues}',
      );

      // 354 Expense/Income (không đổi) + 4 Savings đã khử trùng lặp (8 dòng
      // gốc → 4 cặp) = 358, KHÔNG phải 362 — đúng như bảng ánh xạ field đã
      // ghi trước khi code (docs/decisions.md § Phase 9).
      expect(parseResult.rows, hasLength(358));

      final report = computeRollyReconciliation(parseResult.rows);
      expect(report.savingsTransferCount, 4);

      // Oracle docs/rolly-schema.md § "Oracle nghiệm thu" — đã đối chiếu
      // chéo với wallet_view của chính Rolly, hai nguồn độc lập trùng khớp.
      expect(report.totalExpenseMinor, -51449000);
      expect(report.totalIncomeMinor, 97280000);

      final byMonth = {for (final m in report.months) m.yearMonth: m};
      void expectMonth(String ym, int expenseMinor, int incomeMinor) {
        final m = byMonth[ym];
        expect(m, isNotNull, reason: 'Thiếu tháng $ym trong báo cáo.');
        expect(
          m!.expenseMinor,
          expenseMinor,
          reason: 'Chi tháng $ym lệch oracle.',
        );
        expect(
          m.incomeMinor,
          incomeMinor,
          reason: 'Thu tháng $ym lệch oracle.',
        );
      }

      expectMonth('2026-05', -18803000, 21428000);
      expectMonth('2026-06', -15396000, 20637000);
      expectMonth('2026-07', -8891000, 25682000);
      expectMonth('2026-08', -8359000, 29533000);
    },
  );
}
