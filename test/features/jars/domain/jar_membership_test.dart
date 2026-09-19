import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/jars/domain/jar_membership.dart';

void main() {
  const thietYeu = 1;
  const huongThu = 2;

  group('jarMembership', () {
    test('danh mục gốc: thẳng / ở hũ khác / không hũ nào', () {
      expect(
        jarMembership(jarId: thietYeu, ownJarId: thietYeu, parentJarId: null),
        JarMembership.direct,
      );
      expect(
        jarMembership(jarId: thietYeu, ownJarId: huongThu, parentJarId: null),
        JarMembership.elsewhere,
      );
      expect(
        jarMembership(jarId: thietYeu, ownJarId: null, parentJarId: null),
        JarMembership.none,
      );
    });

    test('con chưa xếp riêng thì theo cha', () {
      expect(
        jarMembership(jarId: thietYeu, ownJarId: null, parentJarId: thietYeu),
        JarMembership.inherited,
      );
      expect(
        jarMembership(jarId: huongThu, ownJarId: null, parentJarId: thietYeu),
        JarMembership.elsewhere,
      );
    });

    test('con xếp riêng sang hũ khác thì KHÔNG còn thuộc hũ của cha', () {
      expect(
        jarMembership(
          jarId: thietYeu,
          ownJarId: huongThu,
          parentJarId: thietYeu,
        ),
        JarMembership.elsewhere,
      );
      expect(
        jarMembership(
          jarId: huongThu,
          ownJarId: huongThu,
          parentJarId: thietYeu,
        ),
        JarMembership.direct,
      );
    });
  });

  group('jarIdAfterToggle', () {
    test('tick con mà cha đã ở hũ này → thừa hưởng (null), không chép id', () {
      expect(
        jarIdAfterToggle(
          jarId: thietYeu,
          checked: true,
          ownJarId: huongThu,
          parentJarId: thietYeu,
        ),
        isNull,
      );
    });

    test('tick con vào hũ khác cha → xếp riêng', () {
      expect(
        jarIdAfterToggle(
          jarId: huongThu,
          checked: true,
          ownJarId: null,
          parentJarId: thietYeu,
        ),
        huongThu,
      );
    });

    test('bỏ tick chỉ gỡ dây nối tới ĐÚNG hũ đang mở', () {
      expect(
        jarIdAfterToggle(
          jarId: huongThu,
          checked: false,
          ownJarId: huongThu,
          parentJarId: thietYeu,
        ),
        isNull,
      );
      expect(
        jarIdAfterToggle(
          jarId: huongThu,
          checked: false,
          ownJarId: thietYeu,
          parentJarId: null,
        ),
        thietYeu,
      );
    });
  });

  test('categoryIdsInJar khớp đúng công thức COALESCE(con, cha)', () {
    final cats = [
      (id: 10, parentCategoryId: null, jarId: thietYeu), // Ăn uống
      (id: 11, parentCategoryId: 10, jarId: null), // Ăn trưa — theo cha
      (id: 12, parentCategoryId: 10, jarId: huongThu), // Giao lưu — tách
      (id: 20, parentCategoryId: null, jarId: null), // Giải trí
      (id: 21, parentCategoryId: 20, jarId: thietYeu), // con tách vào
    ];
    expect(categoryIdsInJar(cats, thietYeu), {10, 11, 21});
    expect(categoryIdsInJar(cats, huongThu), {12});
  });
}
