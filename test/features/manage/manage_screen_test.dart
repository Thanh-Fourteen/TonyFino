// Màn "Quản lý" tách khỏi Cài đặt theo yêu cầu của Tony ("đưa phần quản lý
// ra khỏi setting"). Test canh đúng hai điều: mọi lối vào cũ vẫn còn (không
// mất tính năng khi dời chỗ), và Cài đặt KHÔNG còn giữ bản sao thứ hai.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/manage/manage_screen.dart';
import 'package:tonyfino/features/settings/recurring/recurring_screen.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  const expected = [
    'Ví',
    'Hạn mức theo danh mục',
    'Hũ chia thu nhập',
    'Mục tiêu & nợ vay',
    'Danh mục',
    'Thẻ',
    'Giao dịch định kỳ',
    'Mẫu giao dịch',
  ];

  testWidgets('liệt kê đủ 8 mục quản lý, không thiếu mục nào từ Cài đặt cũ', (
    tester,
  ) async {
    await pumpApp(tester, db: db, child: const ManageScreen());
    await tester.pumpAndSettle();

    for (final label in expected) {
      await tester.scrollUntilVisible(
        find.text(label),
        80,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      expect(find.text(label), findsOneWidget, reason: 'thiếu mục "$label"');
    }
  });

  testWidgets('bấm "Giao dịch định kỳ" mở đúng màn RecurringScreen', (
    tester,
  ) async {
    await pumpApp(tester, db: db, child: const ManageScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Giao dịch định kỳ'),
      80,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    await tester.tap(find.text('Giao dịch định kỳ'));
    await tester.pumpAndSettle();

    expect(find.byType(RecurringScreen), findsOneWidget);
  });
}
