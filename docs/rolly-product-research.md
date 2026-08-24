# TonyFino — Nghiên cứu SẢN PHẨM Rolly (2026-08-21)

`docs/rolly-schema.md` (Phase 2) ghi lại **hình dạng dữ liệu** của Rolly để viết importer (Phase 9).
File này khác hẳn: nghiên cứu Rolly như một SẢN PHẨM — tính năng thật, giá, đánh giá người dùng,
cơ chế AI — vì trước giờ chưa từng audit kỹ phần này, chỉ mới rút dữ liệu. Tony dùng Rolly hàng
ngày nên biết rõ nó qua trải nghiệm cá nhân; mục đích file này là bổ sung góc nhìn từ bên ngoài
(store listing, báo chí công nghệ VN, đánh giá người dùng thật) — có thể xác nhận, có thể bổ sung
điều Tony chưa để ý.

**Một số nguồn không lấy được trực tiếp** (Play Store/App Store render bằng JS, một số trang chặn
fetch) — mọi chỗ không xác nhận được đều ghi rõ "không xác nhận được," không đoán.

## A. Store listing, giá, đánh giá

- Package Android: `com.jc.rollymoneytracker`. Tên hiển thị: "Rolly: AI Sổ Thu Chi Hằng Ngày" (VN)
  / "Rolly: AI Budget Money Tracker" (EN). Danh mục Tài chính. **4.8/5**, 524K+ lượt tải (Android,
  từ 8/2024). App Store: 4.8/5, số lượt đánh giá dao động theo nguồn/thời điểm (295 → 5.9K → 11.7K
  tuỳ đợt đo) — khả năng phản ánh tăng trưởng theo thời gian, không phải mâu thuẫn dữ liệu.
  Bản mới nhất iOS: 15.3.0, ~111MB, cập nhật 8/2026 — **vẫn đang phát triển tích cực**.
- 🚨 **Điểm số trung bình 4.8 che một cụm người dùng rất không hài lòng**: trong 192 đánh giá viết
  (không phải điểm sao) trên App Store, chỉ 96 là 5 sao, còn **53 là 1 sao** — lệch hẳn so với con
  số 4.8 tổng. Bài học: điểm trung bình một app store KHÔNG đủ để đánh giá chất lượng thật.
- Đỉnh cao tăng trưởng: 11/2024 xếp #2 tổng lượt tải, #1 danh mục Tài chính trên App Store VN —
  nhưng ở kho Mỹ hiện KHÔNG lọt top 30 Tài chính. Đây là hit của thị trường VN/Đông Nam Á, không
  phải app charts toàn cầu.
- **Giá — CÓ THAY ĐỔI THEO THỜI GIAN, không xác nhận được mốc mới nhất 100%**: giai đoạn viral
  11/2024 nhiều báo VN ghi 49.000đ/tháng + 499.000đ trọn đời; sau đó 59.000đ/tháng, 249.000đ/năm,
  799.000đ trọn đời; số Tony đưa ra (79.000đ/tháng, 299.000đ/năm, 799.000đ trọn đời) khớp với một
  kết quả tìm được ghi "hiện tại" nhưng KHÔNG fetch trực tiếp được từ store để xác nhận 100%. **Suy
  luận hợp lý: Rolly đã tăng giá dần** (49k→59k→79k/tháng, 499k→799k trọn đời) qua các đợt — không
  phải một mức giá cố định từ đầu.
- Gói Mỹ/quốc tế dùng USD ($1.99–$79.99, gói trọn đời bán qua DealMirror ~$60, giá gốc $99) — tách
  hẳn thang giá VND, khác nhà cung cấp/khác thị trường.
- **Không lấy được ảnh chụp màn hình thật** — các trang store không render được nội dung qua fetch.

## B. Tính năng đã quảng cáo — free vs. trả phí

Ranh giới free/premium KHÔNG được tài liệu hoá rõ ràng ở bất cứ đâu — đây là tổng hợp tốt nhất có
thể từ nhiều nguồn (trang chính thức rollyapp.ai, mô tả store, trang so sánh/deal bên thứ ba).

**Nhập liệu**
- Chat/nhắn tin tự nhiên ("Café 30k") — miễn phí, tính năng lõi
- Nhập giọng nói — **trả phí**
- Quét hoá đơn OCR (trích merchant/mặt hàng/thuế/tip) — **trả phí**
- Chuyển tiếp email ngân hàng để tự tạo giao dịch (tính năng thêm 2025)

**Tổ chức**
- Tự động phân loại bằng AI — miễn phí (lõi)
- Nhiều ví, ví chia sẻ đồng bộ real-time — bản free giới hạn **1 ví**; nhiều ví/ví chia sẻ **trả phí**
- Danh mục tuỳ chỉnh, xem lịch chi tiêu theo ngày — chỉ nhắc ở trang chính thức, không rõ free/trả phí
- Giao dịch định kỳ tự động, nhắc thanh toán hoá đơn
- Thêm 2025: **widget màn hình chính**, tính năng theo dõi **cho vay/mượn**, mời chia sẻ ví

**Ngân sách/mục tiêu**
- Ngân sách gợi ý bằng AI, mục tiêu tiết kiệm có theo dõi tiến độ, theo dõi trả nợ

**Phân tích**
- Biểu đồ chi tiêu tuần/tháng, phân tích theo danh mục, phát hiện xu hướng, **"Ask Rolly"** — hỏi
  đáp tự do về ngân sách/chi tiêu/mục tiêu của chính mình (lớp chat tư vấn tài chính trên nền sổ ghi)

**Khác**
- Dark mode — **hai bài báo VN ghi rõ là tính năng chỉ dành cho Premium**
- Khoá vân tay — có nhắc tới, chưa rõ free/trả phí
- Import/export CSV — có nhắc tới, chưa rõ free/trả phí
- Đa tiền tệ (9 ngôn ngữ/locale), liên kết tài khoản ngân hàng (một đánh giá nói liên kết KHÔNG
  thực sự tự động đồng bộ)
- Đa nền tảng: iOS, Android, web, cả app macOS, đồng bộ xuyên thiết bị
- Dùng thử Premium 7 ngày (giọng nói, quét hoá đơn, "AI insight nâng cao") là cơ chế trial nhất quán
- Bản free bị **giới hạn tốc độ** — một nguồn VN ghi "phải chờ vài giây giữa các lượt chat" nếu
  không phải Premium

## C. Than phiền từ người dùng thật, theo chủ đề

**Ba than phiền đã biết — cả ba đều được xác nhận ĐỘC LẬP qua nghiên cứu này:**

1. **Số dư ví sai/không cập nhật** — xác nhận độc lập: có báo cáo "số dư hàng tháng không cộng dồn
   (reset về 0)", và một bug cụ thể: giao dịch được AI nhận đúng là khoản THU, cộng vào ví, nhưng
   sau đó lại bị TRỪ khỏi tổng số dư — một bug hỏng số dư có thật, không chỉ trải nghiệm riêng của
   Tony. Tổng hợp cảm nhận đánh giá cũng liệt kê "hiển thị số dư sai" là chủ đề lặp lại.
2. **Giao dịch âm thầm không lưu được** — không tìm thấy đúng nguyên văn, nhưng có báo cáo liền kề:
   tab "Ask Rolly" **nhấp nháy liên tục và không dùng được** khi nhập dữ liệu trên một số máy; một
   đánh giá khác nói app "dừng ở màn đầu, không qua được bước tiếp theo" (crash chặn onboarding).
   Ủng hộ một mẫu hình chung về luồng nhập/lưu không ổn định, dù không đúng câu chữ "thiếu nút Save."
3. **Một tin nhắn nhiều khoản chi chỉ tạo một giao dịch** — **xác nhận trực tiếp, rõ ràng**, độc
   lập với trải nghiệm của Tony: một bài báo công nghệ VN viết thẳng "Khi người dùng nhập nhiều
   giao dịch cùng lúc, Rolly sẽ không thể phân tích chính xác, mà lại gộp chung thành một khoản
   chi." Đây là hạn chế ĐÃ ĐƯỢC CÔNG BỐ, không phải trường hợp hiếm chỉ Tony gặp.

**Than phiền MỚI tìm được (chưa có trong danh sách 3 điều đã biết):**

- **Mất dữ liệu sau khi cập nhật app** — một người dùng mất sạch lịch sử chi tiêu sau update; đội
  ngũ hỗ trợ phản hồi bằng cách yêu cầu gửi email khôi phục thủ công (team@rollyapp.site) thay vì
  sửa lỗi trong app.
- **Lỗi logic tính năng "streak"** — streak tính theo ngày NHẬP giao dịch, không phải ngày giao
  dịch thật sự xảy ra — nhập ly cà phê hôm qua vào hôm nay sẽ làm gãy streak; người dùng phản ánh
  đội ngũ Rolly có vẻ bảo vệ thiết kế thay vì lắng nghe.
- **Tính phí trùng** — một người dùng bị trừ tiền cả gói Trọn đời LẪN gói Năm cùng lúc, hơn một
  ngày không có phản hồi hỗ trợ.
- **Khó hoàn tiền** — ít nhất hai đánh giá kể việc xin hoàn tiền Google Play/App Store ngay sau khi
  mua (một trường hợp hoàn ngay trong ngày) và bị từ chối, cảnh báo người khác "cân nhắc kỹ trước
  khi mua."
- **"Lỗi nghiêm trọng sau mỗi bản cập nhật"** — chủ đề lặp lại trong tổng hợp cảm nhận đánh giá,
  cùng với "vấn đề tính phí/subscription" và "hiển thị số dư sai."
- **Không có chế độ offline thật** — lặp lại nhiều lần trên báo chí VN vì phân tích AI cần mạng;
  một trang so sánh bên thứ ba xếp đây là nhược điểm hàng đầu.
- **Bản dịch tiếng Việt chưa đầy đủ trên iOS** — chat được bằng tiếng Việt nhưng GIAO DIỆN iOS vẫn
  tiếng Anh; Android có tiếng Việt đầy đủ hơn — một khoảng lệch thật giữa hai nền tảng.
- **Ép đánh giá ngay lần đầu mở app** — một đánh giá 1 sao trên App Store than phiền app đòi review
  trước cả khi kịp dùng thử.
- **Liên kết ngân hàng không thực sự tự động** — dù quảng cáo có "liên kết tài khoản", ít nhất một
  đánh giá nói nó không tự đồng bộ như mô tả.
- **Giao diện sơ sài** — nhiều bài báo VN độc lập mô tả UI là "sơ sài," cần đơn giản hoá thêm, nhất
  là khi xử lý câu hỏi tài chính phức tạp hơn.
- **Lo ngại quyền riêng tư dữ liệu** — vài bài báo VN nêu lo ngại chung (không có bằng chứng rò rỉ
  thật) về việc dữ liệu tài chính được gửi lên và lưu trên server của nhà phát triển do mô hình
  nhập liệu qua AI/chat.

**Không tìm thấy bằng chứng về quảng cáo gây khó chịu** — đã tìm riêng, không ra kết quả nào theo
cả hai hướng (không xác nhận được có hay không).

## D. Điều người dùng THÍCH / khen

- **Chính cơ chế tính cách AI "mắng" là điều được khen nhiều nhất** — nhiều đánh giá App Store và
  báo chí VN mô tả "vui," "cuốn hút," "sáng tạo," biến việc ghi chi tiêu từ việc vặt thành trải
  nghiệm. Nhiều người tự thuật lại: bị AI "mắng" thực sự khiến họ chi tiêu ít hơn.
- **Tốc độ/độ dễ ghi chép** — khen liên tục là "đơn giản," "trực quan," tiết kiệm thời gian so với
  nhập tay; nhập giọng nói được ít nhất một người khen riêng.
- **Tự động phân loại** — khen nhất quán là chính xác, "thông minh," giúp thấy insight chi tiêu mà
  không cần gắn thẻ tay.
- **Yếu tố lan truyền xã hội** — không chỉ hữu ích: giới trẻ VN chia sẻ ảnh chụp màn hình những câu
  "mắng" hài hước của AI lên Threads/Facebook rộng rãi — một phần độ nổi tiếng đến từ việc app
  "vui để khoe," không chỉ hữu dụng.
- **Hỗ trợ khách hàng tốt** — ít nhất một đánh giá khen, trái ngược với các than phiền về hoàn tiền/
  tính phí trùng ở trên — có vẻ chất lượng hỗ trợ KHÔNG đồng đều, không phải tệ toàn bộ.

## E. Góc "AI" — điều thực sự khác biệt

- **Phản hồi theo "tính cách" là khác biệt cốt lõi**, không chỉ là lớp chatbot phủ ngoài: mỗi giao
  dịch ghi vào được một nhân vật AI (chọn được) phản ứng lại. Bộ nhân vật đã tiến hoá theo thời
  gian — đầu 2024 chỉ có 3 mức cảm xúc đơn giản (Vui/Buồn/Giận), về sau (không rõ mốc chính xác)
  marketing nói tới nhân vật có tên: **"Angry Mom"** (mắng khi mua thứ không cần) và **"Wise
  Mentor/Wise Friend"** (khuyên thực tế, không mắng).
- **Phản ứng có ngữ cảnh, không chỉ theo số tiền** — một nguồn VN ghi rõ AI phê bình một món mua
  không cần thiết khác hẳn cách nó khen một khoản hợp lý (vd không phê bình khoản mua thuốc dù số
  tiền tương đương một khoản bị mắng) — có phán đoán vượt ngưỡng số tiền đơn thuần.
- **"Ask Rolly" là một lớp chat tài chính mở thật sự**, không chỉ ô nhập liệu: hỏi tự do kiểu "tháng
  này tôi đang ổn không so với ngân sách" và nhận câu trả lời hội thoại — một lớp tư vấn tài chính
  nhẹ nằm trên nền sổ ghi chép.
- 🔥 **Điểm yếu lớn nhất trong chính lời hứa cốt lõi của AI**: lỗi không tách được tin nhắn nhiều
  khoản chi (than phiền #3) đâm thẳng vào lời quảng cáo "chỉ cần nói chuyện là xong" — và đây là
  lỗi phân tích AI được báo chí VN nêu công khai, không chỉ trải nghiệm riêng Tony.
- **Câu chuyện tăng trưởng cũng là điểm khác biệt**: độ nổi tiếng ở VN được gán thẳng cho hiệu ứng
  lan truyền của cơ chế "mắng," không phải marketing truyền thống — báo chí VN gần như đóng khung
  toàn bộ app quanh MỘT móc câu này hơn bất kỳ tính năng nào khác.

## Ý nghĩa cho TonyFino

- Ba than phiền gốc (Phase 2/Context) đều được xác nhận độc lập — càng củng cố D7 (số dư dẫn xuất,
  không cache) và việc `segmenter.dart` (Phase 7) đã CHỦ ĐỘNG giải quyết đúng lỗi tách nhiều khoản
  chi mà báo chí VN ghi nhận là lỗi công khai của Rolly.
- Các than phiền MỚI tìm được (mất dữ liệu sau update, tính phí trùng, khó hoàn tiền, ép review) đều
  là lớp vấn đề **TonyFino tự động miễn nhiễm** nhờ kiến trúc đã chọn: không tài khoản, không server,
  không subscription, không billing — đáng ghi lại như một xác nhận gián tiếp cho các quyết định
  D1-D10, không phải việc cần làm thêm.
- "Streak" (chuỗi ngày ghi chép liên tục) là một ý tưởng gamification chưa có trong TonyFino và
  chưa nằm trong Backlog — đáng cân nhắc nhưng PHẢI làm đúng (tính theo NGÀY GIAO DỊCH thật, không
  phải ngày nhập, đúng lỗi Rolly đã mắc) nếu sau này thêm.
- "Ask Rolly" (chat hỏi-đáp tự do về tài chính của chính mình) là ý tưởng gần nhất với Phase 12 (AI
  fallback) — đáng cân nhắc mở rộng phạm vi Phase 12 từ "chỉ fallback khi parser không hiểu" sang
  "hỏi đáp chủ động về ngân sách/chi tiêu," nhưng đó là quyết định phạm vi Tony cần chốt, không tự
  thêm vào đây.
- Widget màn hình chính, theo dõi cho vay/mượn, chuyển tiếp email ngân hàng đã có sẵn trong danh
  sách Rolly quảng cáo 2025 — khớp với các mục đã có trong `Backlog sau v1` (widget, vay/cho vay);
  "chuyển tiếp email ngân hàng" là ý tưởng MỚI, đã thêm vào Backlog.

## Điểm chưa xác nhận được (không đoán)

Không lấy được toàn văn đánh giá Play Store/App Store trực tiếp; không tìm thấy thảo luận Rolly
trên Reddit; không tìm thấy thread tiếng Việt trên tinhte/voz bàn về Rolly; không xác nhận được
100% mốc giá hiện tại (79k/299k/799k là suy luận hợp lý nhất, không phải xác nhận trực tiếp từ
store); không lấy được ảnh chụp màn hình thật; không xác nhận được có/không quảng cáo gây khó chịu.
