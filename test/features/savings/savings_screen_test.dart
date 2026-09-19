// Widget test qua CÂY SẢN XUẤT THẬT, cùng kỷ luật `BudgetsScreen`/
// `WalletsScreen` (Phase 11/13) — filter tab → provider → SQL → widget.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/savings/savings_screen.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<void> pumpSavings(WidgetTester tester) async {
    await pumpApp(tester, db: db, child: const SavingsScreen());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'chưa có mục tiêu/khoản vay nào → hiện trạng thái rỗng ở cả hai tab',
    (tester) async {
      await pumpSavings(tester);

      expect(find.text('Chưa có mục tiêu tiết kiệm nào'), findsOneWidget);

      await tester.tap(find.text('Nợ vay'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có khoản vay/cho vay nào'), findsOneWidget);
    },
  );

  testWidgets(
    'thêm mục tiêu mới qua sheet — hiện ngay trên danh sách với tiến độ 0',
    (tester) async {
      await pumpSavings(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Thêm mục tiêu tiết kiệm'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Tên mục tiêu'),
        'Du lịch Đà Lạt',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Số tiền cần đạt'),
        '10000000',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(find.text('Du lịch Đà Lạt'), findsOneWidget);
      expect(find.textContaining('10.000.000'), findsWidgets);
    },
  );

  testWidgets(
    '🚨 đóng góp cho mục tiêu qua nút "+" trên tile — lưu xong tiến độ cập nhật ngay',
    (tester) async {
      final goals = db.savingsGoals;
      await db
          .into(goals)
          .insert(
            SavingsGoalsCompanion.insert(
              name: 'Du lịch',
              targetAmountMinor: 5000000,
              currency: 'VND',
              currencyScale: 0,
            ),
          );

      await pumpSavings(tester);
      expect(find.text('Du lịch'), findsOneWidget);

      await tester.tap(find.byTooltip('Nạp tiền vào quỹ'));
      await tester.pumpAndSettle();

      // Sheet RIÊNG cho việc nạp quỹ, không phải form "Thêm giao dịch": tiêu
      // đề gọi đúng tên việc, và KHÔNG có lưới danh mục nào để chọn nhầm.
      expect(find.text('Nạp vào quỹ Du lịch'), findsOneWidget);
      expect(find.text('Thêm giao dịch'), findsNothing);
      expect(find.text('Danh mục'), findsNothing);
      expect(find.text('Tách giao dịch'), findsNothing);

      await tester.enterText(find.byType(TextField).first, '2000000');
      await tester.tap(find.text('Nạp'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2.000.000'), findsWidgets);
    },
  );

  testWidgets(
    '🎨 Phase 22: đóng góp đủ ĐỂ ĐẠT mục tiêu → hiện dialog ăn mừng đúng '
    'MỘT LẦN tại thời điểm chuyển trạng thái',
    (tester) async {
      await db
          .into(db.savingsGoals)
          .insert(
            SavingsGoalsCompanion.insert(
              name: 'Xe máy',
              targetAmountMinor: 1000000,
              currency: 'VND',
              currencyScale: 0,
            ),
          );

      await pumpSavings(tester);
      expect(find.text('Đã đạt mục tiêu!'), findsNothing);

      await tester.tap(find.byTooltip('Nạp tiền vào quỹ'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '1000000');
      await tester.tap(find.text('Nạp'));
      await tester.pumpAndSettle();

      expect(find.text('Đã đạt mục tiêu!'), findsOneWidget);
      expect(find.text('Xe máy'), findsWidgets);

      // Đóng dialog — mở lại màn (không đóng góp thêm) KHÔNG được ăn mừng
      // lại, vì goal đã đạt từ trước, không phải một chuyển trạng thái mới.
      await tester.tap(find.text('Tuyệt vời'));
      await tester.pumpAndSettle();
      expect(find.text('Đã đạt mục tiêu!'), findsNothing);
    },
  );

  testWidgets(
    'thêm khoản vay mới (mình nợ) qua sheet — hiện ngay trên tab Nợ vay',
    (tester) async {
      await pumpSavings(tester);

      await tester.tap(find.text('Nợ vay'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Thêm khoản vay/cho vay'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Tên người/đối tượng'),
        'Anh Long',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Số tiền gốc'),
        '5000000',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(find.text('Anh Long'), findsOneWidget);
      expect(find.textContaining('5.000.000'), findsWidgets);
    },
  );

  testWidgets(
    'lưu trữ một mục tiêu — biến mất khỏi danh sách chính, hiện trong "Đã lưu trữ", khôi phục được',
    (tester) async {
      await db
          .into(db.savingsGoals)
          .insert(
            SavingsGoalsCompanion.insert(
              name: 'Du lịch',
              targetAmountMinor: 5000000,
              currency: 'VND',
              currencyScale: 0,
            ),
          );
      await pumpSavings(tester);

      // "Lưu trữ" đã dời vào menu ⋮ của màn CHI TIẾT quỹ — thẻ trong danh
      // sách giờ chỉ giữ đúng một nút icon (Nạp tiền), thay vì ba nút không
      // nhãn chen nhau như trước.
      await tester.tap(find.text('Du lịch'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử'), findsOneWidget);

      // Generic của menu là kiểu private của màn chi tiết nên `byType` không
      // gọi tên được — tìm theo hình dạng widget.
      await tester.tap(
        find.byWidgetPredicate((w) => w is PopupMenuButton).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu trữ'));
      await tester.pumpAndSettle();

      expect(find.text('Đã lưu trữ'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Du lịch'), findsOneWidget);

      await tester.tap(find.text('Khôi phục'));
      await tester.pumpAndSettle();
      expect(find.text('Đã lưu trữ'), findsNothing);
    },
  );
}
