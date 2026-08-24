// Trích merchant + tổng tiền từ văn bản OCR thô — test bằng văn bản MÔ
// PHỎNG kết quả ML Kit trả về cho hoá đơn Việt Nam thật (quán ăn/siêu thị),
// KHÔNG cần chạy OCR thật/thiết bị thật (đó là việc của xác minh trên thiết
// bị, xem docs/decisions.md § Phase 18) — bài test này chỉ chứng minh LUẬT
// trích xuất đúng khi đã có văn bản, tách biệt khỏi engine OCR đúng kỷ luật
// `category_matcher.dart` (Phase 7).
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/transactions/domain/receipt_ocr_parser.dart';

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
      final result = extractReceiptInfo(ocrText);
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
      final result = extractReceiptInfo(ocrText);
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
      final result = extractReceiptInfo(ocrText);
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
      final result = extractReceiptInfo(ocrText);
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
      final result = extractReceiptInfo(ocrText);
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
      final result = extractReceiptInfo(ocrText);
      expect(result.amountMinor, 45000);
    },
  );

  test('văn bản rỗng → cả hai trường null, không lỗi', () {
    final result = extractReceiptInfo('');
    expect(result.merchantName, null);
    expect(result.amountMinor, null);
  });

  test('văn bản chỉ toàn khoảng trắng/xuống dòng → cả hai trường null', () {
    final result = extractReceiptInfo('   \n\n   \n');
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
      final result = extractReceiptInfo(ocrText);
      expect(result.merchantName, 'QUÁN ĂN VẶT');
      expect(result.amountMinor, null);
    },
  );
}
