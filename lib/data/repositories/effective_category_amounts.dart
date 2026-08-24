import 'package:drift/drift.dart';

import '../db/database.dart';

/// Một "dòng tiền có danh mục" hiệu lực cho MỖI giao dịch (Phase 14) — hợp
/// nhất qua `UNION ALL` hai nguồn:
///   1. giao dịch KHÔNG tách dòng: đọc thẳng `transactions.category_id` +
///      `amount_minor` (giao dịch không có hàng nào trong `transaction_lines`).
///   2. giao dịch CÓ tách dòng: đọc TỪNG `transaction_lines.category_id` +
///      `amount_minor` riêng — một giao dịch tách 3 dòng sinh ra 3 hàng hiệu
///      lực ở đây, không phải 1.
/// Một giao dịch chỉ rơi vào ĐÚNG MỘT trong hai nhánh, không bao giờ cả hai —
/// `TransactionRepository.insert`/`update` đảm bảo điều này bằng cách luôn
/// set `transactions.category_id = NULL` cho giao dịch có tách dòng, nên
/// KHÔNG có giao dịch nào vừa tự có category_id vừa có dòng con để bị đếm
/// hai lần.
///
/// Mọi query gộp theo danh mục (`ReportsRepository`, `BudgetRepository`)
/// PHẢI đọc qua đây thay vì `transactions.category_id`/`amount_minor` trực
/// tiếp — xem docs/decisions.md § Phase 14 "Tách giao dịch: hai đường dữ
/// liệu". `occurredAt`/`isTransfer` đi kèm trong mỗi hàng hiệu lực (đọc từ
/// `transactions`, giống nhau cho mọi dòng con của cùng một giao dịch) để
/// call site lọc theo khoảng ngày/loại-trừ-chuyển-khoản mà không cần JOIN
/// lại `transactions` lần hai. `walletId` cũng đi kèm vì lý do tương tự
/// (thêm ở v13 cho tính năng hũ) — hai nhánh UNION phải cùng đọc từ `t`,
/// kể cả nhánh dòng con. `goalId` cũng vậy: giao dịch nạp/rút mục tiêu tiết
/// kiệm là CHUYỂN TIỀN giữa hai túi của chính mình, không phải chi tiêu, nên
/// mọi báo cáo phải loại nó ra — xem `ReportsRepository`.
///
/// Dùng `db.selectOnly(effectiveCategoryAmounts(db))` để bắt đầu một query
/// mới trên "bảng ảo" này, và `.ref(db.transactions.xxx)` để đọc từng cột —
/// xem `Subquery.ref` (drift) để hiểu vì sao phải tham chiếu qua cột GỐC của
/// `db.transactions`, không phải một tên cột mới.
// Row type không dùng tới (chỉ tham chiếu cột qua `Subquery.ref`, không bao
// giờ `readTable`/`.map` cả hàng), và hai nhánh UNION có kiểu cột khác nhau
// đủ để không thể đặt một type argument chung.
// ignore: strict_raw_type
Subquery effectiveCategoryAmounts(
  AppDatabase db, {
  String alias = 'effective_category_amounts',
}) {
  final t = db.transactions;
  final tl = db.transactionLines;

  final linkedToLine = db.selectOnly(tl)..addColumns([tl.transactionId]);

  final unsplit = db.selectOnly(t)
    ..addColumns([
      t.id,
      t.categoryId,
      t.amountMinor,
      t.occurredAt,
      t.isTransfer,
      t.walletId,
      t.goalId,
    ])
    ..where(t.id.isNotInQuery(linkedToLine));

  final split =
      db.selectOnly(tl).join([innerJoin(t, t.id.equalsExp(tl.transactionId))])
        ..addColumns([
          tl.transactionId,
          tl.categoryId,
          tl.amountMinor,
          t.occurredAt,
          t.isTransfer,
          // 🚨 THỨ TỰ CỘT PHẢI KHỚP TUYỆT ĐỐI với nhánh `unsplit` ở trên:
          // `UNION ALL` ghép theo VỊ TRÍ, không theo tên. Đảo `walletId` và
          // `goalId` ở một nhánh là mọi dòng con đọc ví thành mục tiêu và
          // ngược lại — dữ liệu sai lặng lẽ, không lỗi biên dịch nào.
          //
          // Dòng con KHÔNG có ví/mục tiêu riêng: cả hai thừa hưởng từ giao
          // dịch mẹ nên đọc từ `t`, không phải `tl`.
          t.walletId,
          t.goalId,
        ]);

  unsplit.unionAll(split);
  return Subquery(unsplit, alias);
}
