import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../core/result/result.dart';

/// Mã hoá/giải mã file backup bằng mật khẩu người dùng tự đặt — CHỈ dùng cho
/// đích rời khỏi máy (Google Drive), KHÔNG áp cho SAF/share nội bộ (JSON
/// thường vẫn ổn khi file nằm trên chính máy của Tony).
///
/// `appDataFolder` của Drive là khu vực riêng tư (chỉ app này trên đúng tài
/// khoản Google đọc được), nhưng vẫn là hạ tầng của bên thứ ba — mã hoá thêm
/// một lớp để tài khoản Google bị chiếm cũng không lộ được dữ liệu tài chính.
/// Quên mật khẩu backup là MẤT VĨNH VIỄN bản backup đó — không có cách khôi
/// phục nào khác, kể cả từ phía nhà phát triển (không ai giữ mật khẩu này).
///
/// Định dạng "envelope" (mọi phần cần để giải mã đi kèm ngay trong file,
/// không cần lưu gì riêng): `[version:1][salt:16][nonce:12][mac:16][ciphertext:...]`.
class BackupEncryption {
  const BackupEncryption();

  static const _version = 1;
  static const _saltLength = 16;

  /// Tham số Argon2id theo khuyến nghị OWASP cho dùng tương tác trên di động
  /// (m=19MiB, t=2, p=1) — đủ chậm để chống dò mật khẩu vét cạn, đủ nhanh để
  /// không làm người dùng chờ lâu trên điện thoại.
  Argon2id _kdf() => Argon2id(
    memory: 19456,
    iterations: 2,
    parallelism: 1,
    hashLength: 32,
  );

  Future<SecretKey> _deriveKey(String passphrase, Uint8List salt) {
    return _kdf().deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  Future<Uint8List> encrypt(Uint8List plaintext, String passphrase) async {
    final rng = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => rng.nextInt(256)),
    );
    final secretKey = await _deriveKey(passphrase, salt);
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    return Uint8List.fromList([
      _version,
      ...salt,
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ]);
  }

  /// `Err` khi mật khẩu sai (MAC không khớp) hoặc envelope hỏng/không đúng
  /// định dạng — cả hai trường hợp trả cùng một thông điệp, không tiết lộ
  /// cho người dùng biết cái nào đúng hơn (tránh dò mật khẩu qua thông báo lỗi).
  Future<Result<Uint8List, AppError>> decrypt(
    Uint8List envelope,
    String passphrase,
  ) async {
    const wrongPassphraseError = AppError(
      'Sai mật khẩu backup, hoặc file backup bị hỏng.',
    );
    const headerLength = 1 + _saltLength + 12 + 16;
    if (envelope.length < headerLength || envelope[0] != _version) {
      return const Result.err(wrongPassphraseError);
    }
    var offset = 1;
    final salt = envelope.sublist(offset, offset + _saltLength);
    offset += _saltLength;
    final nonce = envelope.sublist(offset, offset + 12);
    offset += 12;
    final mac = envelope.sublist(offset, offset + 16);
    offset += 16;
    final cipherText = envelope.sublist(offset);

    try {
      final secretKey = await _deriveKey(passphrase, salt);
      final algorithm = AesGcm.with256bits();
      final plaintext = await algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
      );
      return Result.ok(Uint8List.fromList(plaintext));
    } on SecretBoxAuthenticationError {
      return const Result.err(wrongPassphraseError);
    }
  }
}
