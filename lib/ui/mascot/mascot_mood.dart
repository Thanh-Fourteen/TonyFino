/// Trạng thái của [AppMascot] (Phase 22) — mỗi giá trị ứng với một phản ứng
/// theo dữ liệu THẬT, không phải trang trí ngẫu nhiên:
/// - [idle]: mặc định (empty state, onboarding) — thở nhẹ, chớp mắt.
/// - [streak]: đang có chuỗi ngày ghi giao dịch liên tiếp (tính theo NGÀY
///   GIAO DỊCH THẬT, xem `entry_streak.dart` — tránh đúng lỗi Rolly tính
///   theo ngày NHẬP, xem docs/rolly-product-research.md).
/// - [celebrate]: vừa đạt một mục tiêu tiết kiệm (chuyển trạng thái, không
///   phải tĩnh — xem `docs/decisions.md` § Phase 22).
enum MascotMood { idle, streak, celebrate }
