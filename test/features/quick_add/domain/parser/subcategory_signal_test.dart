// 🚨 Gõ "hủ tíu trưa 30k" phải vào ĐÚNG danh mục con, không dừng ở cha.
//
// Bug thật Tony bắt được trên máy: câu đã nói rõ "trưa" mà thẻ vẫn chỉ ra
// danh mục cha "Ăn uống", và danh mục con "Ăn trưa" không cách nào được
// chọn tự động. Hai nguyên nhân, cùng chữa ở bản này:
//  * `category_matcher` argmax PHẲNG → cha luôn đè con vì từ khoá món ăn
//    dài hơn (nay chấm điểm theo NHÁNH, xem `category_matcher.dart`);
//  * không có gì nối chữ "trưa" trong câu với danh mục con tên "Ăn trưa"
//    (nay `categoryKeywordEntriesProvider` sinh tín hiệu buổi từ chính tên
//    danh mục con).
//
// Test chạy qua CÂY SẢN XUẤT THẬT (`QuickAddScreen` + DB thật) chứ không
// gọi thẳng matcher — chính chỗ nối dây giữa provider và parser mới là chỗ
// đã hỏng.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/quick_add/quick_add_screen.dart';

import '../../../../support/fake_shared_preferences.dart';
import '../../../../support/open_test_database.dart';
import '../../../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<int> insertSubcategory(String name, String parentName) async {
    final all = await db.select(db.categories).get();
    final parent = all.firstWhere((c) => c.name == parentName);
    return db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            kind: parent.kind,
            categoryColorId: parent.categoryColorId,
            iconCode: parent.iconCode,
            walletId: parent.walletId,
            parentCategoryId: Value(parent.id),
          ),
        );
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
  }

  testWidgets('🚨 "hủ tíu trưa 30k" → Ăn uống › Ăn trưa, không dừng ở cha', (
    tester,
  ) async {
    await insertSubcategory('Ăn trưa', 'Ăn uống');

    await pumpApp(tester, db: db, child: const QuickAddScreen());
    await tester.pumpAndSettle();
    await send(tester, 'hủ tíu trưa 30k');

    expect(find.textContaining('Ăn trưa'), findsWidgets);
  });

  testWidgets('không có chữ chỉ buổi → vẫn là danh mục CHA', (tester) async {
    await insertSubcategory('Ăn trưa', 'Ăn uống');

    await pumpApp(tester, db: db, child: const QuickAddScreen());
    await tester.pumpAndSettle();
    await send(tester, 'hủ tíu 30k');

    expect(find.textContaining('Ăn uống'), findsWidgets);
    expect(find.textContaining('Ăn trưa'), findsNothing);
  });

  testWidgets('chữ chỉ buổi KHÔNG kéo được câu sang nhánh khác', (
    tester,
  ) async {
    await insertSubcategory('Ăn trưa', 'Ăn uống');

    await pumpApp(tester, db: db, child: const QuickAddScreen());
    await tester.pumpAndSettle();
    // "gửi xe" là từ khoá seed mạnh của Di chuyển — "trưa" chỉ được phép
    // chọn con TRONG nhánh đã thắng, không được lôi cả câu sang bữa ăn.
    await send(tester, 'gửi xe trưa 5k');

    expect(find.textContaining('Di chuyển'), findsWidgets);
    expect(find.textContaining('Ăn trưa'), findsNothing);
  });

  testWidgets('🚨 "trưa nay" (cụm NGÀY) cũng phải xuống được danh mục con', (
    tester,
  ) async {
    // `findDate` cắt "trưa nay" khỏi token trước khi bộ khớp nhìn thấy —
    // nếu không nối lại nhãn buổi thì cùng một ý lại ra hai kết quả khác
    // nhau tuỳ người dùng có gõ thêm chữ "nay" hay không.
    await insertSubcategory('Ăn trưa', 'Ăn uống');

    await pumpApp(tester, db: db, child: const QuickAddScreen());
    await tester.pumpAndSettle();
    await send(tester, 'hủ tíu trưa nay 30k');

    expect(find.textContaining('Ăn trưa'), findsWidgets);
  });

  testWidgets('tên con THẬT của Tony: "Ăn trưa thiết yếu" cũng khớp', (
    tester,
  ) async {
    // Sổ thật (nhập từ Rolly) có "Ăn sáng thiết yếu"/"Ăn trưa thiết yếu"/
    // "Ăn tối thiết yếu" — tín hiệu buổi phải lấy được từ TỪ trong tên, chứ
    // không phải so khớp cả tên danh mục.
    await insertSubcategory('Ăn sáng thiết yếu', 'Ăn uống');
    await insertSubcategory('Ăn trưa thiết yếu', 'Ăn uống');
    await insertSubcategory('Ăn tối thiết yếu', 'Ăn uống');

    await pumpApp(tester, db: db, child: const QuickAddScreen());
    await tester.pumpAndSettle();
    await send(tester, 'hủ tíu trưa 30k');

    expect(find.textContaining('Ăn trưa thiết yếu'), findsWidgets);
    expect(find.textContaining('Ăn sáng thiết yếu'), findsNothing);
  });

  testWidgets('🚨 "bún chả ăn sáng 40k" → Ăn sáng thiết yếu (tên con thật)', (
    tester,
  ) async {
    await insertSubcategory('Ăn sáng thiết yếu', 'Ăn uống');
    await insertSubcategory('Ăn trưa thiết yếu', 'Ăn uống');
    await insertSubcategory('Ăn tối thiết yếu', 'Ăn uống');

    await pumpApp(tester, db: db, child: const QuickAddScreen());
    await tester.pumpAndSettle();
    await send(tester, 'bún chả ăn sáng 40k');

    expect(find.textContaining('Ăn sáng thiết yếu'), findsWidgets);
  });

  testWidgets(
    '🚨 "Ốc chung Oxytoxin 120k" → Ăn chung oxytocin, dù gõ SAI tên riêng '
    'và dù có một danh mục con khác cùng tên đó ở nhánh Gia đình',
    (tester) async {
      // Ca khó nhất trong sổ thật: "oxytocin" xuất hiện ở CẢ HAI nhánh
      // ("Gia đình › Oxytocin" và "Ăn uống › Ăn chung oxytocin"), người gõ
      // lại sai một ký tự. Thứ duy nhất phân biệt được hai danh mục là cụm
      // "chung oxytocin" — xem `subcategoryWordSignals`.
      await insertSubcategory('Ăn chung oxytocin', 'Ăn uống');
      await insertSubcategory('Oxytocin', 'Gia đình');

      await pumpApp(tester, db: db, child: const QuickAddScreen());
      await tester.pumpAndSettle();
      await send(tester, 'Ốc chung Oxytoxin 120k');

      expect(find.textContaining('Ăn chung oxytocin'), findsWidgets);
      expect(find.textContaining('Gia đình'), findsNothing);
    },
  );

  testWidgets('tên riêng đứng MỘT MÌNH vẫn về đúng nhánh của nó', (
    tester,
  ) async {
    await insertSubcategory('Ăn chung oxytocin', 'Ăn uống');
    await insertSubcategory('Oxytocin', 'Gia đình');

    await pumpApp(tester, db: db, child: const QuickAddScreen());
    await tester.pumpAndSettle();
    await send(tester, 'oxytoxin 500k');

    expect(find.textContaining('Oxytocin'), findsWidgets);
    expect(find.textContaining('Ăn chung'), findsNothing);
  });

  testWidgets('không có danh mục con nào → hành vi cũ giữ nguyên', (
    tester,
  ) async {
    await pumpApp(tester, db: db, child: const QuickAddScreen());
    await tester.pumpAndSettle();
    await send(tester, 'hủ tíu trưa 30k');

    expect(find.textContaining('Ăn uống'), findsWidgets);
  });
}
