// Tách DÒNG HÀNG trên văn bản ML Kit THẬT của hoá đơn thật (fixture
// `real_*.txt` — ảnh Tony gửi 2026-09-28, đọc qua ML Kit trên máy ảo) và
// văn bản ML Kit của ảnh dựng Emart.
//
// Mỗi test chốt ĐÚNG những gì bộ tách làm được trên dữ liệu thật — kể cả
// giới hạn đã biết (ghi rõ ở từng test), để một thay đổi luật sau này làm
// hỏng hoá đơn thật nào là test đỏ ngay, không phải đợi Tony chụp lại.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/transactions/domain/receipt_ocr_parser.dart';

ReceiptOcrExtraction _read(String fixture) => extractReceiptInfo(
  File(
    'test/fixtures/receipts/$fixture',
  ).readAsLinesSync().where((line) => !line.startsWith('#')).join('\n'),
  now: DateTime(2026, 9, 28),
);

int _sum(List<ReceiptItem> items) =>
    items.fold(0, (sum, item) => sum + (item.amountMinor ?? 0));

void main() {
  test(
    'Emart (ML Kit, ảnh thẳng) — đủ 12 món, cộng đúng bằng tổng 414.000',
    () {
      final r = _read('emart_mlkit_straight.txt');
      expect(r.items, hasLength(12));
      expect(_sum(r.items), 414000);
      expect(r.amountMinor, 414000);
      // Món nằm trên HAI hàng (tên / mã vạch + tiền) ghép đúng; tiền tố
      // "01) VAT08" bị bỏ.
      expect(r.items.first.name, 'SNACK POCA SƠI NƯA VI MALA CAYN');
      expect(r.items.first.amountMinor, 63900);
      expect(r.items.last.amountMinor, 52900);
    },
  );

  test('shop quần áo (cầm tay, giấy cong) — 3 món, lấy THÀNH TIỀN ngoài '
      'cùng phải chứ không phải đơn giá/chiết khấu', () {
    final r = _read('real_shop_clothes.txt');
    expect([for (final i in r.items) i.amountMinor], [450000, 517000, 480000]);
    expect(r.items.first.name, startsWith('Váy mát hè'));
    expect(_sum(r.items), 1447000);
    expect(r.amountMinor, 1447000);
    // Số điện thoại đọc vỡ ở đầu không được làm tên quán.
    expect(r.merchantName, isNull);
  });

  test('🚨 Hội An — "Tổng SL:" KHÔNG phải tiêu đề cột; tên hai hàng ghép lại; '
      'tiền đọc vỡ ("150.0") thì món vẫn có, ô tiền trống', () {
    final r = _read('real_hoian_mask.txt');
    expect(r.items, hasLength(1));
    expect(r.items.single.name, 'KHẨU TRANG Y TẾ');
    expect(r.items.single.amountMinor, isNull);
    expect(r.amountMinor, 150000);
    expect(r.merchantName, isNull, reason: 'tên quán bị làm mờ trong ảnh');
  });

  test('🚨 nhà hàng (ngón tay che cột tiền) — món bị che vẫn vào bảng với ô '
      'tiền trống; tổng "1.542" bị cắt bị loại', () {
    final r = _read('real_restaurant_buffet.txt');
    expect(r.items.map((i) => i.name), [
      'SET Phúc An Khang',
      'Vé BFLine HT',
      'Buffet đö uống (HT)',
      'Khoai môn',
      'Nãm vị cua nàu',
      'Cải bó xôi',
      'Rong bin vàng có hoa (ALC)',
      'Bắp lõi cỡ bò Wagyu 100g',
      'Muc nút',
      'Bach tuỘc baby',
    ]);
    expect(r.items.where((i) => i.amountMinor == null), hasLength(4));
    // "Người lớn  4  0" (thành tiền 0) không thành món.
    expect(r.items.map((i) => i.name), isNot(contains('Nguời lớn')));
    // Giới hạn đã biết: tổng thật 1.542.240 bị ngón tay che; lấy được số
    // TRƯỚC VAT còn đọc được, không phải 1.542đ.
    expect(r.amountMinor, 1428000);
    expect(r.merchantName, isNull);
  });

  test('🚨 WinMart — "0.346" (cân nặng) KHÔNG thành 346đ; phải trả 68.097 '
      '(voucher) được giữ dù nhỏ hơn món đắt nhất', () {
    final r = _read('real_winmart.txt');
    expect(r.amountMinor, 68097);
    expect(r.merchantName, 'WinMart');
    expect(r.items, hasLength(6));
    expect(r.items.every((i) => (i.amountMinor ?? 0) >= 1000), isTrue);
    // Giới hạn đã biết: OCR đọc "16,954" thành "16 954" và "54,863" thành
    // "54 B63", nên hai món lấy nhầm ĐƠN GIÁ (58.000, 149.900). 4/6 món
    // đúng; tổng các món lệch tổng hoá đơn → dòng tổng trong form tô đỏ để
    // Tony sửa.
    expect(
      [for (final i in r.items) i.amountMinor],
      [58000, 65844, 149900, 120018, 96004, 113514],
    );
  });
}
