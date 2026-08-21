// Cổng E3: drift mở NativeDatabase.memory() chạy trên host bằng `flutter test`,
// không emulator, không mock. Đây là nền cho mọi repository test ở Phase 4.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drift NativeDatabase.memory() chạy SQL thật trên host', () async {
    final db = NativeDatabase.memory();
    final executor = DatabaseConnection(db);
    // dùng trực tiếp low-level để khỏi cần generated code ở phase này
    await executor.executor.ensureOpen(_NoopUser());
    final result = await executor.executor
        .runSelect('SELECT 35000 AS amount_minor, ? AS note', ['cà phê 35k']);
    expect(result.single['amount_minor'], 35000);
    expect(result.single['note'], 'cà phê 35k');
    await executor.executor.close();
  });
}

class _NoopUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;
  @override
  Future<void> beforeOpen(QueryExecutor e, OpeningDetails details) async {}
}
