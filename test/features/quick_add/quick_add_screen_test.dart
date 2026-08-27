import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/features/quick_add/domain/ai_parse_fallback.dart';
import 'package:tonyfino/features/quick_add/domain/parser/parse_result.dart';
import 'package:tonyfino/features/quick_add/quick_add_providers.dart';
import 'package:tonyfino/features/quick_add/quick_add_screen.dart';
import 'package:tonyfino/features/quick_add/widgets/quick_add_input_bar.dart';
import 'package:tonyfino/theme/tokens/icons.dart';
import 'package:tonyfino/ui/app_chip.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;
  final frozenClock = Clock.fixed(DateTime(2026, 8, 21)); // Thứ Sáu

  setUp(() {
    installFakeSharedPreferences();
    db = openTestDatabase();
  });
  tearDown(() => db.close());

  Future<void> pumpQuickAdd(WidgetTester tester) => pumpApp(
    tester,
    db: db,
    child: const QuickAddScreen(),
    extraOverrides: [clockProvider.overrideWithValue(frozenClock)],
  );

  Future<void> sendMessage(WidgetTester tester, String text) async {
    // Neo ĐÍCH DANH ô nhập của thanh nhập liệu. `find.byType(TextField).last`
    // là bẫy thật: khi transcript đang có một thẻ "chưa hiểu" (thẻ đó có
    // thêm ô "Nội dung" và ô "Số tiền"), `.last` trỏ vào ô SỐ TIỀN của thẻ
    // chứ không phải thanh nhập — test trông vẫn xanh nhưng đang thao tác
    // nhầm chỗ.
    await tester.enterText(
      find.descendant(
        of: find.byType(QuickAddInputBar),
        matching: find.byType(TextField),
      ),
      text,
    );
    // Nút gửi biến hình từ mic sang mũi tên CHỈ SAU khi `_onChanged` chạy và
    // cây widget build lại — `enterText` không tự pump.
    await tester.pump();
    await tester.tap(find.byIcon(kIconArrowUpward));
    await tester.pumpAndSettle();
  }

  testWidgets(
    '"Café 30k, xem phim 100k hôm qua" → 2 thẻ, đúng số, đúng ngày, cả hai lưu',
    (tester) async {
      await pumpQuickAdd(tester);

      await sendMessage(tester, 'Café 30k, xem phim 100k hôm qua');

      // 2 thẻ hiện trên màn hình, đúng số tiền.
      expect(find.textContaining('30.000'), findsWidgets);
      expect(find.textContaining('100.000'), findsWidgets);

      // Cả hai đã ghi thật vào drift — không phải chỉ hiện trên UI.
      final saved = await db.select(db.transactions).get();
      expect(saved, hasLength(2));

      final amounts = saved.map((t) => t.amountMinor.abs()).toSet();
      expect(amounts, {30000, 100000});

      // Khớp danh mục qua ĐÚNG đường dây provider thật (không chỉ gọi
      // thẳng category_matcher/repository như test khác) — khoá lại bug đã
      // bắt được trên thiết bị thật: `categoryKeywordEntriesProvider` chỉ
      // `ref.read()` chứ không `ref.watch()` ở đâu thì Riverpod 3 tạm dừng
      // stream và mọi khớp danh mục lặng lẽ ra null (xem
      // `docs/decisions.md` § Phase 8).
      final categories = await db.select(db.categories).get();
      final categoryById = {for (final c in categories) c.id: c};
      for (final t in saved) {
        expect(
          t.categoryId,
          isNotNull,
          reason: 'giao dịch $t phải khớp được danh mục, không phải null',
        );
        expect(
          categoryById[t.categoryId],
          isNotNull,
          reason: 'categoryId phải trỏ tới một danh mục thật trong DB',
        );
      }

      // "hôm qua" (segment thứ hai) phải resolve đúng 2026-08-20 — segment
      // đầu ("Café 30k") không có cụm ngày nên mặc định hôm nay 2026-08-21.
      final byAmount = {for (final t in saved) t.amountMinor.abs(): t};
      expect(byAmount[30000]!.occurredAt, DateTime(2026, 8, 21));
      expect(byAmount[100000]!.occurredAt, DateTime(2026, 8, 20));
    },
  );

  testWidgets(
    '🎨 Phase 22 addendum: "cafe 20k" trên DB MỚI TINH (chưa import gì) → tự '
    'khớp thẳng vào danh mục con "Tiêu vặt" (dưới "Ăn uống"), không cần sửa '
    'tay lần nào — Tony yêu cầu trực tiếp, xem docs/decisions.md',
    (tester) async {
      await pumpQuickAdd(tester);

      await sendMessage(tester, 'cafe 20k');

      final saved = await (db.select(
        db.transactions,
      )..where((t) => t.amountMinor.equals(-20000))).getSingle();

      final tieuVat = await (db.select(
        db.categories,
      )..where((c) => c.name.equals('Tiêu vặt'))).getSingle();
      final anUong = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(tieuVat.parentCategoryId!))).getSingle();

      expect(anUong.name, 'Ăn uống');
      expect(
        saved.categoryId,
        tieuVat.id,
        reason:
            'từ khoá mặc định "cafe" phải trỏ vào danh mục con "Tiêu vặt" '
            '(seed Phase 22 addendum), không phải danh mục gốc "Ăn uống"',
      );
    },
  );

  testWidgets('câu không có số tiền → thẻ "chưa hiểu", không ghi gì vào DB', (
    tester,
  ) async {
    await pumpQuickAdd(tester);

    await sendMessage(tester, 'đi chơi với bạn xyz123notakeyword');

    expect(find.textContaining('Mình chưa hiểu'), findsOneWidget);
    final saved = await db.select(db.transactions).get();
    expect(saved, isEmpty);
  });

  testWidgets(
    'gửi câu thứ hai khi thẻ "chưa hiểu" của câu trước vẫn còn → transcript '
    'không vỡ (không RenderErrorBox)',
    (tester) async {
      // Trên máy thật gặp một khối đỏ #960F0F (RenderErrorBox của Flutter)
      // phủ kín vùng transcript sau khi gõ liên tiếp hai câu, câu đầu không
      // parse được. Test này dựng lại đúng chuỗi thao tác đó.
      await pumpQuickAdd(tester);

      await sendMessage(tester, 'zzz khong phai tu khoa nao');
      expect(find.textContaining('Mình chưa hiểu'), findsOneWidget);

      await sendMessage(tester, 'qqq cung khong phai tu khoa');
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'không được có exception nào khi dựng lại transcript',
      );
      // Transcript vẫn dựng được (còn ít nhất thẻ chưa hiểu của câu đầu) —
      // KHÔNG cố định số thẻ ở đây: câu thứ hai hiểu được hay không là việc
      // của parser, không phải điều test này đang khẳng định.
      expect(find.textContaining('Mình chưa hiểu'), findsWidgets);
      expect(find.byType(ErrorWidget), findsNothing);
    },
  );

  testWidgets('rỗng thì hiện EmptyState, không crash', (tester) async {
    await pumpQuickAdd(tester);
    await tester.pumpAndSettle();

    expect(find.text('Chưa có gì ở đây'), findsOneWidget);
  });

  testWidgets('Hoàn tác trên thẻ vừa lưu xoá luôn giao dịch thật', (
    tester,
  ) async {
    await pumpQuickAdd(tester);

    await sendMessage(tester, 'cà phê 35k');
    expect(await db.select(db.transactions).get(), hasLength(1));

    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();

    expect(await db.select(db.transactions).get(), isEmpty);
  });

  testWidgets(
    'sửa danh mục trên thẻ chờ → ghi vào transaction thật, HỎI trước khi học',
    (tester) async {
      await pumpQuickAdd(tester);

      // "phở" (không phải "cà phê") — kể từ Phase 22 addendum, "cà phê" tự
      // khớp thẳng vào danh mục CON "Tiêu vặt", không còn hợp làm ví dụ
      // "khớp mặc định vào danh mục GỐC" cho test này nữa; "phở" vẫn ở
      // nguyên danh mục gốc "Ăn uống" (xem category_seed.dart).
      await sendMessage(tester, 'phở 35k');
      // Khớp mặc định phải là "Ăn uống" (từ khoá seed) — tiền đề để phép sửa
      // dưới đây thực sự là một sự THAY ĐỔI, không phải chọn lại chính nó.
      expect(find.widgetWithText(AppChip, 'Ăn uống'), findsOneWidget);

      final categories = await db.select(db.categories).get();
      final diChuyen = categories.firstWhere((c) => c.name == 'Di chuyển');

      // Chạm chip danh mục trên thẻ CHỜ (chưa co lại) → mở sheet chọn.
      await tester.tap(find.widgetWithText(AppChip, 'Ăn uống'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppChip, 'Di chuyển'));
      await tester.pumpAndSettle();

      // Giao dịch đã lưu (lạc quan) phải được CẬP NHẬT ngay, không phải ghi
      // giao dịch mới.
      final saved = await db.select(db.transactions).get();
      expect(saved, hasLength(1));
      expect(saved.single.categoryId, diChuyen.id);

      // 🚨 KHÔNG học âm thầm nữa: sửa danh mục xong, app HỎI trước.
      // Không bấm gì = không nhớ gì.
      final learnedBefore = await (db.select(
        db.categoryKeywords,
      )..where((k) => k.categoryId.equals(diChuyen.id))).get();
      expect(
        learnedBefore.any((k) => k.keywordAscii.contains('pho')),
        isFalse,
        reason: 'chưa bấm "Nhớ" thì không được ghi gì vào category_keywords',
      );
      expect(find.textContaining('Nhớ "phở"'), findsOneWidget);
    },
  );

  testWidgets(
    'bấm "Nhớ" trên snackbar → mới thật sự học từ khoá cho danh mục mới',
    (tester) async {
      await pumpQuickAdd(tester);
      await sendMessage(tester, 'phở 35k');

      final categories = await db.select(db.categories).get();
      final diChuyen = categories.firstWhere((c) => c.name == 'Di chuyển');

      await tester.tap(find.widgetWithText(AppChip, 'Ăn uống'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppChip, 'Di chuyển'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nhớ'));
      await tester.pumpAndSettle();

      final learned = await (db.select(
        db.categoryKeywords,
      )..where((k) => k.categoryId.equals(diChuyen.id))).get();
      expect(
        learned.any((k) => k.keywordAscii.contains('pho')),
        isTrue,
        reason:
            'sau khi Tony đồng ý, "phở" → Di chuyển phải nằm trong '
            'category_keywords; thực tế: ${learned.map((k) => k.keyword)}',
      );
    },
  );

  testWidgets('nút "Chọn từ" mở sheet, bỏ bớt từ rồi nhớ đúng phần đã chọn', (
    tester,
  ) async {
    await pumpQuickAdd(tester);
    await sendMessage(tester, 'hủ tíu trưa 30k');

    final categories = await db.select(db.categories).get();
    final diChuyen = categories.firstWhere((c) => c.name == 'Di chuyển');

    await tester.tap(find.widgetWithText(AppChip, 'Ăn uống'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppChip, 'Di chuyển'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chọn từ'));
    await tester.pumpAndSettle();
    expect(find.text('Nhớ từ nào?'), findsOneWidget);

    // Bỏ tick "trưa", chỉ nhớ "hủ tíu".
    await tester.tap(find.widgetWithText(AppChip, 'trưa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Nhớ'));
    await tester.pumpAndSettle();

    final learned = await (db.select(
      db.categoryKeywords,
    )..where((k) => k.categoryId.equals(diChuyen.id))).get();
    final words = learned.map((k) => k.keyword).toSet();
    // Cụm giữ nguyên "hủ tíu" — KHÔNG tách thành "hủ" + "tíu".
    expect(words, contains('hủ tíu'));
    expect(words.any((w) => w.contains('trưa')), isFalse);
  });

  testWidgets(
    'sửa danh mục KHÔNG được xoá mất thẻ khác đang chờ trong CÙNG phiên',
    (tester) async {
      await pumpQuickAdd(tester);

      // Hai tin nhắn RIÊNG BIỆT trong cùng phiên — cả hai vẫn đang ở trạng
      // thái "chờ" (còn nút "Hoàn tác", chưa co lại). "phở" (không phải "cà
      // phê") — lý do như test phía trên.
      await sendMessage(tester, 'phở 35k');
      await sendMessage(tester, 'xăng 40k');
      expect(find.text('Hoàn tác'), findsNWidgets(2));

      // Sửa danh mục trên thẻ ĐẦU (phở) — thao tác này GHI vào
      // category_keywords, đúng dòng dữ liệu khiến `categoryKeywordEntriesProvider`
      // phát giá trị mới.
      await tester.tap(find.widgetWithText(AppChip, 'Ăn uống').first);
      await tester.pumpAndSettle();
      // Sheet chọn danh mục là MODAL — thẻ "xăng 40k" phía sau cũng đang
      // hiện chip "Di chuyển" của chính nó, nên không thể tap mù theo text.
      // Phân biệt bằng `editable`: chip TRONG sheet luôn `editable: false`
      // (`category_picker_sheet.dart`), chip TRÊN THẺ chờ thì `editable:
      // true` (có caret ▾, xem `draft_card.dart`) — chỉ đúng MỘT chip khớp.
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is AppChip && w.label == 'Di chuyển' && !w.editable,
        ),
      );
      await tester.pumpAndSettle();

      // Thẻ "xăng 40k" — KHÔNG bị đụng tới — vẫn phải còn nguyên trên màn,
      // vẫn còn nút "Hoàn tác" của chính nó. Nếu `QuickAddController.build()`
      // lỡ `ref.watch` (thay vì `ref.listen`) provider vừa ghi ở trên, toàn
      // bộ `state.messages` của phiên sẽ bị xoá sạch ở đây — cả hai
      // "Hoàn tác" biến mất, dù giao dịch vẫn còn trong DB (chỉ mất khỏi
      // UI phiên hiện tại). Xem `docs/decisions.md` § Phase 9 (bug cùng lớp
      // bắt được khi viết importer Rolly, rồi soát lại thấy Phase 8 cũng dính).
      expect(find.text('Hoàn tác'), findsNWidgets(2));

      final saved = await db.select(db.transactions).get();
      expect(saved, hasLength(2));
    },
  );

  group(
    '🚨 Phase 18: "giọng nói chỉ là một cách gõ khác" — câu tự nhiên kiểu lời nói',
    () {
      // Nhập giọng nói (`quick_add_input_bar.dart`'s `_onSpeechResult`) gọi
      // ĐÚNG `_send()` này — cùng một nút gửi, không có đường ghi riêng cho
      // giọng nói (xem docs/decisions.md § Phase 18). Test này không giả lập
      // `SpeechToTextPlatform` (đó là hành vi OS/plugin, không phải logic của
      // app) — chỉ chứng minh văn bản kiểu "lời nói tự nhiên" (không dấu
      // phẩy/chấm câu như văn bản gõ tay thường có, không viết tắt "k"/"tr")
      // vẫn ra kết quả hợp lý qua ĐÚNG pipeline mà cả gõ tay lẫn giọng nói
      // cùng dùng.
      testWidgets(
        '"tôi vừa ăn trưa hết ba mươi lăm nghìn" → hiểu đúng số tiền, chờ xác nhận',
        (tester) async {
          await pumpQuickAdd(tester);

          await sendMessage(tester, 'tôi vừa ăn trưa hết ba mươi lăm nghìn');

          expect(find.textContaining('35.000'), findsWidgets);
          expect(find.text('Hoàn tác'), findsOneWidget);
        },
      );

      testWidgets('"đổ xăng hết năm mươi nghìn đồng" → hiểu đúng số tiền', (
        tester,
      ) async {
        await pumpQuickAdd(tester);

        await sendMessage(tester, 'đổ xăng hết năm mươi nghìn đồng');

        expect(find.textContaining('50.000'), findsWidgets);
        expect(find.text('Hoàn tác'), findsOneWidget);
      });

      testWidgets(
        'câu không có số tiền nào (lời nói ngoài lề) → không crash, không thẻ hiểu được',
        (tester) async {
          await pumpQuickAdd(tester);

          await sendMessage(tester, 'hôm nay trời đẹp quá đi mất');

          // Không có "Hoàn tác" nào — không giao dịch nào được hiểu/ghi, đúng
          // hành vi câu vô nghĩa về mặt tài chính (giống hệt gõ tay câu tương tự).
          expect(find.text('Hoàn tác'), findsNothing);
          expect(await db.select(db.transactions).get(), isEmpty);
        },
      );
    },
  );

  group('🚨 Phase 23: sheet đồng ý cloud fallback lần đầu gặp câu mơ hồ', () {
    // `aiParseFallbackProvider` override thẳng bằng fake này (không phải qua
    // `cloudFallbackEnabled`) — cố tình tách rời khỏi mạng thật/proxy thật,
    // chỉ kiểm chứng ĐÚNG cái mới ở Phase 23: sheet tự bật, "đồng ý" gọi lại
    // fallback cho đúng thẻ và ghi kết quả cải thiện, "từ chối" chỉ đánh dấu
    // đã hỏi (hành vi y hệt trước Phase 23, không có gì thay đổi).
    testWidgets(
      'câu chưa hiểu → sheet tự bật, đồng ý → gọi lại fallback, thẻ được lưu',
      (tester) async {
        // `armed = false` lúc đầu — giả lập ĐÚNG hành vi thật: TRƯỚC khi đồng
        // ý, `aiParseFallbackProvider` thật trả về `NoopFallback` (luôn
        // `null`), gọi tự động từ `sendMessage` không cải thiện được gì; chỉ
        // SAU khi bấm "Bật trợ lý AI" (kích hoạt `retryFallbackForCard`) mới
        // "vũ trang" fake để trả kết quả thật — nếu để fake trả kết quả ngay
        // từ đầu, lượt gọi TỰ ĐỘNG (không cần đồng ý) đã âm thầm giải quyết
        // xong thẻ trước khi sheet kịp kiểm tra, che mất đúng thứ đang test.
        final fake = _FakeAiParseFallback(
          result: [
            ParsedDraft(
              rawText: 'đi chơi với bạn xyz123notakeyword',
              leftoverText: 'đi chơi với bạn',
              amount: const ParsedAmount(minorUnits: 50000, confident: true),
              date: ParsedDate(date: DateTime(2026, 8, 21), explicit: false),
              category: null,
            ),
          ],
          armed: false,
        );
        await pumpApp(
          tester,
          db: db,
          child: const QuickAddScreen(),
          extraOverrides: [
            clockProvider.overrideWithValue(frozenClock),
            aiParseFallbackProvider.overrideWithValue(fake),
          ],
        );

        await sendMessage(tester, 'đi chơi với bạn xyz123notakeyword');
        expect(find.textContaining('Câu này hơi khó đoán'), findsOneWidget);
        expect(find.textContaining('Mình chưa hiểu'), findsOneWidget);

        fake.armed = true;
        await tester.tap(find.widgetWithText(FilledButton, 'Bật trợ lý AI'));
        await tester.pumpAndSettle();

        expect(fake.callCount, 2);
        expect(find.textContaining('50.000'), findsWidgets);
        final saved = await db.select(db.transactions).get();
        expect(saved, hasLength(1));
        expect(saved.single.amountMinor.abs(), 50000);
      },
    );

    testWidgets(
      'từ chối → chỉ đánh dấu đã hỏi, KHÔNG gọi fallback, hành vi giữ nguyên',
      (tester) async {
        final fake = _FakeAiParseFallback(result: null);
        await pumpApp(
          tester,
          db: db,
          child: const QuickAddScreen(),
          extraOverrides: [
            clockProvider.overrideWithValue(frozenClock),
            aiParseFallbackProvider.overrideWithValue(fake),
          ],
        );

        await sendMessage(tester, 'đi chơi với bạn xyz123notakeyword');
        expect(find.textContaining('Câu này hơi khó đoán'), findsOneWidget);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Không dùng'));
        await tester.pumpAndSettle();

        // Đã hỏi rồi — gửi thêm một câu mơ hồ khác trong CÙNG phiên không bật
        // sheet lại lần nữa.
        await sendMessage(tester, 'nói chuyện phiếm không liên quan tiền bạc');
        expect(find.textContaining('Câu này hơi khó đoán'), findsNothing);

        expect(find.textContaining('Mình chưa hiểu'), findsWidgets);
        expect(await db.select(db.transactions).get(), isEmpty);
      },
    );
  });
  testWidgets(
    '🚨 sửa NGÀY của một giao dịch đã lưu → vạch ngăn ngày trong lịch sử '
    'chat đổi theo (trước đây transcript nhóm theo createdAt nên không nhúc '
    'nhích, trông như nút Lưu không ăn)',
    (tester) async {
      final walletId = (await db.select(db.wallets).get()).first.id;
      final categoryId = (await db.select(db.categories).get()).first.id;
      // Giao dịch gõ tay (sourceId = null nên THUỘC transcript), ngày giao
      // dịch là HÔM NAY theo đồng hồ đóng băng.
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -40000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 21),
              walletId: walletId,
              categoryId: Value(categoryId),
              note: const Value('hủ tíu'),
            ),
          );

      await pumpQuickAdd(tester);
      await tester.pumpAndSettle();
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Hôm qua'), findsNothing);

      // Chỉ đổi NGÀY, không đụng gì khác — đúng thao tác Tony mô tả.
      await (db.update(db.transactions)..where((t) => t.id.equals(1))).write(
        TransactionsCompanion(occurredAt: Value(DateTime(2026, 8, 20))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hôm qua'), findsOneWidget);
      expect(find.text('Hôm nay'), findsNothing);
    },
  );

  testWidgets(
    '🚨 gõ "hủ tíu 40k" → xếp thẳng vào Ăn uống (đi qua TỪ KHOÁ TRONG DB, '
    'không phải hằng số trong code)',
    (tester) async {
      await pumpQuickAdd(tester);
      await sendMessage(tester, 'hủ tíu 40k');
      await tester.pumpAndSettle();

      expect(find.text('Ăn uống'), findsWidgets);
      expect(find.textContaining('chưa hiểu'), findsNothing);
    },
  );

  testWidgets(
    'gõ "cafe 35k" → danh mục CON "Tiêu vặt" (đúng yêu cầu Phase 22), không '
    'rơi vào "chưa hiểu"',
    (tester) async {
      await pumpQuickAdd(tester);
      await sendMessage(tester, 'cafe 35k');
      await tester.pumpAndSettle();

      expect(find.text('Tiêu vặt'), findsWidgets);
      expect(find.textContaining('chưa hiểu'), findsNothing);
    },
  );

  // Hai câu tách thành HAI test: gửi câu thứ hai trong cùng một test làm
  // transcript có hai thẻ, `find.text` khi đó khớp nhiều hơn một widget.
  testWidgets('🚨 "nước lọc 10k" → Ăn uống, KHÔNG phải hoá đơn Nhà cửa', (
    tester,
  ) async {
    await pumpQuickAdd(tester);
    await sendMessage(tester, 'nước lọc 10k');
    await tester.pumpAndSettle();
    expect(find.text('Ăn uống'), findsWidgets);
    expect(find.text('Nhà cửa'), findsNothing);
  });

  testWidgets('"tiền nước 200k" vẫn về Nhà cửa (từ khoá dài hơn thắng)', (
    tester,
  ) async {
    await pumpQuickAdd(tester);
    await sendMessage(tester, 'tiền nước 200k');
    await tester.pumpAndSettle();
    expect(find.text('Nhà cửa'), findsWidgets);
  });

  testWidgets(
    '🚨 chat → lưu → sửa NGÀY → thẻ trong phiên đổi ngày theo (trước đây thẻ '
    '"đã lưu" vẽ theo bản nháp trong bộ nhớ nên đứng im, trông như nút Lưu '
    'không ăn)',
    (tester) async {
      await pumpQuickAdd(tester);
      await sendMessage(tester, 'hủ tíu 40k');
      // Thẻ tự lưu rồi CO LẠI sau vài giây — phải chờ hết hẹn giờ đó mới ra
      // trạng thái "đã lưu" (dạng một dòng), thứ đang cần kiểm.
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      // Thẻ vừa lưu hiện "hôm nay" (đồng hồ đóng băng 21/8).
      expect(find.textContaining('hôm nay'), findsWidgets);

      // Sửa NGÀY thẳng dưới DB — mô phỏng đúng việc bấm "Đổi ngày" rồi Lưu
      // trong sheet Sửa, không phụ thuộc vào việc lái date picker.
      final saved = await db.select(db.transactions).getSingle();
      await (db.update(
        db.transactions,
      )..where((t) => t.id.equals(saved.id))).write(
        TransactionsCompanion(occurredAt: Value(DateTime(2026, 8, 20))),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('hôm nay'), findsNothing);
      expect(find.textContaining('hôm qua'), findsWidgets);
    },
  );

  testWidgets('sửa SỐ TIỀN cũng cập nhật thẻ đã lưu trong phiên', (
    tester,
  ) async {
    await pumpQuickAdd(tester);
    await sendMessage(tester, 'hủ tíu 40k');
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(find.textContaining('40.000'), findsWidgets);

    final saved = await db.select(db.transactions).getSingle();
    await (db.update(db.transactions)..where((t) => t.id.equals(saved.id)))
        .write(const TransactionsCompanion(amountMinor: Value(-95000)));
    await tester.pumpAndSettle();

    expect(find.textContaining('95.000'), findsWidgets);
  });

  testWidgets(
    '🚨 hàng đã lưu trong transcript hiện ĐỦ HAI TẦNG "Cha › Con", không in '
    'mỗi tên danh mục con',
    (tester) async {
      final all = await db.select(db.categories).get();
      final parent = all.firstWhere(
        (c) => c.parentCategoryId == null && c.name == 'Ăn uống',
      );
      final childId = await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Ăn tối thiết yếu',
              kind: parent.kind,
              categoryColorId: parent.categoryColorId,
              iconCode: parent.iconCode,
              parentCategoryId: Value(parent.id),
              walletId: parent.walletId,
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amountMinor: -50000,
              currency: 'VND',
              currencyScale: 0,
              occurredAt: DateTime(2026, 8, 21),
              walletId: parent.walletId,
              categoryId: Value(childId),
            ),
          );

      await pumpQuickAdd(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ăn uống › Ăn tối thiết yếu'), findsWidgets);
      // Chỉ mỗi tên con là KHÔNG đủ — nhìn "Ăn tối thiết yếu" trần thì không
      // biết nó thuộc Ăn uống hay danh mục nào khác.
      expect(find.text('Ăn tối thiết yếu'), findsNothing);
    },
  );
}

class _FakeAiParseFallback implements AiParseFallback {
  _FakeAiParseFallback({required this.result, this.armed = true});

  final List<ParsedDraft>? result;

  /// `false` = giả lập `NoopFallback` thật (luôn `null`) — dùng cho lượt gọi
  /// TỰ ĐỘNG trước khi Tony đồng ý, đúng hành vi thật khi cloud fallback
  /// chưa bật.
  bool armed;
  int callCount = 0;

  @override
  Future<List<ParsedDraft>?> tryParse(
    String rawMessage, {
    required Clock clock,
  }) async {
    callCount++;
    return armed ? result : null;
  }
}
