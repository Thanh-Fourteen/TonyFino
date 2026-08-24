# TonyFino — Nghiên cứu thiết kế vòng 2: "đẹp, 3D, thú vị" (2026-08-21)

Tony yêu cầu rõ trước khi làm các phase sau: nghiên cứu màu sắc/giao diện/hình nền theo hướng
**đẹp, 3D, thú vị** hơn nữa. Đây là nghiên cứu thật (web search, có trích nguồn), KHÔNG phải mockup
đã quyết — mục đích là đưa ra lựa chọn có cơ sở để Tony chọn hướng trước khi biến nó thành một
phase thực thi. Đọc cùng `docs/design-research.md` (Phase 5, đặc tả hiện tại) — tài liệu này KHÔNG
thay thế đặc tả đó, mà đề xuất một vòng tinh chỉnh tiếp theo.

**Quan trọng — căng thẳng cần nhìn thẳng:** nghiên cứu tìm thấy một mâu thuẫn xuyên suốt gần như
mọi nguồn: **app tài chính nghiêm túc đang đi ngược hướng "vui/3D" trong 2025-2026**, không phải
xuôi theo nó, chính vì hành động tài chính có rủi ro thật khiến hiệu ứng vui nhộn dễ đọc thành
"không nghiêm túc." Copilot Money — app ngân sách gần giống TonyFino nhất về việc phải hiển thị
danh sách giao dịch dày đặc số — thắng Apple Design Award 2024 nhờ **sự tiết chế** (typography,
khoảng trắng, animation "cảm giác bản địa"), không phải nhờ trang trí. Cùng lúc, các app đi hướng
"vui" thật sự (Cleo, Monzo) đều định vị là app tính cách/Gen-Z, khác nhóm với một app sổ ghi chép
số liệu. Ba đề xuất bên dưới đều cố tình giữ vùng dữ liệu dày đặc (danh sách giao dịch, biểu đồ,
form) NGUYÊN VẸN như hiện tại — chỉ đổi các vùng "rảnh" (hero card, empty state, onboarding).

## A. Các ví dụ thật đã tìm được

- **Cleo AI** — mascot AI "chị lớn" có "Personality Engine" đổi giọng điệu (mắng/động viên). Nét
  nhận diện chính là PHONG CÁCH MINH HOẠ (cố tình "quirky, funny, ironic" chứ không polish/hình
  học), dùng ở bong bóng chat, empty state, onboarding — không phải hiệu ứng 3D render. Đây là ví
  dụ gần nhất với ý "linh vật cho empty state" mà `docs/design-research.md` (Phase 5) đã bỏ ngỏ.
- **Monzo** — làm mới thương hiệu bằng màu táo bạo (xanh ngọc/hồng/cam) + giọng văn đơn giản +
  minh hoạ vui, KHÔNG phải render 3D hay motion nặng.
- **Copilot Money** — lọt vào chung kết Apple Design Award 2024 nhờ sự rõ ràng/tiết chế, phản ví
  dụ mạnh nhất cho hướng "vui/3D" trong đúng bối cảnh gần TonyFino nhất.
- **Wise/Revolut** — một bài phân tích xu hướng fintech 2026 chỉ thẳng: vài năm trước fintech đầy
  confetti/animation nảy mượn từ app mạng xã hội, "năng lượng đó đã nguội thành thứ có mục đích
  hơn." Motion còn lại (vd Wise vẽ tiền di chuyển) là motion CHỨC NĂNG (minh hoạ đúng việc đang xảy
  ra), không phải trang trí thuần.
- **Apple "Liquid Glass"** (iOS 26, 2025-2026) — xu hướng "3D-ish" thống trị toàn nền tảng: kết hợp
  skeuomorphism + flat + glassmorphism thành một chất liệu (trong suốt, khúc xạ, phản ứng ánh
  sáng/chuyển động). Về bản chất là phiên bản mở rộng của đúng kỹ thuật TODOS.md đã duyệt hẹp (2
  chỗ: nav bar + thanh nhập chat) — chỉ khác là động và lan rộng hơn nhiều.
- **Claymorphism** (bo góc lớn + bóng đúp mềm + màu pastel) — hướng dẫn thiết kế xếp nó vào NICHE
  rõ ràng ("onboarding, app trẻ em, fintech thân thiện, trang landing 3D") và CẢNH BÁO thẳng: tránh
  dùng cho "bảng dữ liệu dày, dashboard cần đọc nhanh/nghiêm túc" — đúng mô tả màn Giao dịch/Báo cáo
  của TonyFino. Màu pastel còn có rủi ro tương phản WCAG AA thật.
- **Bento grid** — được gọi là "xu hướng UI định hình 2025-2026" cho MÀN HÌNH DÀY DỮ LIỆU cụ thể
  (Amplitude/Mixpanel/Datadog dùng để nhét 15-30 chỉ số mà không choáng ngợp). Đây là xu hướng BỐ
  CỤC, không phải trang trí 3D — và TonyFino ĐÃ dùng đúng pattern này ở màn Báo cáo (Phase 10)
  trước khi biết nó là xu hướng, tín hiệu tốt.
- **Minh hoạ isometric/3D** — phổ biến ở trang landing/marketing fintech (heo đất, khoá bảo mật vẽ
  3D), không phải ở màn hình trong-app dày dữ liệu.
- **Duolingo (Duo)** — case study gamification/mascot được trích dẫn nhiều nhất: mascot phản ứng
  CẢM XÚC theo hành vi người dùng (streak, bỏ bê), chỉ xuất hiện ở khoảnh khắc cụ thể (empty state,
  phần thưởng), không thường trực trên màn hình.

## B. Vật liệu/kỹ thuật dùng được trong Flutter — không cần template trả phí

| Lựa chọn | Là gì | Giấy phép | Dùng được cho TonyFino? |
|---|---|---|---|
| Microsoft Fluent Emoji (bản 3D) | ~1500-3000 emoji 3D bóng, chính chủ Microsoft | **MIT** | Có — miễn phí thật, không cần ghi công ngoài giữ license notice. Nên dùng nhỏ giọt (icon danh mục điểm nhấn, không phải toàn bộ hệ icon) vì phong cách bóng/3D lệch với thẩm mỹ phẳng hiện tại |
| 3dicons.co | 1500+ icon 3D vẽ tay, gốc Figma | **CC0** (bản miễn phí) | Có, không cần ghi công. Chưa xác nhận được định dạng export (SVG/PNG hay chỉ Figma) — cần kiểm tra trước khi chốt |
| Iconoir/Lucide/Remix/Hugeicons/Atlas | Icon phẳng/outline mã nguồn mở, có package Flutter/Dart | MIT/ISC/Apache 2.0 | Có, nhưng là icon 2D — chỉ hợp vai "phương án dè dặt," không phải hướng 3D/vui |
| unDraw | Thư viện minh hoạ phẳng/bán-3D, đổi màu được | Miễn phí thương mại, **không cần ghi công** | Có — hợp cho empty state/onboarding |
| Storyset | Thư viện minh hoạ, một số bộ nghiêng 3D hơn | Bản miễn phí YÊU CẦU ghi công | Dùng được nhưng cần màn "credits" trong app — cấn với chủ trương "không lối tắt" của Tony |
| Blush | Thư viện minh hoạ pha trộn được | Bản miễn phí cho phép dùng thương mại | Dùng được, nhưng license tính theo TỪNG gói/hoạ sĩ — phải kiểm tra riêng từng bộ |
| `rive` (package Flutter) | Runtime animation vector tương tác, có state machine — hợp để làm mascot phản ứng theo state app | Rive Editor có bản miễn phí (một số tính năng team trả phí); **runtime + package Flutter dùng để phát MIỄN PHÍ** | Dùng được đúng kịch bản Phase 5 đã bỏ ngỏ ("linh vật cho empty state") — chi phí nằm ở khâu VẼ/dựng animation (làm ở bản Rive Editor miễn phí), không phải khâu chạy trong app |
| `lottie` (package Flutter) | Animation JSON xuất từ After Effects, kho cộng đồng lớn trên LottieFiles | Lottie mã nguồn mở/miễn phí; từng file `.json` có license riêng (nhiều loại miễn phí+ghi công) | Dùng được cho animation một lần đơn giản; với mascot tương tác phản ứng dữ liệu sống thì `rive` kỹ thuật hợp hơn (file nhỏ hơn tới 10 lần, tương tác tốt hơn theo báo cáo) |
| `mesh_gradient` (pub.dev) | Widget nền gradient mesh động, chạy bằng shader (`flutter_shaders`) | **MIT** | Dùng thẳng được, không cần asset ngoài — khớp thật với ý "hình nền" mà không cần commission tranh hay template trả phí. Chi phí GPU cần đo trên máy thật |
| `flutter_shaders` + tự viết GLSL (`FragmentProgram`) | API chính chủ Flutter (từ 3.7) để viết fragment shader chạy trên GPU, bọc qua `CustomPaint`/`ShaderBuilder` | Giấy phép SDK Flutter (miễn phí) | Lựa chọn "tự viết, không lối tắt" thuần nhất — không asset ngoài, không license phải theo dõi. Đòi hỏi công sức viết shader thật, không phải chỉ nhét package |
| `BackdropFilter` (đã dùng ở 2 chỗ) | Blur gốc Flutter | N/A | Đã duyệt hẹp. **Xác nhận được rủi ro GPU là thật, không phải lý thuyết**: issue công khai trên GitHub Flutter ghi nhận blur chồng lớp gây hồi quy raster-thread (~6ms/frame Skia so với ~16-24ms/frame Impeller) khi có nhiều lớp blur, nhất là lúc cuộn — đúng khớp lý do TODOS.md đã tự giới hạn glass ở 2 chỗ |

**Tóm tắt B**: không có rào cản giấy phép nào — mọi hướng (icon 3D, minh hoạ, nền động) đều có
lựa chọn miễn phí/mã nguồn mở thật. Rào cản thật nằm ở (1) **đồng bộ phong cách** — hầu hết bộ icon
3D/minh hoạ miễn phí có nét bóng/tròn trịa, lệch hẳn thẩm mỹ "sổ cái in đẹp" hiện tại, cần biên tập
kỹ hoặc tô lại màu mới không bị "dán đè lên," và (2) **chi phí GPU**, đã có bằng chứng thật từ
chính lý do TODOS.md giới hạn glass hẹp.

## C. Hình nền/wallpaper sau màn hình dày dữ liệu — mảng nghiên cứu mỏng nhất

Không tìm được ví dụ cụ thể, có tên, được khen "làm tốt" về việc đặt hình nền trang trí NGAY SAU
một danh sách số cuộn được — nói thẳng thay vì phóng đại. Điều tìm được:
- Mẫu số đông trong app tài chính: nền phẳng gần trắng/gần đen, màu/hoạ tiết CHỈ xuất hiện ở vùng
  khoanh vùng riêng (hero card số dư, vùng biểu đồ, badge danh mục) — không chạy liên tục sau các
  hàng danh sách.
- Nơi có sự phong phú thị giác, nó luôn nằm ở vùng hero/tổng quan, còn danh sách quay lại phẳng,
  tương phản cao. Khớp cách Copilot Money làm (bề mặt danh sách sạch, độ phong phú dồn vào biểu đồ)
  và khớp logic bento grid (thú vị nằm ở cách chia ô, không phải ảnh nền bên dưới chữ).
- Cảnh báo rõ nhất tìm được về "làm sai" đến từ chính hướng dẫn claymorphism: hình khối mềm và dữ
  liệu dày là "một cuộc hôn nhân tệ," tránh dùng cho bảng/dashboard cần đọc nhanh.

**Kết luận C**: app tài chính dồn độ phong phú thị giác vào vùng RIÊNG, giới hạn thông tin thấp
(hero card, header, onboarding, empty state, nền biểu đồ) và giữ bề mặt danh sách/bảng phẳng, tương
phản cao — đây là phát hiện có cấu trúc, không chỉ gu thẩm mỹ.

## D. Ba hướng đề xuất — CHƯA quyết, để Tony chọn

**Hướng 1 — "Phong phú có giới hạn":** giữ nguyên 100% vùng dữ liệu (danh sách, form, biểu đồ),
dồn mọi hiệu ứng 3D/vui/hình nền vào một số vùng nhỏ không chứa dữ liệu: nền gradient mesh/shader tự
viết sau hero card màn Giao dịch, mascot Rive/Lottie chỉ ở empty state + onboarding (đúng điều kiện
Phase 5 đã bỏ ngỏ), 3-6 icon 3D chọn lọc (Fluent Emoji MIT hoặc 3dicons CC0, tô lại màu khớp bảng
tím/ngà) chỉ dùng cho glyph danh mục hoặc khoảnh khắc ăn mừng (vd đạt mục tiêu ngân sách), KHÔNG
BAO GIỜ trong hàng giao dịch.
- Đánh đổi thật: đây là hướng ÍT thay đổi nhất — phần lớn thời gian dùng app (danh sách giao dịch)
  trông y hệt hôm nay. Nếu Tony muốn app "cảm giác khác" mỗi lần mở lên, hướng này chưa đủ.
- Độ khó Flutter: **thấp-trung bình**, rủi ro GPU thấp vì shader chỉ chạy sau MỘT vùng hero, không
  chạy lúc cuộn danh sách dài (né đúng kiểu hồi quy `BackdropFilter`/Impeller đã tìm thấy ở mục B).

**Hướng 2 — "Kính lỏng phiên bản nhẹ":** mở rộng glassmorphism đã duyệt (2 chỗ) sang thêm vài chỗ
có kiểm soát (hero card số dư, header sheet), dùng `BackdropFilter`/shader gốc Flutter, KHÔNG dùng
icon 3D.
- Đánh đổi thật: đây KHÔNG PHẢI điều Tony xin ("đẹp, 3D, THÚ VỊ") — kính mở rộng đọc ra "cao
  cấp/thanh lịch" hơn là "vui." Không chạm trục mascot/minh hoạ/tính cách nào. Tái xác nhận đúng
  rủi ro GPU mà TODOS.md từng dùng để giới hạn glass — mỗi bề mặt blur thêm là chi phí đã có bằng
  chứng, cần đo trên máy thật trước khi chốt, không chỉ quyết bằng mắt.

**Hướng 3 — "Lớp tính cách":** thêm một mascot vẽ tay/commission (dựng bằng Rive, đúng điều kiện
Phase 5 đã bỏ ngỏ) + một hệ minh hoạ tiết chế cho empty state, khoảnh khắc đạt mốc, onboarding —
giữ nguyên hoàn toàn danh sách giao dịch/form/biểu đồ.
- Đánh đổi thật: đây là hướng khớp nhất với cảm giác "3D và vui" thật sự (theo đúng các ví dụ tìm
  được — Cleo, Duolingo) vì mascot/minh hoạ theo bản chất sống ở không gian TRỐNG, không cạnh
  tranh với số liệu dày. Rủi ro: làm dở (dùng nguyên xi asset miễn phí không biên tập) sẽ trông
  "template" — đúng thứ Tony muốn tránh, dù đúng luật giấy phép. Độ khó Flutter **trung bình**:
  tích hợp package `rive` đơn giản, nhưng thiết kế state machine cho mascot phản ứng dữ liệu thật
  (streak, chi tiêu tăng vọt, đạt mục tiêu) là công sức thiết kế thật, không phải việc thêm nhanh.

**Tổng hợp trung thực**: không nguồn nào ủng hộ việc đưa 3D/vui/kính chạm vào danh sách giao dịch,
form, hay số liệu — mọi nguồn liên quan (rõ nhất là hướng dẫn claymorphism, nhưng cả Copilot Money
lẫn phát hiện mục C) đều coi dữ liệu tài chính dày và trang trí 3D/kính/clay nặng là CĂNG THẲNG với
nhau, không trung lập. Đề xuất mạnh nhất, trung thực nhất: **Hướng 1 kết hợp một phần Hướng 3** —
giữ nguyên các bề mặt "sổ cái" như hiện tại, dồn toàn bộ ngân sách "đẹp, 3D, thú vị" vào một số vùng
có giới hạn (nền hero card, empty state, mascot, khoảnh khắc ăn mừng) — đây cũng là đường rẻ nhất
và rủi ro GPU thấp nhất để làm trong Flutter. Hướng 2 (mở rộng kính) là thay đổi an toàn nhất nhưng
là hướng ÍT có khả năng thoả đúng yêu cầu "vui" nhất, vì kính đọc ra cao cấp/lạnh chứ không ấm/vui.

## Nguồn đã dùng

Cleo AI: laurenrowe.co.uk, gventures.co, izzoul.com · Monzo: creativereview.co.uk, monzo.com/blog ·
Copilot Money: apple.com/newsroom (ADA 2024), developer.apple.com/articles · Fintech trend 2026:
wandr.studio/blog · Liquid Glass: apple.com/newsroom, wikipedia.org, designmonks.co · Claymorphism:
setproduct.com, designmd.app · Bento grid: beryldesign.fr, orbix.studio · Minh hoạ isometric:
lummi.ai · Duolingo: 925studios.co, strivecloud.io · Fluent Emoji: github.com/microsoft/fluentui-emoji
· 3dicons: 3dicons.co · unDraw/Storyset/Blush: trang chính thức từng bộ · Rive/Lottie: pub.dev,
tài liệu chính thức · `mesh_gradient`/`flutter_shaders`: pub.dev, docs.flutter.dev · `BackdropFilter`
GPU cost: issue công khai trên github.com/flutter/flutter.
