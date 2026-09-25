/// Cấu hình OAuth cho Đăng nhập Google — project `TonyFino` riêng trên
/// Google Cloud Console (KHÔNG dùng chung với project khác của Tony).
///
/// `serverClientId` KHÔNG phải bí mật — đây là OAuth Client ID loại "Web
/// application", Google cho phép nhúng thẳng vào app di động (khác với
/// "client secret", thứ không bao giờ được nhúng). Nhúng cứng ở đây an toàn
/// kể cả trong repo công khai. `google_sign_in` cần giá trị này để
/// Credential Manager trên Android xin đúng audience khi lấy quyền truy cập
/// Drive — client Android (package + SHA-1) được Google tự khớp qua chữ ký
/// app, không cần khai trong code.
class GoogleAuthConfig {
  const GoogleAuthConfig._();

  static const serverClientId =
      '296996191667-4fa84ds188gf84ask6ckdscjjsbmq19r.apps.googleusercontent.com';
}
