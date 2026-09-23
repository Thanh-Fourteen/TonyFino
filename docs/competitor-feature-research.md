# TonyFino — Nghiên cứu tính năng app cùng chủ đề (2026-08-21)

Theo yêu cầu của Tony: nghiên cứu **nhiều app cùng chủ đề, không chỉ Rolly** (xem
`docs/rolly-product-research.md` cho riêng Rolly), học hỏi cái hay của từng app, tìm tính năng
TonyFino còn thiếu. Đã nghiên cứu 12 app: **Money Lover, MISA Money Keeper (Sổ Thu Chi MISA),
Realbyte Money Manager** (phổ biến ở VN) và **YNAB, Copilot Money, Monarch Money, PocketGuard,
Goodbudget, Wallet by BudgetBakers, Spendee, Emma, Fast Budget, ZenMoney** (được đánh giá cao quốc
tế). Danh sách dưới đây là tính năng cụ thể tìm được, ĐÃ LOẠI những gì trùng với Backlog cũ (xem
TODOS.md § Backlog sau v1) — mục đích là bổ sung, không lặp lại.

Mỗi mục ghi: tên · mô tả 1 câu · app đã thấy · ước lượng giá trị/công sức cho một dev solo, app
local-only (drift, không backend).

## Quản lý danh mục (khoảng trống THẬT — TonyFino hiện KHÔNG có UI quản lý danh mục nào)

1. **CRUD danh mục + danh mục con + kéo-thả sắp xếp** — thêm/sửa/xoá/sắp lại danh mục chính và
   danh mục con lồng nhau (vd "Ăn uống" → "Cà phê", "Ăn sáng"). *Money Lover, Realbyte Money
   Manager.* Giá trị cao · công sức trung bình (cần schema cha-con + UI sắp xếp + di trú 12 danh
   mục seed hiện có).
2. **Gộp danh mục** — gộp hai danh mục thành một, chuyển hết giao dịch cũ sang, giữ nguyên tổng.
   *Lunch Money, Actual Budget.* Giá trị cao (nhu cầu dedup thật một khi người dùng tự tạo danh
   mục) · công sức thấp (một UPDATE trên `categoryId` + xoá danh mục cũ).
3. **Lưu trữ danh mục (archive) thay vì xoá cứng** — danh mục đã archive biến mất khỏi bộ chọn/đặt
   ngân sách nhưng vẫn hiện trong báo cáo/lọc lịch sử. *Lunch Money, Beyond Budget.* Giá trị cao ·
   công sức thấp (thêm cột `archived` boolean, lọc ở query).
4. **Nhóm danh mục 3 tầng** — một lớp nhóm phía trên danh mục/danh mục con, chỉ để gộp báo cáo (vd
   nhóm "Thiết yếu" gồm Ăn uống, Di chuyển, Hoá đơn). *Actual Budget, Origin.* Giá trị trung bình ·
   công sức trung bình.
5. **Loại danh mục (Chi/Thu/Nợ-vay)** — danh mục có kiểu, kiểu quyết định nó xuất hiện ở
   report/màn nào. *Money Lover.* Giá trị trung bình · công sức thấp nếu schema đã có field kiểu.

## Quản lý ví (mảng đã có trong Backlog cũ — bổ sung CHI TIẾT triển khai)

6. **Ví theo loại/mẫu** — Tiền mặt, ngân hàng, thẻ tín dụng, ví mục tiêu tiết kiệm, mỗi loại icon/
   hành vi riêng thay vì một loại ví chung chung. *Money Lover.* Giá trị trung bình · công sức
   thấp-trung bình.
7. **Lưu trữ ví (archive) thay vì xoá** — ẩn ví đã đóng khỏi bộ chọn nhưng giữ lịch sử giao dịch
   cho báo cáo. Giá trị trung bình · công sức thấp.
8. **Ví thẻ tín dụng biết chu kỳ sao kê** — ví "biết" ngày chốt sao kê/ngày đến hạn, tự tính dư nợ
   và số ngày còn lại, nhắc trước hạn (khác nhắc hoá đơn chung chung — đây gắn với số dư thật).
   *MISA Money Keeper, Realbyte Money Manager.* Giá trị trung bình-cao (rất khớp thói quen VN theo
   dõi thẻ tín dụng) · công sức trung bình-cao.
9. **Chuyển khoản giữa ví tự tạo cặp Chi+Thu liên kết, LOẠI khỏi báo cáo theo danh mục** — chi tiết
   triển khai quan trọng: chọn "Chuyển khoản," ví nguồn, ví đích, số tiền, ngày → tự tạo 2 giao
   dịch gắn cờ "chuyển khoản" và CẢ HAI bị loại khỏi báo cáo thu/chi để không thổi phồng số liệu.
   *Money Lover.* Giá trị cao (đây là chi tiết khiến "chuyển khoản giữa ví" thực sự dùng được, không
   chỉ là một checkbox) · công sức trung bình.
10. **Đa tiền tệ theo ví + quy đổi tự động về một tổng** — mỗi ví/tài khoản có thể ở tiền tệ khác
    nhau (VND, USD, vàng quy đổi); một dashboard tổng quy đổi và cộng dồn về một tiền tệ chính theo
    tỷ giá lưu/nhập thủ công. *Wallet by BudgetBakers (150+ tiền tệ), Spendee.* Giá trị trung bình
    (hữu ích cho ai giữ USD/vàng tiết kiệm), khá niche · công sức trung bình-cao (cần bảng tỷ giá
    offline hoặc nhập tay vì app không có backend).

## Kiểu nhập liệu hàng loạt (ngoài chat tự nhiên đã có)

11. **Nhân đôi/sao chép giao dịch** — nhấn giữ hoặc menu tạo bản sao một giao dịch có sẵn (giữ số
    tiền/danh mục/ghi chú, đổi ngày về hôm nay), sẵn sàng sửa và lưu. *BudgetBakers Wallet,
    Expensify.* Giá trị cao (cách rẻ nhất để tăng tốc nhập lặp lại, ngoài chat NLP) · công sức thấp.
12. **Tách một giao dịch thành nhiều danh mục** — một lần mua (vd đi siêu thị) chia số tiền vào
    nhiều danh mục TRONG CÙNG một giao dịch, thay vì phải ghi thành nhiều dòng riêng. *YNAB,
    BudgetBakers Wallet.* Giá trị cao · công sức trung bình (cần schema một-nhiều dòng giao dịch,
    khác cột `categoryId` đơn giản hiện tại).
13. **Mẫu giao dịch/giao dịch yêu thích** — lưu một giao dịch đã cấu hình đủ (số tiền, danh mục,
    ghi chú, đối tượng) thành mẫu có tên, bấm một lần là nhập lại đúng y hệt — khác chat NLP vì
    không cần gõ lại câu. *ExpenseIn ("Add to Favourites"), Fast Budget.* Giá trị trung bình-cao ·
    công sức thấp-trung bình.
14. **Gợi ý nhập nhanh dạng chip** — sau khi đủ lịch sử, màn nhập liệu tự gợi ý các "chip" giao dịch
    khả năng cao (học theo giờ/thứ trong tuần/tần suất); bấm một chip điền sẵn danh mục+số tiền+ghi
    chú. *Pocket Clear.* Giá trị trung bình · công sức trung bình (chỉ cần chấm điểm tần suất/gần
    đây trên dữ liệu local, không cần hạ tầng ML).

## Ngân sách — mở rộng trực tiếp trên tính năng Phase 11 đã có

15. 🔥 **Số "an toàn để tiêu hôm nay"** (PocketGuard gọi "In My Pocket") — MỘT con số duy nhất =
    thu nhập trừ hoá đơn/định kỳ đã cam kết trừ mục tiêu tiết kiệm trừ đã chi, chia đều cho số ngày
    còn lại trong kỳ. Khác vòng nhịp theo TỪNG danh mục đã có (Phase 11) vì đây là con số TOÀN VÍ,
    theo ngày. *PocketGuard — đây là tính năng chữ ký của họ.* Giá trị cao (rẻ, dễ thấy, chỉ là
    phép tính trên dữ liệu đã có sẵn) · công sức thấp-trung bình.
16. **Ngân sách tự cân đối lại** — app phân tích chi thật so với ngân sách, gợi ý chuyển phần dư từ
    danh mục chi ít sang danh mục đang vượt, không đổi tổng. *Copilot Money ("Rebalancing").* Giá
    trị trung bình · công sức trung bình-cao (cần luật gợi ý, không cần ML).
17. **Kỳ ngân sách theo chu kỳ lương (không cố định đầu tháng)** — ngân sách reset theo đúng ngày
    lương thật của người dùng thay vì luôn là ngày 1. *Emma.* Giá trị trung bình (liên quan trực
    tiếp: Phase 11 hiện CHỈ hỗ trợ tháng lịch cố định) · công sức trung bình (kỳ ngân sách cần một
    ngày neo cấu hình được, công thức vạch nhịp phải tính theo ngày neo đó thay vì mốc đầu tháng).
18. 🔥 **Ngân sách kiểu "phong bì" có carry-over TUỲ CHỌN theo từng danh mục** — bật/tắt riêng từng
    danh mục: phần dư cuối kỳ CÓ chuyển sang kỳ sau thay vì luôn reset về 0. *Goodbudget, YNAB
    (chính là triết lý ngân sách phong bì).* Giá trị cao (mở rộng tự nhiên trên hạ tầng ngân sách
    Phase 11 đã có sẵn — có lẽ là mục giá trị cao nhất trong toàn danh sách vì build thẳng lên cái
    đã có) · công sức thấp-trung bình (thêm cờ carry-over + cộng phần dư kỳ trước vào phép tính
    vòng nhịp kỳ mới). **Lưu ý:** Phase 11 đã CHỦ ĐỘNG quyết định KHÔNG carry-over (xem
    `docs/decisions.md` § Phase 11, lý do D7 — không cache/không cộng dồn qua tháng); mục này chỉ
    nên cân nhắc nếu Tony muốn đảo lại quyết định đó có chủ đích, không phải mặc định bật.

## Chia sẻ/gia đình

19. **Ngân sách hộ gia đình dùng chung** — một subscription, nhiều thành viên đăng nhập, dashboard
    chung real-time. *Monarch Money.* Giá trị THẤP cho TonyFino (mâu thuẫn trực tiếp với chủ trương
    không tài khoản/không server/không backend) — ghi lại cho đầy đủ, không đề xuất làm. Công sức
    RẤT CAO (về bản chất cần hạ tầng đồng bộ, đi ngược kiến trúc hiện tại).
20. **Chọn ví nào chia sẻ, ví nào riêng tư** trong ngữ cảnh dùng chung. *Spendee, BudgetBakers
    Wallet.* Cùng lý do #19 — giá trị thấp, công sức cao, không đề xuất.

## Đính kèm

21. **Đính kèm ảnh hoá đơn vào giao dịch** — gắn ảnh (hoặc file có sẵn) vào một giao dịch, xem lại
    sau từ màn chi tiết — KHÁC quét OCR đã có trong Backlog (đây chỉ là "giữ ảnh hoá đơn," không
    phân tích). *Koody, Spendee, Expense Track.* Giá trị cao · công sức thấp-trung bình (image
    picker + lưu file local + thêm cột đường dẫn trong drift).
22. **Gắn vị trí GPS vào giao dịch** — tự động lưu toạ độ lúc ghi giao dịch, xem lại trên bản đồ
    sau này. *Coupa (SmarterTrip).* Giá trị thấp (niche, nhạy cảm quyền riêng tư, không rõ nhu cầu
    thật) · công sức trung bình.

## Thẻ (tags) — độc lập với cây danh mục

23. **Hệ thẻ tự do, độc lập với danh mục** — gắn nhiều thẻ tự do (vd "chuyến-đi-Đà-Nẵng",
    "hoàn-thuế") cắt ngang qua danh mục, lọc/báo cáo được riêng theo thẻ. *Spendee ("labels"),
    Monarch Money (tags).* Giá trị trung bình-cao (thật sự khác trục với khoảng trống quản lý danh
    mục — đáng theo dõi riêng) · công sức trung bình (bảng tag + bảng nối + UI lọc ở báo cáo/tìm
    kiếm).

## Xuất dữ liệu ngoài CSV

24. **Xuất báo cáo PDF** — tạo bản PDF định dạng đẹp (biểu đồ + tổng) để in/chia sẻ, thay vì hàng
    thô. Giá trị trung bình · công sức trung bình (cần package sinh PDF, vd `pdf`/`printing`).
25. **Xuất Excel có định dạng (nhiều sheet, không phải CSV phẳng)** — tách sheet theo kỳ/danh mục,
    có định dạng cơ bản. Giá trị thấp-trung bình · công sức trung bình.

## Khác — đáng chú ý riêng

26. **Không thấy tính năng đồng bộ ngân hàng (bank-sync) là khoảng trống** — hầu hết app quốc tế
    (Wallet, Monarch, Copilot) coi đây là tính năng đầu bảng, nhưng nó mâu thuẫn kiến trúc thẳng với
    chủ trương không tài khoản/không backend của TonyFino — ghi lại để xác nhận đây là loại trừ CÓ
    CHỦ ĐÍCH, không phải bỏ sót.

## Đã gộp vào `TODOS.md` § Backlog sau v1

Các mục #1, #2, #3, #9, #11, #12, #15, #18, #21, #23 (giá trị cao nhất, ít mâu thuẫn kiến trúc
nhất) đã được thêm vào Backlog chính — xem TODOS.md. Các mục còn lại giữ ở đây làm tài liệu tham
khảo, chưa đưa vào Backlog vì giá trị thấp hơn hoặc mâu thuẫn kiến trúc (#19, #20, #26) hoặc niche
(#10, #22, #25).

## Bổ sung 2026-09-23 — tính năng "thú vị", ngoài phạm vi 12 app đã khảo sát

Tony hỏi thêm "tính năng nào thú vị" sau khi 12 app cùng chủ đề đã cạn ý (phần lớn giá trị cao đã
lên lịch/đã build, xem § Đã gộp). Mở rộng sang nhóm liền kề: app tiết kiệm game hoá (Qapital, Zogo,
Fortune City), xu hướng "Wrapped" cuối năm, và soát lại chính code hiện có để tìm khoảng trống thật
(không lặp cơ chế mascot streak/celebrate đã có ở `lib/ui/mascot/mascot_mood.dart`).

**Đã loại có chủ đích** (xem TODOS.md § Backlog, mục "Cân nhắc nhưng KHÔNG đề xuất"): thi đua bạn bè
kiểu "Challenge", điểm "sức khoẻ tài chính" tổng hợp — cả hai mâu thuẫn tông giọng "không phán xét"
(Phase 8/25) và/hoặc cần backend.

**Cả ba mục 27-29 đã code xong (2026-09-23), không còn ở Backlog** — `JarVessel`
(`lib/features/jars/widgets/jar_vessel.dart`), `WrappedScreen`
(`lib/features/reports/wrapped_screen.dart`), `isTetSeason`
(`lib/features/home/domain/tet_season.dart`). Giữ nguyên văn bản nghiên cứu bên dưới làm hồ sơ lý do.

27. 🔥 **Hũ vẽ thành hũ thật, có mực nước dâng** — `JarProgressBar` hiện chỉ là thanh 8px
    (`lib/features/jars/jars_screen.dart:480`), trong khi "hũ" vốn là ẩn dụ vật lý xuyên suốt app.
    `CustomPaint` vẽ hình hũ, mực "nước" dâng theo % tiến độ, sóng sánh nhẹ khi vừa nạp tiền (đổi
    trạng thái, giống cơ chế `MascotMood.celebrate` đã có). *Chưa thấy ở 12 app đã khảo sát — hầu
    hết dùng thanh ngang/vòng tròn chuẩn.* Giá trị cao (đúng bản sắc riêng, tận dụng đúng cái tên
    app đã chọn) · công sức trung bình (CustomPaint + animation, không đụng schema/domain logic).
28. **"TonyFino Wrapped" cuối năm** — thẻ tổng kết trượt xem (danh mục chi nhiều nhất, xu hướng thu,
    tổng số giao dịch, streak dài nhất trong năm) dựng từ dữ liệu `reports_repository.dart` đã có
    sẵn, KHÔNG chia sẻ mạng xã hội (khác Spotify Wrapped) — chỉ tự xem, hợp tông "không phán xét".
    *Actual Budget (một trong 12 app đã khảo sát) làm đúng tính năng này cuối 2025
    (actualbudget.org/blog/actual-budget-wrapped-2025).* Giá trị trung bình-cao · công sức thấp
    (không cần hạ tầng mới, chỉ 1 màn tổng hợp + vài query đã có).
29. **Áo Tết cho giao diện** — đổi màu nhấn/icon mascot theo dịp Tết Nguyên Đán (đỏ/vàng, hoa mai/
    đào, lì xì) trong ~1 tuần quanh Tết rồi tự trở lại theme thường — gắn văn hoá người dùng thật
    (Việt Nam). Giá trị trung bình (dễ tạo cảm giác "app quan tâm mình") · công sức thấp (theme
    override có điều kiện ngày qua `Clock`, không đụng kiến trúc).

## Nguồn đã dùng

Money Lover (moneylover.zendesk.com) · Sổ Thu Chi MISA (sothuchi.misa.vn, Play Store) · Realbyte
Money Manager (Play Store) · YNAB (support.ynab.com) · Copilot Money (copilot.money,
developer.apple.com) · Monarch Money (help.monarch.com) · Wallet by BudgetBakers
(budgetbakers.com, support.budgetbakers.com) · Goodbudget/PocketGuard (forbes.com/advisor) ·
Spendee (spendee.com) · Emma (emma-app.com) · Fast Budget (fastbudget.app) · ZenMoney (App Store) ·
Lunch Money (support.lunchmoney.app, lunchmoney.app/blog) · Actual Budget (actualbudget.org) ·
Pocket Clear (pocketclear.app) · ExpenseIn (docs.expensein.com) · Koody (koody.com) · getfinny.app
(đa tiền tệ 2026).
