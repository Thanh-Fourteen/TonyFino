import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/data/services/backup/backup_encryption.dart';

void main() {
  const encryption = BackupEncryption();

  test('mã hoá rồi giải mã đúng mật khẩu → ra lại đúng bytes gốc', () async {
    final plaintext = Uint8List.fromList(utf8.encode('{"ví":1000000}'));
    final envelope = await encryption.encrypt(plaintext, 'mật khẩu của Tony');

    final result = await encryption.decrypt(envelope, 'mật khẩu của Tony');

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, plaintext);
  });

  test('🚨 sai mật khẩu → Err, KHÔNG ném exception, KHÔNG trả rác', () async {
    final plaintext = Uint8List.fromList(utf8.encode('dữ liệu nhạy cảm'));
    final envelope = await encryption.encrypt(plaintext, 'đúng');

    final result = await encryption.decrypt(envelope, 'sai');

    expect(result.isErr, isTrue);
  });

  test('mỗi lần mã hoá dùng salt/nonce khác nhau — hai bản mã của CÙNG một '
      'plaintext KHÔNG giống nhau', () async {
    final plaintext = Uint8List.fromList(utf8.encode('lặp lại'));

    final a = await encryption.encrypt(plaintext, 'cùng mật khẩu');
    final b = await encryption.encrypt(plaintext, 'cùng mật khẩu');

    expect(a, isNot(equals(b)));
    // Nhưng cả hai vẫn giải mã đúng về cùng plaintext.
    expect((await encryption.decrypt(a, 'cùng mật khẩu')).valueOrNull, plaintext);
    expect((await encryption.decrypt(b, 'cùng mật khẩu')).valueOrNull, plaintext);
  });

  test('file rác/hỏng (không phải envelope hợp lệ) → Err, không crash', () async {
    final garbage = Uint8List.fromList(List.generate(5, (i) => i));

    final result = await encryption.decrypt(garbage, 'bất kỳ');

    expect(result.isErr, isTrue);
  });
}
