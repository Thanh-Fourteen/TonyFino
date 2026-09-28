import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/quick_add/quick_add_screen.dart';
import 'package:tonyfino/features/quick_add/widgets/quick_add_input_bar.dart';
import 'package:tonyfino/theme/tokens/icons.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/fake_speech_to_text.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

/// Nhập giọng nói điền chữ vào ô, CHỜ Tony đọc lại rồi tự bấm gửi — không
/// bao giờ tự ghi giao dịch (docs/decisions.md § 2026-09-28).
void main() {
  late AppDatabase db;
  late FakeSpeechToTextPlatform speech;
  final frozenClock = Clock.fixed(DateTime(2026, 9, 28));

  setUp(() {
    installFakeSharedPreferences();
    speech = installFakeSpeechToText();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<void> pumpQuickAdd(WidgetTester tester) => pumpApp(
    tester,
    db: db,
    child: const QuickAddScreen(),
    extraOverrides: [clockProvider.overrideWithValue(frozenClock)],
  );

  String inputText(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byType(QuickAddInputBar),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  Future<void> startListening(WidgetTester tester) async {
    // Mic nằm sau dấu + cạnh ô nhập (cùng chỗ với nút quét hoá đơn).
    await tester.tap(find.byTooltip('Thêm cách nhập'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nói'));
    await tester.pump();
    expect(speech.listenCalls, 1);
    expect(find.text('Đang nghe…'), findsOneWidget);
  }

  testWidgets('kết quả CUỐI chỉ điền vào ô nhập, KHÔNG tự ghi giao dịch — '
      'Tony bấm gửi mới ghi', (tester) async {
    await pumpQuickAdd(tester);
    await startListening(tester);

    speech.emitResult('cà phê', isFinal: false);
    await tester.pump();
    speech.emitResult('cà phê 35k', isFinal: true);
    await tester.pumpAndSettle();

    expect(inputText(tester), 'cà phê 35k');
    expect(await db.select(db.transactions).get(), isEmpty);
    // Hết phiên nghe: nút thành mũi tên gửi, gợi ý thôi báo "Đang nghe…".
    expect(find.byIcon(kIconArrowUpward), findsOneWidget);

    // Sửa lại chỗ nhận dạng sai trước khi gửi — đúng lý do của thay đổi.
    await tester.enterText(
      find.descendant(
        of: find.byType(QuickAddInputBar),
        matching: find.byType(TextField),
      ),
      'cà phê 45k',
    );
    await tester.pump();
    await tester.tap(find.byIcon(kIconArrowUpward));
    await tester.pumpAndSettle();

    final saved = await db.select(db.transactions).get();
    expect(saved, hasLength(1));
    expect(saved.single.amountMinor.abs(), 45000);
    expect(inputText(tester), isEmpty);
  });

  testWidgets('đang nghe mà đã có chữ tạm thời thì nút là DỪNG NGHE, '
      'không gửi nửa câu', (tester) async {
    await pumpQuickAdd(tester);
    await startListening(tester);

    speech.emitResult('xăng năm', isFinal: false);
    await tester.pumpAndSettle();
    // Chữ đã có nhưng nút vẫn là mic (dừng), không hoá mũi tên gửi.
    expect(find.byIcon(kIconArrowUpward), findsNothing);

    await tester.tap(find.byTooltip('Dừng nghe'));
    // Vượt `finalTimeout` 2 giây của plugin (nó tự chốt kết quả tạm thời
    // cuối cùng thành kết quả cuối sau khi `stop()`).
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(speech.stopCalls, 1);
    expect(inputText(tester), 'xăng năm');
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(find.byIcon(kIconArrowUpward), findsOneWidget);
  });

  testWidgets('🚨 ô nhập dựng lại (rời màn rồi quay lại) vẫn nhận trạng thái '
      'hết nghe — SpeechToText là singleton, listener phải gắn lại', (
    tester,
  ) async {
    // Lần mount đầu: gọi `initialize()` lần đầu, listener gắn vào State này.
    await pumpQuickAdd(tester);
    await startListening(tester);
    speech.emitStatus('notListening');
    await tester.pumpAndSettle();

    // Huỷ hẳn cây widget rồi dựng State MỚI.
    await tester.pumpWidget(const SizedBox());
    await pumpQuickAdd(tester);
    await tester.tap(find.byTooltip('Thêm cách nhập'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nói'));
    await tester.pump();
    expect(find.text('Đang nghe…'), findsOneWidget);

    // Máy báo hết nghe (không nói gì) — State MỚI phải nhận được.
    speech.emitStatus('notListening');
    await tester.pumpAndSettle();
    expect(find.text('Đang nghe…'), findsNothing);
  });

  testWidgets('dấu + cạnh ô nhập mở ra giọng nói VÀ quét hoá đơn; quét mở '
      'chọn nguồn ảnh', (tester) async {
    await pumpQuickAdd(tester);
    expect(find.byTooltip('Quét hoá đơn'), findsNothing);
    expect(find.byTooltip('Nói'), findsNothing);

    await tester.tap(find.byTooltip('Thêm cách nhập'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Nói'), findsOneWidget);
    expect(find.byTooltip('Quét hoá đơn'), findsOneWidget);

    await tester.tap(find.byTooltip('Quét hoá đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Chụp ảnh'), findsOneWidget);
    expect(find.text('Chọn ảnh có sẵn'), findsOneWidget);
  });

  testWidgets('gõ chữ thì dấu + gập lại thành nút gửi', (tester) async {
    await pumpQuickAdd(tester);
    await tester.tap(find.byTooltip('Thêm cách nhập'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cà phê 35k');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Gửi'), findsOneWidget);
    expect(find.byTooltip('Quét hoá đơn'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Thêm cách nhập'), findsOneWidget);
    expect(find.byTooltip('Quét hoá đơn'), findsNothing);
  });
}
