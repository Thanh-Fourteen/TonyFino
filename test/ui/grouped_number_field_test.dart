import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/ui/grouped_number_field.dart';

void main() {
  const f = ThousandsSeparatorInputFormatter();

  TextEditingValue type(String before, String after, int cursor) =>
      f.formatEditUpdate(
        TextEditingValue(text: before),
        TextEditingValue(
          text: after,
          selection: TextSelection.collapsed(offset: cursor),
        ),
      );

  test('groupDigits chèn dấu chấm mỗi 3 chữ số từ PHẢI sang', () {
    expect(groupDigits('1'), '1');
    expect(groupDigits('999'), '999');
    expect(groupDigits('1000'), '1.000');
    expect(groupDigits('500000'), '500.000');
    expect(groupDigits('43220000'), '43.220.000');
    expect(groupDigits(''), '');
  });

  test(
    'digitsOf bóc sạch dấu phân nhóm — chuỗi này mới đem int.parse được',
    () {
      expect(digitsOf('43.220.000'), '43220000');
      expect(int.parse(digitsOf('500.000')), 500000);
      expect(digitsOf(''), '');
    },
  );

  test('gõ thêm một chữ số vượt mốc nghìn → có dấu chấm, không mất chữ số', () {
    final r = type('999', '9999', 4);
    expect(r.text, '9.999');
  });

  test('🚨 con trỏ neo theo SỐ CHỮ SỐ đứng trước, không theo vị trí ký tự', () {
    // Gõ chữ số thứ 4 của "9999": trước con trỏ có 4 chữ số. Trong
    // "9.999" chữ số thứ 4 nằm ở index 4, nên con trỏ phải ở 5 — nếu neo
    // theo offset cũ (4) con trỏ rơi vào GIỮA "99" cuối và chữ số gõ tiếp
    // sẽ chèn sai chỗ.
    final r = type('999', '9999', 4);
    expect(r.selection.baseOffset, 5);
    expect(digitsOf(r.text.substring(0, r.selection.baseOffset)).length, 4);
  });

  test('sửa GIỮA chuỗi: con trỏ vẫn đứng sau đúng chữ số vừa gõ', () {
    // "500.000" → chèn "9" sau chữ số thứ 2 → "5900000" → "5.900.000".
    final r = type('500.000', '5900.000', 2);
    expect(r.text, '5.900.000');
    expect(digitsOf(r.text.substring(0, r.selection.baseOffset)).length, 2);
  });

  test('xoá sạch → ô rỗng, KHÔNG để lại dấu chấm mồ côi', () {
    final r = type('1.000', '', 0);
    expect(r.text, '');
  });

  test('dán chuỗi có chữ và ký tự lạ → chỉ giữ chữ số', () {
    final r = type('', '1a2b3c000đ', 10);
    expect(r.text, '123.000');
  });
}
