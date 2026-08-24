import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/settings/import/import_screen.dart';
import 'package:tonyfino/ui/app_card.dart';

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

  Uint8List sampleRollyFile() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'input': [
          {
            'id': 1,
            'type': 'Expense',
            'amount': 35000.0,
            'date': '2026-05-10',
            'item': 'cà phê',
            'category_id': 1,
          },
          {
            'id': 2,
            'type': 'Expense',
            'amount': 20000.0,
            'date': '2026-05-11',
            'item': 'lạ',
            'category_id': 2,
          },
          {
            'id': 3,
            'type': 'Income',
            'amount': 15000000.0,
            'date': '2026-05-01',
            'item': 'lương',
            'category_id': 3,
          },
        ],
        'category_view': [
          {'id': 1, 'title': 'Ăn uống'},
          {'id': 2, 'title': 'Thức ăn lạ'},
          {'id': 3, 'title': 'Lương'},
        ],
      }),
    ),
  );

  Future<void> pickFile(WidgetTester tester) async {
    filePicker.nextFileBytes = sampleRollyFile();
    await tester.tap(find.text('Chọn file JSON Rolly'));
    await tester.pumpAndSettle();
  }

  Future<void> resolveThucAnLa(WidgetTester tester) async {
    // Thẻ ánh xạ giờ là Column (tên trên, dropdown dưới) — neo theo AppCard
    // thay vì Row, vốn đã biến mất khi đổi bố cục.
    final card = find.ancestor(
      of: find.textContaining('Thức ăn lạ'),
      matching: find.byType(AppCard),
    );
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byWidgetPredicate((w) => w is DropdownButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'chọn file → 1 danh mục không map được BẮT phải chọn → dry-run → commit → đúng số giao dịch, import lại thì idempotent',
    (tester) async {
      await pumpApp(tester, db: db, child: const ImportScreen());

      await pickFile(tester);

      // "Ăn uống" và "Lương" tự gợi ý (trùng tên tuyệt đối), "Thức ăn lạ"
      // thì KHÔNG — 2/3 đã chọn, nút "Tiếp tục" phải bị khoá.
      expect(find.textContaining('2/3 đã chọn'), findsOneWidget);
      final continueButton = find.widgetWithText(
        FilledButton,
        'Tiếp tục → xem trước',
      );
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

      await resolveThucAnLa(tester);

      expect(find.textContaining('3/3 đã chọn'), findsOneWidget);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);

      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Màn xem trước → dry-run.
      await tester.tap(find.text('Xem trước (dry-run)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 giao dịch MỚI'), findsOneWidget);
      expect(find.textContaining('0 đã có sẵn'), findsOneWidget);
      // Báo cáo đối chiếu: 35k + 20k Chi, 15tr Thu, đúng tháng 2026-05.
      expect(find.textContaining('2026-05'), findsOneWidget);

      await tester.tap(find.text('Xác nhận nhập 3 giao dịch'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã nhập 3 giao dịch mới'), findsOneWidget);

      final saved = await db.select(db.transactions).get();
      expect(saved, hasLength(3));
      final byAmount = {for (final t in saved) t.amountMinor: t};
      expect(byAmount[-35000]!.sourceId, 'rolly:1');
      expect(byAmount[-20000]!.sourceId, 'rolly:2');
      expect(byAmount[15000000]!.sourceId, 'rolly:3');

      // Xong màn → về Idle, thử import LẠI CHÍNH FILE ĐÓ → idempotent.
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      await pickFile(tester);
      // Gợi ý tự động luôn tính lại từ đầu bằng tên chuẩn hoá (không "học"
      // từ lần chọn trước) — "Thức ăn lạ" vẫn cần chọn tay y hệt lần trước.
      await resolveThucAnLa(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Tiếp tục → xem trước'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem trước (dry-run)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('0 giao dịch MỚI'), findsOneWidget);
      expect(find.textContaining('3 đã có sẵn'), findsOneWidget);
      // Nút xác nhận bị khoá khi không có gì mới — không tạo bản ghi trùng.
      expect(find.text('Không có gì mới để nhập'), findsOneWidget);
      expect(await db.select(db.transactions).get(), hasLength(3));
    },
  );

  testWidgets(
    'danh mục Rolly không trùng tên nào có sẵn → chọn "Tạo mới" thì danh mục '
    'MỚI được tạo thật và giao dịch gắn vào đó, KHÔNG rơi vào Chưa phân loại',
    (tester) async {
      // Đúng ca thật đã làm Tony mất dữ liệu: "Giặt đồ" là danh mục cấp 1 ở
      // Rolly (8 giao dịch trong `raw_rolly`) nhưng TonyFino không có danh
      // mục nào tên như vậy, mà màn ánh xạ trước đây chỉ cho chọn danh mục
      // CÓ SẴN hoặc "Chưa phân loại".
      await pumpApp(tester, db: db, child: const ImportScreen());

      filePicker.nextFileBytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'input': [
              {
                'id': 10,
                'type': 'Expense',
                'amount': 45000.0,
                'date': '2026-05-11',
                'item': 'giặt đồ',
                'category_id': 7264057,
              },
              {
                'id': 11,
                'type': 'Expense',
                'amount': 120000.0,
                'date': '2026-08-17',
                'item': 'giặt đồ',
                'category_id': 7264057,
              },
            ],
            'category_view': [
              {'id': 7264057, 'title': 'Giặt đồ'},
            ],
          }),
        ),
      );
      await tester.tap(find.text('Chọn file JSON Rolly'));
      await tester.pumpAndSettle();

      final before = await db.select(db.categories).get();
      expect(
        before.where((c) => c.name == 'Giặt đồ'),
        isEmpty,
        reason: 'tiền đề: TonyFino chưa có danh mục "Giặt đồ"',
      );

      final card = find.ancestor(
        of: find.textContaining('Giặt đồ'),
        matching: find.byType(AppCard),
      );
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.byWidgetPredicate((w) => w is DropdownButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('➕ Tạo mới "Giặt đồ"').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Tiếp tục → xem trước'),
      );
      await tester.pumpAndSettle();

      // Danh mục phải được tạo NGAY ở bước xác nhận ánh xạ, không đợi commit
      // — dry-run là chỗ Tony đối chiếu, hiện sai ở đó là hỏng van an toàn.
      final created = (await db.select(db.categories).get())
          .where((c) => c.name == 'Giặt đồ')
          .toList();
      expect(created, hasLength(1));
      expect(created.single.kind, 'expense');

      await tester.tap(find.text('Xem trước (dry-run)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận nhập 2 giao dịch'));
      await tester.pumpAndSettle();

      final saved = await db.select(db.transactions).get();
      expect(saved, hasLength(2));
      expect(
        saved.every((t) => t.categoryId == created.single.id),
        isTrue,
        reason: 'cả 2 giao dịch phải nằm trong danh mục "Giặt đồ" mới tạo',
      );
    },
  );

  testWidgets(
    'tạo NHIỀU danh mục trong cùng một lần import → mỗi cái một màu khác '
    'nhau, không dồn hết về một màu',
    (tester) async {
      // Diễn tập trên emulator với 358 giao dịch thật cho thấy: import thật
      // tạo 5-6 danh mục một lượt, nếu tất cả cùng `categoryColorId` thì
      // biểu đồ tròn ở màn Báo cáo thành một mảng xám không đọc được lát nào
      // là lát nào. Test này khoá tính chất "mỗi danh mục mới một màu".
      await pumpApp(tester, db: db, child: const ImportScreen());

      final names = ['Giặt đồ', 'Thực phẩm', 'Tiền nhà'];
      filePicker.nextFileBytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'input': [
              for (var i = 0; i < names.length; i++)
                {
                  'id': 100 + i,
                  'type': 'Expense',
                  'amount': 50000.0,
                  'date': '2026-05-1${i + 1}',
                  'item': names[i],
                  'category_id': 900 + i,
                },
            ],
            'category_view': [
              for (var i = 0; i < names.length; i++)
                {'id': 900 + i, 'title': names[i]},
            ],
          }),
        ),
      );
      await tester.tap(find.text('Chọn file JSON Rolly'));
      await tester.pumpAndSettle();

      for (final name in names) {
        final card = find.ancestor(
          of: find.textContaining('$name (1 giao dịch)'),
          matching: find.byType(AppCard),
        );
        await tester.tap(
          find.descendant(
            of: card,
            matching: find.byWidgetPredicate((w) => w is DropdownButton),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('➕ Tạo mới "$name"').last);
        await tester.pumpAndSettle();
      }

      await tester.tap(
        find.widgetWithText(FilledButton, 'Tiếp tục → xem trước'),
      );
      await tester.pumpAndSettle();

      final created = (await db.select(db.categories).get())
          .where((c) => names.contains(c.name))
          .toList();
      expect(created, hasLength(names.length));
      expect(
        created.map((c) => c.categoryColorId).toSet(),
        hasLength(names.length),
        reason: 'mỗi danh mục mới phải nhận một màu riêng',
      );
    },
  );

  testWidgets(
    'file gộp đủ 4 mảng → commit xong TỰ chạy nốt backfill danh mục phụ + '
    'tiết kiệm, không bắt chọn lại file thêm hai lần',
    (tester) async {
      await pumpApp(tester, db: db, child: const ImportScreen());

      filePicker.nextFileBytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'input': [
              {
                'id': 1,
                'type': 'Expense',
                'amount': 35000.0,
                'date': '2026-05-10',
                'item': 'cà phê',
                'category_id': 1,
                'subcategory_id': 70,
              },
            ],
            'category_view': [
              {'id': 1, 'title': 'Ăn uống'},
            ],
            'subcategory': [
              {'id': 70, 'title': 'Tiêu vặt', 'category_id': 1},
            ],
            'savings': <Map<String, Object?>>[],
          }),
        ),
      );
      await tester.tap(find.text('Chọn file JSON Rolly'));
      await tester.pumpAndSettle();

      // "Ăn uống" trùng tên tuyệt đối nên tự gợi ý — đi thẳng tới commit.
      await tester.tap(
        find.widgetWithText(FilledButton, 'Tiếp tục → xem trước'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem trước (dry-run)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận nhập 1 giao dịch'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã nhập 1 giao dịch mới'), findsOneWidget);
      // Bước danh mục phụ đã tự chạy: báo cáo hiện ngay trên màn xong.
      expect(find.textContaining('Danh mục phụ:'), findsOneWidget);

      // Và ghi thật: giao dịch được chuyển sang danh mục CON "Tiêu vặt".
      final categories = await db.select(db.categories).get();
      final sub = categories.where((c) => c.name == 'Tiêu vặt').toList();
      expect(sub, hasLength(1));
      expect(sub.single.parentCategoryId, isNotNull);
      final saved = await db.select(db.transactions).get();
      expect(saved.single.categoryId, sub.single.id);
    },
  );
}
