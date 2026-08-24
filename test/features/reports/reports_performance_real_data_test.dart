// XÁC MINH HIỆU NĂNG của Phase 10 (yêu cầu tường minh trong prompt): "báo
// cáo render dưới 500ms với dữ liệu THẬT đã import, không phải dữ liệu mẫu".
// Dùng chính `raw_rolly/input.json` (gitignored, không có trên máy khác/CI —
// SKIP chứ không fail, cùng quy ước với `rolly_real_import_reconciliation_test.dart`
// ở Phase 9) qua parser thật của Phase 9, KHÔNG bịa dữ liệu giả lập.
//
// Đo trên host (`flutter test`), không phải trên thiết bị thật — máy dev
// nhanh hơn Redmi Note 13 Pro nhiều, nên đây là ngưỡng SÀN cho biết SQL
// aggregation không suy biến theo khối lượng thật, KHÔNG thay thế cho quan
// sát trực tiếp trên emulator/dogfood APK (H5/H7, TODOS.md) — mục đó vẫn làm
// riêng, ghi lại trong docs/decisions.md § Phase 10.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/reports_repository.dart';
import 'package:tonyfino/features/reports/domain/category_slice.dart';
import 'package:tonyfino/features/reports/domain/daily_spend.dart';
import 'package:tonyfino/features/reports/domain/report_range.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_json_parser.dart';
import 'package:tonyfino/features/settings/import/domain/staged_transaction.dart';

import '../../support/open_test_database.dart';

void main() {
  final inputFile = File('raw_rolly/input.json');

  test(
    '4 truy vấn báo cáo + gộp domain cộng lại dưới 500ms với ~360 giao dịch THẬT',
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

      final db = openTestDatabase();
      addTearDown(db.close);
      final categoryId = (await db.select(db.categories).get()).first.id;
      final walletId = (await db.select(db.wallets).get()).first.id;

      await db.batch((batch) {
        batch.insertAll(db.transactions, [
          for (var i = 0; i < rows.length; i++)
            TransactionsCompanion.insert(
              amountMinor: rows[i].amountMinor,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: rows[i].occurredAt,
              walletId: walletId,
              // Xen kẽ có/không danh mục — gần thực tế hơn "toàn bộ null", vẫn
              // đủ để exercise nhánh JOIN + gộp "chưa phân loại" trong
              // watchCategoryBreakdown.
              categoryId: Value(i.isEven ? categoryId : null),
            ),
        ]);
      });

      final repo = ReportsRepository(db);
      final range = ReportRange.preset(
        ReportRangePreset.allTime,
        DateTime(2027),
      );

      final stopwatch = Stopwatch()..start();

      final breakdown = await repo.watchCategoryBreakdown(range).first;
      final monthly = await repo.watchMonthlyTrend(range).first;
      final daily = await repo.watchDailySpend(range).first;
      final summary = await repo.watchPeriodSummary(range).first;

      // Xử lý domain THUẦN Dart phía sau truy vấn — cũng phải tính vào ngân
      // sách 500ms vì đây là những gì thật sự chạy trước khi widget vẽ khung
      // hình đầu (Luật hiệu năng Phase 10: không lặp Dart trên SỔ CÁI, nhưng
      // gộp lát bánh/lưới heatmap chỉ chạy trên kết quả ĐÃ GỘP SQL — nhỏ, rẻ).
      buildCategorySlices(breakdown);
      buildHeatmapWeeks(daily, rangeStart: range.start, rangeEnd: range.end);

      stopwatch.stop();

      // ignore: avoid_print
      print(
        'reports perf: ${rows.length} giao dịch thật · '
        '${monthly.length} tháng · ${daily.length} ngày có chi · '
        '${stopwatch.elapsedMilliseconds}ms',
      );

      expect(summary.transactionCount, rows.length);
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    },
  );
}
