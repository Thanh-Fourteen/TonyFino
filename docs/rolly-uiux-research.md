# TonyFino — Nghiên cứu UI/UX Rolly, đối chiếu màn hình thật (2026-08-22)

Bổ sung cho `docs/rolly-product-research.md` (đã có: giá, tính năng quảng cáo, than phiền người dùng,
góc AI) — file đó tự ghi rõ **"không lấy được ảnh chụp màn hình thật"**. File này lấp đúng khoảng
trống đó: tải trực tiếp 10 ảnh chụp màn hình THẬT từ App Store (`apps.apple.com/us/app/rolly-ai-budget-
money-tracker/id6636525257`, qua iTunes lookup API — không phải suy đoán từ mô tả marketing), soi từng
màn hình bằng mắt, cộng thêm ảnh Tony đã tự chụp từ app thật của mình (gửi trực tiếp trong phiên làm
việc này) và các phát hiện MỚI đào từ chính `raw_rolly/*.json` (schema thật, chưa từng khai thác góc
UI/UX trước đây, chỉ mới dùng cho import).

**Quy tắc nguồn**: mọi mô tả dưới đây đều ghi RÕ mức tin cậy — "thấy ảnh thật" (screenshot trực tiếp),
"chỉ có mô tả chữ" (suy ra từ văn bản, không có ảnh), hoặc "không tìm thấy" (không đoán). Không có phần
nào bịa ra chi tiết hình ảnh không có nguồn.

---

## A. Điều hướng tổng thể (Information Architecture)

**Thấy ảnh thật**: thanh điều hướng dưới cùng có ĐÚNG 4 tab: **Home / Transactions / Money Tools /
Settings** (icon nhà / ví / chồng đồng xu / bánh răng). **Không có tab "Reports" riêng** — biểu đồ nằm
ngay trên Home (biểu đồ tròn), phân tích sâu hơn nằm rải trong từng công cụ ở "Money Tools", không phải
một màn báo cáo tổng hợp độc lập như TonyFino đang có.

**"Money Tools" là một màn hub riêng** (thấy ảnh thật) — danh sách 5 thẻ lớn, mỗi thẻ: icon tròn
gradient xanh ngọc, tiêu đề đậm, mô tả 1 dòng, chevron bên phải:
- **Budget** — "Đặt ngân sách ngày/tuần/tháng để theo dõi chi tiêu"
- **Savings** — "Theo dõi mục tiêu tiết kiệm"
- **Debt** — "Theo dõi và trả hết nợ"
- **Lend/Borrow** — "Theo dõi tiền đã cho vay/đi mượn" *(TonyFino gộp chung khái niệm này vào `Debts`
  qua `DebtKind` — Rolly tách thành hai công cụ riêng trong UI dù dữ liệu `debt`/`loan` gần giống nhau)*
- **Challenge** — "Thi đua tiết kiệm với bạn bè, bảng xếp hạng" — **tính năng xã hội TonyFino hoàn
  toàn không có và KHÔNG nên có** (ngược triết lý không tài khoản/không server, D1/D8)

---

## B. Màn nhập liệu (chat/quick-add) — màn giá trị nhất tìm được

**Thấy ảnh thật**, đây là màn chi tiết nhất tìm được, đáng đối chiếu kỹ với `quick_add_screen.dart`:

- Bong bóng chat: bot chào trước ("Hello! 👋 Let's start adding your transaction here!"), người dùng
  gõ nguyên văn nhiều khoản trong MỘT tin nhắn ("Starbucks 7.45, Electricity 120...") — ảnh marketing
  CỐ TÌNH show case đúng khả năng "nhiều khoản một câu" mà `vatvostudio.vn` (đánh giá độc lập, đã dẫn
  ở `rolly-product-research.md`) nói KHÔNG hoạt động ổn định trong thực tế — một khoảng lệch quảng cáo
  vs. trải nghiệm thật, không phải TonyFino tưởng tượng ra.
- Bot trả lời gộp CẢ bình luận theo tính cách LẪN một dòng còn lại ngân sách có cấu trúc: `"$69.7
  remaining from the budget of $250 for Everyday Food. 📅 (Aug 1 - Aug 31, 2026)"` — Rolly hiển thị
  tiến độ ngân sách NGAY TRONG luồng chat, TonyFino hiện tách hẳn ngân sách sang tab riêng.
- Mỗi giao dịch được phân tích ra một **card "Recorded: Expense"** riêng: icon emoji tròn theo danh
  mục, tên danh mục (đậm), merchant/note (xám, dòng phụ), ngày (góc trên phải), số tiền (góc dưới phải,
  màu đỏ) — cấu trúc thông tin GẦN GIỐNG `DraftCard`/`SavedTransactionRow` của TonyFino, khác biệt
  chính là Rolly hiện NGÀY ở góc thẻ, TonyFino hiện ngày ở header nhóm ngày phía trên (thiết kế khác,
  không phải thiếu).
- **Hàng chip hành động nhanh** ngay TRÊN ô nhập: `↔ Move fund` (chuyển quỹ) và `🔄 Recurring
  transaction` (tạo giao dịch định kỳ) — truy cập NGAY TỪ màn chat, không cần rời màn. TonyFino hiện
  yêu cầu vào Cài đặt → Quản lý giao dịch định kỳ để tạo mới — một khoảng cách UX thật đáng cân nhắc.
- Ô nhập có placeholder DẠY cú pháp bằng ví dụ thật (`"dinner 50, shopping 200"`) — kỹ thuật "dạy qua
  placeholder" TonyFino KHÔNG có (hint text hiện tại là gì, cần soát lại `quick_add_input_bar.dart`).
- **"🪄 Rolly's Memory"** — một liên kết nhỏ dưới ô nhập, KHÔNG tìm thấy mô tả ở bất cứ nguồn văn bản
  nào (kể cả trang chính thức) — tính năng ẩn, không rõ chức năng thật, không đoán.

---

## C. Màn Home/Dashboard

**Thấy ảnh thật (một phần, bị che ~40% bởi overlay quảng cáo)**:
- Dải thẻ ví cuộn ngang ở đầu trang (Everyday/Family/Business...) — TonyFino hiện chọn ví qua dropdown
  chip trong Transactions, không có dải thẻ cuộn ngang riêng ở trang chủ.
- Bộ lọc Tháng/Năm dạng hai dropdown cạnh nhau.
- **Thanh "Health" (đồng hồ sức khoẻ tài chính)** dạng thước đo màu, hiện phần trăm — một tổng hợp
  MỘT chỉ số duy nhất cho "tình hình tài chính tháng này", TonyFino chưa có khái niệm tương đương (gần
  nhất là "An toàn để tiêu hôm nay" ở Phase 15, nhưng đó là số tiền/ngày, không phải một thước đo sức
  khoẻ tổng quát).
- Toggle Chi/Thu dạng pill, biểu đồ tròn theo danh mục ngay dưới.

## D. Màn giao dịch (Transactions) + Ví chia sẻ

**Thấy ảnh thật**:
- Thanh tổng ở đầu MỘT DÒNG DUY NHẤT: mũi tên đỏ (chi) — mũi tên xanh (thu) — tổng ròng, gọn hơn 2 ô
  "Tổng chi/Tổng thu" tách riêng của TonyFino.
- Mỗi giao dịch trong ví CHIA SẺ hiện thêm icon người + tên thành viên đã ghi khoản đó (vd "Emma").
- **Popover "Wallet Members"**: danh sách thành viên + vai trò (Owner/Member) + nút xoá (dấu trừ đỏ) +
  **"+ Create Invite Link"** ở cuối — TonyFino cố tình KHÔNG có tính năng này (D1: không tài khoản,
  không server — chia sẻ ví thật cần backend đồng bộ nhiều người dùng).

## E. Màn Danh mục (Category List)

**Thấy ảnh thật**: danh sách dạng viên thuốc (pill), zig-zag trái/phải xen kẽ (không phải list thẳng
hàng — một lựa chọn thẩm mỹ cụ thể), mỗi hàng: icon emoji tròn nền trắng, tên danh mục, chevron `>` bên
phải gợi ý có thể bấm xem thêm.

🚨 **Không tìm thấy màn tạo/quản lý danh mục PHỤ ở bất cứ nguồn nào** (kể cả ảnh thật) — dù đây chính là
câu hỏi Tony đặt ra tuần này. Chevron trên mỗi hàng CÓ THỂ dẫn tới màn danh mục phụ, nhưng đây là suy
đoán từ hình ảnh, không xác nhận được. **Nguồn xác nhận thật sự tốt nhất vẫn là ảnh chính Tony đã gửi
trong phiên làm việc này** (xem mục G bên dưới) — quý hơn bất kỳ nguồn web nào vì là dữ liệu thật của
chính Tony, không phải suy đoán từ marketing asset.

## F. Ngân sách (Budget) — dưới "Money Tools"

**Thấy ảnh thật**: nav ngang 4 tab con (`🥧 Budget` / `🐷 Savings` / `💳 Debt` / `Lend...`), danh sách
thẻ ngân sách xếp chồng, mỗi thẻ:
- Tiêu đề + icon bút sửa góc trên phải
- Chip danh mục (icon + tên) ngay dưới tiêu đề
- Dòng trạng thái CÓ MÀU: đỏ "`$X exceeded budget of $Y`" hoặc xanh "`$X remaining from budget of
  $Y`", kèm thanh tiến độ màu tương ứng VÀ **badge tròn hiện % ngay giữa thanh tiến độ** (TonyFino
  hiện % qua `BudgetRing` dạng vòng tròn riêng, không đè lên thanh ngang)
- **Viền trái đổi màu đỏ/xanh** theo trạng thái vượt/chưa vượt ngân sách — một tín hiệu thị giác phụ
  TonyFino chưa có (`BudgetRing` chỉ đổi màu chính vòng tròn, card bao quanh giữ nguyên trung tính)
- Footer ngày bắt đầu/kết thúc kỳ, kèm icon lịch

## G. Đối chiếu với ảnh THẬT Tony đã gửi (nguồn đáng tin nhất)

Tony đã tự chụp và gửi 5 ảnh màn hình Rolly thật của chính mình trong phiên làm việc trước đó — đáng
tin hơn ảnh marketing App Store vì là trải nghiệm thật, không phải bản dựng cho quảng cáo:

1. **Sửa ví**: form Tên ví/Tiền tệ/Số dư ban đầu, nút "Quản lý danh mục" NGAY TRONG màn sửa ví (không
   phải một mục Cài đặt tách riêng như TonyFino), toggle "Ví yêu cầu mở khoá sinh trắc học" — khoá vân
   tay ở CẤP VÍ (từng ví một), không phải khoá toàn app như TonyFino (Phase 12, khoá một lần cho cả
   app). Nút "Xoá ví" màu đỏ cảnh báo rõ, nút "Lưu" màu xanh ngọc (khác hệ màu tím chủ đạo TonyFino).
2. **Màn "Loại"** (quản lý danh mục thật): 2 tab Chi phí/Thu nhập, danh sách phẳng có "Chưa được phân
   loại" luôn ở đầu, mỗi hàng có chevron, nút nổi "+ Thêm danh mục" — XÁC NHẬN đây chính là màn dẫn vào
   danh mục phụ.
3. **Màn danh mục phụ THẬT** (bấm vào "Thức ăn & Đồ uống" từ màn 2): tiêu đề = tên danh mục cha + icon
   + bút sửa, section "Danh mục phụ" liệt kê từng danh mục con dạng card có menu `⋮` (sửa/xoá riêng
   từng cái), nút "+ Thêm danh mục phụ" ở cuối — **đây chính là màn TonyFino CHƯA có tương đương**:
   TonyFino tạo danh mục con qua sheet CHUNG "Thêm danh mục" (chọn cha từ danh sách chip), không có màn
   RIÊNG cho từng cha để quản lý tập trung các con của nó. Đáng cân nhắc thêm một màn "chi tiết danh
   mục" (bấm vào một danh mục cha trong `CategoriesScreen` → màn riêng liệt kê + quản lý con của nó)
   thay vì chỉ dựa vào sheet thêm/sửa chung.
4. **Danh sách giao dịch thật**: mỗi giao dịch hiện MỘT chip nhỏ tên danh mục PHỤ ngay cạnh tên danh
   mục cha (vd "Thức ăn & Đồ... [Tiêu vặt]") — TonyFino sau bản vá vừa rồi ĐÃ hiện đúng cơ chế này
   (xác nhận trực tiếp trên máy Tony ở phiên trước), khớp đúng mẫu hình Rolly.
5. **Màn chi tiết danh mục dạng báo cáo thật** (bấm vào danh mục cha từ Báo cáo): header tên danh mục +
   icon sửa, bộ lọc ngày riêng CHO MÀN NÀY (không dùng chung bộ lọc toàn app), tổng Chi/Thu/Ròng, rồi
   **breakdown danh mục phụ dạng danh sách CÓ SỐ TIỀN + %** (đúng những gì `_SubcategoryBreakdownSheet`
   của TonyFino vừa xây), và NGAY BÊN DƯỚI breakdown là **danh sách giao dịch đã lọc theo đúng danh mục
   cha đó, nhóm theo ngày** — TonyFino hiện dừng lại ở sheet breakdown (modal, không cuộn tiếp xem giao
   dịch), Rolly là MỘT MÀN ĐẦY ĐỦ (không phải sheet) có luôn danh sách giao dịch bên dưới.

---

## H. Phát hiện MỚI từ `raw_rolly/*.json` — kiến trúc backend suy luận được qua schema thật

Không phải ảnh UI, nhưng là bằng chứng THẬT (dữ liệu chính Tony đã kéo về từ Phase 2) tiết lộ cách Rolly
vận hành phía sau, đáng ghi lại vì giải thích được một số than phiền đã biết:

- **`categorisation_rule.json` (41 rule thật)** — vòng lặp "học" của Rolly lưu dưới dạng CÂU TIẾNG VIỆT
  ĐẦY ĐỦ kiểu `"gửi xe should be Giao thông"`, `"Tiêm HPV oxytocin should be Gia đình"` — gần chắc chắn
  đây là few-shot examples đút thẳng vào prompt AI mỗi lần phân loại lại, nghĩa là **mỗi lần phân loại
  cần gọi mạng + tốn token AI**. Khác hẳn TonyFino: `category_keywords` (Phase 8) là bảng từ khoá +
  trọng số cục bộ, so khớp thuần Dart, KHÔNG mạng, KHÔNG chi phí biên — đây là một xác nhận thêm cho
  quyết định kiến trúc D7/D8 (offline-first), không phải phát hiện mới cần hành động.
- **`monthly_category_sums_with_total.json` (50 dòng)** — Rolly duy trì một BẢNG CACHE có sẵn tổng theo
  từng danh mục/từng tháng/luỹ kế theo năm (`total_amount`, `all_time_amount`, `total_2024`,
  `total_2025`). Đây là kiến trúc "cache số dẫn xuất" — ĐÚNG lớp kiến trúc mà D7 (TonyFino luôn SUM lại
  từ `transactions`, không bao giờ cache) được thiết kế để tránh. Khớp trực tiếp với than phiền "số dư
  sai/không cập nhật/reset về 0" đã ghi trong `rolly-product-research.md` § C — cache có thể lệch khỏi
  nguồn thật nếu logic đồng bộ có lỗi, đúng lớp lỗi D7 loại trừ được từ đầu.
- **`wallet_view.json`** — ví Rolly có sẵn field `credit_limit`, `due_date`, `type` (giá trị quan sát
  được: `"cash"`, ngụ ý còn giá trị khác như thẻ tín dụng), `member_count`, `to_be_deleted` (xoá mềm).
  TonyFino's `Wallets` hiện chỉ có tên/màu/icon, không có khái niệm hạn mức/ngày đến hạn cho ví dạng thẻ
  tín dụng — một tính năng THẬT Rolly có mà TonyFino chưa từng cân nhắc, đáng đưa vào Backlog nếu Tony
  có nhu cầu theo dõi thẻ tín dụng (hiện dữ liệu thật của Tony chỉ có 1 ví `"cash"`, chưa rõ có cần hay
  không).

---

## Không tìm thấy dù đã tìm kỹ (không đoán)

- Không trang tiếng Việt nào (genk, tinhte, voz — thử lại vẫn không ra) có ảnh chụp màn hình thật kèm
  bài hướng dẫn, dù tiêu đề nhiều bài ghi "hướng dẫn chi tiết".
- Không có bài UX teardown/phân tích thiết kế chuyên sâu nào về riêng Rolly.
- Không lấy được transcript video YouTube review nào.
- Không xác nhận được nội dung màn Settings (chỉ biết nó tồn tại qua icon bánh răng ở thanh điều hướng).
- Ảnh chụp màn hình Android riêng (khác iOS) không tách lọc sạch được từ Play Store — các nguồn văn bản
  đều mô tả luồng giống hệt hai nền tảng, nhưng chưa xác nhận bằng ảnh Android thật.

---

## Ý nghĩa cho TonyFino — tổng hợp việc đáng cân nhắc, CHƯA quyết định gì

Đây là danh sách phát hiện, KHÔNG phải quyết định — đúng quy trình Tony chọn (ghi research trước, sau
đó mới bàn Phase/thực hiện):

1. **Màn "chi tiết danh mục" riêng** (không chỉ sheet) — bấm vào một danh mục ở `CategoriesScreen` →
   màn đầy đủ vừa quản lý danh mục PHỤ vừa xem breakdown/giao dịch của riêng nó, khớp mẫu hình Rolly ở
   mục G.3 và G.5, gộp hai nhu cầu (quản lý + xem báo cáo) đang tách rời ở TonyFino hiện tại.
2. **Hành động nhanh trong luồng chat**: chip "Chuyển quỹ"/"Tạo giao dịch định kỳ" ngay trên ô nhập
   quick-add, thay vì phải rời màn vào Cài đặt.
3. **Hiện tiến độ ngân sách ngay trong câu trả lời chat** khi một giao dịch chạm vào danh mục có ngân
   sách — Rolly làm điều này tự nhiên trong luồng hội thoại.
4. **Một chỉ số "sức khoẻ tài chính" tổng hợp** ở màn chính (khác "An toàn để tiêu hôm nay" hiện có) —
   ý tưởng gamification/tổng quan, chưa rõ có hợp triết lý "sổ cái trung thực, không phán xét" hay
   không (Phase 8 cố tình tránh giọng điệu "chấm điểm"), cần Tony cân nhắc kỹ trước khi làm.
5. **Placeholder dạy cú pháp bằng ví dụ cụ thể** ở ô nhập quick-add — thay đổi nhỏ, dễ làm, đáng soát
   lại `quick_add_input_bar.dart` hiện tại đang hiện gì.
6. **Viền trái đổi màu theo trạng thái vượt/chưa vượt ngân sách** trên card — bổ sung nhỏ cho
   `BudgetRing`/card ngân sách.
7. **Trường `credit_limit`/`due_date` cho ví** — chỉ đáng làm nếu Tony thật sự cần theo dõi thẻ tín
   dụng (dữ liệu thật hiện tại chỉ có 1 ví tiền mặt).
8. **KHÔNG nên làm theo** (mâu thuẫn kiến trúc D1/D8, đã xác nhận lại qua nghiên cứu này): ví chia sẻ
   nhiều người dùng thật (cần backend), tính năng "Challenge" thi đua bạn bè (cần backend + tài khoản
   xã hội), cache số dẫn xuất kiểu `monthly_category_sums` (đã xác nhận là nguồn gốc khả dĩ của bug số
   dư sai Rolly gặp phải).
