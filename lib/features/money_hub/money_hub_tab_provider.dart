import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab con nào của "Túi tiền" sẽ mở: 0 Ví · 1 Quỹ · 2 Hũ.
///
/// Có để các thẻ tổng quan ở Trang chủ mở ĐÚNG trang tương ứng. Không có
/// nó thì bấm thẻ "Hũ tháng này" vẫn rơi vào tab Ví và người dùng phải tự
/// tìm tiếp — thẻ tổng quan mà không dẫn thẳng tới nơi thì chỉ là trang trí.
///
/// `Notifier` chứ không phải `StateProvider`: Riverpod 3 đã bỏ hẳn
/// `StateProvider`.
class MoneyHubTab extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final moneyHubTabProvider = NotifierProvider<MoneyHubTab, int>(MoneyHubTab.new);
