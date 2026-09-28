// Luồng quét hoá đơn: nguồn ảnh → XOAY/CẮT → OCR → form bảng món (KHÔNG
// tự lưu).
//
// Camera, thư viện ảnh, màn cắt uCrop và ML Kit đều là native — thay bằng
// service giả qua provider để lái đủ các nhánh: chụp, chọn ảnh có sẵn, huỷ
// ở bước chọn, thoát ở bước cắt.
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
  _FakeCapture({required this.pickedPath, required this.croppedPath});

  /// `null` = Tony huỷ ở bước chọn/chụp.
  final String? pickedPath;

  /// `null` = Tony thoát màn cắt.
  final String? croppedPath;
  final pickCalls = <bool>[]; // fromCamera của từng lần gọi
  final cropCalls = <String>[];

  @override
  Future<String?> pickImage({required bool fromCamera}) async {
    pickCalls.add(fromCamera);
    return pickedPath;
  }

  @override
  Future<String?> cropImage(String imagePath) async {
    cropCalls.add(imagePath);
    return croppedPath;
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
  late String originalPath;
  late String croppedPath;
  final now = DateTime(2026, 9, 28, 9);

  setUp(() {
    db = openTestDatabase();
    tempDir = Directory.systemTemp.createTempSync('receipt_scan_flow');
    originalPath = '${tempDir.path}/goc.jpg';
    croppedPath = '${tempDir.path}/da_cat.jpg';
    File(originalPath).writeAsBytesSync(_onePixelPng);
    File(croppedPath).writeAsBytesSync(_onePixelPng);
  });
  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  Future<(_FakeCapture, _FakeOcr)> openFlow(
    WidgetTester tester, {
    required String choice,
    bool cancelPick = false,
    bool cancelCrop = false,
  }) async {
    final capture = _FakeCapture(
      pickedPath: cancelPick ? null : originalPath,
      croppedPath: cancelCrop ? null : croppedPath,
    );
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
    // đóng → chọn → cắt → đọc file → OCR → mở form) cho tới khi chạy hết.
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

  testWidgets('🚨 CHỤP → xoay/cắt → OCR đọc ảnh ĐÃ CẮT (không phải ảnh gốc) '
      '→ form điền tổng, tên quán, ngày, bảng món; KHÔNG ghi gì vào DB', (
    tester,
  ) async {
    final (capture, ocr) = await openFlow(tester, choice: 'Chụp ảnh');

    expect(capture.pickCalls, [true]);
    expect(capture.cropCalls, [originalPath]);
    expect(ocr.seenPaths, [croppedPath]);
    expectPrefilledForm();
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  testWidgets('CHỌN ẢNH CÓ SẴN cũng qua bước xoay/cắt', (tester) async {
    final (capture, ocr) = await openFlow(tester, choice: 'Chọn ảnh có sẵn');

    expect(capture.pickCalls, [false]);
    expect(capture.cropCalls, [originalPath]);
    expect(ocr.seenPaths, [croppedPath]);
    expectPrefilledForm();
  });

  testWidgets('huỷ ở bước chụp/chọn → không cắt, không OCR, không mở gì', (
    tester,
  ) async {
    final (capture, ocr) = await openFlow(
      tester,
      choice: 'Chụp ảnh',
      cancelPick: true,
    );

    expect(capture.cropCalls, isEmpty);
    expect(ocr.seenPaths, isEmpty);
    expect(find.text('74.000'), findsNothing);
  });

  testWidgets('🚨 thoát màn cắt → KHÔNG tự OCR ảnh gốc Tony vừa bỏ', (
    tester,
  ) async {
    final (_, ocr) = await openFlow(
      tester,
      choice: 'Chọn ảnh có sẵn',
      cancelCrop: true,
    );

    expect(ocr.seenPaths, isEmpty);
    expect(find.text('74.000'), findsNothing);
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
