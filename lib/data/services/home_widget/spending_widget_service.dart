import 'dart:developer' as developer;

import 'package:flutter/services.dart' show PlatformException;
import 'package:home_widget/home_widget.dart';

import '../../repositories/transaction_repository.dart';

/// Đẩy "Chi tiêu từ đầu tháng" sang widget màn hình chính (Phase 21).
///
/// CHỈ gửi chuỗi Flutter đã format sẵn (`Money.format()` — giống hệt hero
/// card Phase 6, không có logic tính riêng nào ở đây hay ở phía Kotlin).
/// `SpendingWidgetProvider.kt` chỉ đọc chuỗi, không parse/cộng lại số tiền.
/// Tên `_androidProviderName` phải khớp tên class Kotlin đó.
class SpendingWidgetService {
  const SpendingWidgetService();

  static const _androidProviderName = 'SpendingWidgetProvider';
  static const _expenseKey = 'expense_since_month_start';
  static const _updatedAtKey = 'updated_at_label';

  /// Cập nhật widget là việc PHỤ, chạy kèm mỗi lần lưu giao dịch. Hỏng ở
  /// đây TUYỆT ĐỐI không được nổi lên thành exception chưa ai bắt: nó không
  /// làm sai một đồng nào trong sổ, mà lại xảy ra ngay sau thao tác lưu —
  /// đúng lúc người dùng đang chờ phản hồi.
  ///
  /// Có ít nhất một ca hỏng chắc chắn xảy ra và hoàn toàn vô hại:
  /// `home_widget` tìm class Kotlin theo `<applicationId>.<name>`, mà bản
  /// debug có `applicationIdSuffix = ".dev"` (build.gradle.kts) nên nó tìm
  /// `dev.tony.tonyfino.dev.SpendingWidgetProvider` — không tồn tại →
  /// `PlatformException` mỗi lần lưu. Bắt được tận tay trên emulator.
  Future<void> sync(MonthSummary summary, {required DateTime updatedAt}) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        _expenseKey,
        summary.expense.format(),
      );
      await HomeWidget.saveWidgetData<String>(
        _updatedAtKey,
        _formatClock(updatedAt),
      );
      await HomeWidget.updateWidget(name: _androidProviderName);
    } on PlatformException catch (e) {
      // Ghi log để không NUỐT LẶNG LẼ (nếu widget thật sự hỏng trên bản
      // release thì vẫn có dấu vết), nhưng không ném tiếp.
      developer.log(
        'Không cập nhật được widget màn hình chính — bỏ qua, sổ vẫn đúng.',
        name: 'SpendingWidgetService',
        error: e,
      );
    }
  }

  // HH:mm:ss (không chỉ HH:mm) — cần độ chính xác giây để đo độ trễ cập nhật
  // thật trên emulator (TODOS.md § Phase 21 "Xác minh"), và hiển thị luôn
  // trên widget để trung thực về độ mới của số liệu thay vì hứa "real-time".
  String _formatClock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
