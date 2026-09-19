import '../../../data/repositories/transaction_repository.dart';
import '../day_label.dart';

/// Một ngày trong một danh sách giao dịch đã sắp mới-nhất-trước.
class TransactionDayGroup {
  TransactionDayGroup(this.day);

  final DateTime day;
  final List<TransactionWithCategory> items = [];

  /// Tổng `amountMinor` THÔ của ngày (chi âm, thu dương). Màn nào muốn đọc
  /// theo chiều khác (vd lịch sử quỹ: nạp là quỹ TĂNG) tự đảo dấu khi hiện.
  int netMinor = 0;
}

/// Gom [items] (đã sắp mới nhất trước) theo NGÀY LỊCH, giữ nguyên thứ tự.
///
/// Trước đây mỗi màn danh sách tự chép một bản — tab Giao dịch, Chi tiết
/// danh mục, Lịch sử quỹ — và màn Chi tiết hũ sẽ là bản thứ tư. Gom về đây
/// để "một ngày" có đúng một định nghĩa (`dayKey`).
List<TransactionDayGroup> groupTransactionsByDay(
  List<TransactionWithCategory> items,
) {
  final groups = <DateTime, TransactionDayGroup>{};
  final order = <DateTime>[];
  for (final item in items) {
    final key = dayKey(item.transaction.occurredAt);
    final group = groups.putIfAbsent(key, () {
      order.add(key);
      return TransactionDayGroup(key);
    });
    group.items.add(item);
    group.netMinor += item.transaction.amountMinor;
  }
  return [for (final key in order) groups[key]!];
}
