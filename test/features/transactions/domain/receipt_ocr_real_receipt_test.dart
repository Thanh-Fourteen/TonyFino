// 🚨 Hoá đơn THẬT, không phải ảnh mẫu.
//
// Đây là ô cuối cùng còn trống của Phase 18: "test OCR trên hoá đơn tiếng
// Việt THẬT". Tony chụp hoá đơn Emart Sala Thủ Thiêm 23/08/2026 (12 mặt
// hàng, tổng 414.000đ) và gửi ảnh. Văn bản trong fixture chép đúng theo ảnh
// đó, kể cả những chỗ OCR/máy in dễ nhầm (chữ O thay số 0 ở mã vạch dòng 10).
//
// File này kiểm phần TRÍCH XUẤT (`extractReceiptInfo`) — thuần Dart, chạy
// được ở CI. Phần NHẬN DẠNG ẢNH (ML Kit) chỉ chạy trên thiết bị thật.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/transactions/domain/receipt_ocr_parser.dart';

void main() {
  // Bỏ các dòng chú thích `#` đầu fixture. Trước đây test đọc NGUYÊN file,
  // nên "tên cửa hàng" thật ra là dòng chú thích "# Hoá đơn Emart…" — test
  // "chứa emart" xanh nhờ may, không nhờ bộ trích xuất.
  final text = File(
    'test/fixtures/receipts/emart_sala_thu_thiem.txt',
  ).readAsLinesSync().where((line) => !line.startsWith('#')).join('\n');
  final now = DateTime(2026, 9, 28, 10);

  test('🚨 hoá đơn Emart THẬT → lấy đúng tổng 414.000đ', () {
    final result = extractReceiptInfo(text, now: now);
    expect(
      result.amountMinor,
      414000,
      reason: 'Tổng hoá đơn là 414.000đ (383.334 hàng + 30.666 thuế)',
    );
  });

  test('🚨 KHÔNG nhặt nhầm MÃ VẠCH làm số tiền', () {
    final result = extractReceiptInfo(text, now: now);
    // Mã vạch EAN-13 là số 13 chữ số (8936136116143…). Nếu bộ trích xuất
    // rơi vào nhánh "lấy số lớn nhất toàn hoá đơn" thì mã vạch THẮNG tuyệt
    // đối — và người dùng thấy một khoản chi tám nghìn tỉ đồng.
    expect(result.amountMinor, lessThan(100000000));
  });

  test('lấy được tên cửa hàng', () {
    final result = extractReceiptInfo(text, now: now);
    expect(result.merchantName, isNotNull);
    expect(result.merchantName!.toLowerCase(), contains('emart'));
  });

  test('lấy đúng ngày giờ mua in trên hoá đơn (23-08-2026 21:27)', () {
    // Dòng "Hoạt động từ : 07h30 - 22h30" nằm TRÊN dòng ngày — là giờ mở
    // cửa, không được lấy làm giờ mua.
    expect(
      extractReceiptInfo(text, now: now).occurredAt,
      DateTime(2026, 8, 23, 21, 27),
    );
  });

  group('văn bản ML Kit THẬT (ảnh dựng, ảnh thẳng)', () {
    final mlkit = File(
      'test/fixtures/receipts/emart_mlkit_straight.txt',
    ).readAsLinesSync().where((line) => !line.startsWith('#')).join('\n');

    test(
      '🚨 đủ tổng, tên quán, NGÀY — "23-08- 2026" có dấu cách vẫn đọc được',
      () {
        final result = extractReceiptInfo(mlkit, now: now);
        expect(result.amountMinor, 414000);
        expect(result.merchantName, 'emart');
        expect(result.occurredAt, DateTime(2026, 8, 23, 21, 27));
      },
    );

    test('"78, 000" (dấu cách sau dấu phẩy) là MỘT số 78.000', () {
      expect(
        extractReceiptInfo('A\nTổng cộng  78, 000', now: now).amountMinor,
        78000,
      );
    });

    test('hai cột số cách nhau HAI dấu cách không bị nối thành một', () {
      expect(
        extractReceiptInfo(
          'A\nTổng cộng  36,900  36,900',
          now: now,
        ).amountMinor,
        36900,
      );
    });
  });
}
