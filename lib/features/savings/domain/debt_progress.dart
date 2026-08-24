import '../../../data/db/database.dart';
import 'debt_kind.dart';

/// Kết quả JOIN + `SUM` của `DebtRepository.watchActiveWithProgress` — một
/// dòng cho MỖI khoản vay/cho vay, [remainingMinor] LUÔN dẫn xuất từ
/// `debt.principalMinor` + `SUM(transactions.amount_minor)` các giao dịch
/// gắn `debtId`, KHÔNG có cột "còn nợ bao nhiêu" nào lưu sẵn (D7). Công thức
/// khác nhau theo [DebtKind] nhưng KHÔNG dùng `ABS()` — xem docs/decisions.md
/// § Phase 16 để biết lý do (một khoản trả thừa được hoàn lại một phần vẫn
/// phải cộng dồn đúng dấu).
class DebtProgress {
  const DebtProgress({required this.debt, required this.contributionsSumMinor});

  final Debt debt;

  /// `SUM(amount_minor)` THÔ, CÓ DẤU — chưa quy đổi theo [kind].
  final int contributionsSumMinor;

  DebtKind get kind => DebtKind.fromDbValue(debt.kind);

  /// Số tiền đã trả (nếu mình nợ) / đã thu (nếu mình cho vay) — LUÔN dương
  /// trong dữ liệu hợp lệ (repayment/collection transactions có dấu đúng
  /// theo kind), có thể âm nếu có giao dịch hoàn lại ròng vượt phần đã trả.
  int get paidMinor =>
      kind == DebtKind.debt ? -contributionsSumMinor : contributionsSumMinor;

  /// Có thể ÂM nếu đã trả/thu vượt gốc (dữ liệu bất thường nhưng không chặn).
  int get remainingMinor => debt.principalMinor - paidMinor;

  double get progressFraction {
    if (debt.principalMinor <= 0) return 0.0;
    return (paidMinor / debt.principalMinor).clamp(0.0, 1.0);
  }

  bool get isSettled => paidMinor >= debt.principalMinor;
}
