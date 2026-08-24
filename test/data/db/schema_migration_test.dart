// Test migration/schema cho Phase 4.
//
// `dart run drift_dev make-migrations` (đã xác nhận chạy được — xem
// docs/decisions.md: phải pin `drift: 2.34.0` chính xác cùng patch với
// `drift_dev: 2.34.0`, vì cặp lệch patch — drift 2.34.1+ với drift_dev
// 2.34.0 — làm chính CLI biên dịch lỗi ở `verifier_common.dart`, không
// chạy được subcommand nào) chỉ sinh ra
// `drift_schemas/app_database/drift_schema_v1.json` cho lần chạy đầu — CLI
// chỉ sinh step file + test so sánh v(N-1)→vN khi có phiên bản TRƯỚC đó để
// diff. Ở v1 chưa có "N-1", nên bài test dưới đây tự làm việc tương đương:
// xác nhận schema LIVE (từ `MigrationStrategy.onCreate`) khớp đúng với
// snapshot JSON đã commit — nếu ai đổi `tables.dart` mà quên bump
// `schemaVersion` + chạy lại `make-migrations`, test này đỏ ngay.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/open_test_database.dart';

void main() {
  test('schemaVersion khớp file snapshot đã commit trong drift_schemas/', () {
    final db = openTestDatabase();
    addTearDown(db.close);

    final snapshotFile = File(
      'drift_schemas/app_database/drift_schema_v${db.schemaVersion}.json',
    );
    expect(
      snapshotFile.existsSync(),
      isTrue,
      reason:
          'Thiếu drift_schemas/app_database/drift_schema_v${db.schemaVersion}.json — '
          'chạy `dart run drift_dev make-migrations` và commit lại.',
    );
  });

  test('onCreate tạo đúng tập bảng + cột như snapshot đã commit', () async {
    final db = openTestDatabase();
    addTearDown(db.close);

    // Chạm một câu SELECT bất kỳ để buộc drift chạy MigrationStrategy.onCreate.
    await db.select(db.appEvents).get();

    final snapshot =
        jsonDecode(
              File(
                'drift_schemas/app_database/drift_schema_v${db.schemaVersion}.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final expectedTables = <String, Set<String>>{
      for (final entity
          in (snapshot['entities'] as List).cast<Map<String, Object?>>())
        if (entity['type'] == 'table')
          (entity['data'] as Map<String, Object?>)['name'] as String: {
            for (final col
                in ((entity['data'] as Map<String, Object?>)['columns'] as List)
                    .cast<Map<String, Object?>>())
              col['name'] as String,
          },
    };

    for (final MapEntry(key: tableName, value: expectedColumns)
        in expectedTables.entries) {
      final rows = await db.customSelect('PRAGMA table_info($tableName)').get();
      expect(
        rows,
        isNotEmpty,
        reason:
            'Bảng "$tableName" có trong snapshot nhưng không tồn tại trong DB thật.',
      );
      final actualColumns = rows.map((r) => r.data['name'] as String).toSet();
      expect(
        actualColumns,
        expectedColumns,
        reason: 'Cột của bảng "$tableName" lệch khỏi snapshot đã commit.',
      );
    }
  });

  test('seed: đúng 12 danh mục gốc + 1 danh mục con mặc định ("Tiêu vặt" dưới '
      '"Ăn uống", Phase 22 addendum) + khoảng 300 từ khoá', () async {
    final db = openTestDatabase();
    addTearDown(db.close);

    final categories = await db.select(db.categories).get();
    final keywords = await db.select(db.categoryKeywords).get();

    expect(categories, hasLength(13));
    final anUong = categories.singleWhere((c) => c.name == 'Ăn uống');
    final tieuVat = categories.singleWhere((c) => c.name == 'Tiêu vặt');
    expect(tieuVat.parentCategoryId, anUong.id);
    expect(keywords.length, greaterThanOrEqualTo(250));
    // Mỗi từ khoá phải gắn được với một categoryId có thật (FK không mồ côi).
    final categoryIds = categories.map((c) => c.id).toSet();
    expect(keywords.every((k) => categoryIds.contains(k.categoryId)), isTrue);
  });
}
