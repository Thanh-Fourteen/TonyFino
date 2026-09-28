// Luồng quét hoá đơn: nguồn ảnh → OCR → form điền sẵn (KHÔNG tự lưu).
//
// Máy quét tài liệu và ML Kit chạy qua Play Services, không có trên host —
// thay bằng service giả qua provider để lái đủ bốn nhánh: quét được, Tony
// huỷ, máy không mở được máy quét (lùi về camera), ảnh chụp màn hình.
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/core/time/clock_provider.dart';
import 'package:tonyfino/data/db/database.dart';
import 'package:tonyfino/data/services/receipt_capture_service.dart';
import 'package:tonyfino/data/services/receipt_ocr_service.dart';
import 'package:tonyfino/features/transactions/receipt_scan.dart';

import '../../support/open_test_database.dart';
import '../../support/pump_app.dart';

/// PNG 1×1 hợp lệ — form hiện ảnh đính kèm, bytes rỗng làm nó ném lỗi giải mã.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC',
);

const _receiptText = '''
QUÁN CƠM TẤM
Ngày: 26/09/2026 12:15
Cơm sườn  2  70.000
Tổng cộng     74.000
''';

class _FakeCapture implements ReceiptCaptureService {
  _FakeCapture(this.scanOutcome, this.imagePath);

  final DocumentScanOutcome scanOutcome;
  final String imagePath;
  int scanCalls = 0;
  final pickCalls = <bool>[]; // fromCamera của từng lần gọi

  @override
  Future<DocumentScanOutcome> scanDocument() async {
    scanCalls++;
    return scanOutcome;
  }

  @override
  Future<String?> pickImage({required bool fromCamera}) async {
    pickCalls.add(fromCamera);
    return imagePath;
  }
}

class _FakeOcr implements ReceiptOcrService {
  final seenPaths = <String>[];

  @override
  Future<String> recognizeText(String imagePath) async {
    seenPaths.add(imagePath);
    return _receiptText;
  }
}

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late String imagePath;
  final now = DateTime(2026, 9, 28, 9);

  setUp(() {
    db = openTestDatabase();
    tempDir = Directory.systemTemp.createTempSync('receipt_scan_flow');
    imagePath = '${tempDir.path}/scan.jpg';
    File(imagePath).writeAsBytesSync(_onePixelPng);
  });
  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  Future<(_FakeCapture, _FakeOcr)> openFlow(
    WidgetTester tester, {
    required DocumentScanOutcome scanOutcome,
    required String choice,
  }) async {
    final capture = _FakeCapture(scanOutcome, imagePath);
    final ocr = _FakeOcr();
    await pumpApp(
      tester,
      db: db,
      extraOverrides: [
        clockProvider.overrideWithValue(Clock.fixed(now)),
        receiptCaptureServiceProvider.overrideWithValue(capture),
        receiptOcrServiceProvider.overrideWithValue(ocr),
      ],
      child: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => openReceiptScanFlow(context, ref),
            child: const Text('quét'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('quét'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(choice));
    // `XFile.readAsBytes` là I/O THẬT — trong fake async của widget test nó
    // không bao giờ xong. Nhường thời gian thật xen kẽ với dựng frame (sheet
    // đóng → quét → đọc file → OCR → mở form) cho tới khi luồng chạy hết.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    return (capture, ocr);
  }

  void expectPrefilledForm() {
    expect(find.text('74.000'), findsOneWidget);
    expect(find.text('QUÁN CƠM TẤM'), findsOneWidget);
    // 26/09 là Thứ Bảy — ngày trên hoá đơn, không phải "Hôm nay".
    expect(find.textContaining('26/09'), findsOneWidget);
    // Bảng món: món đọc được + dòng "Thuế, phí, khác" bù phần tổng lớn hơn
    // (74.000 − 70.000), để các dòng cộng khớp tổng ngay.
    expect(find.text('Cơm sườn'), findsOneWidget);
    expect(find.text('70.000'), findsOneWidget);
    expect(find.text('Thuế, phí, khác'), findsOneWidget);
    expect(find.text('4.000'), findsOneWidget);
  }

  testWidgets('quét được → OCR đúng ảnh đã quét, form điền số tiền + tên + '
      'NGÀY trên hoá đơn, KHÔNG ghi gì vào DB', (tester) async {
    final (capture, ocr) = await openFlow(
      tester,
      scanOutcome: DocumentScanned(imagePath),
      choice: 'Quét hoá đơn giấy',
    );

    expect(capture.scanCalls, 1);
    expect(capture.pickCalls, isEmpty);
    expect(ocr.seenPaths, [imagePath]);
    expectPrefilledForm();
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  testWidgets('Tony thoát máy quét → không mở gì, KHÔNG bị đẩy sang camera', (
    tester,
  ) async {
    final (capture, ocr) = await openFlow(
      tester,
      scanOutcome: const DocumentScanCancelled(),
      choice: 'Quét hoá đơn giấy',
    );

    expect(capture.pickCalls, isEmpty);
    expect(ocr.seenPaths, isEmpty);
    expect(find.text('74.000'), findsNothing);
  });

  testWidgets('🚨 thoát máy quét vẫn có lối "Chụp thường" — Play Services '
      'tải mô-đun hỏng cũng trả về "huỷ"', (tester) async {
    final (capture, _) = await openFlow(
      tester,
      scanOutcome: const DocumentScanCancelled(),
      choice: 'Quét hoá đơn giấy',
    );

    await tester.tap(find.text('Chụp thường'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(capture.pickCalls, [true]);
    expectPrefilledForm();
  });

  testWidgets('máy không mở được máy quét → báo, lùi về CAMERA thường, vẫn '
      'điền form', (tester) async {
    final (capture, _) = await openFlow(
      tester,
      scanOutcome: const DocumentScannerUnavailable(),
      choice: 'Quét hoá đơn giấy',
    );

    expect(capture.pickCalls, [true]);
    expectPrefilledForm();
  });

  testWidgets('ảnh chụp màn hình → thư viện ảnh, KHÔNG qua máy quét', (
    tester,
  ) async {
    final (capture, _) = await openFlow(
      tester,
      scanOutcome: DocumentScanned(imagePath),
      choice: 'Chọn ảnh chụp màn hình',
    );

    expect(capture.scanCalls, 0);
    expect(capture.pickCalls, [false]);
    expectPrefilledForm();
  });

  group('danh mục chung của hoá đơn', () {
    test('danh mục khớp NHIỀU món nhất thắng', () {
      expect(receiptFallbackCategory([null, 3, 7, 3, null]), 3);
    });
    test('hoà thì danh mục gặp trước', () {
      expect(receiptFallbackCategory([7, 3]), 7);
    });
    test('không món nào khớp → null', () {
      expect(receiptFallbackCategory([null, null]), isNull);
      expect(receiptFallbackCategory([]), isNull);
    });
  });
}
