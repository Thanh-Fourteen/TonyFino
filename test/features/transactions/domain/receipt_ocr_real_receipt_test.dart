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
  final text = File(
    'test/fixtures/receipts/emart_sala_thu_thiem.txt',
  ).readAsStringSync();

  test('🚨 hoá đơn Emart THẬT → lấy đúng tổng 414.000đ', () {
    final result = extractReceiptInfo(text);
    expect(
      result.amountMinor,
      414000,
      reason: 'Tổng hoá đơn là 414.000đ (383.334 hàng + 30.666 thuế)',
    );
  });

  test('🚨 KHÔNG nhặt nhầm MÃ VẠCH làm số tiền', () {
    final result = extractReceiptInfo(text);
    // Mã vạch EAN-13 là số 13 chữ số (8936136116143…). Nếu bộ trích xuất
    // rơi vào nhánh "lấy số lớn nhất toàn hoá đơn" thì mã vạch THẮNG tuyệt
    // đối — và người dùng thấy một khoản chi tám nghìn tỉ đồng.
    expect(result.amountMinor, lessThan(100000000));
  });

  test('lấy được tên cửa hàng', () {
    final result = extractReceiptInfo(text);
    expect(result.merchantName, isNotNull);
    expect(result.merchantName!.toLowerCase(), contains('emart'));
  });
}
