import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_reconciliation.dart';
import 'package:tonyfino/features/settings/import/domain/staged_transaction.dart';

StagedRollyTransaction _row({
  required String id,
  required int amountMinor,
  required DateTime date,
  required RollySourceType type,
}) => StagedRollyTransaction(
  sourceId: id,
  amountMinor: amountMinor,
  occurredAt: date,
  note: null,
  sourceType: type,
  categoryBucket: type == RollySourceType.savingsTransfer
      ? const CategoryBucketKey.savingsTransfer()
      : const CategoryBucketKey.uncategorized(),
);

void main() {
  test(
    'gộp Chi/Thu theo tháng, LOẠI Savings hoàn toàn — đúng định nghĩa oracle Phase 2',
    () {
      final rows = [
        _row(
          id: 'a',
          amountMinor: -35000,
          date: DateTime(2026, 5, 10),
          type: RollySourceType.expense,
        ),
        _row(
          id: 'b',
          amountMinor: -120000,
          date: DateTime(2026, 5, 11),
          type: RollySourceType.expense,
        ),
        _row(
          id: 'c',
          amountMinor: 15000000,
          date: DateTime(2026, 5, 1),
          type: RollySourceType.income,
        ),
        _row(
          id: 'd',
          amountMinor: -5000000,
          date: DateTime(2026, 6, 1),
          type: RollySourceType.savingsTransfer,
        ),
        _row(
          id: 'e',
          amountMinor: -5000,
          date: DateTime(2026, 6, 15),
          type: RollySourceType.expense,
        ),
      ];

      final report = computeRollyReconciliation(rows);

      expect(report.months, hasLength(2));
      final may = report.months.firstWhere((m) => m.yearMonth == '2026-05');
      expect(may.transactionCount, 3);
      expect(may.expenseMinor, -155000);
      expect(may.incomeMinor, 15000000);

      final june = report.months.firstWhere((m) => m.yearMonth == '2026-06');
      // Savings (dòng "d") KHÔNG được tính vào tháng 6 — chỉ dòng "e".
      expect(june.transactionCount, 1);
      expect(june.expenseMinor, -5000);
      expect(june.incomeMinor, 0);

      expect(report.totalTransactionCount, 4);
      expect(report.totalExpenseMinor, -160000);
      expect(report.totalIncomeMinor, 15000000);
      expect(report.savingsTransferCount, 1);
    },
  );

  test('rỗng thì báo cáo rỗng, không lỗi', () {
    final report = computeRollyReconciliation(const []);
    expect(report.months, isEmpty);
    expect(report.totalTransactionCount, 0);
    expect(report.savingsTransferCount, 0);
  });
}
