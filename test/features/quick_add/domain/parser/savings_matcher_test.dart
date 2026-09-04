// `savings_matcher.dart` — nhận ra "cất vào / rút ra khỏi mục tiêu tiết kiệm"
// trong câu chat, và (quan trọng hơn) KHÔNG nhận nhầm câu chi tiêu thường.
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/features/quick_add/domain/parser/parse_result.dart';
import 'package:tonyfino/features/quick_add/domain/parser/savings_matcher.dart';

SavingsTargetEntry _target(String key, String name, String ascii) =>
    SavingsTargetEntry(goalKey: key, name: name, nameAscii: ascii);

final _oneGoal = [_target('1', 'Mua nhà', 'mua nha')];
final _twoGoals = [
  _target('1', 'Mua nhà', 'mua nha'),
  _target('2', 'Du lịch Nhật', 'du lich nhat'),
];

void main() {
  group('nhận ra ý định để dành', () {
    test('"chuyen vao tiet kiem" + đúng một mục tiêu → mục tiêu đó', () {
      final match = matchSavings('chuyen vao tiet kiem', _oneGoal);
      expect(match, isNotNull);
      expect(match!.goalKey, '1');
      expect(match.isWithdrawal, isFalse);
    });

    test('gọi thẳng TÊN mục tiêu thì nhiều mục tiêu vẫn chọn đúng', () {
      final match = matchSavings('chuyen vao quy du lich nhat', _twoGoals);
      expect(match?.goalKey, '2');
    });

    test('"de danh" một mình cũng là ý định (không cần động từ)', () {
      expect(matchSavings('de danh', _oneGoal)?.goalKey, '1');
    });

    test('"rut ra khoi tiet kiem" → rút, không phải cất', () {
      final match = matchSavings('rut ra khoi tiet kiem', _oneGoal);
      expect(match?.isWithdrawal, isTrue);
    });

    test('tên dài thắng tên ngắn khi cả hai cùng xuất hiện', () {
      final targets = [
        _target('1', 'Nhật', 'nhat'),
        _target('2', 'Du lịch Nhật', 'du lich nhat'),
      ];
      expect(matchSavings('chuyen vao du lich nhat', targets)?.goalKey, '2');
    });
  });

  group('🚨 KHÔNG nhận nhầm khoản chi thường', () {
    test('câu chi tiêu bình thường', () {
      expect(matchSavings('ca phe sang', _oneGoal), isNull);
      expect(matchSavings('an trua voi tee', _oneGoal), isNull);
    });

    test('"chuyen khoan tien nha" — có động từ nhưng không có đích', () {
      expect(
        matchSavings('chuyen khoan tien nha', [_target('1', 'Nhà', 'nha')]),
        isNull,
        reason: 'tên mục tiêu 3 ký tự không được tự nó làm bằng chứng',
      );
    });

    test('tên mục tiêu ngắn vẫn dùng được KHI câu đã nói "tiết kiệm"', () {
      expect(
        matchSavings('chuyen vao tiet kiem nha', [_target('1', 'Nhà', 'nha')])
            ?.goalKey,
        '1',
      );
    });

    test('nói "tiết kiệm" nhưng có HAI mục tiêu → không đoán bừa', () {
      expect(matchSavings('chuyen vao tiet kiem', _twoGoals), isNull);
    });

    test('sổ chưa có mục tiêu nào → không bao giờ khớp', () {
      expect(matchSavings('chuyen vao tiet kiem', const []), isNull);
    });

    test('khớp theo TỪ, không phải substring', () {
      expect(
        matchSavings('chuyen vao mua nhang', _oneGoal),
        isNull,
        reason: '"mua nha" không được khớp vào giữa "mua nhang"',
      );
    });
  });
}
