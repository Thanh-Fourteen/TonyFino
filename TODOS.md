# TonyFino — App quản lý chi tiêu thay thế Rolly

> **Cách dùng file này.** Mỗi `##  Phase N` là một phase chạy được. Khối ``` cuối cùng không nhãn trong phase chính là prompt gửi đi; các khối có nhãn (```dart, ```text) chỉ là ví dụ, tool bỏ qua. Phase coi như xong khi **toàn bộ checkbox trong phase đã tick** — nên mỗi prompt đều kết bằng lệnh tự tick.
>
> Các mục `##` không phải phase (Context, Design system, Bối cảnh chung, …) không có khối không-nhãn nên tool tự động bỏ qua. Chúng là tài liệu tham chiếu mà prompt trỏ tới — đó là cách một session mới hoặc sau compact lấy lại toàn bộ ngữ cảnh.

---

## Context — vì sao làm việc này

Tony đang dùng **Rolly: AI Budget Money Tracker** vài tháng nay. Rolly khoá sau paywall (79.000đ/tháng · 299.000đ/năm · 799.000đ vĩnh viễn) đúng những thứ đáng giá nhất: nhiều ví, export CSV, xem lịch chi tiêu, dark mode, khoá vân tay, quét hoá đơn. Tệ hơn, review App Store cho thấy **paywall creep** — mỗi bản cập nhật lại khoá thêm một tính năng đang miễn phí — và Apple privacy label khai báo app **theo dõi quảng cáo xuyên app**, điều không chấp nhận được với một app tài chính.

Mục tiêu: xây **TonyFino** — bản thay thế cá nhân, chạy Android trước, codebase sạch để port iOS sau, dữ liệu nằm hoàn toàn trên máy, không tài khoản, không server, không chi phí định kỳ, **và đẹp hơn hẳn Rolly**. Toàn bộ lịch sử giao dịch trong Rolly phải được đưa sang, đối chiếu khớp số.

**Kết quả mong đợi:** APK cài trên `redmi-note-13-pro`, chứa đủ lịch sử cũ, nhập chi tiêu bằng tiếng Việt tự nhiên, biểu đồ + ngân sách đầy đủ, mọi thứ Rolly tính phí đều miễn phí.

### Ba lỗi của Rolly phải đánh bại (rút từ review thật)
1. **Số dư ví sai / không cập nhật sau khi thêm giao dịch** — than phiền số 1, áp đảo. → Quyết định D7.
2. **Giao dịch âm thầm không lưu được**, form sửa thiếu nút Save. → Quyết định D7 + Phase 6.
3. **Một tin nhắn chỉ nhận ra một khoản chi** dù quảng cáo "Café 30k, Xem phim 100k". → `segmenter.dart`, Phase 7.

Cộng thêm một điều Tony yêu cầu rõ: **giao diện phải siêu đẹp và hiện đại.** Rolly bị chê "sparse and crude" — thưa thớt và thô. Toàn bộ Phase 5 dành riêng cho việc này.

---

## Phạm vi v1 (Tony đã chốt)

**Có trong APK đầu tiên:** nhập chat tiếng Việt + tự phân loại · import toàn bộ dữ liệu Rolly cũ · biểu đồ + báo cáo + ngân sách · **design system hoàn chỉnh light + dark**.

**Hoãn sang Phase 12+:** nhiều ví & chuyển khoản · mục tiêu tiết kiệm · vay/cho vay · nhắc hoá đơn · quét hoá đơn OCR · nhập giọng nói · widget màn hình chính · AI personalities ("Mẹ Thiên Hạ").

---

## Quyết định đã chốt (D1–D10)

| ID | Quyết định | Lý do |
|---|---|---|
| **D1** | Tên hiển thị **TonyFino**, `applicationId` = **`dev.tony.tonyfino`**. Bản debug thêm `applicationIdSuffix ".dev"`, label `TonyFino (dev)` | `applicationId` **bất biến trọn đời app** — đổi sau = app khác = mất dữ liệu. Suffix `.dev` khiến bản emulator và bản thật là hai package Android riêng, hai thư mục dữ liệu riêng → **không đời nào bản debug xoá nhầm lịch sử tài chính thật** |
| **D2** | `git init` ngay Phase 1. `.gitignore` phải chặn `raw_rolly/`, `dist/`, `*.jks`, `key.properties`; **không được** ignore `drift_schemas/`, `test/fixtures/`, `*.g.dart` | `drift_schemas/*.json` không vào git thì migration test vô nghĩa. Corpus parser cần lịch sử blame vì sẽ tinh chỉnh hàng tháng |
| **D3** | **Keystore release riêng** tại `~/keystores/tonyfino-release.jks`, sao lưu 3 nơi. Gradle **fail lớn** nếu thiếu `key.properties`, tuyệt đối không rơi về debug signing | Android: APK ký khác key ⇒ buộc gỡ cài ⇒ **xoá sạch dữ liệu**. `~/.android/debug.keystore` tự sinh lại nếu bị xoá → mọi bản build sau đó thành uninstall-only, âm thầm, muộn, thảm hoạ. Template Flutter *lặng lẽ* rơi về debug signing khi thiếu `key.properties` — phải chặn |
| **D4** | `versionCode` tăng đơn điệu thủ công mỗi lần cài lên máy. `versionName` semver theo phase: `0.1.0` → `1.0.0`. Mọi build nhúng `--dart-define=GIT_SHA=...` hiện ở Settings → About | Tự deploy, không có store ⇒ "APK nào đang nằm trên máy?" thành câu hỏi thật trong 2 tuần. `schemaVersion` của drift **độc lập**, không gắn với version app |
| **D5** | **Cắt khỏi v1:** `workmanager`, `flutter_local_notifications`, `permission_handler`, `local_auth` | Đều phục vụ tính năng đã hoãn. Mỗi cái là một plugin 0.x nằm chắn đường tới APK đầu tiên. Auto-backup v1 dùng **kiểm tra khi app resume** — vốn đã là đường chính, `workmanager` chỉ là đai an toàn thêm |
| **D6** | Build **universal APK**, KHÔNG `--split-per-abi` | Emulator là `x86_64`, điện thoại là `arm64-v8a`. Split ⇒ **file đã test không phải file đem cài**. Quan trọng gấp bội vì sqlite3mc **biên dịch từ C theo từng ABI**. Đổi lại ~8 MB — không đáng bận tâm khi sideload |
| **D7** | **Số dư luôn là giá trị dẫn xuất, không bao giờ lưu.** Không có cột `balance` ở bất cứ đâu. Balance = `SUM(amount_minor)` phát qua drift `Stream` | Đây là câu trả lời cho than phiền số 1 của Rolly. Không có cache thì không thể sai. Kèm theo: mọi write của repository trả `Result<T, AppError>`, **zero fire-and-forget**, lỗi hiện blocking dialog + ghi vào bảng `app_events` |
| **D8** | AI proxy **host trên tailnet của máy này** (`/tonyfino-ai/`) thay vì Cloudflare Worker. Base URL cấu hình được trong Settings. **Cloud fallback mặc định TẮT**, có sheet đồng ý một lần | Worker = endpoint public giữ key tính tiền ⇒ kế thừa rủi ro lạm dụng, phải viết quota/KV, phải chặn trần chi tiêu, phải có tài khoản Cloudflare + `wrangler login` (cần browser — mà máy chỉ có Firefox). Trong khi đó **điện thoại đã ở trên tailnet**, `tailscale serve` mặc định chỉ tailnet ⇒ xác thực ở tầng mạng theo danh tính thiết bị, **APK không chứa credential nào**. Giao thức giống hệt nên Worker vẫn là bản thay thế cắm-vào-là-chạy ở Phase 15 nếu cần dùng ngoài tailnet |
| **D9** 🎨 | **Không fork, không mua template.** Tự viết design system + ~15 widget riêng | Đã rà toàn bộ GitHub: app Flutter finance **đẹp** thì đều copyleft (Cashew GPL-3.0, Monekin AGPL-3.0, BeeCount Business Source), app **license dùng được** thì đều nhìn tầm thường (sossoldi MIT, totals MIT, waterfly MIT). Template CodeCanyon $7–29 là code Flutter-3.0-era `setState`/GetX với màu hardcode — gắn vào Riverpod 3 + drift + ThemeExtension tốn công hơn viết mới, chưa kể không ai nghĩ tới tiếng Việt. ~15 widget riêng ≈ 2–3 ngày, và đó chính là chỗ tạo khác biệt |
| **D10** 🎨 | **Lưu `categoryColorId INTEGER` trong DB, TUYỆT ĐỐI không lưu chuỗi hex** | Sai lầm không thể đảo ngược phổ biến nhất trong app quản lý chi tiêu. Lưu ID rồi resolve qua `ThemeExtension` mới giữ được dark mode đúng, mới đổi được cả bảng màu trong một file, mới thêm được theme AMOLED/tương phản cao sau này miễn phí |

**D8 — cảnh báo riêng về quyền riêng tư:** Gemini **free tier dùng prompt của bạn để train**. Prompt ở đây là *"Ăn trưa với sếp 250k"* gắn với một người thật. Hai biện pháp, đều rẻ: (a) đặt key **paid tier** lên proxy — paid tier không bị train, ở mức fallback-của-fallback chỉ tốn vài xu/tháng; (b) mặc định TẮT cloud fallback. Làm cả hai.

---

## 🎨 Design system — đặc tả chốt

Nghiên cứu đầy đủ đã xong. Đây là bản rút gọn để thực thi; lý do chi tiết ghi trong `docs/design-research.md` ở Phase 5.

### Cảm giác tổng thể, ba câu
> **TonyFino nên có cảm giác như một cuốn sổ cái Việt Nam in đẹp, không phải một dashboard fintech.** Nền trắng ngà hoặc mực đậm tĩnh lặng, một sắc tím tự tin duy nhất, màu chỉ dùng ở nơi mang nghĩa, và chữ gánh gần như toàn bộ công việc — số to dạng bảng đặt cạnh chữ Việt yên tĩnh có đủ chỗ cho dấu thở. Nó phải **nhanh và im lặng**: không gì chuyển động trừ khi một con số vừa đổi, và màn chat trả lời dưới 50 ms bằng một thẻ sửa được trong một chạm.

**Phản đề:** Rolly bị chê "sparse and crude". **Thưa thớt ≠ tối giản.** Vấn đề của Rolly là trống rỗng vì thiếu thiết kế. Của ta phải là tối giản **hào phóng** — chữ to, đệm rộng, phân cấp có chủ ý, và một khoảnh khắc thú vị cho mỗi tương tác.

### Font — có một cái bẫy chết người ở đây

🚨 **`DM Sans` và `Figtree` KHÔNG có bộ tiếng Việt.** Cả hai cực kỳ phổ biến trong ảnh design fintech; **Cashew ship thẳng DM Sans**. Dùng là ra ô vuông tofu hoặc nhảy font giữa chừng từ. Đã kiểm chứng trực tiếp qua file `METADATA.pb` của Google Fonts.

**Cặp font chốt: `Be Vietnam Pro` cho chữ + `Inter` cho số.** Cả hai OFL, **bundle cục bộ trong pubspec, KHÔNG dùng `google_fonts`** (nó tải HTTP lúc chạy → nháy font khi khởi động nguội không mạng, trong khi app này là offline-first).

- **Be Vietnam Pro** — font duy nhất trong danh sách được *thiết kế riêng cho tiếng Việt*, có "diacritics adaptive forms" nên `ế` và `ữ` không chen chúc ở cỡ 13sp. Không phải variable → bundle 4 file tĩnh (400/500/600/700, ~500 KB)
- **Inter** — font duy nhất kiểm chứng được **đồng thời** có tabular figures, slashed zero, trục `opsz` 14–32 **và** bộ tiếng Việt. Dùng **chỉ cho tiền, ngày, phần trăm, trục biểu đồ**. Bundle một file variable duy nhất, điều khiển qua `fontVariations`

*Vì sao không dùng Inter cho tất cả?* x-height của Inter rất lớn → ít chỗ đứng nhất cho dấu chồng của tiếng Việt ở cỡ nhỏ, mà danh sách giao dịch sống đúng ở cỡ nhỏ.
*Dự phòng nếu muốn một font duy nhất:* **Plus Jakarta Sans** (Việt ✅, tabular ✅ từ v2.500).

**Tabular figures là bắt buộc, không thương lượng:**
```dart
const kMoneyFeatures = [FontFeature.tabularFigures()];
```
Thiếu `tnum` thì cột số tiền căn phải **giật nhìn thấy được** mỗi khi chữ số đổi — đúng cái cảm giác bảng tính rẻ tiền đang muốn thoát khỏi.

**Chống cắt dấu — bắt buộc mọi `TextStyle`:** `height` body ≥ **1.45**, title ≥ 1.30, display ≥ 1.15; đặt `leadingDistribution: TextLeadingDistribution.even`. Chuỗi test trong mọi golden: **`Đồng Nai — ế ữ ỗ ặ ỡ Ế Ữ Ỗ · 1.234.567 ₫`**

| Role | Family | Size / Weight / Height | Letter-spacing |
|---|---|---|---|
| `moneyHero` | Inter | 40 / 700 / 1.10, `opsz 32`, **tnum** | −0.02em |
| `moneyLarge` | Inter | 28 / 600 / 1.15, **tnum** | −0.01em |
| `moneyMedium` | Inter | 17 / 600 / 1.20, **tnum** | 0 |
| `moneySmall` | Inter | 13 / 500 / 1.25, **tnum** | 0 |
| `displayLarge` | Be Vietnam Pro | 30 / 700 / 1.25 | −0.01em |
| `titleLarge` | Be Vietnam Pro | 20 / 600 / 1.30 | 0 |
| `titleMedium` | Be Vietnam Pro | 16 / 600 / 1.35 | 0 |
| `bodyLarge` | Be Vietnam Pro | 15 / 400 / **1.50** | 0 |
| `bodyMedium` | Be Vietnam Pro | 14 / 400 / **1.50** | 0 |
| `labelMedium` | Be Vietnam Pro | 12 / 500 / **1.45** | +0.01em |

### Màu — nguồn chân lý là Radix Colors (MIT)

[radix-ui/colors](https://github.com/radix-ui/colors) là lựa chọn đúng vì thang 12 bậc có **biến thể sáng và tối thiết kế cùng nhau** nên hai theme không thể lệch nhau, và tương phản tính bằng **APCA** chứ không phải WCAG 2.x. Phân vai: **bậc 9 = màu đặc** (chấm, cột, series biểu đồ), **bậc 11 = chữ tương phản thấp**, **bậc 12 = chữ tương phản cao**.

**Brand primary: tím `#6E56CF`** (Radix violet 9). Cố ý: mọi thương hiệu tài chính Việt Nam đều xanh dương (Timo, ZaloPay, VPBank), đỏ (Techcombank, TPBank), hoặc hồng sen (MoMo). Tím khác biệt trong thị trường đó, đọc ra "bình tĩnh & hiện đại" chứ không "ngân hàng doanh nghiệp", và **không tranh nghĩa với xanh/đỏ ngữ nghĩa**.

**Ba luật màu tách app có thiết kế khỏi bảng tính:**
1. **Tô màu con số, không tô cả dòng.** Không bao giờ nhuộm xanh/đỏ cả hàng giao dịch. Chỉ tô chữ số tiền
2. 🔥 **Chi tiêu mặc định là màu trung tính, KHÔNG phải đỏ.** Trong app quản lý chi tiêu ~90% dòng là chi. Đỏ hết thì đỏ vô nghĩa và màn hình gào lên. **Chi render bằng `onSurface`; thu render xanh kèm dấu `+` tường minh. Đỏ chỉ dành riêng cho vượt ngân sách và hành động phá huỷ.** Một quyết định này nâng cảm nhận chất lượng nhiều hơn mọi lựa chọn màu khác
3. **Không bao giờ mã hoá nghĩa bằng riêng sắc độ.** Luôn kèm dấu `+`/`−`, icon, nhãn. Đỏ-xanh chính là cặp va chạm của mù màu deuteranopia/protanopia

| Token | Light | Dark |
|---|---|---|
| `surface` (nền trang) | `#FBFBFD` | `#0C0D10` |
| cards | `#FFFFFF` | `#14161A` |
| `surfaceContainer` | `#F3F3F6` | `#1A1D22` |
| sheets | `#EBEBF0` | `#22262C` |
| `hairline` | `#E4E4E9` | `#2A2F36` |
| `onSurface` | `#16161A` | `#EDEEF0` |
| `onSurfaceVariant` | `#61616B` | `#9BA1A6` |
| `primary` / `onPrimary` | `#6E56CF` / `#FFFFFF` | `#9E8CFC` / `#1B1436` |
| `primaryContainer` / on | `#EDE9FE` / `#3C2F80` | `#2B2251` / `#DDD5FF` |
| `income.text` / `.fill` | `#18794E` / `#30A46C` | `#4CC38A` / `#30A46C` |
| `expense.text` / `.fill` | `#CD2B31` / `#E5484D` | `#FF6369` / `#E5484D` |
| `budgetOk / Warn / Over` | `#30A46C` / `#FFB224` / `#E5484D` | ↑ giống |

**Nước cờ then chốt của light mode: card trắng tinh trên nền hơi ngà.** Khoảng cách 4 điểm độ sáng đó là thứ khiến light mode trông *có thiết kế* thay vì trống trơn — và khiến card đọc ra là nổi lên mà gần như không cần đổ bóng.

**Dark mode: base `#0C0D10` (gần đen, hơi lạnh), không phải `#000000`.** Ship thêm toggle **"Đen tuyền (AMOLED)"** đổi base sang `#000000` — 3 dòng nếu token có cấu trúc đúng. Điện thoại Android ở Việt Nam đa số OLED và người dùng để ý pin.

**12 màu danh mục** (Radix bậc 9, **giống nhau ở cả hai theme** nên legend biểu đồ không nhảy khi đổi theme):
`Ăn uống #F76B15` · `Cà phê #FFB224` · `Đi lại #0091FF` · `Mua sắm #D6409F` · `Hóa đơn #3E63DD` · `Giải trí #8E4EC6` (plum, vì violet đã là brand) · `Sức khỏe #12A594` · `Giáo dục #05A2C2` · `Nhà cửa #AD7F58` · `Quà tặng #E93D82` · `Tiết kiệm #46A758` · `Khác #8D8D8D`

Mắt người chỉ phân biệt tin cậy **6–8 sắc độ** trong một biểu đồ. Nên: **mỗi danh mục luôn kèm icon**, không chỉ chấm màu (đây cũng là cách sửa cho người mù màu); và **giới hạn biểu đồ tròn ở 6 lát + "Khác"**, chạm để xem đầy đủ.

**Heatmap 5 bậc:** light `#EDE9FE → #C7BCF5 → #A48FEB → #8367DE → #6E56CF`; dark `#241D3D → #35295C → #4A3A80 → #6250AB → #9E8CFC`

### Bo góc, khoảng cách, đổ bóng

**Bo góc:** `xs 6 · sm 10 · md 14 · lg 18 · xl 24 · xxl 28 · full 999`. Luật: **bề mặt càng lớn, góc càng lớn.** Chip/avatar/FAB/thanh nhập/pill nav → `full` · nút → `14` · hàng giao dịch → `12` · card → `18` · hero card → `24` + `smooth_corner` 0.6 · bottom sheet (2 góc trên) → `28` + smoothing.

**Khoảng cách** hệ 4: `2 · 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48`. Lề ngang màn hình **16** · đệm trong card **16**, hero **24** · giữa các card **12** · giữa section **24** · **đệm dọc hàng giao dịch 14** (→ hàng ~60px) — *đây là con số phải bảo vệ; nhồi hàng xuống 48px chính là thứ làm app quản lý chi tiêu trông như bảng tính* · divider thụt trái **56** · vùng chạm tối thiểu **48×48**.

**Đổ bóng — Material `elevation:` để `0` ở MỌI NƠI, tự vẽ `BoxShadow`.** Bóng mặc định của Material quá tối, quá chặt, đọc ra ngay "app Flutter mặc định".

| Bậc | Light | Dark |
|---|---|---|
| **0** — trang, hàng | không bóng, không viền | không bóng, không viền |
| **1** — card | `BoxShadow(Color(0x0D0B1220), blur 16, offset (0,4), spread −2)` + hairline `#E4E4E9` | **không bóng.** Bề mặt sáng hơn `#14161A` + viền 1px `#FFFFFF0F` |
| **2** — sheet, menu, nav mờ | `BoxShadow(Color(0x1A0B1220), blur 32, offset (0,12), spread −6)` | **không bóng.** `#22262C` + viền 1px `#FFFFFF14` + highlight trên 1px `#FFFFFF0A` |

🔥 **Dark mode không bao giờ dùng đổ bóng.** Bóng trên nền gần đen thì hoặc vô hình hoặc đục. Chiều sâu trong dark mode là **độ sáng bề mặt + hairline**. Một luật này chiếm phần lớn khác biệt giữa một dark theme tốt và một light theme bị đổi màu.

### Vật liệu — cái nào thật, cái nào hype

| Kỹ thuật | Tình trạng 2026 | Quyết định |
|---|---|---|
| **Glassmorphism** | Thật sự sống lại (Apple Liquid Glass), nhưng bản 2026 sắc nét hơn và **ưu tiên đọc được** | **Dùng đúng HAI chỗ:** thanh bottom nav và thanh nhập chat nổi, cả hai đè lên nội dung cuộn. `BackdropFilter(sigma 20)` + nền 70–80% + hairline 1px trên. **Không chỗ nào khác** — blur nặng trên Android đọc ra là bắt chước Apple, và `BackdropFilter` là một lượt render offscreen thật sự tốn GPU trên máy tầm trung vốn thống trị thị trường Việt Nam |
| **Neumorphism** | **Chết.** Không xuất hiện trong bất kỳ danh sách xu hướng 2026 nào. Tự thân vi phạm tương phản. `flutter_neumorphic` bỏ hoang | **Không bao giờ** |
| **Bento grid** | Thật và hữu ích | **Chỉ ở màn Báo cáo.** Lưới 2 cột ô thống kê + biểu đồ full-width + heatmap full-width. **KHÔNG bento hoá danh sách giao dịch** — danh sách cần nhịp, không cần ô |
| **Neo-brutalism** | Hype với app tài chính | **Bỏ.** Nó đọc ra là *chưa hoàn thiện* — đúng lời chê "sparse and crude" đang muốn thoát |
| **Material 3 Expressive** | Google công bố 5/2025, **Flutter chính thức tạm dừng phát triển 7/2025 và tới nay vẫn chưa có trong SDK**. `material_ui` 1.0.1 cài được trên 3.44 nhưng **không chứa component Expressive nào** | **Không đuổi theo.** Nhưng viết theme sao cho migration sau này là đổi một dòng import: **mọi file token chỉ import `dart:ui`/`painting.dart`, TUYỆT ĐỐI không `material.dart`**. Và tự tay lấy 3 ý tưởng đáng giá: (1) motion đàn hồi nhẹ, overshoot 1.02–1.04, chỉ ở pill nav / chọn chip / dấu tích lưu; (2) **pill nav biến hình** — animate chiều rộng + bo góc thay vì cross-fade; (3) một nấc weight đậm hơn cho display role |

### Bố cục — các quyết định then chốt

- 🔥 **Danh sách giao dịch: hàng tràn viền, KHÔNG phải card-mỗi-hàng.** Đây là quyết định bố cục đòn bẩy cao nhất app. Card-mỗi-hàng ngốn ~30% chiều dọc vào lề và tạo nhiễu thị giác từ viền lặp. Thay vào đó: hàng full-bleed trên bề mặt nền, chia bằng hairline thụt vào ngang chữ, gom dưới **header ngày dính**. Đây chính xác là khác biệt giữa Spendee/Copilot (thanh lịch) và app template (bừa bộn)
- 🔥 **Header ngày mang tổng ròng của ngày, căn phải.** `Hôm nay · Thứ Năm` bên trái, `−285.000 ₫` bên phải bằng Inter tabular. Biến một danh sách phẳng thành một cuốn sổ cái, và là tín hiệu "có thiết kế" rẻ nhất có thể thêm
- **Bottom nav 4 mục, không hơn:** `Nhập` (chat) · `Giao dịch` · `Báo cáo` · `Ngân sách`. Cài đặt nằm sau icon ở app bar. 5 tab là lúc nav bắt đầu trông như thanh công cụ bảng tính
- **FAB chỉ ở tab `Giao dịch`.** Ở tab chat thì thanh nhập *chính là* FAB
- **Hero card** đầu tab `Giao dịch`: một card, đệm 24, số khổng lồ là **chi tiêu từ đầu tháng** (không phải "số dư" — số dư của một app nhập tay là hư cấu), dưới là hàng hai cột `Thu` / `Chi`
- **Bottom-sheet-first:** chọn danh mục, chọn ngày, chi tiết giao dịch, bộ lọc — tất cả là sheet, không phải trang mới. Mọi hành động chính nằm ở **một phần ba dưới màn hình** (75% tương tác điện thoại bằng một ngón cái)

### Chuyển động — ngân sách cứng 5 animation, không gì khác động

App này chạy cục bộ, **không có độ trễ nào để che giấu**, nên mọi animation phải được biện minh bằng *sự hiểu*, không phải sự thích thú.

| # | Animation | Ở đâu | Thông số |
|---|---|---|---|
| 1 | **Số đếm lên** | Số hero, ngân sách còn lại — **chỉ khi giá trị đổi**, không bao giờ ở lần vẽ đầu | 600 ms `easeOutExpo`. **Bắt buộc tabular figures** nếu không chữ số giật |
| 2 | **Biểu đồ vẽ vào** | fl_chart khi vào tab, một lần | 450 ms `easeOutCubic`. Tròn: animate **bán kính**, không phải góc quét (quét trông như spinner loading). Đường: animate clip rect trái→phải. Cột: animate chiều cao, lệch 30 ms mỗi cột |
| 3 | **Danh sách vào lệch pha** | Danh sách giao dịch, **chỉ lần vẽ đầu của màn**, không bao giờ khi đang cuộn | fade + `slideY(8px)`, cách 24 ms, **giới hạn 8 item** — quá 8 thành làn sóng và cảm giác chậm |
| 4 | **Sheet trồi lên** | Mọi bottom sheet | 320 ms `easeOutCubic` |
| 5 | 🔥 **Nhịp xác nhận** | Dấu tích lưu trên thẻ xác nhận chat | 220 ms scale 0.85→1.04→1.0 `easeOutBack` + `HapticFeedback.lightImpact()`. **Đây là khoảnh khắc chữ ký duy nhất** — bài học Revolut/Copilot: một animation xác nhận dùng nhất quán khắp app |

**Haptics:** `selectionClick` khi đổi chip/tab · `lightImpact` khi lưu thành công · **không gì khi lỗi** (trừng phạt bằng rung tạo cảm giác tệ).

### Package UI — cái nào xứng đáng

| Package | Quyết định | Lý do |
|---|---|---|
| **Font bundle cục bộ** (`fonts:` trong pubspec) | ✅ **Làm thế này** | Offline-first, người dùng Việt, không nháy font lần chạy đầu |
| `google_fonts` | ❌ **Bỏ hẳn** | Tải HTTP lúc chạy ⇒ nháy font khi khởi động nguội không mạng. Mà nếu bundle asset rồi thì nó thành gánh nặng thừa |
| [`material_symbols_icons`](https://pub.dev/packages/material_symbols_icons) 4.2960.0 | ✅ **Bộ icon chính** | Apache-2.0, cập nhật 28 ngày trước, **4.264 icon**, trục biến thiên `wght`/`FILL`/`GRAD`/`opsz`. **Trục FILL là tính năng sát thủ**: tab nav đang chọn là *cùng một icon* ở `FILL 1`, animate được. Dùng style **Rounded** cho khớp bo góc rộng |
| `lucide_icons_flutter` | ⚠️ Thay thế được | MIT, nhẹ hơn, hình học hơn. **Nhưng không có biến thể tô đặc** → mất trạng thái tab active |
| `phosphor_flutter` | ❌ **Tránh** | MIT nhưng **xuất bản lần cuối 2 năm trước, chỉ 55 pub point**, 772 icon so với 4.264 |
| [`skeletonizer`](https://pub.dev/packages/skeletonizer) 2.1.3 | ✅ thay cho `shimmer` | MIT, 2.34k likes. Nó skeleton hoá **cây widget thật**; `shimmer` bắt bạn duy trì một cây layout song song rồi mục nát. App drift cục bộ hầu như không cần loading state — chỉ dùng cho frame khởi động nguội đầu tiên |
| [`animations`](https://pub.dev/packages/animations) | ✅ **Chính** | Publisher flutter.dev, BSD-3. Container transform, shared-axis. Chuẩn M3 đúng |
| `flutter_animate` 4.5.2 | ⚠️ Dùng dè | BSD-3 nhưng **commit cuối 25/11/2024, ~21 tháng ì**. Thuần Dart nên không vỡ. **Chỉ dùng cho stagger một dòng**, đừng xây kiến trúc lên nó |
| `animated_flip_counter` | ✅ | Hỗ trợ `thousandSeparator: '.'` đúng kiểu VND và tự yêu cầu tabular figures |
| [`dynamic_color`](https://pub.dev/packages/dynamic_color) 2.1.0 | ✅ **opt-in, mặc định TẮT** | Apache-2.0, material.io, cập nhật rất tích cực. Tắt mặc định vì bảng màu danh mục và màu ngữ nghĩa thu/chi phải cố định để biểu đồ đọc được. Chỉ cho dynamic color lái `primary` và surface trung tính |
| `smooth_corner` 1.1.1 | ⚠️ Tuỳ chọn, **2 chỗ** | BSD-3 nhưng **19 tháng ì**. Bo góc kiểu Figma (superellipse). Ở bán kính ≥20 khác biệt nhìn thấy rõ và đọc ra là cao cấp hơn. **Chỉ dùng cho hero card và bottom sheet.** Hoặc copy ~150 dòng `SmoothRectangleBorder` vào repo (BSD-3 cho phép, kèm ghi công) |
| `percent_indicator` | ⚠️ | Chạy được, nhưng vòng ngân sách là ~40 dòng `CustomPainter` và tự viết mới có đầu nét bo tròn, gradient quét, và **vạch nhịp** (xem Phase 11) mà không package nào có. **Tự viết** |
| `flutter_heatmap_calendar` | ❌ | Ì và cứng nhắc. Heatmap của ta là `GridView`/`CustomPainter` 7×N với 5 bậc cường độ VND — ~120 dòng, toàn quyền theme. **Tự viết** |
| Package chat UI (`flutter_chat_ui`, `chat_bubbles`, `flutter_gen_ai_chat_ui`) | ❌ **Không dùng cái nào** | Tất cả đều giả định miền nhắn tin (avatar, đã đọc, đính kèm, streaming) mà ta không có. Cãi nhau với quan điểm của chúng tốn hơn tự viết |
| Rive / Lottie | ❌ | Không có gì để animate. Chỉ cân nhắc nếu sau này đặt vẽ linh vật cho empty state |

### 🚨 Android 15/16 edge-to-edge — cái sẽ cắn thật

Flutter ≥3.27 target API 35 nên **app là edge-to-edge dù bạn có thiết kế cho nó hay không**.

- **Không bao giờ đặt `systemNavigationBarColor` / `statusBarColor` sang giá trị không trong suốt.** Các API đó đã deprecated trên Android 15+ và Play Console cảnh báo ngay cả khi layout đúng. Đặt trong suốt hoàn toàn + `systemNavigationBarContrastEnforced: false`
- **Không dựa vào `android:windowOptOutEdgeToEdgeEnforcement`** — đã nằm trong lịch trình deprecated
- **Xử lý inset theo từng scroll view, không phải một `SafeArea` toàn cục.** Danh sách giao dịch phải cuộn **bên dưới** thanh nav (`padding: EdgeInsets.only(bottom: viewPadding.bottom + navBarHeight)` trên sliver) — đó chính là thứ làm thanh nav mờ trông đúng. Một `SafeArea` bao trùm giết hiệu ứng và phí màn hình
- Dùng `MediaQuery.viewPaddingOf(context)` (không phải `.padding`) khi bàn phím lên

### ❌ Mẫu lỗi thời cần tránh

Tàn dư Material 2 (`primaryColor`, `accentColor`, `RaisedButton`, `FlatButton`; và lưu ý 3.44 dùng `CardThemeData`/`DialogThemeData`/`TabBarThemeData` chứ không phải tên cũ) · **`elevation:` mặc định của Material** · `BackdropFilter` ngoài 2 chỗ đã duyệt · **`Opacity` và `ClipRRect` bên trong item danh sách** (cả hai ép `saveLayer` — dùng `Color.withValues(alpha:)` và `BoxDecoration(borderRadius:)`) · neumorphism · plugin không có hậu tố `_plus` (`connectivity`, `share`, `package_info`, `device_info` đều bỏ hoang) · `ui.window` (dùng `View.of(context)`) · **lưu chuỗi hex màu trong drift** (D10) · legend biểu đồ 12 mục · `#000000` làm dark base mặc định.

---

## Cảnh báo môi trường — đã kiểm chứng trực tiếp trên máy

| ID | Phát hiện | Hệ quả |
|---|---|---|
| **E1** ⚠️ | `tailscale serve` **đường `/` đã bị chiếm**: proxy sang `http://127.0.0.1:8765`, cùng `/web/`, `/task1.apk`, `/task1-arm64.apk`, `/task1-video.mp4` — thuộc project "writing task 1" | Tony chọn URL `https://tony.tailfcdcfc.ts.net/` nhưng gốc `/` không dùng được. **URL giao hàng thành `https://tony.tailfcdcfc.ts.net/tonyfino/`.** **TUYỆT ĐỐI KHÔNG chạy `tailscale serve reset`** — sẽ xoá sạch cấu hình của project kia |
| **E2** | **Không có Chrome/Chromium/Brave/Edge.** Chỉ có Firefox | Runbook trích xuất Rolly viết cho **Firefox DevTools**. Thực ra tốt hơn: Firefox có JSON viewer sẵn, "Copy All", và "Save All As HAR" |
| **E3** 🔴 | **Thiếu `clang` và `ninja`** (có `gcc` 13.3, `cmake` 3.28.3). Dart build hooks (`native_toolchain_c`) gọi **clang**, không phải gcc | `flutter test` biên dịch sqlite3mc cho `linux-x64` sẽ hỏng. **Chặn toàn bộ chiến lược test.** Phase 1: `sudo apt install clang ninja-build` |
| **E4** | AVD `test34` là **API 34**, `hw.gpu.enabled = no`, **RAM 1536 MB**. `system-images/` chỉ có **android-34** (platforms có tới 36) | Target SDK 36 mà test trên 34 sẽ bỏ lọt **edge-to-edge cưỡng chế của Android 15** — đúng loại bug làm nút Save trong bottom-sheet bị nav bar che (than phiền #3 của Rolly). Phase 1 tải `system-images;android-36;google_apis;x86_64`, tạo AVD **`tonyfino36`** RAM 4096 MB |
| **E5** | KVM **dùng được** (`/dev/kvm` có ACL `user:tony:rw-`). Nhưng session là `DISPLAY=:1` X11 ảo, không có `glxinfo`/`vulkaninfo` | CPU nhanh, **GPU thì không**. Chạy `-gpu swiftshader_indirect`. Flutter 3.44 mặc định **Impeller/Vulkan** trên Android — trên SwiftShader có thể chậm hoặc rơi về Skia. Phase 3 phải xác định; nếu phải tắt Impeller thì **mọi golden test chỉ bảo đảm layout, không bảo đảm pixel** — và vòng dogfood APK thành kênh kiểm tra thị giác thật duy nhất |
| **E6** | `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME` đều **chưa set**. Flutter tự xoay xở được | Chỉ các lệnh gọi thẳng `adb`/`emulator`/`sdkmanager`/`avdmanager` mới hỏng. Giải pháp: `tool/env.sh` commit vào repo, mọi script source nó. **Không sửa `~/.bashrc`** |
| **E7** ✅ | Ổ hệ thống `/` là **SSD Kingston SUV400S**, 109 GB, còn **25 GB**. Có thêm **ổ 1TB `/mnt/data1tb`, còn trống 503 GB**, tony sở hữu, ext4, đã có trong `/etc/fstab` với `nofail` nên tự mount lúc boot. ⚠️ **Nhưng nó là HDD Apple HTS541, `rotational=1` — đĩa quay 5400rpm, chậm** | **Chia việc, đừng dời tất.** Gradle cache, pub cache, `build/`, source, và AVD đang chạy đều là **IO ngẫu nhiên nặng** — để trên HDD là build và emulator chậm thấy rõ. Chỉ dời **kho lạnh** sang HDD: symlink `~/Android/Sdk/system-images` (4,2 GB, chỉ đọc tuần tự lúc emulator boot) sang `/mnt/data1tb/android-dev/system-images`. Riêng việc đó giải phóng 4,2 GB **và** image API 36 (~2 GB) cũng rơi thẳng sang HDD → SSD còn ~29 GB cho ~10 GB nhu cầu mới. Thoải mái. Kèm `tool/clean.sh` |
| **E8** | `redmi-note-13-pro` (100.107.81.123) **offline, lần cuối 2 ngày trước**. Máy là **arm64-v8a** | Phase giao hàng phụ thuộc con người: Tony phải bật máy lên tailnet. Củng cố D6 (universal APK) |
| **E9** | git global là `Tony <thanhfourteen@gmail.com>`, context session là `teamtriscec@gmail.com` | Set `user.email` **cấp repo** lúc `git init` |

**Đã xác nhận tốt:** Flutter 3.44.1 / Dart 3.12.1 · cờ `enable-native-assets` đang bật · platform `android-36` đã cài · build-tools 34.0.0 + 36.0.0 · NDK 28.2.13676358 · JDK 17.0.19 · Gradle 9.1.0 + 9.5.0 đã cache · pub cache có sẵn 179 package · **302 font Noto (tiếng Việt hiển thị tốt)** · Docker + Node 25.8.2.

---

## Rủi ro thứ tự (H1–H8)

| ID | Rủi ro | Xử lý |
|---|---|---|
| **H1** | Trích xuất Rolly xếp quá muộn nhưng **chặn cứng ngày giao hàng** (v1 bắt buộc có import), lại là việc duy nhất phụ thuộc bên ngoài không kiểm soát được | **Đẩy lên Phase 2, chạy song song Phase 3.** Việc này không cần code. Importer vẫn ở Phase 9, viết sau khi biết schema thật |
| **H2** | Không có phương án dự phòng nếu `app.rollyapp.ai` không hợp tác | Thang 4 bậc + **cổng quyết định rõ ràng** trong Phase 2: nếu bậc 1–3 hỏng hết, v1 ship **không có import**, thay bằng màn "số dư đầu kỳ". Ngày giao hàng không trượt |
| **H3** 🔴 | Nhiều phase trôi qua trước khi APK đầu tiên chạm điện thoại. Toàn bộ đường ống giao hàng (keystore → universal APK → `tailscale serve` subpath → "cài app không rõ nguồn" → **nâng cấp đè lên bản đang cài**) chưa được thử cho tới đúng lúc rủi ro nhất | **Chèn checkpoint "dogfood APK" ngay cuối Phase 6** (v0.1.0, nhập tay, dữ liệu vứt đi), rồi lặp lại mỗi phase. **Đây là thay đổi giá trị nhất trong toàn bộ kế hoạch** |
| **H4** | `sqlite3` + `sqlite3mc` qua Dart build hooks là phụ thuộc kỹ thuật rủi ro nhất, và **mọi thứ đều đứng trên nó** | **Spike trên nhánh vứt đi ở Phase 3, trước mọi code tính năng**, kèm phương án lùi khai báo trước (F1) |
| **H5** | Mã hoá-tại-chỗ giá trị thấp hơn vẻ ngoài, rủi ro cao hơn: đổi rủi ro **mất dữ liệu** lấy tính bảo mật mà FBE của Android phần lớn đã có | Giữ làm mục tiêu nhưng **để dạng cờ**. Spike không sạch trong timebox ⇒ v1 không mã hoá tại chỗ, **mã hoá file backup thay thế** |
| **H6** | Grant SAF có thể **chết âm thầm** sau reboot nếu `file_picker` v12 không lộ `takePersistableUriPermission()` | Health-check đích backup **mỗi lần app resume**. Hệ thống backup hỏng âm thầm còn tệ hơn không có |
| **H7** | Impeller trên emulator không GPU (E5) | Xác định ở Phase 3. Nếu phải tắt Impeller thì golden chỉ canh **layout** |
| **H8** | Test API 34 trong khi target SDK 36 (E4) | Cài system image API 36 ngay Phase 1 |

---

## Bối cảnh chung — mọi prompt phase đều đọc phần này

```text
DỰ ÁN: TonyFino — app quản lý chi tiêu cá nhân, Flutter, Android trước, iOS sau.
       Bản thay thế miễn phí cho app Rolly mà Tony đang trả phí.
THƯ MỤC: /home/tony/Tony/TonyFino
TÀI LIỆU: đọc TODOS.md ở gốc repo — chứa quyết định D1–D10, đặc tả design system đầy đủ,
          cảnh báo môi trường E1–E9, rủi ro H1–H8, và mọi phase.
          docs/decisions.md ghi quyết định phát sinh. docs/design-research.md ghi lý do design.

STACK (đã chốt, đừng đổi):
  Flutter 3.44.1 / Dart 3.12.1
  flutter_riverpod ^3.4.2 (+ riverpod_annotation ^4.0.6, riverpod_generator ^4.0.8,
    riverpod_lint ^3.1.8 — cài qua analysis_options.yaml theo cơ chế analysis_server_plugin,
    KHÔNG phải custom_lint)
  go_router ^17.5.0 · drift ^2.34.3 + drift_dev ^2.34.5 + drift_flutter ^0.3.1
  sqlite3 ^3.5.2 (bundle qua Dart build hooks, hooks.user_defines.sqlite3.source = sqlite3mc)
  path_provider ^2.1.6 · flutter_secure_storage ^11.0.0 · intl ^0.20.3 · decimal ^3.2.6
  fl_chart ^1.2.0 · share_plus ^13.3.0 · file_picker ^12.0.0 · csv ^8.0.0
  diacritic ^0.1.6 · clock · http ^1.6.0
  UI: material_symbols_icons ^4.2960.0 · animations · skeletonizer ^2.1.3 ·
      animated_flip_counter · dynamic_color ^2.1.0 (opt-in, mặc định tắt) ·
      flutter_animate ^4.5.2 (chỉ stagger một dòng) · smooth_corner (tuỳ chọn, 2 chỗ)
  FONT: bundle cục bộ trong pubspec — Be Vietnam Pro (4 file tĩnh) + Inter (1 file variable)
  dev: build_runner ^2.16.0 · alchemist ^0.14.0 · integration_test · sqlite3_test

CẤM TUYỆT ĐỐI (đã chết/deprecated tính tới 8/2026):
  isar, isar_community, realm, google_generative_ai,
  sqlcipher_flutter_libs, sqlite3_flutter_libs (cả hai đã thành stub no-op "+eol"),
  golden_toolkit (bỏ hoang 9/2024), android_alarm_manager_plus,
  quyền MANAGE_EXTERNAL_STORAGE (Play từ chối thẳng),
  google_fonts (tải HTTP lúc chạy), phosphor_flutter (2 năm không cập nhật),
  flutter_neumorphic, mọi package chat UI, Rive/Lottie,
  font DM Sans và Figtree (KHÔNG CÓ TIẾNG VIỆT),
  plugin không có hậu tố _plus.

LUẬT BẮT BUỘC:
  1. Số dư LUÔN dẫn xuất bằng SUM(), KHÔNG BAO GIỜ lưu cột balance. (D7)
  2. Tiền lưu dạng int minor units + currency + currencyScale. VND scale = 0.
     KHÔNG double, KHÔNG Decimal trong DB. Decimal chỉ dùng thoáng qua ở domain layer.
  3. KHÔNG dùng DateTime.now() ở bất cứ đâu — luôn qua Clock được inject (package:clock).
  4. KHÔNG có dart:io / Platform. bên trong lib/features/ — mọi thứ platform-specific
     nằm sau interface ở core/ hoặc data/services/, chọn implementation bằng Riverpod provider.
  5. KHÔNG BAO GIỜ lưu đường dẫn tuyệt đối — chỉ lưu tên file, resolve lại base dir mỗi lần khởi động.
  6. Mọi write của repository trả Result<T, AppError>. Zero fire-and-forget.
  7. KHÔNG BAO GIỜ tự động commit một kết quả parse — luôn hiện thẻ xác nhận sửa được,
     và ngày đã resolve phải hiển thị rõ.
  8. KHÔNG analytics, KHÔNG crash reporter gọi về nhà.
  9. Lưu categoryColorId INTEGER trong DB, TUYỆT ĐỐI không lưu chuỗi hex màu. (D10)
 10. File token trong lib/theme/tokens/ chỉ import dart:ui / painting.dart,
     TUYỆT ĐỐI không material.dart — đây là thứ khiến migration sang material_ui sau này
     chỉ là đổi một dòng.
 11. Material elevation: 0 ở mọi component, tự vẽ BoxShadow. Dark mode KHÔNG dùng đổ bóng.
 12. Mọi TextStyle phải có height tường minh (body ≥1.45) và
     leadingDistribution: TextLeadingDistribution.even — nếu không dấu tiếng Việt bị cắt.
 13. Mọi style hiển thị tiền phải có FontFeature.tabularFigures().

LUẬT NGHIÊN CỨU TRƯỚC KHI CODE (Tony yêu cầu rõ — không code chắp vá):
  Trước khi viết dòng nào dùng một package, ĐỌC CHANGELOG.md và API surface thật của nó tại
  ~/.pub-cache/hosted/pub.dev/<pkg>-<version>/.
  Riverpod 3, go_router 17, fl_chart 1.x, drift 2.34, share_plus 13, file_picker 12
  đều vừa có breaking change lớn — ĐA SỐ tài liệu/blog/StackOverflow ngoài kia nói về major TRƯỚC ĐÓ.
  Sự thật nằm trên đĩa, không nằm trong trí nhớ.

MÔI TRƯỜNG — CẠM BẪY:
  - ANDROID_HOME/JAVA_HOME chưa set → mọi script phải `source tool/env.sh` (E6)
  - tailscale serve: đường "/" ĐÃ BỊ CHIẾM bởi project khác. Dùng /tonyfino/.
    KHÔNG BAO GIỜ chạy `tailscale serve reset` (E1)
  - Chỉ có Firefox, không có Chrome (E2)
  - Emulator: dùng AVD tonyfino36 (API 36), cờ -gpu swiftshader_indirect (E4, E5)
  - Đĩa: / là SSD còn ~25GB. /mnt/data1tb là HDD 5400rpm còn 503GB.
    Chỉ để KHO LẠNH trên HDD (system-images). Gradle cache, pub cache, build/, source, AVD
    phải ở lại SSD — chúng là IO ngẫu nhiên nặng, để trên HDD là chậm thấy rõ. (E7)
  - Điện thoại redmi-note-13-pro là arm64-v8a, emulator là x86_64
    → luôn build universal APK, KHÔNG --split-per-abi (D6)
```

---

# CÁC PHASE

---

## Phase 1 — Quyết định, repo, môi trường *(không có code app)*

**Mục tiêu:** Khoá mọi quyết định không thể đảo ngược và bịt mọi lỗ hổng môi trường trước khi tồn tại một file Dart nào.

**Nghiên cứu trước:** Xác nhận tổ hợp AGP/Gradle/Kotlin mà template `flutter create` của Flutter 3.44.1 phát ra, đối chiếu Gradle dist đã cache (9.1.0, 9.5.0). Xác nhận package id và dung lượng system image API 36 (E7).

**Bàn giao:**
- `git init` + `user.name`/`user.email` cấp repo (E9) + commit đầu
- `.gitignore`: chặn `build/`, `.dart_tool/`, `android/local.properties`, `android/key.properties`, `*.jks`, `*.keystore`, `.env`, **`raw_rolly/`**, **`dist/`**. **Không** ignore `drift_schemas/`, `test/fixtures/`, `*.g.dart`, `*.drift.dart`
- **Giải phóng SSD (E7):** dời `~/Android/Sdk/system-images` sang `/mnt/data1tb/android-dev/system-images` rồi symlink lại. Kiểm tra `sdkmanager --list_installed` vẫn nhận đúng sau khi symlink **trước khi** tải image API 36. **Không dời** `.gradle`, `.pub-cache`, `~/.android/avd`, hay `build/` — chúng ở lại SSD
- `tool/env.sh` (E6) · `tool/emulator.sh` với `-gpu swiftshader_indirect -no-snapshot-save` (E5) · `tool/clean.sh` (E7)
- `sudo apt install clang ninja-build` (E3 — gỡ chặn toàn bộ test)
- `sdkmanager "system-images;android-36;google_apis;x86_64"` + `avdmanager create avd -n tonyfino36` (RAM 4096 MB, userdata 8 GB) (E4)
- **Keystore release** `~/keystores/tonyfino-release.jks` (RSA 4096, validity 10000) + **sao lưu 3 nơi ngay bây giờ** (D3)
- **Tải font:** Be Vietnam Pro (400/500/600/700 tĩnh) + Inter Variable từ Google Fonts, đặt vào `assets/fonts/`. Kiểm chứng bằng mắt chuỗi `Đồng Nai — ế ữ ỗ ặ ỡ Ế Ữ Ỗ`
- `docs/decisions.md` ghi D1–D10 kèm lý do

**Xác minh:** `flutter doctor -v` → Android toolchain ✓ · `sdkmanager --list_installed` vẫn đúng sau khi symlink `system-images`, `df -h /` cho thấy SSD được giải phóng ~4 GB · `tool/emulator.sh` boot được, `adb shell getprop ro.build.version.sdk` → `36` · `clang --version && ninja --version` chạy · `keytool -list` thấy alias · **bản sao lưu keystore đọc được TỪ chính vị trí sao lưu** · file font mở được và hiển thị đủ dấu tiếng Việt.

**Checklist:**

- [x] `git init` + `user.name`/`user.email` cấp repo, `.gitignore` (chặn `raw_rolly/`, `dist/`, `*.jks`, `key.properties`; **không** chặn `drift_schemas/`, `test/fixtures/`, `*.g.dart`), commit đầu gồm `TODOS.md`
- [x] Dời `~/Android/Sdk/system-images` sang `/mnt/data1tb/android-dev/`, symlink lại, `sdkmanager --list_installed` vẫn đúng
- [x] `sudo apt install clang ninja-build` — Tony đã cài 2026-08-21. clang 18.1.3 + ninja 1.11.1. Đã smoke-test: clang biên dịch được `.so` cho linux-x64 và `dlopen` gọi được — đúng đường sqlite3mc sẽ đi ở Phase 3
- [x] Tải `system-images;android-36;google_apis;x86_64`, tạo AVD `tonyfino36` (RAM 4096MB)
- [x] `tool/env.sh`, `tool/emulator.sh`, `tool/clean.sh`
- [x] Keystore `~/keystores/tonyfino-release.jks` + sao lưu 3 nơi, đọc được từ chính vị trí sao lưu — RSA 4096 PKCS12. Bản 1 SSD, bản 2 HDD `/mnt/data1tb/backups/`, cả hai đã xác minh fingerprint. Bản 3 (gói `.tar.gz.gpg` AES256) **đã Taildrop sang `redmi-note-13-pro` 2026-08-21 12:26** → giờ đã có bản sao trên thiết bị vật lý khác
- [x] Font Be Vietnam Pro (4 file) + Inter Variable vào `assets/fonts/`
- [x] `docs/decisions.md` ghi D1–D10

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md, phần "Bối cảnh chung" và "Phase 1". Thực hiện Phase 1.

Phase thiết lập, KHÔNG viết code app. Mục tiêu: khoá mọi quyết định không đảo ngược được
và bịt mọi lỗ hổng môi trường trước khi có file Dart nào.

Năm điều quan trọng nhất:
1. applicationId = dev.tony.tonyfino là BẤT BIẾN trọn đời app. Đổi sau = app khác = mất
   toàn bộ dữ liệu. Bản debug phải có applicationIdSuffix ".dev" để không bao giờ
   đụng vào dữ liệu thật.
2. `sudo apt install clang ninja-build` — máy này THIẾU cả hai. Dart build hooks gọi clang
   chứ không phải gcc, nên thiếu là `flutter test` hỏng hoàn toàn. Blocker cứng.
3. Tạo AVD mới tên tonyfino36 (API 36, RAM 4096MB). AVD test34 đang có là API 34, RAM 1536MB,
   và system-images/ chỉ có android-34 — phải sdkmanager tải android-36 trước.
   Target SDK 36 mà test trên 34 sẽ bỏ lọt edge-to-edge cưỡng chế của Android 15.
4. Tạo keystore release NGAY và sao lưu 3 nơi. Trên Android, APK ký bằng key khác thì buộc
   phải gỡ cài, mà gỡ cài là xoá sạch dữ liệu. Mất keystore = không bao giờ cập nhật được nữa.
   Không dùng debug keystore: nó tự sinh lại nếu bị xoá, hỏng âm thầm.
5. Tải font Be Vietnam Pro (4 file tĩnh 400/500/600/700) và Inter Variable (1 file) vào
   assets/fonts/. TUYỆT ĐỐI KHÔNG dùng package google_fonts — nó tải HTTP lúc chạy, gây nháy
   font khi khởi động nguội không mạng, mà app này là offline-first.
   Và TUYỆT ĐỐI không dùng DM Sans hay Figtree: cả hai KHÔNG CÓ bộ tiếng Việt.

ĐĨA — làm trước khi tải system image API 36:
Ổ hệ thống / là SSD Kingston còn ~25GB. Có ổ thứ hai /mnt/data1tb còn 503GB, đã trong fstab,
tony sở hữu. NHƯNG nó là HDD Apple 5400rpm (rotational=1), chậm.
Vậy nên CHIA VIỆC chứ đừng dời tất: chỉ symlink ~/Android/Sdk/system-images (4.2GB, chỉ đọc
tuần tự lúc emulator boot) sang /mnt/data1tb/android-dev/system-images. Riêng việc đó giải phóng
4.2GB và image API 36 mới cũng rơi thẳng sang HDD.
TUYỆT ĐỐI KHÔNG dời ~/.gradle, ~/.pub-cache, ~/.android/avd, hay build/ sang HDD — chúng là IO
ngẫu nhiên nặng, để trên đĩa quay là build và emulator chậm thấy rõ.
Sau khi symlink, chạy `sdkmanager --list_installed` xác nhận SDK vẫn nhận đúng TRƯỚC KHI tải thêm.

Đừng sửa ~/.bashrc, mọi biến môi trường đặt trong tool/env.sh commit vào repo.

Xong thì tick các checkbox của Phase 1 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 2 — Trích xuất dữ liệu Rolly ⚡ *do Tony thao tác, chạy song song Phase 3*

**Mục tiêu:** Lấy lịch sử giao dịch thật ra khỏi Rolly và ghim được **schema JSON thật**. Không code app.

Đẩy lên đầu theo H1: đây là việc duy nhất phụ thuộc bên ngoài (server Rolly, phiên đăng nhập, thời gian rảnh của Tony). Trượt ngày nào, giao hàng trượt ngày đó.

**Nghiên cứu trước:** Xác nhận `app.rollyapp.ai` tồn tại và dùng cơ chế đăng nhập gì. Xác nhận quy trình Firefox DevTools (E2): Network → lọc **XHR** → ép app tải hết lịch sử → chuột phải request → **Save All As HAR**. Ưu tiên HAR: bắt được *mọi* trang phân trang trong một file, giữ nguyên URL request.

**Bàn giao:**
- `docs/rolly-extraction.md` — runbook bấm-từng-bước cho Firefox
- `raw_rolly/rolly-<ngày>.har` + `raw_rolly/transactions-*.json` (**gitignored**)
- `docs/rolly-schema.md` — schema **quan sát được từ payload, không phải đoán**: tên field, số tiền (**minor unit hay major? string hay number? quy ước dấu thu vs chi?**), timestamp và múi giờ, category (id hay tên), field ví, pagination, cờ soft-delete, tổng số bản ghi
- `test/fixtures/rolly/sample.json` — bản **tổng hợp, ẩn danh** khớp đúng schema (**commit**; file thật thì không)
- **Số đối chiếu:** tổng số giao dịch + tổng tiền theo từng tháng, đọc từ chính UI Rolly — "oracle" nghiệm thu cho Phase 9
- **Bonus quan trọng:** chụp màn hình các màn Rolly để so sánh — ta cần *đẹp hơn hẳn*, và có bản gốc để đối chiếu thì dễ đánh giá

**⚠️ Thang dự phòng (H2) — thử theo thứ tự, dừng ở bậc đầu tiên thành công:**
1. Bắt DevTools/HAR trên web app *(ưu tiên)*
2. Nút share/report nào trong app mobile không bị paywall (kể cả PDF/text từng tháng) → parse
3. `adb backup` / pull app data — **cần root; Redmi gần như chắc chắn không root**. Xác suất thấp
4. **Dựng lại thủ công:** chỉ nhập số dư đầu kỳ theo danh mục/tháng, sổ thật bắt đầu từ hôm nay, giữ Rolly làm kho lưu trữ chỉ-đọc

**Cổng quyết định:** nếu bậc 1–3 hỏng hết ⇒ **v1 ship không có import**, "Import" dời sang Phase 15. **Ngày giao hàng không trượt.**

**Xác minh:** JSON parse được, số bản ghi khớp UI Rolly. Đối chiếu tay 10 giao dịch từng field — **đặc biệt quy ước dấu và múi giờ**, hai field âm thầm phá nát cả bộ import.

**Checklist:**

- [ ] `docs/rolly-extraction.md` — runbook Firefox DevTools từng bước
- [ ] Bắt được HAR/JSON đầy đủ vào `raw_rolly/` (đã gitignore)
- [ ] `docs/rolly-schema.md` — trả lời rõ: thang số tiền, quy ước dấu thu/chi, múi giờ, pagination
- [ ] `test/fixtures/rolly/sample.json` — bản ẩn danh khớp schema, có commit
- [ ] Ghi oracle nghiệm thu: tổng số giao dịch + tổng tiền từng tháng đọc từ UI Rolly
- [ ] Ảnh chụp màn Rolly vào `docs/rolly-screens/` để đối chiếu thiết kế
- [ ] Đối chiếu tay 10 giao dịch, đặc biệt dấu và múi giờ

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md, phần "Bối cảnh chung" và "Phase 2". Thực hiện Phase 2.

Việc này Tony thao tác trên trình duyệt, bạn hướng dẫn từng bước và xử lý file thu được.
KHÔNG viết code app ở phase này.

Bối cảnh: Tony dùng app Rolly (rollyapp.ai) vài tháng, cần lấy lịch sử giao dịch ra để import
sang app mới. Rolly CÓ export CSV nhưng khoá sau gói Premium và Tony không muốn trả phí.
Đường đi đã chọn: đăng nhập web app app.rollyapp.ai trên desktop, bắt JSON từ tab Network.

LƯU Ý: máy này CHỈ CÓ FIREFOX, không có Chrome. Viết runbook cho Firefox DevTools.
Ưu tiên "Save All As HAR" hơn copy từng response — HAR bắt được mọi trang phân trang
trong một file và giữ nguyên URL request.

Sản phẩm quan trọng nhất là docs/rolly-schema.md: schema QUAN SÁT ĐƯỢC từ payload thật,
tuyệt đối không đoán. Phải trả lời rõ: số tiền là minor unit hay major, string hay number;
quy ước dấu phân biệt thu và chi; định dạng timestamp và múi giờ; category là id hay tên;
hình dạng pagination. Sai hai field "quy ước dấu" và "múi giờ" là hỏng cả bộ import mà
không ai phát hiện.

Cũng phải ghi lại "oracle" nghiệm thu: tổng số giao dịch + tổng tiền từng tháng đọc từ chính
UI Rolly. Phase 9 sẽ đối chiếu với con số này.

Tiện thể nhờ Tony chụp màn hình các màn chính của Rolly (danh sách, báo cáo, chat, ngân sách)
lưu vào docs/rolly-screens/ — ta cần làm ĐẸP HƠN HẲN nên có bản gốc để đối chiếu là hữu ích.

File thật đặt ở raw_rolly/ (đã gitignore). Tạo thêm test/fixtures/rolly/sample.json là bản
tổng hợp ẩn danh khớp đúng schema, file này ĐƯỢC commit.

Nếu web app không hợp tác, đi theo thang dự phòng 4 bậc trong TODOS.md và báo Tony đang ở bậc nào.
Nếu bậc 1-3 hỏng hết thì v1 ship không có import — đừng để nó chặn tiến độ.

Xong thì tick các checkbox của Phase 2 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 3 — Scaffold, hardening, và native spike

**Mục tiêu:** Một app rỗng nhưng **cấu hình đúng, port-được-sang-iOS**, build và chạy được, với phụ thuộc native rủi ro nhất đã được chứng minh hoặc đã lùi phương án.

**Nghiên cứu trước:**
- Riverpod 3.x: hợp nhất `Ref`, hình dạng codegen `@riverpod`, `Notifier`/`AsyncNotifier` — đọc `flutter_riverpod-3.4.2/CHANGELOG.md` trên đĩa. **Tài liệu Riverpod 2 gây hiểu sai chủ động**
- go_router 17.x: `StatefulShellRoute.indexedStack` cho bottom-nav shell
- Cú pháp Dart build hooks / `user_defines` cho `sqlite3: {source: sqlite3mc}` — đối chiếu README của chính `sqlite3-3.5.2`
- Schema XML `android:dataExtractionRules` và **tên file SharedPreferences chính xác của `flutter_secure_storage` cần loại trừ** — bỏ sót là dính `InvalidKeyException`

**Bàn giao:**
- `flutter create --org dev.tony --project-name tonyfino --platforms=android,ios .` — **tạo cả iOS ngay từ đầu**
- `pubspec.yaml` với **bộ dependency v1 đã cắt gọn** (D5) + `hooks.user_defines` + khai báo `fonts:` cho Be Vietnam Pro và Inter
- Android: `compileSdk 36`, **`targetSdk 36`**, `minSdk 24`, `applicationId dev.tony.tonyfino`, debug `applicationIdSuffix ".dev"` (D1), `signingConfigs.release` đọc `key.properties` và **fail lớn nếu thiếu** (D3)
- Manifest: `android:allowBackup="false"`, `android:dataExtractionRules="@xml/data_extraction_rules"`, không `MANAGE_EXTERNAL_STORAGE`, không quảng cáo/analytics
- Cây thư mục: `lib/{main.dart,bootstrap.dart}`, `lib/core/{money,time,result,l10n,router}/`, **`lib/theme/{tokens/,...}`**, `lib/data/{db,repositories,services}/`, `lib/features/{transactions,quick_add,budgets,reports,settings,backup}/`
- `analysis_options.yaml` + `riverpod_lint` + **grep trong CI chặn `Platform.`, `dart:io`, `DateTime.now()` trong `lib/features/`, và chặn `material.dart` trong `lib/theme/tokens/`**
- Edge-to-edge setup: system bar trong suốt, `systemNavigationBarContrastEnforced: false`
- **Spike (F1):** nhánh vứt đi chứng minh drift-trên-sqlite3mc mở được bằng `PRAGMA key`, trên **cả** emulator API 36 **và** host Linux dưới `flutter test`

> **F1 — phương án lùi, khai báo trước (H4/H5):** spike không sạch trong timebox ⇒ v1 ship **không mã hoá tại chỗ**, chuyển mã hoá sang **file backup**. Ghi vào `docs/decisions.md` và đi tiếp **ngay trong ngày**.

**Xác minh:** `flutter analyze` 0 issue · `build_runner` sạch · `flutter run` chạy trên **API 36**, ghi lại Impeller hay Skia (H7) · một `flutter test` mở `NativeDatabase.memory()` **pass trên host** (cổng E3 thật) · grep lint không ra kết quả.

**Checklist:**

- [ ] `flutter create --org dev.tony --project-name tonyfino --platforms=android,ios .`
- [ ] `pubspec.yaml`: dep v1 đã cắt + `hooks.user_defines` sqlite3mc + khai báo `fonts:`
- [ ] Gradle: `targetSdk 36`, `applicationId dev.tony.tonyfino`, debug suffix `.dev`, release signing **fail lớn** khi thiếu `key.properties`
- [ ] Manifest: `allowBackup="false"` + `dataExtractionRules` loại trừ `.db`/`.db-wal`/`.db-shm` + prefs của flutter_secure_storage
- [ ] Cây thư mục `core/ theme/ data/ features/` + `analysis_options.yaml` + grep lint chặn `dart:io`/`Platform.`/`DateTime.now()` trong `features/` và `material.dart` trong `theme/tokens/`
- [ ] Edge-to-edge: system bar trong suốt, `systemNavigationBarContrastEnforced: false`
- [ ] **Spike F1**: drift + sqlite3mc mở được bằng `PRAGMA key` trên **cả** emulator API 36 **lẫn** host dưới `flutter test` — hoặc đã lùi phương án và ghi vào `docs/decisions.md`
- [ ] `flutter analyze` 0 issue, app chạy trên API 36, đã ghi lại Impeller hay Skia

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md, phần "Bối cảnh chung" và "Phase 3". Thực hiện Phase 3.

Mục tiêu: app rỗng nhưng cấu hình ĐÚNG CHUẨN PRODUCTION và port-được-sang-iOS, build chạy được.

NGHIÊN CỨU TRƯỚC KHI CODE (bắt buộc, Tony yêu cầu không code chắp vá):
Riverpod 3.x có breaking change lớn so với 2.x — đọc CHANGELOG.md thật tại
~/.pub-cache/hosted/pub.dev/flutter_riverpod-3.4.2/ chứ đừng theo trí nhớ hay blog.
Tương tự go_router 17.x và cú pháp Dart build hooks của sqlite3 3.5.2.

Năm điểm dễ sai nhất:
1. `flutter create` phải có --platforms=android,ios NGAY BÂY GIỜ. Thư mục ios/ chưa từng
   tồn tại thì port sau khó gấp nhiều lần thư mục chỉ chưa từng build.
2. Gradle release signing phải FAIL LỚN khi thiếu android/key.properties. Template Flutter
   mặc định lặng lẽ rơi về debug signing — mà debug key đổi là mất sạch dữ liệu.
3. android:allowBackup="false" BẮT BUỘC, kèm dataExtractionRules loại trừ .db/.db-wal/.db-shm
   VÀ file SharedPreferences của flutter_secure_storage. Bỏ sót cái cuối là dính
   InvalidKeyException "app mở ra thấy database rỗng".
4. Thêm grep vào CI chặn dart:io, Platform., DateTime.now() trong lib/features/,
   và chặn import material.dart trong lib/theme/tokens/. Ép luật bằng máy, đừng ép bằng trí nhớ.
   (Luật thứ hai là thứ khiến migration sang material_ui sau này chỉ là đổi một dòng.)
5. Khai báo fonts: trong pubspec cho Be Vietnam Pro (4 file tĩnh) và Inter (1 file variable).
   KHÔNG dùng package google_fonts.

SPIKE F1 — làm trên nhánh vứt đi, TRƯỚC mọi code tính năng:
Chứng minh drift + sqlite3mc mở được bằng PRAGMA key, trên CẢ emulator tonyfino36 LẪN host Linux
dưới `flutter test`. Đây là phụ thuộc rủi ro nhất và mọi thứ khác đứng trên nó.
Nếu không sạch trong timebox: ship v1 KHÔNG mã hoá tại chỗ, chuyển mã hoá sang file backup,
ghi quyết định vào docs/decisions.md, đi tiếp NGAY TRONG NGÀY.

Ghi lại app đang chạy Impeller hay Skia trên emulator — ảnh hưởng độ tin cậy của golden test.

Xong thì tick các checkbox của Phase 3 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 4 — Data layer, Money, migrations, **và backup/restore**

**Mục tiêu:** Schema, kiểu tiền tệ, và — quan trọng nhất — **vòng export→xoá→import đã được chứng minh**, trước khi bất kỳ tính năng nào phụ thuộc vào nó.

Backup/restore nằm ở đây chứ không phải cuối, theo D3: nó chính là thứ khiến việc mất keystore và `allowBackup="false"` trở nên sống sót được. Nó là hệ thống an toàn, mà hệ thống an toàn thì xây trước thứ nó bảo vệ.

**Nghiên cứu trước:** drift 2.34 `MigrationStrategy` + `make-migrations` + hình dạng test `schema_vN.dart` · `sqlite3_test` `TestSqliteFileSystem` × `withClock` · vì sao `NativeDatabase.memory(closeStreamsSynchronously: true)` **bắt buộc** trong widget test · **share_plus 13: `SharePlus.instance.share(ShareParams(...))` — API tĩnh `Share.shareXFiles()` đã deprecated** · **file_picker 12 (H6): có lộ persistable URI permission không?** Nếu không, chốt ngay giữa package `saf` và platform channel Kotlin ~60 dòng.

**Bàn giao:**
- `lib/core/money/money.dart` — value type bất biến trên `int` minor units + `currency` + `currencyScale`, **assert cùng loại tiền**, `Decimal` chỉ thoáng qua, format `NumberFormat.currency(locale:'vi_VN', symbol:'₫', decimalDigits:0)`
- `lib/core/time/clock_provider.dart` · `lib/core/result/result.dart`
- `lib/data/db/` — bảng drift: `transactions` (`amount_minor`, `currency`, `currency_scale`, `occurred_at`, `note`, **`note_ascii` cột bóng** cho FTS5), `categories` (**`categoryColorId INTEGER` + `iconCode`, KHÔNG lưu hex — D10**), **`category_keywords` (`keyword`, `keyword_ascii`, `weight`)**, `budgets`, `app_events`. Migration seed ~300 từ khoá tiếng Việt + 12 danh mục mặc định
- `lib/data/repositories/transaction_repository.dart` — **mọi read là `Stream`; không có số dư lưu trữ** (D7)
- `lib/data/services/backup/` — `BackupDestination` interface + `AndroidSafDestination` + `ShareSheetDestination`; **`IosDocumentsDestination` cố ý chưa có nhưng interface đã đúng hình dạng**
- `lib/data/services/path_service.dart` — **chỉ lưu tên file**
- Backup format: JSON có version + field `schemaVersion`
- `drift_schemas/` commit

**Xác minh:** `money_test.dart` cộng khác loại tiền **ném lỗi**, VND ra `35.000 ₫` · migration test v(N−1)→vN xanh · **round-trip: seed 500 giao dịch → export → xoá DB → import → khớp từng byte + tổng theo tháng** · **bất biến số dư: 1000 thao tác ngẫu nhiên, số dư == `SUM()` mọi bước** (D7).

**Checklist:**

- [ ] `Money` value type: int minor units, assert cùng loại tiền, format `vi_VN` ra `35.000 ₫`
- [ ] `Clock` provider inject + `Result<T, AppError>`
- [ ] Schema drift: **không có cột balance**, `categoryColorId INTEGER` (không hex), `note_ascii` cột bóng, `category_keywords`, `app_events`
- [ ] Seed ~300 từ khoá tiếng Việt + 12 danh mục mặc định
- [ ] Repository: mọi read là `Stream`, mọi write trả `Result`
- [ ] `BackupDestination` interface + `AndroidSafDestination` + `ShareSheetDestination` (đã chốt cách lấy persistable SAF grant)
- [ ] `path_service.dart` chỉ lưu tên file, resolve base dir mỗi lần khởi động
- [ ] Migration + `drift_schemas/` đã commit, test v(N−1)→vN xanh
- [ ] Test round-trip: 500 giao dịch → export → xoá DB → import → khớp từng byte
- [ ] Test bất biến số dư: 1000 thao tác ngẫu nhiên, số dư == `SUM()` mọi bước

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md, phần "Bối cảnh chung" và "Phase 4". Thực hiện Phase 4.

Mục tiêu: schema drift + kiểu Money + migration có test + backup/restore ĐÃ CHỨNG MINH ĐƯỢC.

Vì sao backup/restore nằm ở phase 2 chứ không phải cuối: app này giữ bản sao duy nhất của
lịch sử tài chính Tony. allowBackup="false" nghĩa là Google auto-backup và adb backup đều
không cứu được. File backup trong app là ĐƯỜNG PHỤC HỒI DUY NHẤT TỒN TẠI. Nếu restore chạy
được thì mất keystore từ "thảm hoạ" hạ xuống "phiền phức". Xây hệ thống an toàn trước thứ nó bảo vệ.

HAI LUẬT SCHEMA KHÔNG ĐƯỢC PHÁ:
1. KHÔNG có cột balance ở bất cứ đâu. Số dư luôn là SUM(amount_minor) phát qua drift Stream.
   Than phiền số 1 về Rolly là số dư sai và không cập nhật sau khi thêm giao dịch — đó không
   phải bug cần cẩn thận, đó là quyết định schema. Không có cache thì không thể sai.
2. Bảng categories lưu categoryColorId INTEGER, TUYỆT ĐỐI không lưu chuỗi hex màu. Lưu hex là
   sai lầm không đảo ngược được phổ biến nhất trong app quản lý chi tiêu: dark mode sẽ sai,
   không đổi được cả bảng màu trong một file, không thêm được theme AMOLED sau này.

Tiền: int minor units + currency + currencyScale. VND scale 0. Không double, không Decimal trong DB.
Bọc trong value type Money bất biến, assert cùng loại tiền khi cộng trừ.

NGHIÊN CỨU TRƯỚC: share_plus 13 đã bỏ API tĩnh Share.shareXFiles() (gần như mọi ví dụ trên mạng
vẫn dùng cái cũ) — giờ là SharePlus.instance.share(ShareParams(...)). Và kiểm tra file_picker 12
có lộ takePersistableUriPermission() không: nếu KHÔNG thì grant SAF chết âm thầm sau reboot,
user tưởng có backup mà không có. Chốt ngay giữa package `saf` và platform channel Kotlin ~60 dòng.

Bốn test bắt buộc xanh trước khi qua phase sau:
1. Money: cộng khác loại tiền phải ném lỗi; VND ra "35.000 ₫" (vi_VN dùng "." phân cách nghìn)
2. Migration test sinh bởi `dart run drift_dev make-migrations`, commit drift_schemas/
3. Round-trip: seed 500 giao dịch → export → xoá DB → import → khớp từng byte + tổng theo tháng
4. Bất biến số dư: 1000 thao tác ngẫu nhiên, số dư hiển thị == SUM() ở mọi bước

Dùng NativeDatabase.memory(closeStreamsSynchronously: true) — thiếu tham số này là widget test
fail lúc teardown vì pending timer.

Xong thì tick các checkbox của Phase 4 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 5 🎨 — Design system *(chỉ theme + widget nguyên tử, chưa có màn hình)*

**Mục tiêu:** Toàn bộ ngôn ngữ thị giác tồn tại dưới dạng token và widget tái sử dụng **trước khi** viết màn hình nào. Đây là điều khiến các phase sau nhanh và nhất quán, thay vì mỗi màn tự bịa màu và khoảng cách.

Đọc **§ "Design system — đặc tả chốt"** ở đầu file. Đó là spec đầy đủ; phase này chỉ là thực thi nó.

**Nghiên cứu trước:**
- `ThemeExtension` — `lerp` và `copyWith` đúng chuẩn. **`lerp` phải nội suy thật, không được `=> other`**: theme switch có animate, `lerp` lười khiến màu tuỳ biến giật khi đổi light/dark trong khi màu Material chuyển mượt. Không ai để ý một cách có ý thức và ai cũng cảm thấy
- Trục biến thiên của `material_symbols_icons`: `wght`, `FILL`, `GRAD`, `opsz` — cách animate `FILL 0→1`
- `FontVariation` để điều khiển Inter variable · `FontFeature.tabularFigures()`
- `alchemist` golden test: tách platform test (chữ thật, chạy local) khỏi CI test (chữ thành khối màu) — đây là cách diệt nguồn giật golden số 1 là khác biệt render font giữa máy dev và CI
- Kiểm chứng bằng thực nghiệm: render chuỗi `Đồng Nai — ế ữ ỗ ặ ỡ Ế Ữ Ỗ · 1.234.567 ₫` ở mọi text style và **soi xem dấu có bị cắt không**

**Bàn giao:**
```text
lib/theme/
  tokens/              ← KHÔNG import material.dart ở bất kỳ file nào trong đây
    palette.dart       ← hex Radix thô, const Color, zero ngữ nghĩa
    spacing.dart  radii.dart  durations.dart  curves.dart
  app_colors.dart      ← ThemeExtension<AppColors> (ngữ nghĩa + 12 màu danh mục)
  app_typography.dart  ← ThemeExtension<AppTypography> (các style tiền)
  app_shadows.dart     ← ThemeExtension<AppShadows>
  app_theme.dart       ← file DUY NHẤT dựng ThemeData, qua _build(Brightness)
  context_ext.dart     ← context.colors / context.money / context.space
lib/ui/                ← widget nguyên tử dùng chung
  money_text.dart      ← nhận int đồng + dấu, format vi_VN, tabular, tô màu theo dấu
  category_avatar.dart ← nhận categoryColorId + iconCode, resolve màu QUA THEME
  app_card.dart  app_bottom_sheet.dart  app_chip.dart
  day_header.dart      ← tên ngày trái, tổng ròng phải bằng Inter tabular
  transaction_row.dart ← hàng tràn viền, KHÔNG phải card
  budget_ring.dart     ← CustomPainter, đầu nét bo tròn + vạch nhịp
  glass_surface.dart   ← BackdropFilter, CHỈ dùng ở nav bar và thanh nhập chat
  empty_state.dart  count_up_text.dart
docs/design-research.md ← lý do đầy đủ, để sau này không ai lật lại quyết định vì quên
```

**Luật thực thi:**
- **Một hàm `_build(Brightness b)` sinh ra cả `lightTheme` và `darkTheme`.** Hai `ThemeData` viết tay riêng **sẽ** lệch nhau theo thời gian; một hàm nhận tham số `Brightness` thì không thể
- `ColorScheme` lo mọi thứ M3 đã mô hình hoá; `ThemeExtension` **chỉ** lo cái M3 không có: `incomeText/Fill/Container`, `expenseText/Fill/Container`, `transfer`, `budgetOk/Warn/Over`, `categoryFills` (List 12), `chartGrid`, `chartAxisLabel`, `heatmapScale` (List 5), `skeletonBase/Highlight`, `glassTint`, `hairline`
- `elevation: 0` trên mọi component trong `ThemeData`, tự vẽ `BoxShadow`
- Call site đọc `context.colors.incomeText`, không bao giờ `Theme.of(context).extension<AppColors>()!`

**Xác minh:**
- **Golden test cho MỌI text style, ở CẢ light và dark, ở 1.0× và 1.3× text scale, với chuỗi `Đồng Nai — ế ữ ỗ ặ ỡ Ế Ữ Ỗ · 1.234.567 ₫`.** Đây là thứ bắt lỗi cắt dấu trước khi nó ship
- Golden cho mỗi widget nguyên tử, light + dark
- Test `MoneyText`: chi ra màu trung tính (không đỏ), thu ra xanh có tiền tố `+`, cả hai tabular
- Test `lerp` của mọi `ThemeExtension` nội suy thật ở `t = 0.5`
- Một màn "Style Gallery" chỉ có ở debug build, liệt kê mọi token và widget — vừa là tài liệu sống vừa là chỗ soi mắt

**Checklist:**

- [ ] `lib/theme/tokens/{palette,spacing,radii,durations,curves}.dart` — **không file nào import `material.dart`**
- [ ] `AppColors` / `AppTypography` / `AppShadows` ThemeExtension, **`lerp` nội suy thật** (không `=> other`)
- [ ] Một hàm `_build(Brightness)` sinh cả `lightTheme` lẫn `darkTheme`
- [ ] `elevation: 0` trên mọi component, tự vẽ `BoxShadow`; dark mode không đổ bóng
- [ ] `context.colors` / `context.money` / `context.space` extension
- [ ] Widget nguyên tử `lib/ui/`: `MoneyText`, `CategoryAvatar`, `AppCard`, `DayHeader`, `TransactionRow`, `BudgetRing`, `GlassSurface`, `EmptyState`, `CountUpText`
- [ ] `MoneyText`: chi = màu trung tính, thu = xanh có tiền tố `+`, cả hai tabular figures
- [ ] Golden **mọi** text style ở light+dark, 1.0× và 1.3×, chuỗi `Đồng Nai — ế ữ ỗ ặ ỡ Ế Ữ Ỗ · 1.234.567 ₫` không cắt dấu
- [ ] Màn Style Gallery chỉ có ở debug build
- [ ] `docs/design-research.md` ghi lý do

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md — phần "Bối cảnh chung", TOÀN BỘ mục
"🎨 Design system — đặc tả chốt", và "Phase 5". Thực hiện Phase 5.

Tony yêu cầu rõ: giao diện phải SIÊU ĐẸP VÀ HIỆN ĐẠI. Rolly bị chê "sparse and crude".
Phase này dựng toàn bộ ngôn ngữ thị giác dưới dạng token + widget nguyên tử TRƯỚC KHI viết
màn hình nào — đó là thứ khiến các phase sau nhanh và nhất quán thay vì mỗi màn tự bịa màu.

Đặc tả đầy đủ (font, bảng màu Radix, thang bo góc, thang khoảng cách, đổ bóng, motion) đã có
sẵn trong TODOS.md mục "🎨 Design system". Đừng phát minh lại, hãy thực thi nó.

BỐN LUẬT KHÔNG ĐƯỢC PHÁ:
1. lib/theme/tokens/ KHÔNG import material.dart ở bất kỳ file nào — chỉ dart:ui / painting.dart.
   Flutter đã đóng băng thư viện material trong SDK và sẽ chuyển sang package material_ui.
   Luật này khiến migration đó chỉ là đổi một dòng import.
2. MỘT hàm _build(Brightness b) sinh ra cả lightTheme lẫn darkTheme. Hai ThemeData viết tay
   riêng SẼ lệch nhau theo thời gian.
3. Mọi ThemeExtension phải có lerp() nội suy THẬT, không được viết `=> other`. Theme switch có
   animate; lerp lười khiến màu tuỳ biến giật trong khi màu Material chuyển mượt.
4. elevation: 0 trên MỌI component, tự vẽ BoxShadow. Và dark mode KHÔNG dùng đổ bóng —
   chiều sâu trong dark mode là độ sáng bề mặt + hairline. Một luật này chiếm phần lớn khác biệt
   giữa dark theme tốt và light theme bị đổi màu.

HAI QUYẾT ĐỊNH THỊ GIÁC ĐÁNG GIÁ NHẤT, đừng làm sai:
- Chi tiêu render màu TRUNG TÍNH (onSurface), không phải đỏ. Thu render xanh có tiền tố "+".
  Đỏ chỉ dành cho vượt ngân sách và hành động phá huỷ. Trong app quản lý chi tiêu ~90% dòng là chi;
  đỏ hết thì đỏ vô nghĩa và màn hình gào lên.
- Hàng giao dịch TRÀN VIỀN, không phải card-mỗi-hàng. Card-mỗi-hàng ngốn 30% chiều dọc vào lề
  và tạo nhiễu từ viền lặp. Đây là khác biệt giữa Spendee/Copilot và app template.

CẠM BẪY TIẾNG VIỆT: mọi TextStyle phải có height tường minh (body ≥1.45) và
leadingDistribution: TextLeadingDistribution.even, nếu không dấu chồng của tiếng Việt (ế ữ ỗ ặ)
bị cắt. Mọi style tiền phải có FontFeature.tabularFigures(), thiếu là cột số căn phải giật
nhìn thấy được mỗi khi chữ số đổi.

XÁC MINH BẮT BUỘC: golden test cho MỌI text style, ở CẢ light và dark, ở 1.0x và 1.3x text scale,
với chuỗi "Đồng Nai — ế ữ ỗ ặ ỡ Ế Ữ Ỗ · 1.234.567 ₫". Đây là thứ bắt lỗi cắt dấu trước khi ship.
Kèm một màn "Style Gallery" chỉ có ở debug build để soi mắt.

Xong thì tick các checkbox của Phase 5 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 6 — CRUD giao dịch + 🚀 **dogfood APK đầu tiên (v0.1.0)**

**Mục tiêu:** App nhập tay dùng được và đã đẹp, và — theo H3 — **chứng minh toàn bộ đường ống giao hàng trong khi dữ liệu còn vô giá trị.**

**Nghiên cứu trước:** Flutter App Architecture guide (View/ViewModel/Repository) ánh xạ sang Riverpod 3 `AsyncNotifier` · **edge-to-edge cưỡng chế của Android 15+** (E4/H8) — giữ nút chính của bottom-sheet trên cả bàn phím lẫn gesture inset, đây chính là than phiền #3 của Rolly · `animations` package `OpenContainer` cho container transform · predictive back trên API 36.

**Bàn giao:**
- `lib/features/transactions/` — danh sách **hàng tràn viền dưới header ngày dính, header mang tổng ròng của ngày căn phải**; **hero card** đầu danh sách (chi tiêu từ đầu tháng làm số khổng lồ, dưới là hai cột Thu/Chi); form thêm/sửa dạng **bottom sheet**; xoá có undo
- `lib/core/router/` — go_router `StatefulShellRoute`, **bottom nav 4 tab** `Nhập · Giao dịch · Báo cáo · Ngân sách` trên `glass_surface`, **pill biến hình + icon `FILL 0→1`** khi đổi tab; Cài đặt sau icon ở app bar
- FAB `Thêm` **chỉ ở tab Giao dịch**, thu về icon-only khi cuộn
- Settings → About hiện version + `GIT_SHA` + build time (D4) + toggle theme (Sáng/Tối/Theo hệ thống) + toggle **Đen tuyền (AMOLED)**
- Toàn bộ chữ tiếng Việt, xưng hô thân mật (`Bạn`, không `Quý khách`); `l10n` mặc định `vi`, `en` stub
- `tool/build_apk.sh`, `tool/serve_apk.sh`

**🚀 Checkpoint dogfood:** `flutter build apk --release` → **universal APK** (D6) · `adb install` lên emulator, rồi **tăng `versionCode` và cài đè** — chứng minh nâng cấp tại chỗ giữ nguyên dữ liệu; **lặp lại ở mọi phase sau** · `tailscale serve --bg --set-path /tonyfino/ <dist>` (**E1**) · cài lên điện thoại từ `https://tony.tailfcdcfc.ts.net/tonyfino/`.

**Xác minh:** widget test + golden (light/dark) cho danh sách, hero card, form · thủ công: xoay màn, đổi theme, **nút Save còn với tới được khi bàn phím mở, trên emulator API 36** · cài đè giữ nguyên database. **Nếu bước này hỏng, dừng mọi thứ để sửa.**

**Checklist:**

- [ ] Danh sách: hàng **tràn viền** dưới header ngày dính, header mang tổng ròng căn phải
- [ ] Hero card: chi tiêu từ đầu tháng làm số khổng lồ + hai cột Thu/Chi
- [ ] Form thêm/sửa là **bottom sheet**, xoá có undo
- [ ] Bottom nav đúng 4 tab trên `GlassSurface`, pill biến hình + icon `FILL 0→1`
- [ ] FAB `Thêm` chỉ ở tab Giao dịch, thu về icon-only khi cuộn
- [ ] Settings → About: version + `GIT_SHA` + build time, toggle theme + AMOLED
- [ ] Widget test + golden light/dark cho danh sách, hero card, form
- [ ] **Nút Save còn với tới được khi bàn phím mở, trên emulator API 36**
- [ ] Build universal APK, `adb install`, tăng versionCode, **cài đè giữ nguyên database**
- [ ] `tailscale serve --bg --set-path /tonyfino/`, `tailscale serve status` xác nhận 4 mục cũ còn nguyên
- [ ] 🚀 Cài v0.1.0 lên điện thoại từ `https://tony.tailfcdcfc.ts.net/tonyfino/`

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md — "Bối cảnh chung", mục "🎨 Design system"
(phần Bố cục), và "Phase 6". Thực hiện Phase 6.

Hai mục tiêu: (a) app nhập tay dùng được và ĐÃ ĐẸP, (b) CHỨNG MINH TOÀN BỘ ĐƯỜNG ỐNG GIAO HÀNG
trong khi dữ liệu còn vứt đi được.

Vì sao (b) quan trọng ngang (a): đường ống giao hàng có 5 mắt xích chưa từng được thử —
keystore → universal APK → tailscale serve subpath → prompt "cài app không rõ nguồn" →
NÂNG CẤP ĐÈ LÊN BẢN ĐANG CÀI. Để tới v1.0.0 mới thử là thử đúng lúc rủi ro nhất, khi APK
đang mang lịch sử tài chính thật. Thử bây giờ khi hỏng cũng chẳng mất gì.

Dùng widget nguyên tử đã dựng ở Phase 5, đừng viết lại. Bố cục theo spec:
- Danh sách: hàng TRÀN VIỀN dưới header ngày DÍNH. Header ngày mang tổng ròng của ngày căn phải
  ("Hôm nay · Thứ Năm" trái, "−285.000 ₫" phải bằng Inter tabular). Đây là tín hiệu "có thiết kế"
  rẻ nhất có thể thêm — nó biến danh sách phẳng thành một cuốn sổ cái.
- Hero card đầu danh sách: số khổng lồ là CHI TIÊU TỪ ĐẦU THÁNG, không phải "số dư"
  (số dư của app nhập tay là hư cấu). Dưới là hai cột Thu/Chi.
- Bottom nav ĐÚNG 4 tab: Nhập · Giao dịch · Báo cáo · Ngân sách. Cài đặt sau icon ở app bar.
  5 tab là lúc nav bắt đầu trông như thanh công cụ bảng tính.
- Form thêm/sửa là BOTTOM SHEET, không phải trang mới.

NGHIÊN CỨU TRƯỚC: Android 15+ cưỡng chế edge-to-edge. Đây chính xác là thay đổi làm nút Save
trong bottom-sheet bị nav bar che — than phiền #3 về Rolly là "form sửa thiếu nút Save".
Xử lý inset THEO TỪNG scroll view, không dùng một SafeArea toàn cục (SafeArea bao trùm giết
hiệu ứng nav bar mờ và phí màn hình). Test THẬT trên emulator tonyfino36 với bàn phím mở.

Build: `flutter build apk --release` KHÔNG --split-per-abi. Emulator x86_64, điện thoại arm64-v8a.
Serve: `tailscale serve --bg --set-path /tonyfino/ <dist>`.
⚠️ TUYỆT ĐỐI KHÔNG `tailscale serve reset` và không bind "/" — đường "/" cùng /web/, /task1.apk,
/task1-arm64.apk, /task1-video.mp4 thuộc project "writing task 1" khác. Sau khi set chạy
`tailscale serve status` xác nhận 4 mục cũ còn nguyên.

XÁC MINH QUAN TRỌNG NHẤT: cài APK lên emulator, tăng versionCode, build lại, cài đè, kiểm tra
database còn nguyên. Nếu hỏng thì dừng mọi thứ khác để sửa.

Xong thì tick các checkbox của Phase 6 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 7 — Parser tiếng Việt *(Dart thuần, không UI)*

**Mục tiêu:** ~400 dòng Dart không phụ thuộc gì, biến chữ tiếng Việt thành `List<ParsedDraft>`. Đoạn code giá trị nhất dự án.

**Nghiên cứu trước:**
- Chuẩn hoá Unicode: NFC, và **kiểm chứng bằng thực nghiệm rằng `đ` KHÔNG phân rã dưới NFD** — nó là chữ cái riêng. Phải map `đ→d` tường minh; kiểm tra package `diacritic` bằng chuỗi tiếng Việt thật
- Biến thể số đếm: `một/mốt`, `năm/lăm`, `bốn/tư`, `mười/mươi`, `linh/lẻ`
- **Luật giá trị nhất — `2tr5`:** chữ số lẻ đứng sau là **phân số của đơn vị THẤP HƠN KẾ TIẾP** → `2tr5` = 2.500.000, `1tr250` = 1.250.000. Liệt kê ca nhập nhằng ra giấy *trước khi* code
- **`thứ 2` = Monday**, lệch một so với ISO · **`12/3` = DD/MM**

**Bàn giao — `lib/features/quick_add/domain/parser/`:** `normalizer.dart` (NFC → lowercase → hai luồng + map `đ→d` + bảng teencode ~50 mục tự chọn) · `tokenizer.dart` · `amount_evaluator.dart` (**đệ quy xuống, KHÔNG regex**) · `date_parser.dart` (**neo vào `Clock` inject**, giữ nhãn buổi trong ngày làm tín hiệu phân loại) · `segmenter.dart` (**tách nhiều giao dịch**) · `category_matcher.dart` (chấm `weight × độ dài khớp`) · `parse_result.dart` · **`test/fixtures/parser/corpus.jsonl` 300+ cặp**.

**Xác minh:** corpus 300+ ca xanh dưới `Clock` đóng băng · fuzz 10.000 chuỗi → không ném lỗi, không số âm · property test `parse(format(n)) == n`.

**Checklist:**

- [ ] `normalizer.dart` — NFC, hai luồng, map `đ→d` tường minh, teencode ~50 mục
- [ ] `tokenizer.dart` + `amount_evaluator.dart` **đệ quy xuống, không regex thuần**
- [ ] Xử lý đúng: `35k`, `35 nghìn/ngàn`, `1tr`, **`2tr5` = 2.500.000**, `1 triệu 2`, `1tr250`, `35 củ`, `rưỡi`, số viết chữ có biến thể
- [ ] `date_parser.dart` neo `Clock` inject — `hôm qua`, **`thứ 2` = Monday**, `thứ 3 tuần trước`, **`12/3` = DD/MM**, nhãn buổi trong ngày
- [ ] `segmenter.dart` — một tin nhắn ra **nhiều** draft
- [ ] `category_matcher.dart` — chấm `weight × độ dài khớp`, argmax trên ngưỡng
- [ ] `test/fixtures/parser/corpus.jsonl` **300+ cặp**, chạy thành một test tham số hoá, xanh dưới `Clock` đóng băng
- [ ] Fuzz 10.000 chuỗi không ném lỗi, không số âm; property test `parse(format(n)) == n`

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md, phần "Bối cảnh chung" và "Phase 7". Thực hiện Phase 7.

Viết parser tiếng Việt: chuỗi chữ → List<ParsedDraft>. Dart thuần, KHÔNG UI, không phụ thuộc
Flutter, không phụ thuộc DB. Đây là đoạn code giá trị nhất dự án và là hàm thuần nên test
vét cạn gần như miễn phí.

KHÔNG CÓ THƯ VIỆN NÀO LÀM SẴN VIỆC NÀY — không phải trong Dart, cũng không trong ngôn ngữ nào.
Đã research kỹ. Phải tự viết, ~400 dòng.

BỐN LUẬT DỄ SAI NHẤT, ghi ra giấy trước khi code:
1. "2tr5" = 2.500.000, KHÔNG PHẢI 2.000.005. Chữ số lẻ đứng sau là phân số của đơn vị
   THẤP HƠN KẾ TIẾP. "1tr250" = 1.250.000. Đây là luật giá trị nhất toàn parser.
2. "thứ 2" = Thứ Hai = Monday. Cách đánh số thứ của tiếng Việt lệch một so với ISO.
3. "12/3" = ngày 12 tháng 3, KHÔNG BAO GIỜ là 3 tháng 12. Việt Nam dùng DD/MM.
4. Chữ "đ" KHÔNG phân rã dưới Unicode NFD — nó là chữ cái riêng chứ không phải d + dấu.
   Phải map đ→d tường minh. Kiểm chứng package diacritic bằng chuỗi tiếng Việt thật,
   đừng giả định. Bỏ sót là hỏng âm thầm mọi phép khớp "dong"/"đồng".

Phải xử lý được: 35k · 35 nghìn · 35 ngàn · 200 nghìn · hai trăm ngàn · 1 triệu · 1tr ·
1 triệu 2 · 2tr5 · 1tr250 · 35 củ (=35 triệu) · một triệu rưỡi · 35tr rưỡi · 35.000 · 35,000 ·
35000đ · 35000 vnd. Dùng tokenizer + đệ quy xuống, KHÔNG regex thuần — regex sẽ chết ở
"1 triệu 2 trăm 50 nghìn".

segmenter.dart quan trọng: một tin nhắn phải ra NHIỀU draft. "Café 30k, xem phim 100k" → 2 draft.
Rolly quảng cáo được cái này nhưng review cho thấy nó chỉ nhận ra một khoản. Đây là điểm ta thắng.

date_parser neo vào Clock được inject (package:clock), TUYỆT ĐỐI không DateTime.now().

Sản phẩm bắt buộc: test/fixtures/parser/corpus.jsonl với 300+ cặp input→expected, chạy thành
MỘT test tham số hoá. Đây là test ROI cao nhất codebase — nó cho phép refactor parser không
sợ hãi trong nhiều tháng tới.

Xong thì tick các checkbox của Phase 7 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 8 — Màn chat quick-add 🎨 *(màn hình đinh)*

**Mục tiêu:** Gõ tiếng Việt → thẻ xác nhận → lưu. Kèm cá nhân hoá không cần ML. Đây là màn hình định nghĩa app.

### Quyết định khung: **màn chat của TonyFino KHÔNG được là chatbot. Nó là một cuốn sổ cái tình cờ nhận được câu văn.**

Đây là toàn bộ cuộc chơi. Khác biệt của Rolly là *tính cách* — chọn tâm trạng AI, câu trả lời hóm hỉnh. Cleo cũng vậy. Cả hai là **nước cờ thu hút người dùng ở thị trường tiếng Anh**. Với một công cụ cá nhân dùng 6 lần/ngày, tính cách trở thành ma sát từ ngày thứ ba.

Cụ thể: **không avatar. Không chỉ báo "đang gõ…". Không lời chào. Không "Tuyệt vời! 🎉". Không spinner suy nghĩ.** Không gì trong transcript mà không phải dữ liệu. Hai mục tiêu, theo thứ tự: **(1) phải cảm giác tức thì, (2) phải hiển nhiên là app đã hiểu gì và sửa được trong một chạm.**

### Thẻ xác nhận — giải phẫu

Không phải bong bóng chat. Là **thẻ giao dịch full-width**, icon danh mục tròn dẫn đầu theo màu danh mục, căn trái trong transcript.

```text
┌────────────────────────────────────────────┐
│ ●  Cà phê                        −35.000 ₫ │  ← 15sp Be Vietnam Pro 500 / Inter 24sp 600 tabular
│                                            │
│ [ 🍵 Cà phê ▾ ] [ Hôm nay ▾ ] [ Tiền mặt ▾ ]│  ← chip SỬA ĐƯỢC
│                                            │
│ ✓ Đã lưu                          Hoàn tác │  ← ghi lạc quan + undo
└────────────────────────────────────────────┘
```

1. **Số tiền là nhân vật chính.** ~24–28sp Inter SemiBold, tabular, căn phải, có dấu `−`/`+` tường minh. Mọi thứ khác 13–15sp
2. **Chip phải trông sửa được.** Có caret `▾` và viền 1px hoặc gạch chân chấm — **không phải pill tô đặc**, pill tô đặc đọc ra là nhãn tĩnh
3. 🔥 **Tín hiệu độ tin cậy — nước cờ tạo lòng tin giá trị nhất.** Field nào parser không chắc thì render chip theo kiểu *chưa xác nhận*: viền + mờ + một glyph `?`. Nó biến "app đoán sai mà mình không để ý" thành "app đã nói trước là nó đang đoán"
4. 🔥 **Ghi lạc quan + undo inline, KHÔNG phải nút xác nhận.** Giao dịch ghi vào drift **ngay lập tức**. Thẻ hiện `✓ Đã lưu` + text button `Hoàn tác` sống ~6 giây rồi co lại thành trạng thái đã lưu gọn (chip thành chữ thường, cao giảm ~40%). Một nút xác nhận trên mỗi lần nhập sẽ **phá huỷ chính cái tốc độ biện minh cho sự tồn tại của màn chat**. Không bao giờ dùng modal dialog
5. **Nhiều giao dịch một tin nhắn** → **nhiều thẻ riêng**, xếp chồng, lệch 60 ms, kèm một `Hoàn tác tất cả` bên dưới
6. 🔥 **Trạng thái lỗi phải là một THẺ, không phải toast.** Không parse được → thẻ thành `Mình chưa hiểu — chọn giúp mình nhé`, **giữ nguyên chữ gốc trong ô sửa được**, ô số tiền tự focus với bàn phím đã bật. Toast ở đây là không thể tha thứ — nó làm mất input
7. **Nhấn giữ thẻ** → sheet: `Sửa` / `Nhân đôi` / `Xoá`

### Thanh nhập — nơi giành lấy cảm giác cao cấp

- Ghim đáy, `borderRadius: full`, đặt trên `glass_surface` (một trong hai chỗ duy nhất dùng blur). Nút gửi **biến hình từ mic sang mũi tên** khi có chữ (200 ms `easeOutCubic`)
- 🔥 **Xem trước số tiền ngay khi đang gõ.** Gõ `cà phê 35k` → hiện ghost `35.000 ₫` căn phải, cập nhật từng phím. **Zero độ trễ, zero LLM, thuần regex** — và là **thắng lợi cảm-giác-thông-minh lớn nhất có thể có**. Nó cho người dùng thấy parser đang hoạt động *trước khi* họ commit, và dạy cú pháp một cách ngầm
- 🔥 **Chip gợi ý phía trên thanh nhập**, cuộn ngang, lấy từ 5 mục nhập gần đây nhất: `cà phê 35k` · `xăng 50k` · `ăn trưa 60k`. Giải quyết luôn empty state, dạy cú pháp, và biến những mục hay dùng nhất thành một chạm
- **Bàn phím không bao giờ tự đóng sau khi gửi.** Transcript tự cuộn, 200 ms `easeOut`
- **Vạch ngăn ngày trong transcript** (`Hôm nay`, `Hôm qua`, `Thứ Hai, 18/8`) để chat log kiêm luôn nhật ký cuộn được, thay vì một phiên rồi biến mất
- Màn chat phải là **màn yên tĩnh nhất app** — không biểu đồ, không card tổng kết. Chỉ bề mặt mềm, transcript, và thanh nhập

### Vòng lặp học — toàn bộ tính năng "AI biết học", zero ML, zero mạng
Mỗi lần user sửa danh mục, **chèn/tăng trọng số `leftoverText` của draft vào `category_keywords`** gắn danh mục đã chọn. Sau hai tuần app thuộc từ vựng riêng của Tony. Rolly làm việc này bằng cách gửi dữ liệu lên LLM bên thứ ba.

**Nghiên cứu trước:** Riverpod 3 `AsyncNotifier` cho transcript · `CustomScrollView(reverse: true)` + `SliverList` (reverse cho hành vi chèn khi bàn phím lên đúng miễn phí) · `MediaQuery.viewInsetsOf(context)` cho đệm bàn phím — **không** dùng riêng `resizeToAvoidBottomInset` vì nó chống lại edge-to-edge · `AnimatedSize` + `AnimatedSwitcher` giữa `_PendingCard`/`_SavedCard`.

**Xác minh:** integration test gõ `"Café 30k, xem phim 100k hôm qua"` → 2 thẻ, đúng số, đúng ngày, cả hai lưu · test học: sửa danh mục một lần → lần sau tự phân loại đúng · golden thẻ xác nhận ở 3 trạng thái (chờ / đã lưu / không hiểu), light + dark · **🚀 dogfood APK v0.2.0** — **Tony bắt đầu ghi chi tiêu thật từ đây**.

**Checklist:**

- [ ] Transcript `CustomScrollView(reverse: true)` — **không dùng package chat UI nào**
- [ ] Thẻ xác nhận: số tiền là nhân vật chính, chip sửa được có caret
- [ ] 🔥 **Xem trước số tiền ngay khi đang gõ** (ghost `35.000 ₫`, thuần regex, cập nhật từng phím)
- [ ] 🔥 **Ghi lạc quan + `Hoàn tác` inline ~6 giây** — không nút xác nhận, không modal
- [ ] 🔥 **Tín hiệu độ tin cậy** — chip chưa chắc render kiểu outlined + mờ + glyph `?`
- [ ] Nhiều giao dịch → nhiều thẻ lệch 60ms + `Hoàn tác tất cả`
- [ ] **Trạng thái lỗi là một THẺ giữ nguyên chữ gốc**, không phải toast
- [ ] Chip gợi ý từ 5 mục gần nhất + vạch ngăn ngày trong transcript
- [ ] **Vòng lặp học**: sửa danh mục → chèn/tăng weight `leftoverText` vào `category_keywords`
- [ ] `AiParseFallback` interface + `NoopFallback`
- [ ] Integration test `"Café 30k, xem phim 100k hôm qua"` → 2 thẻ đúng; golden thẻ ở 3 trạng thái
- [ ] 🚀 dogfood APK v0.2.0 — **Tony bắt đầu ghi chi tiêu thật từ đây**

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md — "Bối cảnh chung", mục "🎨 Design system", và
TOÀN BỘ "Phase 8". Thực hiện Phase 8.

Đây là màn hình ĐINH của app, và là màn định nghĩa cảm giác toàn bộ sản phẩm.

QUYẾT ĐỊNH KHUNG, đọc kỹ: màn chat của TonyFino KHÔNG ĐƯỢC LÀ CHATBOT. Nó là một cuốn sổ cái
tình cờ nhận được câu văn. Khác biệt của Rolly là TÍNH CÁCH — chọn tâm trạng AI, câu trả lời
hóm hỉnh. Đó là nước cờ thu hút người dùng ở thị trường tiếng Anh. Với công cụ cá nhân dùng
6 lần/ngày, tính cách trở thành MA SÁT từ ngày thứ ba.
Cụ thể: KHÔNG avatar, KHÔNG "đang gõ...", KHÔNG lời chào, KHÔNG "Tuyệt vời! 🎉", KHÔNG spinner.
Không gì trong transcript mà không phải dữ liệu.

BA THỨ GIÀNH LẤY CẢM GIÁC CAO CẤP, đừng bỏ cái nào:
1. XEM TRƯỚC SỐ TIỀN NGAY KHI ĐANG GÕ. Gõ "cà phê 35k" thì hiện ghost "35.000 ₫" căn phải,
   cập nhật từng phím. Zero độ trễ, zero LLM, thuần regex — và là thắng lợi cảm-giác-thông-minh
   lớn nhất có thể có. Nó cho thấy parser đang chạy TRƯỚC KHI người dùng commit, và dạy cú pháp ngầm.
2. GHI LẠC QUAN + UNDO INLINE, KHÔNG phải nút xác nhận. Giao dịch ghi vào drift NGAY. Thẻ hiện
   "✓ Đã lưu" + nút "Hoàn tác" sống ~6 giây rồi co lại. Một nút xác nhận trên mỗi lần nhập sẽ
   phá huỷ chính cái tốc độ biện minh cho sự tồn tại của màn chat. KHÔNG BAO GIỜ dùng modal dialog.
3. TÍN HIỆU ĐỘ TIN CẬY. Field nào parser không chắc thì render chip kiểu chưa-xác-nhận (viền,
   mờ, glyph "?"). Nó biến "app đoán sai mà mình không để ý" thành "app đã nói trước là nó đang đoán".

TRẠNG THÁI LỖI PHẢI LÀ MỘT THẺ, KHÔNG PHẢI TOAST. Không parse được → thẻ thành "Mình chưa hiểu —
chọn giúp mình nhé", GIỮ NGUYÊN chữ gốc trong ô sửa được, ô số tiền tự focus với bàn phím đã bật.
Toast ở đây là không thể tha thứ — nó làm mất input của người dùng.

VÒNG LẶP HỌC — toàn bộ tính năng "AI biết học", làm bằng zero ML và zero mạng:
Mỗi lần user sửa danh mục của một draft, chèn (hoặc tăng weight) leftoverText của draft đó vào
bảng category_keywords gắn với danh mục đã chọn. Sau hai tuần app thuộc từ vựng riêng của Tony.

KHÔNG DÙNG package chat UI nào (flutter_chat_ui, chat_bubbles, flutter_gen_ai_chat_ui). Tất cả
giả định miền nhắn tin (avatar, đã đọc, đính kèm, streaming) mà ta không có. Tự dựng bằng
CustomScrollView(reverse: true) + SliverList.

Tạo interface AiParseFallback + NoopFallback. Chỉ kích hoạt khi amount == null hoặc confidence
dưới ngưỡng. Phase 12 cắm bản thật vào.

Kết thúc: dogfood APK v0.2.0, và Tony BẮT ĐẦU GHI CHI TIÊU THẬT từ đây. Những câu parser đoán sai
trong đời thật là đầu vào giá trị nhất để tinh chỉnh Phase 7.

Xong thì tick các checkbox của Phase 8 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 9 — Importer Rolly *(được gỡ chặn bởi Phase 2)*

**Mục tiêu:** Đưa mọi giao dịch lịch sử vào, kèm bằng chứng đối chiếu.

**Nghiên cứu trước:** Đọc lại `docs/rolly-schema.md`. **Viết bảng ánh xạ từng field ra trước khi code**, đặc biệt quy ước dấu, múi giờ, thang số tiền · ánh xạ danh mục Rolly → TonyFino, danh mục không map được phải **hiện ra cho user** · parse JSON dạng stream nếu payload lớn.

**Bàn giao:** `lib/features/settings/import/` — chọn file → **màn xem trước & ánh xạ** → dry-run diff → commit · **Idempotency: `sourceId` xác định cho mỗi dòng** để chạy lại không nhân đôi · import/export CSV luôn (Rolly tính phí cả hai) · **báo cáo đối chiếu**: số lượng + tổng theo tháng so với oracle Phase 2.

**Xác minh:** import `sample.json` → sổ cái đúng kỳ vọng · **import file thật → báo cáo đối chiếu khớp CHÍNH XÁC oracle Phase 2.** Không khớp nghĩa là importer sai — **không được "nhìn qua thấy ổn rồi đi tiếp"** · import hai lần → không trùng · **🚀 dogfood APK v0.3.0**.

> ⚠️ **Từ bản build này trở đi app giữ dữ liệu không thể thay thế.** Backup **trước** mỗi lần cài, xác nhận keystore không đổi.

**Checklist:**

- [ ] Bảng ánh xạ từng field viết ra **trước khi** code (dấu, múi giờ, thang tiền)
- [ ] UI: chọn file → màn xem trước & ánh xạ danh mục → dry-run diff → commit
- [ ] Danh mục không map được **hiện ra cho Tony chọn**, không âm thầm bỏ
- [ ] **`sourceId` xác định** cho mỗi dòng — import hai lần không tạo bản ghi trùng
- [ ] Import/export CSV
- [ ] Import `sample.json` → sổ cái đúng kỳ vọng
- [ ] **Import file thật → báo cáo đối chiếu khớp CHÍNH XÁC oracle Phase 2**
- [ ] 🚀 dogfood APK v0.3.0 — từ đây app giữ dữ liệu không thể thay thế, backup trước mỗi lần cài

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md, phần "Bối cảnh chung" và "Phase 9". Thực hiện Phase 9.
ĐỌC TRƯỚC: docs/rolly-schema.md (sản phẩm của Phase 2) và raw_rolly/.

Viết importer đưa toàn bộ lịch sử giao dịch Rolly của Tony vào TonyFino.

KHÔNG ĐƯỢC ĐOÁN SCHEMA. Hình dạng dữ liệu đã ghi trong docs/rolly-schema.md từ payload thật.
Viết bảng ánh xạ từng field RA GIẤY trước khi code, soi kỹ ba thứ: quy ước dấu (thu vs chi),
múi giờ của timestamp, và thang số tiền (minor unit hay major). Sai một trong ba là hỏng cả bộ
import mà nhìn qua vẫn thấy hợp lý.

IDEMPOTENCY BẮT BUỘC: mỗi dòng import phải có sourceId xác định để chạy import lần hai không tạo
bản ghi trùng. Import CHẮC CHẮN sẽ được chạy nhiều hơn một lần.

Luồng UI: chọn file → màn xem trước & ánh xạ danh mục → dry-run diff → mới commit.
Danh mục Rolly không ánh xạ được phải HIỆN RA cho Tony chọn, tuyệt đối không âm thầm bỏ qua.

XÁC MINH QUAN TRỌNG NHẤT: sau khi import file thật, sinh báo cáo đối chiếu (tổng số giao dịch +
tổng tiền từng tháng) và so với oracle đã ghi ở Phase 2 đọc từ chính UI Rolly. Phải khớp
CHÍNH XÁC. Không khớp nghĩa là importer sai — đừng "nhìn qua thấy ổn rồi đi tiếp".

Làm luôn cả import/export CSV — Rolly tính phí cả hai chiều.

⚠️ Từ bản build này trở đi app giữ dữ liệu KHÔNG THỂ THAY THẾ. Backup trước mỗi lần cài APK mới.

Xong thì tick các checkbox của Phase 9 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 10 — Biểu đồ, báo cáo, lịch chi tiêu 🎨

**Nghiên cứu trước:** **fl_chart 1.x** — API 1.0 khác hẳn 0.6x và gần như toàn bộ tutorial ngoài kia nhắm 0.6x; đọc ví dụ của chính `fl_chart-1.2.0` trên đĩa · gộp SQL hiệu quả trong drift (`groupBy` + `sum`) để biểu đồ đọc từ DB chứ không lặp Dart.

**Bàn giao:** `lib/features/reports/` — **bento grid** (2 cột ô thống kê + biểu đồ full-width + heatmap full-width) · tròn theo danh mục **giới hạn 6 lát + "Khác"**, chạm để xem đầy đủ · đường xu hướng theo tháng · cột thu-vs-chi · **lịch heatmap chi tiêu theo ngày, tự viết `CustomPainter` 7×N với 5 bậc cường độ VND** (Rolly tính phí cái này) · lọc theo khoảng ngày + danh mục.

**Animation:** biểu đồ vẽ vào khi vào tab, một lần, 450 ms `easeOutCubic`. **Tròn animate BÁN KÍNH, không phải góc quét** — quét trông như spinner loading. Đường animate clip rect trái→phải. Cột animate chiều cao lệch 30 ms.

**Xác minh:** unit test gộp số trên DB đã seed · golden mỗi biểu đồ, light + dark (**lưu ý H7**) · **hiệu năng: render < 500 ms với tập dữ liệu THẬT đã import**, không phải dữ liệu mẫu · **🚀 dogfood APK v0.4.0**.

**Checklist:**

- [ ] Bento grid: ô thống kê 2 cột + biểu đồ full-width + heatmap full-width
- [ ] Biểu đồ tròn **giới hạn 6 lát + "Khác"**, mỗi danh mục kèm icon chứ không chỉ chấm màu
- [ ] Đường xu hướng theo tháng + cột thu-vs-chi
- [ ] **Heatmap tự viết `CustomPainter` 7×N**, 5 bậc cường độ VND
- [ ] Animation vẽ vào một lần: tròn animate **bán kính** (không phải góc quét), đường clip trái→phải, cột lệch 30ms
- [ ] Lọc theo khoảng ngày + danh mục
- [ ] Gộp số bằng SQL trong drift, **không** lặp Dart trên toàn sổ cái
- [ ] Golden mỗi biểu đồ light+dark; **render < 500ms với dữ liệu THẬT đã import**
- [ ] 🚀 dogfood APK v0.4.0

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md — "Bối cảnh chung", mục "🎨 Design system", và "Phase 10".
Thực hiện Phase 10.

Màn báo cáo: bento grid gồm ô thống kê 2 cột + biểu đồ tròn theo danh mục + đường xu hướng theo
tháng + cột thu-vs-chi + lịch heatmap chi tiêu theo ngày. Rolly khoá cái lịch sau paywall —
ở đây miễn phí.

NGHIÊN CỨU TRƯỚC: fl_chart 1.x có API khác hẳn 0.6x và GẦN NHƯ TOÀN BỘ tutorial, blog, câu trả lời
StackOverflow ngoài kia đều nhắm 0.6x. Đọc ví dụ của chính package tại
~/.pub-cache/hosted/pub.dev/fl_chart-1.2.0/example/ chứ đừng theo trí nhớ.

BA QUYẾT ĐỊNH THIẾT KẾ:
1. Biểu đồ tròn GIỚI HẠN 6 LÁT + "Khác", chạm để xem đầy đủ. Mắt người chỉ phân biệt tin cậy 6-8
   sắc độ trong một biểu đồ; 12 lát thì không ai đọc được. Mỗi danh mục LUÔN kèm icon chứ không
   chỉ chấm màu — đó cũng là cách sửa cho người mù màu.
2. Heatmap TỰ VIẾT bằng CustomPainter 7×N với 5 bậc cường độ VND (~120 dòng). Các package
   heatmap có sẵn đều ì và cứng nhắc, không theo được theme.
3. Animate biểu đồ tròn bằng BÁN KÍNH, không phải góc quét — quét trông như spinner loading.
   Đường: animate clip rect trái→phải. Cột: animate chiều cao lệch 30ms mỗi cột. Chỉ chạy MỘT LẦN
   khi vào tab.

HIỆU NĂNG: mọi phép gộp làm bằng SQL trong drift (groupBy + sum), KHÔNG kéo toàn bộ sổ cái về Dart
rồi lặp. Đo: báo cáo render dưới 500ms với dữ liệu THẬT đã import, không phải dữ liệu mẫu.

Golden test cho từng biểu đồ, light + dark. Nếu Phase 3 xác định emulator phải tắt Impeller thì
golden chỉ bảo đảm LAYOUT chứ không bảo đảm pixel — ghi rõ vào test.

Kết thúc: dogfood APK v0.4.0. Backup dữ liệu trước khi cài.

Xong thì tick các checkbox của Phase 10 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 11 — Ngân sách 🎨

**Nghiên cứu trước:** Ngữ nghĩa kỳ ngân sách: tháng theo lịch hay cuốn chiếu; carry-over; ranh giới múi giờ. **Quyết và ghi lại** — đây chính là chỗ trú của "bug ngày/tháng" mà Rolly dính.

**Bàn giao:** `lib/features/budgets/` — ngân sách theo danh mục theo tháng, **vòng tiến độ tự viết `CustomPainter`** (đầu nét bo tròn, gradient quét) · trạng thái tính bằng SQL aggregate, **không lưu bộ đếm** (D7).

🔥 **Ý tưởng ăn cắp từ Copilot Money — vạch nhịp:** tô màu vòng theo **nhịp độ**, không phải phần trăm tuyệt đối. Vẽ một vạch mảnh trên vòng ở vị trí `(ngày_trong_tháng / số_ngày_tháng)`. Ở 60% vào ngày 10 là tệ; ở 60% vào ngày 25 là tuyệt. Xanh khi đang trên đà không vượt, vàng khi trên đà sẽ vượt, đỏ khi đã vượt. **Gần như không app nào hiển thị điều này** — nó là thứ khiến ngân sách thực sự hữu ích thay vì chỉ là một thanh tiến độ.

**Xác minh:** test ranh giới tháng dưới `Clock` đóng băng, **bao gồm offset Asia/Ho_Chi_Minh và ranh giới năm** · golden vòng ngân sách ở 4 trạng thái (dưới nhịp / trên nhịp / cảnh báo / vượt), light + dark · **🚀 dogfood APK v0.5.0**.

**Checklist:**

- [ ] Quyết kỳ ngân sách (tháng lịch hay cuốn chiếu, carry-over, múi giờ) và ghi `docs/decisions.md`
- [ ] Ngân sách theo danh mục theo tháng
- [ ] **Vòng tiến độ tự viết `CustomPainter`** — đầu nét bo tròn, gradient quét
- [ ] 🔥 **Vạch nhịp**: vạch mảnh ở `(ngày_trong_tháng / số_ngày_tháng)`; xanh = trên đà an toàn, vàng = trên đà vượt, đỏ = đã vượt
- [ ] Trạng thái tính bằng SQL aggregate, **không lưu bộ đếm**
- [ ] Test ranh giới tháng dưới `Clock` đóng băng, có offset `Asia/Ho_Chi_Minh` và ranh giới năm
- [ ] Golden vòng ngân sách 4 trạng thái, light+dark
- [ ] 🚀 dogfood APK v0.5.0

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md — "Bối cảnh chung", mục "🎨 Design system", và "Phase 11".
Thực hiện Phase 11.

Làm ngân sách theo danh mục theo tháng với vòng tiến độ.

QUYẾT ĐỊNH TRƯỚC KHI CODE, ghi vào docs/decisions.md: kỳ ngân sách là tháng theo lịch hay
cuốn chiếu? Có carry-over phần dư sang tháng sau không? Ranh giới tháng theo múi giờ nào?
Đây chính xác là chỗ trú của loại "bug ngày/tháng" mà review Rolly than phiền. Mơ hồ ở đây
là bug về sau.

Ý TƯỞNG THIẾT KẾ ĐÁNG GIÁ NHẤT PHASE NÀY — vạch nhịp (ăn cắp từ Copilot Money):
Tô màu vòng theo NHỊP ĐỘ chứ không phải phần trăm tuyệt đối. Vẽ một vạch mảnh trên vòng ở vị trí
(ngày_trong_tháng / số_ngày_tháng). Ở 60% vào ngày 10 là tệ; ở 60% vào ngày 25 là tuyệt.
Xanh = đang trên đà không vượt, vàng = trên đà sẽ vượt, đỏ = đã vượt.
Gần như không app nào hiển thị điều này. Nó biến ngân sách từ một thanh tiến độ vô nghĩa thành
một thứ thực sự hữu ích. Tự viết CustomPainter (~40 dòng) — không package nào có vạch nhịp.

Trạng thái ngân sách tính bằng SQL aggregate, KHÔNG lưu bộ đếm. Cùng lý do với số dư ở D7:
không có cache thì không thể sai.

Test ranh giới tháng dưới Clock đóng băng, bao gồm offset Asia/Ho_Chi_Minh (+07) và ranh giới
chuyển năm. Không viết thì bug chỉ lộ ra vào đúng ngày 1 hàng tháng.

Kết thúc: dogfood APK v0.5.0.

Xong thì tick các checkbox của Phase 11 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 12 — AI fallback *(host trên tailnet; Worker để sau)*

**Nghiên cứu trước:** Model ID và giá Gemini **tại thời điểm làm** — kiểm chứng với docs sống của Google · structured output: JSON schema **phẳng**, dùng `enum` cho category để model không bịa danh mục · xác nhận điều khoản paid tier / không-train-trên-dữ-liệu (D8).

**Bàn giao:** service proxy nhỏ trên máy này, expose qua `tailscale serve --set-path /tonyfino-ai/` (**E1**: subpath, cạnh cấu hình đang có) · `lib/data/services/ai/tailnet_fallback.dart` implement `AiParseFallback`, **base URL cấu hình được trong Settings** · **sheet đồng ý một lần, mặc định TẮT** (D8) · timeout + xuống cấp êm thành "xác nhận thủ công".

**Xác minh:** unit test với HTTP client giả (thành công / timeout / JSON hỏng / category ngoài enum) · end-to-end: câu tiếng Việt mơ hồ giải quyết qua fallback · **test chế độ máy bay: app vẫn dùng được đầy đủ**.

**Checklist:**

- [ ] Proxy service trên máy này, expose `tailscale serve --set-path /tonyfino-ai/` (**không** `serve reset`)
- [ ] `tailnet_fallback.dart` implement `AiParseFallback`, **base URL cấu hình được trong Settings**
- [ ] Structured output: JSON schema **phẳng**, `enum` cho category
- [ ] Key **paid tier** (free tier train trên prompt của bạn)
- [ ] **Sheet đồng ý một lần, mặc định TẮT**
- [ ] Unit test HTTP client giả: thành công / timeout / JSON hỏng / category ngoài enum
- [ ] **Test chế độ máy bay: app vẫn dùng được đầy đủ**, fallback xuống cấp im lặng

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md — "Bối cảnh chung", "Phase 12", và quyết định D8.
Thực hiện Phase 12.

Cắm AI fallback thật vào interface AiParseFallback đã tạo ở Phase 8. Chỉ kích hoạt khi parser
offline trả amount == null hoặc confidence dưới ngưỡng — tức khoảng 10% số câu.

KIẾN TRÚC (lý do đầy đủ trong D8): proxy chạy TRÊN MÁY NÀY, expose qua
`tailscale serve --set-path /tonyfino-ai/`, KHÔNG dùng Cloudflare Worker. Lý do: điện thoại đã ở
trên tailnet, tailscale serve mặc định chỉ trong tailnet nên đã xác thực ở tầng mạng theo danh tính
thiết bị — APK không cần chứa credential nào cả. Worker thì là endpoint public giữ key tính tiền,
kéo theo quota, rate limit, trần chi tiêu, và tài khoản Cloudflare. Base URL cấu hình được trong
Settings nên đổi sang Worker sau này là cắm-vào-là-chạy.

⚠️ TUYỆT ĐỐI KHÔNG `tailscale serve reset`. Thêm /tonyfino-ai/ vào cạnh /tonyfino/ và 4 mục của
project "writing task 1". Kiểm tra `tailscale serve status` sau khi set.

QUYỀN RIÊNG TƯ — làm cả hai: (a) dùng key PAID TIER, vì free tier Gemini dùng prompt của bạn để
train, mà prompt ở đây là "Ăn trưa với sếp 250k" gắn với người thật. Ở mức fallback-của-fallback
chi phí chỉ vài xu/tháng. (b) Mặc định TẮT cloud fallback, có sheet đồng ý một lần hiện ra lần đầu
gặp câu mơ hồ.

NGHIÊN CỨU TRƯỚC: model ID và giá Gemini TẠI THỜI ĐIỂM LÀM, kiểm chứng với docs sống của Google.
Đừng tin model ID ghi trong tài liệu cũ. Structured output dùng JSON schema PHẲNG với enum cho
category để model không bịa được danh mục ngoài danh sách.

TEST BẮT BUỘC: bật chế độ máy bay, app phải vẫn dùng được đầy đủ, fallback xuống cấp im lặng thành
"xác nhận thủ công". Fallback không với tới được là chuyện bình thường, không phải lỗi.

Xong thì tick các checkbox của Phase 12 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 13 — Hardening *(cổng trước khi giao hàng)*

**Nghiên cứu trước:** Luật R8/ProGuard cho drift + native assets — lỗi kinh điển "chạy tốt ở debug, crash ở release" · thay đổi hành vi Android 15/16 với app target SDK 36.

**Bàn giao:** ma trận test emulator: **API 36** (chính) + **API 34** (`test34`, sanity) · **chạy chế độ release trên emulator** — không chỉ debug · pass accessibility, **pass cỡ chữ 1.3× và 2.0×** (chỗ dấu tiếng Việt dễ bị cắt nhất), pass trạng thái "chưa có dữ liệu / lần chạy đầu" · **health-check đích backup mỗi lần resume** (H6).

**Xác minh (cổng):** `flutter analyze` sạch · `flutter test` xanh toàn bộ · `integration_test/` xanh trên `tonyfino36` · **diễn tập: backup → gỡ cài → cài lại → restore, trên emulator với bản sao dữ liệu THẬT** · khởi động nguội < 2 s · **không giật khi cuộn 1000+ giao dịch** (đo bằng DevTools, đặc biệt chú ý `BackdropFilter` của nav bar mờ trên máy tầm trung).

**Checklist:**

- [ ] Luật R8/ProGuard cho drift + native assets
- [ ] **Chạy chế độ release trên emulator** (bug R8 chỉ xuất hiện ở release)
- [ ] Ma trận: `tonyfino36` (API 36, chính) + `test34` (API 34, sanity)
- [ ] **Cỡ chữ 1.3× và 2.0×** — chỗ dấu tiếng Việt dễ bị cắt nhất
- [ ] Pass accessibility + trạng thái lần chạy đầu chưa có dữ liệu
- [ ] Health-check đích backup mỗi lần resume, hỏng thì banner cố định
- [ ] **Diễn tập backup → gỡ cài → cài lại → restore với bản sao dữ liệu THẬT**
- [ ] Cuộn 1000+ giao dịch không giật (đo DevTools, chú ý `BackdropFilter`); khởi động nguội < 2s
- [ ] `flutter analyze` sạch, `flutter test` xanh toàn bộ, `integration_test/` xanh trên `tonyfino36`

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md, phần "Bối cảnh chung" và "Phase 13". Thực hiện Phase 13.

Đây là CỔNG trước khi giao APK cho Tony. Tony yêu cầu rõ: chạy giả lập test OK hết rồi mới gửi.

NGHIÊN CỨU TRƯỚC: luật R8/ProGuard cho drift + native assets. Lỗi kinh điển "chạy tốt ở debug,
crash ở release" — mà bản giao cho Tony là bản release.

BẮT BUỘC chạy CHẾ ĐỘ RELEASE trên emulator, không chỉ debug. Bug R8 về bản chất chỉ xuất hiện ở
release nên test debug không chứng minh được gì.

Ma trận test: emulator tonyfino36 (API 36, chính) + test34 (API 34, sanity pass).

DIỄN TẬP QUAN TRỌNG NHẤT — chạy thật ít nhất một lần:
backup → gỡ cài app → cài lại → restore, trên emulator với BẢN SAO DỮ LIỆU THẬT của Tony.
Đây là bài diễn tập khiến việc mất keystore từ thảm hoạ hạ xuống phiền phức. Vì allowBackup="false"
nên Google auto-backup và adb backup đều không cứu được — file backup trong app là đường phục hồi
duy nhất tồn tại.

Thêm health-check đích backup mỗi lần app resume: ghi file thăm dò, hỏng thì hiện banner cố định.
Grant SAF có thể chết âm thầm sau reboot, và backup hỏng âm thầm còn tệ hơn không có.

KIỂM TRA THỊ GIÁC: chạy ở cỡ chữ 1.3x VÀ 2.0x — đây là chỗ dấu tiếng Việt (ế ữ ỗ ặ) dễ bị cắt
nhất. Và đo hiệu năng cuộn 1000+ giao dịch bằng DevTools, đặc biệt chú ý BackdropFilter của nav bar
mờ (nó là một lượt render offscreen thật sự tốn GPU trên máy tầm trung như Redmi Note 13 Pro).

Các cổng còn lại: flutter analyze sạch · flutter test xanh toàn bộ · integration_test xanh trên
tonyfino36 · khởi động nguội dưới 2s · pass trạng thái lần chạy đầu chưa có dữ liệu.

Xong thì tick các checkbox của Phase 13 trong TODOS.md và báo lại ngắn gọn.
```

---

## Phase 14 — Phát hành v1.0.0 & giao hàng

**Bàn giao:** version → `1.0.0+<mã tiếp theo>` (D4) · `flutter build apk --release` → **universal APK** (D6) ký bằng **keystore release** (D3) · `adb install` **đúng file đó** lên `tonyfino36`, smoke test · copy vào `dist/`, serve `tailscale serve --bg --set-path /tonyfino/ /home/tony/Tony/TonyFino/dist/` · giữ `tonyfino-latest.apk` là **file thật, không phải symlink** · **điện thoại phải được đưa lên mạng** (E8).

**Xác minh:** `tailscale serve status` hiện `/tonyfino/` **và cả 4 mục cũ còn nguyên** · tải + cài trên điện thoại; **xác nhận nâng cấp đè lên v0.5.0 mà dữ liệu còn nguyên** · `docs/release-1.0.0.md` ghi git SHA, versionCode, SHA-256 của APK, fingerprint keystore.

**Checklist:**

- [ ] Phase 13 xanh hết — nếu còn mục đỏ thì quay lại, đừng giao
- [ ] Version `1.0.0+<mã tiếp theo>`
- [ ] `flutter build apk --release` **universal APK**, ký bằng `~/keystores/tonyfino-release.jks`
- [ ] `adb install` **đúng file đó** lên `tonyfino36` + smoke test
- [ ] `tailscale serve --bg --set-path /tonyfino/ dist/`, `serve status` xác nhận 4 mục cũ còn nguyên
- [ ] `tonyfino-latest.apk` là **file thật**, không phải symlink
- [ ] Cài lên `redmi-note-13-pro`, **xác nhận nâng cấp đè lên v0.5.0 mà dữ liệu còn nguyên**
- [ ] `docs/release-1.0.0.md`: git SHA, versionCode, SHA-256 APK, fingerprint keystore

**Prompt:**

```
Đọc /home/tony/Tony/TonyFino/TODOS.md, phần "Bối cảnh chung" và "Phase 14". Thực hiện Phase 14.

Phát hành v1.0.0 và giao APK cho Tony.

Điều kiện tiên quyết: Phase 13 phải xanh hết. Tony yêu cầu rõ "chạy giả lập test oke hết rồi mới
gửi". Nếu Phase 13 còn mục đỏ thì quay lại, đừng giao.

Build: `flutter build apk --release` KHÔNG --split-per-abi, ký bằng ~/keystores/tonyfino-release.jks.
Emulator là x86_64, điện thoại Redmi Note 13 Pro là arm64-v8a — universal APK bảo đảm file đã test
đúng là file đem cài.

Cài ĐÚNG FILE ĐÓ lên emulator tonyfino36 bằng adb install và smoke test trước khi serve.

Serve: copy vào /home/tony/Tony/TonyFino/dist/ rồi
`tailscale serve --bg --set-path /tonyfino/ /home/tony/Tony/TonyFino/dist/`
⚠️ TUYỆT ĐỐI KHÔNG `tailscale serve reset`. Đường "/" cùng /web/, /task1.apk, /task1-arm64.apk,
/task1-video.mp4 thuộc project "writing task 1" khác. Sau khi set chạy `tailscale serve status`
và xác nhận đủ 4 mục cũ còn nguyên.
Giữ thêm bản tonyfino-latest.apk là FILE THẬT chứ không phải symlink — path-serving có thể không
đi theo symlink.

URL cho Tony: https://tony.tailfcdcfc.ts.net/tonyfino/
Điện thoại redmi-note-13-pro cần được bật lên tailnet (lần cuối online cách đây 2 ngày) — nhắc Tony.

XÁC MINH CUỐI: cài lên điện thoại và xác nhận nó NÂNG CẤP ĐÈ lên v0.5.0 mà dữ liệu còn nguyên.
Đây là phần thưởng cho chuỗi checkpoint dogfood từ Phase 6.

Ghi docs/release-1.0.0.md: git SHA, versionCode, SHA-256 của APK, fingerprint keystore.

Xong thì tick các checkbox của Phase 14 trong TODOS.md và báo lại ngắn gọn.
```

---

## Backlog sau v1 *(xếp theo giá trị — chưa lên lịch)*

1. **Auto-backup** — `workmanager` hàng ngày + kiểm tra khi resume (D5)
2. **Nhiều ví, số dư đầu kỳ, chuyển khoản giữa ví** — mảng hoãn lớn nhất; luật số-dư-dẫn-xuất mở rộng sang đây không cần sửa gì
3. **Khoá vân tay** (`local_auth`) — Rolly tính phí
4. **Nhắc hoá đơn / giao dịch định kỳ** — `flutter_local_notifications` + `permission_handler`
5. **Tìm kiếm FTS5** trên cột bóng `note_ascii` (cột đã tạo từ Phase 4 nên không cần migration)
6. **Emoji tuỳ chọn cho mỗi danh mục** (ăn cắp từ Cashew) — cực rẻ, làm danh sách liếc là thấy, và cá nhân hoá là đòn bẩy "cao cấp" rẻ nhất
7. **Dynamic color (Material You)** opt-in qua `dynamic_color`, harmonize màu cố định
8. **AI insights + personalities** — thuần việc chỉnh prompt trên proxy Phase 12
9. **Widget màn hình chính**, mục tiêu tiết kiệm, vay/cho vay, OCR hoá đơn, nhập giọng nói
10. **Cloudflare Worker** làm đường AI ngoài tailnet (D8) — chỉ khi giới hạn tailnet thật sự gây khó
11. **Port iOS** — chủ yếu là `IosDocumentsDestination` + signing, *nếu* cổng lint ở Phase 3 được giữ vững

---

## File then chốt

Chưa file nào tồn tại — thư mục trống. Đây là những file mà quyết định thiết kế của nó chặn mọi thứ phía sau, theo thứ tự tạo:

- `/home/tony/Tony/TonyFino/TODOS.md` — chính file này, mỏ neo ngữ cảnh cho mọi session sau
- `/home/tony/Tony/TonyFino/pubspec.yaml` — bộ dep v1 đã cắt (D5) + `hooks.user_defines` cho sqlite3mc + khai báo `fonts:`; spike H4 sống chết ở đây
- `/home/tony/Tony/TonyFino/android/app/build.gradle.kts` — `applicationId dev.tony.tonyfino` (bất biến, D1), `targetSdk 36`, suffix `.dev` cho debug, release signing fail-lớn khi thiếu `key.properties` (D3)
- `/home/tony/Tony/TonyFino/lib/theme/app_theme.dart` — file **duy nhất** dựng `ThemeData`, qua một hàm `_build(Brightness)`; hai theme viết tay riêng sẽ lệch nhau
- `/home/tony/Tony/TonyFino/lib/theme/tokens/palette.dart` — hex Radix thô, **không import `material.dart`** (D9/luật 10)
- `/home/tony/Tony/TonyFino/lib/data/db/database.dart` — schema drift; **không-lưu-số-dư** (D7) + **`categoryColorId` không lưu hex** (D10)
- `/home/tony/Tony/TonyFino/lib/features/quick_add/domain/parser/amount_evaluator.dart` — parser số tiền tiếng Việt đệ quy (`2tr5`, `rưỡi`, biến thể số đếm); logic rủi ro cao nhất app
- `/home/tony/Tony/TonyFino/test/fixtures/parser/corpus.jsonl` — corpus 300+ ca; test ROI cao nhất codebase
- `/home/tony/Tony/TonyFino/docs/rolly-schema.md` — sản phẩm Phase 2; **importer không được viết trước khi file này tồn tại**

---

## Xác minh tổng thể

Coi như xong khi tất cả những điều sau đúng cùng lúc:

1. `flutter analyze` sạch, `flutter test` xanh toàn bộ trên host, `integration_test/` xanh trên `tonyfino36`
2. `grep -rE "dart:io|Platform\.|DateTime\.now\(\)" lib/features/` không ra kết quả *(cổng port-iOS)*
3. `grep -r "material.dart" lib/theme/tokens/` không ra kết quả *(cổng migration `material_ui`)*
4. Corpus parser 300+ ca xanh dưới `Clock` đóng băng
5. Test bất biến số dư xanh sau 1000 thao tác ngẫu nhiên
6. Migration test v(N−1)→vN xanh, `drift_schemas/` đã commit
7. **Golden text style xanh ở light + dark, 1.0× và 1.3×, không cắt dấu ở `Đồng Nai — ế ữ ỗ ặ ỡ Ế Ữ Ỗ · 1.234.567 ₫`**
8. Báo cáo đối chiếu sau import khớp **chính xác** oracle Phase 2
9. Diễn tập backup → gỡ cài → cài lại → restore thành công với bản sao dữ liệu thật
10. Chế độ máy bay: app dùng được đầy đủ
11. Cuộn 1000+ giao dịch không giật; khởi động nguội < 2 s
12. APK release cài lên `redmi-note-13-pro` từ `https://tony.tailfcdcfc.ts.net/tonyfino/`, **nâng cấp đè lên bản trước mà dữ liệu còn nguyên**
13. `tailscale serve status` hiện `/tonyfino/` **và cả 4 mục của project "writing task 1" còn nguyên vẹn**
