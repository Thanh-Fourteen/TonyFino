// Kéo thả thứ tự hũ — test đúng phép tính chỉ số của `onReorderItem`
// (bản mới đã tự trừ chỗ trống của thẻ đang kéo; tự trừ thêm một lần nữa
// là lệch một ô, và chỉ lộ ra khi kéo XUỐNG).
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/repositories/jar_repository.dart';
import 'package:tonyfino/features/jars/jars_screen.dart';

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

  Future<List<String>> orderInDb() async {
    final jars =
        await (db.select(db.jars)..orderBy([
              (j) => OrderingTerm.asc(j.sortOrder),
              (j) => OrderingTerm.asc(j.id),
            ]))
            .get();
    return [for (final j in jars) j.name];
  }

  Future<void> dragJar(WidgetTester tester, String name, double dy) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(name)),
    );
    // Nhấn GIỮ rồi mới kéo — `ReorderableListView` trên mobile dùng
    // long-press để bắt đầu, kéo ngay lập tức chỉ làm cuộn danh sách.
    await tester.pump(kLongPressTimeout + kPressTimeout);
    for (var moved = 0.0; moved.abs() < dy.abs(); moved += dy.sign * 40) {
      await gesture.moveBy(Offset(0, dy.sign * 40));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('kéo hũ cuối lên đầu và kéo hũ đầu xuống — thứ tự ghi vào DB '
      'đúng như thấy trên màn', (tester) async {
    final walletId = await defaultWalletId(db);
    final repo = JarRepository(db);
    for (final (i, name) in ['A', 'B', 'C'].indexed) {
      await repo.insert(
        walletId: walletId,
        name: name,
        percent: 10 + i,
        categoryColorId: i,
        iconCode: 'home',
      );
    }

    // Khung test mặc định 800×600 không đủ cho ba thẻ hũ — thẻ cuối chưa
    // được dựng thì không có gì để kéo (bẫy "ListView dựng lười" đã ghi).
    tester.view.physicalSize = const Size(700, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(tester, db: db, child: const JarsScreen());
    await tester.pumpAndSettle();
    expect(await orderInDb(), ['A', 'B', 'C']);

    // Bất biến thật sự cần giữ: thứ tự GHI XUỐNG DB khớp thứ tự đang THẤY
    // trên màn. So với một danh sách cố định thì bài test lại phụ thuộc
    // quãng kéo (kéo quá tay một nấc là đỏ dù mã đúng).
    List<String> orderOnScreen() {
      final names = ['A', 'B', 'C']
        ..sort(
          (a, b) => tester
              .getCenter(find.text(a))
              .dy
              .compareTo(tester.getCenter(find.text(b)).dy),
        );
      return names;
    }

    // Kéo LÊN: C vượt lên trên.
    await dragJar(tester, 'C', -600);
    expect(orderOnScreen(), ['C', 'A', 'B']);
    expect(await orderInDb(), orderOnScreen());

    // Kéo XUỐNG — ca dễ lệch một ô nếu tự trừ chỉ số thêm lần nữa.
    await dragJar(tester, 'C', 300);
    expect(orderOnScreen().first, 'A', reason: 'C phải rời khỏi vị trí đầu');
    expect(await orderInDb(), orderOnScreen());
  });
}
