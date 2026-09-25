# Chính sách quyền riêng tư — TonyFino

Cập nhật lần cuối: 25/09/2026

TonyFino là ứng dụng quản lý chi tiêu cá nhân, phát triển và duy trì bởi một
cá nhân, không thuộc công ty nào. Trang này giải thích TonyFino xử lý dữ liệu
gì và như thế nào.

## Dữ liệu tài chính của bạn

Toàn bộ giao dịch, ví, quỹ, hũ, ngân sách, ghi chú... được lưu **cục bộ trên
chính điện thoại của bạn**, trong cơ sở dữ liệu SQLite đã mã hoá. TonyFino
không có máy chủ trung tâm lưu dữ liệu người dùng — người phát triển **không
thể** xem, truy cập hay khôi phục dữ liệu tài chính của bạn.

## Camera (quét hoá đơn)

Khi bạn quét hoá đơn, ảnh được nhận dạng chữ **hoàn toàn trên máy** bằng
Google ML Kit (chạy offline qua Google Play Services). Ảnh và nội dung nhận
dạng được không gửi lên bất kỳ máy chủ nào. Kết quả nhận dạng luôn hiện ra để
bạn xác nhận/sửa trước khi lưu vào sổ — TonyFino không tự động ghi một kết
quả quét nào mà chưa qua xác nhận của bạn.

## Micro (nhập liệu bằng giọng nói)

Khi bạn dùng tính năng nhập liệu bằng giọng nói, TonyFino gọi tới dịch vụ
nhận diện giọng nói của hệ điều hành Android (`SpeechRecognizer`). Tuỳ theo
máy và cấu hình của bạn, dịch vụ này có thể xử lý trên máy hoặc gửi đoạn ghi
âm tới máy chủ của Google để chuyển thành văn bản — đây là hành vi của hệ
điều hành, TonyFino không tự gửi thêm bản ghi âm nào tới nơi khác ngoài dịch
vụ nhận diện giọng nói mặc định của máy bạn.

## Trợ lý AI đám mây (tuỳ chọn, mặc định TẮT)

TonyFino có một tính năng phụ, **mặc định tắt**, giúp hiểu các câu nhập liệu
quá mơ hồ mà bộ xử lý offline không tự đoán được. Khi bạn bật tính năng này
trong Cài đặt, CHỈ câu chữ bạn gõ (không phải toàn bộ sổ chi tiêu, không phải
số dư, không phải lịch sử giao dịch) được gửi qua một máy chủ trung gian do
người phát triển vận hành riêng tới Gemini API của Google để phân tích, và
kết quả trả về vẫn hiện ra cho bạn xác nhận trước khi ghi vào sổ.

## Đăng nhập Google & sao lưu Google Drive

TonyFino dùng Đăng nhập Google chỉ để **xác thực danh tính** của bạn (không
thu thập gì thêm ngoài tên, email, ảnh đại diện cơ bản mà Google cung cấp).

Khi bạn bật sao lưu, TonyFino lưu một bản sao lưu **đã mã hoá** (định dạng
giống hệt bản sao lưu thủ công có sẵn trong app) vào một khu vực riêng, ẩn
trên Google Drive của **chính bạn** (gọi là `appDataFolder`) — khu vực này
chỉ TonyFino trên tài khoản Google của bạn mới đọc/ghi được, không hiện trong
giao diện Drive thông thường, và **người phát triển TonyFino không có quyền
truy cập** vào bản sao lưu này dưới bất kỳ hình thức nào. Khi bạn đăng nhập
lại cùng tài khoản Google trên máy khác, app tải bản sao lưu gần nhất về để
khôi phục dữ liệu.

Bạn có thể xoá toàn bộ bản sao lưu này bất cứ lúc nào qua
[Tài khoản Google → Quản lý quyền truy cập của bên thứ ba](https://myaccount.google.com/permissions)
hoặc mục "Xoá dữ liệu ứng dụng ẩn" trong phần quản lý Google Drive.

## TonyFino KHÔNG làm gì

- Không có quảng cáo, không có công cụ theo dõi/phân tích hành vi của bên
  thứ ba (không Google Analytics, không Facebook SDK, v.v.).
- Không bán, cho thuê hay chia sẻ dữ liệu của bạn cho bất kỳ bên nào.
- Không có tài khoản/máy chủ trung tâm nào lưu trữ hay có thể truy cập dữ
  liệu tài chính của bạn.

## Xoá dữ liệu

- Xoá toàn bộ dữ liệu trên máy: gỡ cài đặt TonyFino, hoặc xoá dữ liệu ứng
  dụng trong Cài đặt Android.
- Xoá bản sao lưu trên Google Drive: xem mục "Đăng nhập Google & sao lưu
  Google Drive" ở trên.

## Liên hệ

Có câu hỏi về chính sách này, liên hệ: teamtriscec@gmail.com
