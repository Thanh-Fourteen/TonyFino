import 'package:flutter/services.dart';

/// Chèn dấu chấm phân nhóm nghìn NGAY TRONG Ô NHẬP, kiểu vi-VN: gõ
/// `500000` thấy `500.000`.
///
/// Vì sao cần: mọi chỗ HIỂN THỊ tiền đã đi qua `Money.format()` nên luôn có
/// dấu phân nhóm, nhưng ô NHẬP thì trước đây chỉ có
/// `FilteringTextInputFormatter.digitsOnly` — người dùng nhìn một dãy số
/// trần `43220000` và phải tự đếm số 0. Đúng chỗ Tony kêu "ghi 500000 khó
/// đếm số 0", và đây cũng là chỗ đếm sai gây hậu quả nặng nhất: nhập lệch
/// một chữ số 0 là sai gấp mười.
///
/// Chỉ đụng phần HIỂN THỊ. Mọi nơi đọc giá trị phải gọi [digitsOf] để lấy
/// lại chuỗi số trần trước khi `int.parse` — chuỗi có dấu chấm sẽ làm
/// `int.parse` ném lỗi.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = digitsOf(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final grouped = groupDigits(digits);

    // Giữ con trỏ theo SỐ CHỮ SỐ đứng trước nó, không theo vị trí ký tự:
    // chèn thêm một dấu chấm làm mọi ký tự phía sau dịch phải, nếu neo theo
    // vị trí ký tự thì con trỏ tự nhảy lùi một ô mỗi lần vượt mốc nghìn.
    final digitsBeforeCursor = digitsOf(
      newValue.text.substring(
        0,
        newValue.selection.baseOffset.clamp(0, newValue.text.length),
      ),
    ).length;
    var offset = grouped.length;
    var seen = 0;
    for (var i = 0; i < grouped.length; i++) {
      if (grouped[i] != '.') seen++;
      if (seen == digitsBeforeCursor) {
        offset = i + 1;
        break;
      }
    }
    if (digitsBeforeCursor == 0) offset = 0;

    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Bỏ mọi ký tự không phải chữ số — dùng trước khi `int.parse`.
String digitsOf(String text) => text.replaceAll(RegExp(r'[^0-9]'), '');

/// `1234567` → `1.234.567`. Đầu vào phải là chuỗi chữ số trần.
String groupDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
