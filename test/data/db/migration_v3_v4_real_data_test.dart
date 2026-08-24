// XÁC MINH QUAN TRỌNG NHẤT của Phase 13 (yêu cầu tường minh trong prompt):
// chạy migration 3→4 trên BẢN SAO dữ liệu THẬT (358 giao dịch Rolly đã import
// từ Phase 9), không chỉ fixture nhỏ. Dùng `raw_rolly/input.json` (gitignored,
// không có trên máy khác/CI — SKIP chứ không fail, cùng quy ước với
// `reports_performance_real_data_test.dart` Phase 10 và
// `rolly_real_import_reconciliation_test.dart` Phase 9), qua parser thật của
// Phase 9, KHÔNG bịa dữ liệu giả lập hay hard-code số dòng kỳ vọng — bất kể
// N dòng thật là bao nhiêu, bất biến cần giữ là: N không đổi, SUM(amountMinor)
// không đổi, 100% walletId khác NULL trỏ đúng "Ví mặc định".
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_json_parser.dart';
import 'package:tonyfino/features/settings/import/domain/staged_transaction.dart';

import 'generated/app_database/generated/schema.dart';
import 'generated/app_database/generated/schema_v3.dart' as v3;
import 'generated/app_database/generated/schema_v4.dart' as v4;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final inputFile = File('raw_rolly/input.json');

  test(
    'migration v3→v4 trên bản sao dữ liệu THẬT: không mất/trùng giao dịch, '
    'SUM(amountMinor) khớp tuyệt đối, 100% walletId backfill vào Ví mặc định',
    () async {
      if (!inputFile.existsSync()) {
        markTestSkipped(
          'raw_rolly/input.json không tồn tại trên máy này — bỏ qua.',
        );
        return;
      }

      final rawRows = jsonDecode(inputFile.readAsStringSync()) as List<dynamic>;
      final parseResult = parseRollyInputRows(rawRows);
      final rows = parseResult.rows
          .where((r) => r.sourceType != RollySourceType.savingsTransfer)
          .toList();
      expect(
        rows,
        isNotEmpty,
        reason: 'raw_rolly/input.json phải có giao dịch thật để đo',
      );

      final expectedSum = rows.fold<int>(0, (sum, r) => sum + r.amountMinor);
      final verifier = SchemaVerifier(GeneratedHelper());

      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 4,
        createOld: v3.DatabaseAtV3.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.transactions, [
            for (final r in rows)
              v3.TransactionsCompanion.insert(
                amountMinor: r.amountMinor,
                currency: 'VND',
                currencyScale: 0,
                // Schema các phiên bản cũ lưu `occurredAt` dạng epoch giây
                // thô (`int`), không phải `DateTime` — khác companion HIỆN
                // TẠI (`TransactionsCompanion` ở `database.dart`, dùng
                // `DateTimeConverter` tự quy đổi). Companion sinh ra cho một
                // snapshot v3 cũ phản ánh đúng hình dạng cột lúc đó.
                occurredAt: r.occurredAt.millisecondsSinceEpoch ~/ 1000,
                note: Value(r.note),
                sourceId: Value(r.sourceId),
              ),
          ]);
        },
        validateItems: (newDb) async {
          final wallets = await newDb.select(newDb.wallets).get();
          expect(
            wallets,
            hasLength(1),
            reason: 'Migration phải tạo đúng MỘT "Ví mặc định"',
          );
          final defaultWalletId = wallets.single.id;

          final transactions = await newDb.select(newDb.transactions).get();
          expect(
            transactions,
            hasLength(rows.length),
            reason: 'Không được mất hoặc thêm thừa giao dịch nào qua migration',
          );

          final actualSum = transactions.fold<int>(
            0,
            (sum, t) => sum + t.amountMinor,
          );
          expect(
            actualSum,
            expectedSum,
            reason: 'SUM(amountMinor) phải khớp tuyệt đối trước/sau',
          );

          expect(
            transactions.every((t) => t.walletId == defaultWalletId),
            isTrue,
            reason:
                '100% giao dịch cũ phải trỏ đúng vào "Ví mặc định" vừa tạo, không dòng nào null/lệch',
          );
          // `v4.TransactionsData` là kiểu SNAPSHOT thô (giống `occurredAt`
          // là `int` epoch chứ không phải `DateTime` ở các bản snapshot cũ
          // trong `migration_test.dart`) — cột `BoolColumn` lưu dạng `int`
          // 0/1, không phải `bool`, nên so với `0` chứ không phải `false`.
          expect(
            transactions.every((t) => t.isTransfer == 0),
            isTrue,
            reason:
                'Giao dịch cũ backfill không được tự trở thành "chuyển khoản"',
          );
        },
      );
    },
  );
}
