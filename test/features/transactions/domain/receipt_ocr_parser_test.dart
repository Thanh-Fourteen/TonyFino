// Trích merchant + tổng tiền từ văn bản OCR thô — test bằng văn bản MÔ
// PHỎNG kết quả ML Kit trả về cho hoá đơn Việt Nam thật (quán ăn/siêu thị),
// KHÔNG cần chạy OCR thật/thiết bị thật (đó là việc của xác minh trên thiết
// bị, xem docs/decisions.md § Phase 18) — bài test này chỉ chứng minh LUẬT
// trích xuất đúng khi đã có văn bản, tách biệt khỏi engine OCR đúng kỷ luật
// `category_matcher.dart` (Phase 7).
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/transactions/domain/receipt_ocr_parser.dart';

/// Mốc "bây giờ" cố định — ngày trên hoá đơn được so với nó (không
/// `DateTime.now()`, luật Clock).
final _now = DateTime(2026, 9, 28, 15, 30);

void main() {
  test(
    'hoá đơn quán ăn — merchant là dòng đầu, tổng tiền theo nhãn "Tổng cộng"',
    () {
      const ocrText = '''
QUÁN CƠM TẤM SƯỜN BÌ CHẢ
123 Nguyễn Trãi, Q.1, TP.HCM
--------------------------
Cơm sườn bì chả      x2    70.000
Trà đá               x2     4.000
--------------------------
Tổng cộng:                 74.000
Cảm ơn quý khách!
''';
      final result = extractReceiptInfo(ocrText, now: _now);
      expect(result.merchantName, 'QUÁN CƠM TẤM SƯỜN BÌ CHẢ');
      expect(result.amountMinor, 74000);
    },
  );

  test(
    '🚨 hoá đơn siêu thị — nhãn "Thành tiền" (tổng THẬT) được ưu tiên hơn "Tiền khách '
    'đưa"/"Tiền thối lại" dù hai số đó LỚN HƠN, không phải cứ số lớn nhất là đúng',
    () {
      const ocrText = '''
CO.OP MART
Số HĐ: 0012345
Sữa tươi Vinamilk 1L      35.000
Bánh mì sandwich          18.500
Trứng gà (10 quả)         32.000
--------------------------------
Thành tiền:               85.500
Tiền khách đưa            100.000
Tiền thối lại             14.500
''';
      final result = extractReceiptInfo(ocrText, now: _now);
      expect(result.merchantName, 'CO.OP MART');
      expect(
        result.amountMinor,
        85500,
        reason:
            'phải khớp đúng dòng "Thành tiền", không phải 100.000 (số lớn nhất trên hoá đơn)',
      );
    },
  );

  test(
    'nhãn "TOTAL" tiếng Anh vẫn khớp được (một số quán/app POS in tiếng Anh)',
    () {
      const ocrText = '''
HIGHLANDS COFFEE
Ca phe sua da           29,000
Banh croissant          35,000
TOTAL                   64,000
''';
      final result = extractReceiptInfo(ocrText, now: _now);
      expect(result.amountMinor, 64000);
    },
  );

  test(
    'nhiều dòng khớp nhãn "tổng" (vd tổng tiền hàng RỒI tổng thanh toán sau khi trừ '
    'giảm giá) → lấy dòng khớp CUỐI CÙNG, không phải dòng đầu tiên',
    () {
      const ocrText = '''
SIÊU THỊ ABC
Tổng tiền hàng:            120.000
Giảm giá:                  -20.000
Tổng thanh toán:           100.000
''';
      final result = extractReceiptInfo(ocrText, now: _now);
      expect(result.amountMinor, 100000);
    },
  );

  test(
    'không dòng nào khớp nhãn "tổng" → lùi về số LỚN NHẤT toàn hoá đơn (kém tin cậy '
    'hơn nhưng vẫn là một gợi ý hợp lý, Tony luôn xác nhận lại)',
    () {
      const ocrText = '''
CAFE HIGHLANDS
Cà phê sữa đá         29.000
Bánh croissant        35.000
''';
      final result = extractReceiptInfo(ocrText, now: _now);
      expect(result.amountMinor, 35000);
    },
  );

  test(
    'số không có dấu phân cách nghìn (in liền, không chấm/phẩy) vẫn nhận diện được',
    () {
      const ocrText = '''
QUAN AN NHANH
Com tam suon         45000
Tong cong            45000
''';
      final result = extractReceiptInfo(ocrText, now: _now);
      expect(result.amountMinor, 45000);
    },
  );

  test('văn bản rỗng → cả hai trường null, không lỗi', () {
    final result = extractReceiptInfo('', now: _now);
    expect(result.merchantName, null);
    expect(result.amountMinor, null);
  });

  test('văn bản chỉ toàn khoảng trắng/xuống dòng → cả hai trường null', () {
    final result = extractReceiptInfo('   \n\n   \n', now: _now);
    expect(result.merchantName, null);
    expect(result.amountMinor, null);
  });

  test(
    'văn bản không có số nào (OCR hỏng hoàn toàn) → merchant vẫn có, amount null',
    () {
      const ocrText = '''
QUÁN ĂN VẶT
xxx yyy zzz không đọc được
''';
      final result = extractReceiptInfo(ocrText, now: _now);
      expect(result.merchantName, 'QUÁN ĂN VẶT');
      expect(result.amountMinor, null);
    },
  );

  group('tổng tiền theo TẦNG nhãn', () {
    test('🚨 nhãn tổng in CUỐI thắng — "Tổng cộng" trước VAT, "Tổng" sau '
        'VAT (hoá đơn nhà hàng THẬT)', () {
      const ocrText = '''
Bạch tuộc baby          1       99.000
Tổng cộng:                   1.428.000
VAT:                           114.240
Tổng:                        1.542.240
''';
      expect(extractReceiptInfo(ocrText, now: _now).amountMinor, 1542240);
    });

    test('"Tiền cần thanh toán" sau "TỔNG TIỀN" (voucher trừ bớt) — số phải '
        'trả thật (hoá đơn WinMart THẬT)', () {
      const ocrText = '''
TỔNG TIỀN               -3,460     468,097
Khấu trừ, ưu đãi khác              400,000
Tiền cần thanh toán                 68,097
''';
      expect(extractReceiptInfo(ocrText, now: _now).amountMinor, 68097);
    });

    test('nhãn "Tổng:" trần, "Tổng SL: 3" không phải tiền (hoá đơn THẬT)', () {
      const ocrText = '''
KHẨU TRANG Y TẾ        3      150.000
Tổng SL:                            3
Tổng:                         150.000
''';
      expect(extractReceiptInfo(ocrText, now: _now).amountMinor, 150000);
    });

    test('"Thành tiền" (tạm tính) thua nhãn tổng thật dù in sau', () {
      const ocrText = '''
NHÀ HÀNG BIỂN XANH
Tổng cộng                  450.000
Thành tiền món thêm         50.000
''';
      expect(extractReceiptInfo(ocrText, now: _now).amountMinor, 450000);
    });

    test('"Tổng tiền hàng" (tạm tính) KHÔNG bị coi là "Tổng tiền" — nhãn dài '
        'nhất quyết định', () {
      const ocrText = '''
BÁCH HOÁ GẦN NHÀ
Tổng tiền                   95.000
Tổng tiền hàng             120.000
''';
      expect(extractReceiptInfo(ocrText, now: _now).amountMinor, 95000);
    });

    test('"Tổng cộng (đã gồm VAT)" vẫn là tổng — nhãn tầng 3 không bị loại vì '
        'chữ VAT', () {
      const ocrText = '''
PIZZA 4P
Tiền thuế VAT               32.000
Tổng cộng (đã gồm VAT)     352.000
''';
      expect(extractReceiptInfo(ocrText, now: _now).amountMinor, 352000);
    });

    test('"Tổng tiền thuế" KHÔNG phải tổng phải trả', () {
      const ocrText = '''
CỬA HÀNG X
Tổng tiền                  200.000
Tổng tiền thuế              16.000
''';
      expect(extractReceiptInfo(ocrText, now: _now).amountMinor, 200000);
    });

    test(
      '🚨 không có nhãn tổng → nhánh "số lớn nhất" bỏ qua "Tiền khách đưa"',
      () {
        const ocrText = '''
QUÁN NƯỚC
Trà sữa                     35.000
Bánh flan                   15.000
Tiền khách đưa             100.000
''';
        expect(extractReceiptInfo(ocrText, now: _now).amountMinor, 35000);
      },
    );

    test('nhãn và số bị máy in tách hai hàng → lấy số ở hàng ngay dưới', () {
      const ocrText = '''
CIRCLE K
Mì ly                       12.000
TỔNG THANH TOÁN
                            27.000 VND
''';
      expect(extractReceiptInfo(ocrText, now: _now).amountMinor, 27000);
    });

    test('"subtotal" không bị khớp thành "total"', () {
      const ocrText = '''
THE COFFEE HOUSE
Subtotal                    90,000
Discount                    10,000
Total                       80,000
''';
      expect(extractReceiptInfo(ocrText, now: _now).amountMinor, 80000);
    });

    test('chữ O/o/l/I đọc nhầm trong cụm số được sửa thành 0/1', () {
      const ocrText = '''
QUÁN PHỞ
Tổng cộng                  l2O.OOO
Lon nước                    1O.OOO
''';
      expect(extractReceiptInfo(ocrText, now: _now).amountMinor, 120000);
    });

    test('🚨 chữ TOTAL trong TÊN MÓN không phải nhãn tổng (Lotte THẬT)', () {
      const ocrText = '''
Ma sp  dgia  sl  so tien
009 Pin Energizer E91 AA
8888021200126  55,000  1  55,000
010 KDR TOTAL GUM 100G+BCDR
8935102105273  40,500  1  40,500
011 GOI BONG TAY TRANG P
8936002690005  20,500  1  20,500
''';
      final r = extractReceiptInfo(ocrText, now: _now);
      // Không có dòng tổng thật → dự phòng số lớn nhất, KHÔNG phải 40.500.
      expect(r.amountMinor, 55000);
      // Bảng món không bị cắt cụt ở món có chữ TOTAL.
      expect(r.items, hasLength(3));
      expect(r.items[1].name, 'KDR TOTAL GUM 100G+BCDR');
    });

    test('ảnh chụp chuyển khoản — nhãn "Số tiền"', () {
      const ocrText = '''
Chuyển tiền thành công
Số tiền                -250,000 VND
Nội dung               tien an trua
''';
      expect(extractReceiptInfo(ocrText, now: _now).amountMinor, 250000);
    });
  });

  group('ngày trên hoá đơn', () {
    test('dd/mm/yyyy kèm giờ cùng dòng → đúng ngày giờ', () {
      const ocrText = '''
QUÁN A
Ngày: 25/09/2026 12:45
Tổng cộng                   74.000
''';
      expect(
        extractReceiptInfo(ocrText, now: _now).occurredAt,
        DateTime(2026, 9, 25, 12, 45),
      );
    });

    test(
      'không có giờ → giữ giờ hiện tại (như form vẫn làm với "hôm nay")',
      () {
        const ocrText = 'QUÁN A\nNgày 20-09-2026\nTổng cộng 74.000';
        expect(
          extractReceiptInfo(ocrText, now: _now).occurredAt,
          DateTime(2026, 9, 20, 15, 30),
        );
      },
    );

    test('hoá đơn điện tử "Ngày 23 tháng 08 năm 2026"', () {
      const ocrText = '''
HOÁ ĐƠN GIÁ TRỊ GIA TĂNG
Ngày 23 tháng 08 năm 2026
Tổng tiền thanh toán       1.250.000
''';
      expect(
        extractReceiptInfo(ocrText, now: _now).occurredAt,
        DateTime(2026, 8, 23, 15, 30),
      );
    });

    test('năm hai chữ số và ISO yyyy-mm-dd', () {
      expect(
        extractReceiptInfo('A\n27/09/26 08:05', now: _now).occurredAt,
        DateTime(2026, 9, 27, 8, 5),
      );
      expect(
        extractReceiptInfo('A\n2026-09-26 19:00', now: _now).occurredAt,
        DateTime(2026, 9, 26, 19),
      );
    });

    test('🚨 hạn sử dụng (ngày TƯƠNG LAI) trên dòng hàng bị bỏ qua', () {
      const ocrText = '''
SIÊU THỊ
Sữa chua HSD 15/12/2026      8.000
Ngày bán 27/09/2026
''';
      expect(
        extractReceiptInfo(ocrText, now: _now).occurredAt,
        DateTime(2026, 9, 27, 15, 30),
      );
    });

    test('dòng có nhãn ngày thắng ngày không nhãn đứng trước', () {
      const ocrText = '''
QUÁN A
Mã 01/09/2026
Ngày: 26/09/2026
''';
      expect(extractReceiptInfo(ocrText, now: _now).occurredAt?.day, 26);
    });

    test('ngày không có thật (31/02) và ngày quá một năm → null', () {
      expect(extractReceiptInfo('A\n31/02/2026', now: _now).occurredAt, null);
      expect(extractReceiptInfo('A\n01/01/2024', now: _now).occurredAt, null);
    });

    test(
      'hoá đơn hôm nay in giờ muộn hơn bây giờ (đồng hồ POS lệch) → bây giờ',
      () {
        expect(
          extractReceiptInfo('A\n28/09/2026 23:10', now: _now).occurredAt,
          _now,
        );
      },
    );

    test('giá tiền "1.250.000" không bị đọc thành ngày', () {
      expect(
        extractReceiptInfo('A\nTổng cộng 1.250.000', now: _now).occurredAt,
        null,
      );
    });
  });

  group('tên cửa hàng', () {
    test('bỏ qua dòng web/điện thoại/địa chỉ/tiêu đề chứng từ ở đầu', () {
      const ocrText = '''
HOÁ ĐƠN BÁN LẺ
www.phuclong.com.vn
Hotline: 1800 6779
PHÚC LONG COFFEE & TEA
''';
      expect(
        extractReceiptInfo(ocrText, now: _now).merchantName,
        'PHÚC LONG COFFEE & TEA',
      );
    });

    test('gọt viền trang trí nhưng GIỮ chữ có dấu', () {
      expect(
        extractReceiptInfo('*** QUÁN ĂN Ở ĐÂY ***', now: _now).merchantName,
        'QUÁN ĂN Ở ĐÂY',
      );
    });

    test('"Hotel" không bị loại vì chứa "tel"', () {
      expect(
        extractReceiptInfo(
          'LIBERTY HOTEL SAIGON\nTel: 028 1234',
          now: _now,
        ).merchantName,
        'LIBERTY HOTEL SAIGON',
      );
    });

    test('không dòng nào giống tên quán → null, không đoán bừa', () {
      expect(
        extractReceiptInfo(
          '0901234567\nMST: 0316940306',
          now: _now,
        ).merchantName,
        null,
      );
    });
  });
}
