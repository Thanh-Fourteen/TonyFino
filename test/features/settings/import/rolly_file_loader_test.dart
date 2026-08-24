import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/settings/import/domain/rolly_file_loader.dart';

void main() {
  test('mảng trần → inputRows đúng, categoryTitleById rỗng', () {
    final bytes = utf8.encode(
      jsonEncode([
        {'id': 1, 'type': 'Expense'},
      ]),
    );
    final loaded = decodeRollyImportFile(bytes);
    expect(loaded.inputRows, hasLength(1));
    expect(loaded.categoryTitleById, isEmpty);
  });

  test('object gộp {input, category_view} → cả hai đọc đúng', () {
    final bytes = utf8.encode(
      jsonEncode({
        'input': [
          {'id': 1, 'type': 'Expense'},
        ],
        'category_view': [
          {'id': 501, 'title': 'Ăn uống'},
        ],
      }),
    );
    final loaded = decodeRollyImportFile(bytes);
    expect(loaded.inputRows, hasLength(1));
    expect(loaded.categoryTitleById, {501: 'Ăn uống'});
  });

  test('object thiếu category_view vẫn đọc được input, chỉ thiếu tên đẹp', () {
    final bytes = utf8.encode(
      jsonEncode({
        'input': [
          {'id': 1, 'type': 'Expense'},
        ],
      }),
    );
    final loaded = decodeRollyImportFile(bytes);
    expect(loaded.inputRows, hasLength(1));
    expect(loaded.categoryTitleById, isEmpty);
  });

  test('không phải JSON → RollyFileFormatException rõ ràng', () {
    expect(
      () => decodeRollyImportFile(utf8.encode('không phải json')),
      throwsA(isA<RollyFileFormatException>()),
    );
  });

  test('object thiếu key "input" → RollyFileFormatException rõ ràng', () {
    final bytes = utf8.encode(jsonEncode({'foo': 'bar'}));
    expect(
      () => decodeRollyImportFile(bytes),
      throwsA(isA<RollyFileFormatException>()),
    );
  });

  test('MỘT file gộp cả 4 mảng được CẢ BA decoder chấp nhận — hợp đồng cho '
      '"tải một file, dùng cho cả ba bước import"', () {
    // Nỗi đau thật: trước đây Tony phải tải 3 file JSON riêng về điện thoại
    // (1.1 MB) rồi chọn đúng file cho đúng nút, đúng thứ tự. Ba decoder chỉ
    // đọc key riêng của mình và bỏ qua key lạ, nên một file gộp thoả cả ba
    // — test này khoá tính chất đó lại để không ai vô tình siết decoder
    // thành "chỉ chấp nhận đúng những key này".
    final bytes = utf8.encode(
      jsonEncode({
        'input': [
          {
            'id': 1,
            'type': 'Expense',
            'amount': 35000.0,
            'date': '2026-05-10',
            'item': 'cà phê',
            'category_id': 7,
          },
        ],
        'category_view': [
          {'id': 7, 'title': 'Ăn uống'},
        ],
        'subcategory': [
          {'id': 70, 'title': 'Tiêu vặt', 'category_id': 7},
        ],
        'savings': [
          {'id': 900, 'title': 'CCTG', 'amount': 43200000.0},
        ],
      }),
    );

    final main = decodeRollyImportFile(bytes);
    expect(main.inputRows, hasLength(1));
    expect(main.categoryTitleById[7], 'Ăn uống');

    final sub = decodeRollySubcategoryImportFile(bytes);
    expect(sub.subcategoryRows, hasLength(1));
    expect(sub.inputRows, hasLength(1));

    final savings = decodeRollySavingsImportFile(bytes);
    expect(savings.savingsRows, hasLength(1));
    expect(savings.inputRows, hasLength(1));
  });
}
