// Ghép dòng OCR thành HÀNG theo toạ độ — lý do tồn tại: ML Kit đọc hoá đơn
// theo KHỐI, cột nhãn và cột số là hai khối tách rời, nên "Tổng số" và
// "414,000" không nằm cùng dòng trong `RecognizedText.text`.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/transactions/domain/receipt_ocr_layout.dart';
import 'package:tonyfino/features/transactions/domain/receipt_ocr_parser.dart';

OcrLineBox _box(String text, double left, double top, {double height = 20}) =>
    OcrLineBox.axisAligned(
      text: text,
      left: left,
      top: top,
      right: left + text.length * 10,
      bottom: top + height,
    );

/// Dòng trên một trang NGHIÊNG: xoay quanh gốc toạ độ theo [degrees] (âm =
/// mép phải cao hơn, như ảnh chụp hoá đơn cầm lệch tay).
OcrLineBox _tilted(String text, double left, double top, double degrees) {
  final a = degrees * math.pi / 180;
  math.Point<double> rot(double x, double y) => math.Point(
    x * math.cos(a) - y * math.sin(a),
    x * math.sin(a) + y * math.cos(a),
  );
  final right = left + text.length * 14;
  return OcrLineBox(
    text: text,
    topLeft: rot(left, top),
    topRight: rot(right, top),
    bottomRight: rot(right, top + 24),
    bottomLeft: rot(left, top + 24),
  );
}

void main() {
  // Hai KHỐI như ML Kit trả: toàn bộ cột trái trước, rồi toàn bộ cột phải.
  final blockOrder = [
    _box('Emart Sala Thủ Thiêm', 40, 10),
    _box('Snack Poca', 40, 100),
    _box('Tương ớt Chinsu', 40, 130),
    _box('Tổng số', 40, 200),
    _box('Tiền mặt', 40, 230),
    _box('63,900', 600, 101),
    _box('34,900', 600, 129),
    _box('414,000', 600, 202),
    _box('500,000', 600, 231),
  ];

  test('ghép đúng nhãn với số cùng hàng, trái sang phải, trên xuống dưới', () {
    expect(
      arrangeIntoRows(blockOrder),
      'Emart Sala Thủ Thiêm\n'
      'Snack Poca  63,900\n'
      'Tương ớt Chinsu  34,900\n'
      'Tổng số  414,000\n'
      'Tiền mặt  500,000',
    );
  });

  test('🚨 đọc theo KHỐI thì mất tổng; ghép theo HÀNG thì lấy đúng', () {
    final now = DateTime(2026, 9, 28);
    final asBlocks = blockOrder.map((b) => b.text).join('\n');
    // Theo khối: dòng "Tổng số" không có số, nhánh dự phòng nhặt số lớn
    // nhất 500,000 — tiền khách đưa, không phải tổng.
    expect(extractReceiptInfo(asBlocks, now: now).amountMinor, isNot(414000));
    expect(
      extractReceiptInfo(arrangeIntoRows(blockOrder), now: now).amountMinor,
      414000,
    );
  });

  test('hai hàng sát nhau (lệch hơn nửa chiều cao) KHÔNG bị gộp', () {
    final rows = arrangeIntoRows([
      _box('Trà đá', 40, 100),
      _box('Cơm tấm', 40, 112),
    ]);
    expect(rows, 'Trà đá\nCơm tấm');
  });

  test('một hàng không "trôi": so với dòng đầu hàng, không phải dòng cuối', () {
    // Mỗi dòng lệch 8px so với dòng trước — cộng dồn thành 24px, đã sang
    // hàng khác so với dòng đầu tiên.
    final rows = arrangeIntoRows([
      _box('A', 0, 100),
      _box('B', 100, 108),
      _box('C', 200, 116),
      _box('D', 300, 124),
    ]);
    expect(rows.split('\n'), hasLength(2));
  });

  test('bỏ dòng rỗng, danh sách rỗng ra chuỗi rỗng', () {
    expect(arrangeIntoRows([]), '');
    expect(arrangeIntoRows([_box('  ', 0, 0)]), '');
  });

  test('🚨 trang NGHIÊNG 6° — số mép phải vẫn về đúng hàng nhãn mép trái', () {
    // Tái hiện đúng lỗi đo được trên ảnh dựng Emart nghiêng qua ML Kit thật:
    // không nắn thì "Tổng số" ghép với 383,334 của dòng thuế bên dưới.
    final lines = [
      _tilted('Tổng số', 40, 1000, -6),
      _tilted('414,000', 700, 1000, -6),
      _tilted('Số tiền hạng mục đánh thuế', 40, 1040, -6),
      _tilted('383,334', 700, 1040, -6),
      _tilted('Thuế giá trị gia tăng', 40, 1080, -6),
      _tilted('30,666', 700, 1080, -6),
    ];
    expect(
      arrangeIntoRows(lines),
      'Tổng số  414,000\n'
      'Số tiền hạng mục đánh thuế  383,334\n'
      'Thuế giá trị gia tăng  30,666',
    );
    expect(
      extractReceiptInfo(
        arrangeIntoRows(lines),
        now: DateTime(2026, 9, 28),
      ).amountMinor,
      414000,
    );
  });

  test('nghiêng chiều ngược lại (+6°) cũng nắn đúng', () {
    final rows = arrangeIntoRows([
      _tilted('Tổng cộng', 40, 1000, 6),
      _tilted('74,000', 700, 1000, 6),
      _tilted('Tiền mặt', 40, 1040, 6),
      _tilted('100,000', 700, 1040, 6),
    ]);
    expect(rows, 'Tổng cộng  74,000\nTiền mặt  100,000');
  });
}
