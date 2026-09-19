import '../../../data/db/database.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../ui/category_two_tier_label.dart';

/// Cách MỘT giao dịch hiện thành một hàng `TransactionRow` — nguồn sự thật
/// DUY NHẤT cho cả năm chỗ đang vẽ danh sách giao dịch (tab Giao dịch, Trang
/// chủ "Gần đây", Tìm kiếm, Chi tiết danh mục, và màn Lịch sử quỹ).
///
/// 🚨 Gom về đây vì đã có bằng chứng nó trôi mỗi nơi một kiểu.
///
/// Bốn màn kia từng chép tay cùng một đoạn ba-điều-kiện, và đã lệch nhau thật:
/// tab Giao dịch có `emoji`, Trang chủ thì không; Tìm kiếm bỏ chip danh mục
/// con khi tách dòng, Trang chủ thì không; và KHÔNG màn nào biết khoản NẠP/RÚT
/// QUỸ là gì — cả bốn đều in ra "Chưa phân loại" kèm icon giấy cho một khoản
/// tiền đã cất vào quỹ, trong khi màn chat lại hiện đúng "Để dành › Mua nhà".
/// Sửa từng chỗ là mời lỗi quay lại ở chỗ thứ năm.
///
/// BA khái niệm khác nhau đều có `category == null`, không suy ra được từ
/// `category` nên phải hỏi đúng trường:
/// - `goal != null` → nạp/rút một quỹ (không có danh mục theo thiết kế)
/// - `isSplit` → giao dịch tách nhiều danh mục (Phase 14)
/// - còn lại → "chưa phân loại" thật (quick-add chưa xác nhận, Phase 8)
class TransactionRowDisplay {
  const TransactionRowDisplay({
    required this.categoryColorId,
    required this.iconCode,
    required this.title,
    this.emoji,
    this.subcategoryLabel,
  });

  final int categoryColorId;
  final String iconCode;
  final String title;
  final String? emoji;

  /// Tầng thứ hai, hiện thành chip nhỏ sau [title]: tên danh mục CON cho giao
  /// dịch thường, tên QUỸ cho khoản để dành.
  final String? subcategoryLabel;
}

/// Màu sentinel + icon cho hàng để dành — cùng cặp `11`/`savings` (con heo
/// đất) mà thẻ để dành ở màn chat đang dùng, để cùng một giao dịch trông
/// giống nhau ở mọi màn.
const int kSavingsRowColorId = 11;
const String kSavingsRowIconCode = 'savings';

TransactionRowDisplay transactionRowDisplay(
  TransactionWithCategory twc,
  Map<int, Category> categoriesById,
) {
  final goal = twc.goal;
  if (goal != null) {
    return TransactionRowDisplay(
      categoryColorId: kSavingsRowColorId,
      iconCode: kSavingsRowIconCode,
      // Dòng ÂM là nạp vào quỹ, dòng DƯƠNG là rút ra — cùng quy ước dấu với
      // `SavingsGoalProgress.savedMinor` (`-SUM(amountMinor)`).
      title: twc.transaction.amountMinor > 0 ? 'Rút từ quỹ' : 'Để dành',
      subcategoryLabel: goal.name,
    );
  }

  final category = twc.category;
  // Avatar + tên lấy của danh mục CHA nếu có, để mọi bữa ăn cùng một icon dù
  // ghi vào danh mục con nào (kiểu Rolly).
  final display = displayCategory(category, categoriesById);
  return TransactionRowDisplay(
    categoryColorId: display?.categoryColorId ?? 10,
    iconCode: display?.iconCode ?? 'more_horiz',
    emoji: display?.emoji,
    title: twc.isSplit ? 'Nhiều danh mục' : (display?.name ?? 'Chưa phân loại'),
    subcategoryLabel: twc.isSplit || category?.parentCategoryId == null
        ? null
        : category?.name,
  );
}
