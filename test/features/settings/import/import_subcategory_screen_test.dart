import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/money/money.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/transaction_repository.dart';
import 'package:tonyfino/features/settings/import/import_screen.dart';

import '../../../support/fake_file_picker.dart';
import '../../../support/open_test_database.dart';
import '../../../support/pump_app.dart';

void main() {
  late AppDatabase db;
  late FakeFilePicker filePicker;

  setUp(() {
    db = openTestDatabase();
    filePicker = installFakeFilePicker();
  });
  tearDown(() => db.close());

  Uint8List sampleSubcategoryFile() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'subcategory': [
          {'id': 30048, 'title': 'Gửi xe'},
        ],
        'input': [
          {'id': 200, 'subcategory_id': 30048},
        ],
      }),
    ),
  );

  testWidgets(
    'chọn file danh mục phụ → xem trước → xác nhận → giao dịch cũ được gán lại vào danh mục con mới, import lại thì idempotent',
    (tester) async {
      final categories = await db.select(db.categories).get();
      final parent = categories.first;
      final walletId = (await db.select(db.wallets).get()).first.id;
      final txRepo = TransactionRepository(db);
      final txId = (await txRepo.insert(
        amount: Money.vnd(-10000),
        occurredAt: DateTime(2026, 7, 1),
        walletId: walletId,
        categoryId: parent.id,
        sourceId: 'rolly:200',
      )).valueOrNull!;

      await pumpApp(tester, db: db, child: const ImportScreen());

      filePicker.nextFileBytes = sampleSubcategoryFile();
      // Mục "Danh mục phụ Rolly" nằm dưới mục tiết kiệm — ngoài viewport mặc
      // định của test, cùng gotcha `ListView` lazy-render đã gặp ở
      // `settings_screen_test.dart`.
      await tester.scrollUntilVisible(
        find.text('Chọn file JSON danh mục phụ Rolly'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // `scrollUntilVisible` dừng ngay khi finder khớp (chỉ cần MỘT pixel lọt
      // vào viewport), chưa chắc đã hit-test được ở tâm widget — `ensureVisible`
      // cuộn thêm cho chắc trước khi chạm.
      await tester.ensureVisible(
        find.text('Chọn file JSON danh mục phụ Rolly'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn file JSON danh mục phụ Rolly'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('1 giao dịch có thể khôi phục'),
        findsOneWidget,
      );

      await tester.tap(find.text('Xác nhận khôi phục 1 giao dịch'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã gán lại 1 giao dịch'), findsOneWidget);
      expect(
        find.textContaining('1 danh mục phụ mới được tạo'),
        findsOneWidget,
      );

      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      final subcategory = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(tx.categoryId!))).getSingle();
      expect(subcategory.name, 'Gửi xe');
      expect(subcategory.parentCategoryId, parent.id);

      // Import LẠI CHÍNH FILE ĐÓ → không tạo danh mục con trùng.
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      filePicker.nextFileBytes = sampleSubcategoryFile();
      await tester.scrollUntilVisible(
        find.text('Chọn file JSON danh mục phụ Rolly'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // `scrollUntilVisible` dừng ngay khi finder khớp (chỉ cần MỘT pixel lọt
      // vào viewport), chưa chắc đã hit-test được ở tâm widget — `ensureVisible`
      // cuộn thêm cho chắc trước khi chạm.
      await tester.ensureVisible(
        find.text('Chọn file JSON danh mục phụ Rolly'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn file JSON danh mục phụ Rolly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận khôi phục 1 giao dịch'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã gán lại 0 giao dịch'), findsOneWidget);
      expect(
        find.textContaining('1 giao dịch đã là danh mục con từ trước'),
        findsOneWidget,
      );

      // Lọc theo TÊN — `parent` (categories.first, "Ăn uống") từ Phase 22
      // addendum đã có sẵn 1 con mặc định ("Tiêu vặt") trước khi test này
      // chạy, nên không thể đếm MỌI con của `parent` nữa.
      final guiXeChildren =
          await (db.select(db.categories)..where(
                (c) =>
                    c.parentCategoryId.equals(parent.id) &
                    c.name.equals('Gửi xe'),
              ))
              .get();
      expect(guiXeChildren, hasLength(1));
    },
  );
}
