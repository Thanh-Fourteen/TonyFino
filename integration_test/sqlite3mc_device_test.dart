// SPIKE F1 (phần thiết bị) — chứng minh sqlite3mc build qua NDK và chạy trên Android API 36.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('sqlite3mc mã hoá chạy trên thiết bị Android', (tester) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/enc_device.db';
    File(path).existsSync() ? File(path).deleteSync() : null;
    const key = 'device-passphrase-xxxxxxxxxxxxxx';

    var db = sqlite3.open(path);
    db.execute("PRAGMA key = '$key';");
    db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, note TEXT);');
    db.execute("INSERT INTO t (note) VALUES ('bí mật trên máy');");
    db.dispose();

    final txt = String.fromCharCodes(
        File(path).readAsBytesSync().where((b) => b >= 32 && b < 127));
    expect(txt.contains('bí mật'), isFalse);

    db = sqlite3.open(path);
    db.execute("PRAGMA key = '$key';");
    expect(db.select('SELECT note FROM t;').single['note'], 'bí mật trên máy');
    db.dispose();
    File(path).deleteSync();
  });
}
