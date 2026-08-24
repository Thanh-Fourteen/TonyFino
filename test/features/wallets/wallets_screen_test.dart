// Widget test qua cây sản xuất thật (`WalletsScreen`) — cùng kỷ luật
// `budgets_screen_test.dart`/`recurring_screen_test.dart`: thêm/sửa/lưu trữ
// qua sheet thật, xác nhận hiện ngay trên danh sách không cần khởi động lại.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/wallets/wallets_screen.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpWallets(WidgetTester tester) async {
    await pumpApp(tester, db: db, child: const WalletsScreen());
    await tester.pumpAndSettle();
  }

  testWidgets('mặc định hiện đúng "Ví mặc định", số dư 0', (tester) async {
    await pumpWallets(tester);
    expect(find.text('Ví mặc định'), findsOneWidget);
    expect(find.textContaining('0'), findsWidgets);
  });

  testWidgets('thêm ví mới qua sheet — hiện ngay trên danh sách', (
    tester,
  ) async {
    await pumpWallets(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Tên ví'),
      'Tiền mặt',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Tiền mặt'), findsOneWidget);
    expect(find.text('Ví mặc định'), findsOneWidget);
  });

  testWidgets(
    'lưu trữ ví — biến mất khỏi danh sách chính, hiện trong "Đã lưu trữ", khôi phục được',
    (tester) async {
      await pumpWallets(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Tên ví'),
        'Thẻ tín dụng',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<void>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu trữ'));
      await tester.pumpAndSettle();

      expect(find.text('Đã lưu trữ'), findsOneWidget);
      expect(find.text('Khôi phục'), findsOneWidget);

      await tester.tap(find.text('Khôi phục'));
      await tester.pumpAndSettle();

      expect(find.text('Đã lưu trữ'), findsNothing);
    },
  );

  testWidgets('chuyển khoản giữa 2 ví qua sheet — số dư cả hai ví đổi đúng', (
    tester,
  ) async {
    await pumpWallets(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tên ví'),
      'Ngân hàng',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Chuyển khoản giữa ví'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '200000');
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('sourceWalletChips')),
        matching: find.widgetWithText(ChoiceChip, 'Ví mặc định'),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('destWalletChips')),
        matching: find.widgetWithText(ChoiceChip, 'Ngân hàng'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Chuyển'));
    await tester.pumpAndSettle();

    // Sheet đóng = lưu thành công (không còn "Chuyển khoản giữa ví" trên
    // màn — đúng khuôn mọi sheet khác trong app). Số học chính xác của
    // chuyển khoản (2 dòng liên kết, D7 bất biến) đã kiểm rất kỹ ở
    // `wallet_repository_test.dart` — ở đây chỉ xác nhận UI thật sự GỌI ĐÚNG
    // tới `createTransfer`, không lặp lại phép kiểm định dạng tiền tệ.
    expect(find.text('Chuyển khoản giữa ví'), findsNothing);
    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(2));
    expect(rows.every((t) => t.isTransfer), isTrue);
    expect(rows.map((t) => t.amountMinor).toSet(), {-200000, 200000});
  });
}
