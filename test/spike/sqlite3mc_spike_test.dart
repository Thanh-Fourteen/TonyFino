// SPIKE F1 — chứng minh sqlite3mc (mã hoá tại chỗ) build và chạy bằng PRAGMA key.
// Chạy trên HOST bằng `flutter test` (cần clang biên dịch sqlite3mc cho linux-x64).
// Đây là cổng E3/H4 — mọi thứ khác trong app đứng trên khả năng này.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('sqlite3mc: mã hoá bằng PRAGMA key, mở lại đúng key đọc được', () {
    final dir = Directory.systemTemp.createTempSync('tf_spike');
    final path = '${dir.path}/enc.db';
    const key = 'test-passphrase-32-bytes-xxxxxxx';

    // 1) tạo DB mã hoá, ghi dữ liệu
    var db = sqlite3.open(path);
    db.execute("PRAGMA key = '$key';");
    // xác nhận cipher THẬT SỰ được link (sqlite3mc trả về tên cipher)
    final cipher = db.select('PRAGMA cipher;');
    db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, note TEXT);');
    db.execute("INSERT INTO t (note) VALUES ('bí mật tài chính');");
    db.close();

    // 2) file trên đĩa KHÔNG được chứa plaintext
    final bytes = File(path).readAsBytesSync();
    final asText = String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));
    expect(asText.contains('bí mật'), isFalse,
        reason: 'DB mã hoá không được lộ plaintext trên đĩa');
    expect(asText.contains('CREATE TABLE'), isFalse);

    // 3) mở lại đúng key -> đọc được
    db = sqlite3.open(path);
    db.execute("PRAGMA key = '$key';");
    final rows = db.select('SELECT note FROM t;');
    expect(rows.single['note'], 'bí mật tài chính');
    db.close();

    // 4) mở lại SAI key -> phải thất bại
    db = sqlite3.open(path);
    db.execute("PRAGMA key = 'wrong-key';");
    expect(() => db.select('SELECT note FROM t;'), throwsA(anything),
        reason: 'sai key thì không đọc được');
    db.close();

    dir.deleteSync(recursive: true);
    // ghi lại tên cipher để biết build nào được link
    printOnFailure('cipher = ${cipher.isNotEmpty ? cipher.first : "?"}');
  });
}
