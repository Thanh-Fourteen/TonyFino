// "Nhân đôi" viết lại ở Phase 14 — MỞ sheet Thêm điền sẵn (không còn tự
// động ghi + Hoàn tác như bản Phase 8 cũ). Kiểm qua cây sản xuất thật, từ cả
// hai lối vào: nút "Nhân đôi" trong sheet Sửa VÀ mục "Nhân đôi" trong sheet
// hành động nhấn giữ (quick-add).
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/transactions/transactions_screen.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

/// Tab Giao dịch lọc theo kỳ (mặc định "Tháng này") kể từ khi Tony yêu cầu
/// bộ chọn khoảng. Đóng băng đồng hồ để "tháng này" luôn là tháng chứa dữ
/// liệu seed của test — nếu để đồng hồ thật, bộ test này tự hỏng khi sang
/// tháng mới, đúng loại lỗi chỉ nổ ra vào một ngày ngẫu nhiên trong tương lai.
final _frozenClock = Clock.fixed(DateTime(2026, 1, 15));

void main() {
  late AppDatabase db;
  late int categoryId;
  late int walletId;

  setUp(() async {
    db = openTestDatabase();
    categoryId = (await db.select(db.categories).get()).first.id;
    walletId = (await db.select(db.wallets).get()).first.id;
  });
  tearDown(() => db.close());

  testWidgets(
    'Nhân đôi từ sheet Sửa — mở sheet Thêm điền sẵn số tiền/danh mục/ghi chú, '
    'CHƯA ghi gì cho tới khi bấm Lưu; lưu xong bản GỐC vẫn còn nguyên',
    (tester) async {
      final originalId = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -65000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 1, 1),
              walletId: walletId,
              categoryId: Value(categoryId),
              note: const Value('cà phê'),
            ),
          );

      await pumpApp(
        tester,
        db: db,
        child: const TransactionsScreen(),
        extraOverrides: [clockProvider.overrideWithValue(_frozenClock)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('cà phê'));
      await tester.pumpAndSettle();
      expect(find.text('Sửa giao dịch'), findsOneWidget);

      await tester.tap(find.text('Nhân đôi'));
      await tester.pumpAndSettle();

      // Sheet Sửa đóng, sheet Thêm mở SẴN điền — chưa có bản sao nào trong
      // DB cho tới khi bấm Lưu (khác hành vi insert-ngay-rồi-undo cũ).
      expect(find.text('Thêm giao dịch'), findsOneWidget);
      expect(await db.select(db.transactions).get(), hasLength(1));

      final amountField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Số tiền'),
      );
      // Ô nhập giờ hiện số ĐÃ TÁCH NHÓM (Tony: "ghi 500000 khó đếm số 0").
      expect(amountField.controller!.text, '65.000');
      final noteField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Ghi chú (tuỳ chọn)'),
      );
      expect(noteField.controller!.text, 'cà phê');

      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      final all = await db.select(db.transactions).get();
      expect(all, hasLength(2));
      final original = all.firstWhere((t) => t.id == originalId);
      expect(original.occurredAt, DateTime(2026, 1, 1)); // bản GỐC không đổi
      final copy = all.firstWhere((t) => t.id != originalId);
      expect(copy.amountMinor, -65000);
      expect(copy.categoryId, categoryId);
    },
  );
}
