import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';

/// `pumpBeforeTest` cho mọi golden có [Image.asset] THẬT trong cây widget.
///
/// Không dùng thẳng `precacheImages`: nó THAY THẾ `onlyPumpAndSettle` mặc
/// định của alchemist, nên ở màn dựng bất đồng bộ (danh sách giao dịch lấy
/// từ stream) các hàng còn CHƯA tồn tại lúc precache chạy — ảnh không nằm
/// trong cây thì không có gì để precache, golden chụp ra avatar rỗng (bug
/// thật, thấy tận mắt khi đổi `CategoryAvatar` sang icon 3D).
///
/// Thứ tự đúng: settle cho cây dựng xong → precache ảnh vừa xuất hiện →
/// settle lần nữa để khung hình đầu tiên có ảnh được vẽ.
Future<void> settleThenPrecacheImages(WidgetTester tester) async {
  await onlyPumpAndSettle(tester);
  await precacheImages(tester);
  await onlyPumpAndSettle(tester);
}
