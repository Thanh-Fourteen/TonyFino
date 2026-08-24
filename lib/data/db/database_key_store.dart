import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Khoá mã hoá 32-byte cho sqlite3mc (`PRAGMA key`, Spike F1 ở Phase 3), giữ
/// trong `flutter_secure_storage` — KHÔNG BAO GIỜ trong drift DB nó tự mã hoá,
/// và KHÔNG BAO GIỜ trong `allowBackup`/adb backup (D3: cả hai đều bị chặn,
/// nên mất khoá này tương đương mất toàn bộ dữ liệu — không có phương án lùi).
class DatabaseKeyStore {
  const DatabaseKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'tonyfino_db_key_v1';

  final FlutterSecureStorage _storage;

  /// Đọc khoá đã lưu, hoặc sinh một khoá 32-byte ngẫu nhiên mật mã học mới
  /// và lưu lại nếu đây là lần chạy đầu tiên.
  Future<String> loadOrCreate() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final generated = base64UrlEncode(bytes);
    await _storage.write(key: _keyName, value: generated);
    return generated;
  }
}
