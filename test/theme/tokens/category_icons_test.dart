// Bộ icon danh mục: ba bảng (`categoryIconByCode`, `categoryIcon3dByCode`,
// `categoryIconGroups`) phải luôn khớp nhau và có file thật trên đĩa.
//
// 🚨 Vì sao cần test này: `resolveCategoryIcon3d` trả về `question_mark.png`
// cho mã KHÔNG có trong bảng 3D — mà file đó TỒN TẠI, nên `Image.asset`
// không lỗi và `errorBuilder` (đường lùi về glyph đơn sắc) không bao giờ
// chạy. Thêm một icon mà quên file 3D thì nó hiện thành DẤU HỎI ở mọi màn,
// im lặng, không test nào khác bắt được.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/theme/tokens/icons.dart';

void main() {
  test('mọi iconCode đều có một file 3D thật', () {
    final missing = <String>[];
    for (final code in categoryIconByCode.keys) {
      final path = categoryIcon3dByCode[code];
      if (path == null || !File(path).existsSync()) missing.add(code);
    }
    expect(missing, isEmpty, reason: 'thiếu file 3D → hiện dấu hỏi trên app');
  });

  test('bảng 3D không có mã thừa', () {
    expect(
      categoryIcon3dByCode.keys.toSet().difference(
        categoryIconByCode.keys.toSet(),
      ),
      isEmpty,
    );
  });

  test('bộ chọn phủ ĐỦ mọi mã, mỗi mã đúng một nhóm', () {
    final grouped = [for (final g in categoryIconGroups) ...g.codes];
    expect(
      grouped.toSet(),
      categoryIconByCode.keys.toSet(),
      reason: 'mã không nằm nhóm nào thì không chọn được từ giao diện',
    );
    expect(
      grouped.length,
      grouped.toSet().length,
      reason: 'một mã hiện ở hai nhóm là hai nút cùng nghĩa',
    );
  });

  test('mọi iconCode đều resolve được glyph (không rơi về dấu hỏi)', () {
    for (final code in categoryIconByCode.keys) {
      expect(resolveCategoryIcon(code), isNot(kIconQuestionMark), reason: code);
    }
  });
}
