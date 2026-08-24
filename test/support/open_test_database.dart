import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:tonyfino/data/db/database.dart';

/// `NativeDatabase.memory()` không tự nhận `closeStreamsSynchronously` — cờ
/// đó thuộc `DatabaseConnection` (bọc executor lại), không phải chính
/// `NativeDatabase`. Thiếu nó thì `flutter_test` báo lỗi ở teardown vì
/// timer 1 event-loop mà drift dùng để tránh đóng stream sớm khi
/// `StreamBuilder` reconnect vẫn còn treo sau khi test đã kết thúc.
AppDatabase openTestDatabase() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

/// Ví đầu tiên của một sổ test — `onCreate` luôn tạo đúng một "Ví mặc định"
/// trước khi seed danh mục (v11), nên mọi test cần `walletId` chỉ việc gọi
/// hàm này thay vì hardcode `1`: id do `autoIncrement` sinh, không hứa hẹn
/// giá trị nào.
Future<int> defaultWalletId(AppDatabase db) async {
  final wallet =
      await (db.select(db.wallets)
            ..orderBy([(w) => OrderingTerm.asc(w.id)])
            ..limit(1))
          .getSingle();
  return wallet.id;
}
