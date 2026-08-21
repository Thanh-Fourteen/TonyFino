# Lấy dữ liệu ra khỏi Rolly — runbook Firefox

Máy này chỉ có Firefox (không có Chrome), nên mọi bước dưới đây viết cho Firefox DevTools.

## Rolly được xây bằng gì — và vì sao điều đó có lợi cho ta

Dò `main.dart.js` (10 MB) của `app.rollyapp.ai` cho thấy:

| | |
|---|---|
| Web app | **Flutter Web** — render bằng canvas, nên **không soi được DOM**. Nhưng request mạng vẫn hiện đủ trong tab Network |
| Backend | **Supabase** — `https://ilcayaumqidkbjpecfhq.supabase.co` |
| API | **PostgREST** (chuẩn Supabase). Đã thấy tham số `limit`, `offset`, `gte.`, `lte.`, `apikey`, `Prefer` trong bundle |
| Bảng đã lộ tên | `transactions`, `wallets`, `categories`, `budgets`, `budget_category_links`, `budget_wallet_links`, `recurring_transactions`, `lend_borrow`, `debt`, `categorisation_rule`, `profile` |
| Khác | Có nhúng **Meta Pixel** ngay trang đăng nhập, và `api.prod.finverse.net` (dịch vụ tổng hợp dữ liệu ngân hàng) |

**Vì sao đây là tin tốt:** PostgREST cho phép đặt `limit` tuỳ ý. Nghĩa là **không cần cuộn hết lịch sử để ép app tải từng trang** — chỉ cần bắt được **một** request có token, ta lấy sạch mọi bảng bằng một lệnh. Đây là lý do runbook này ưu tiên "Copy as cURL" hơn "Save All As HAR".

---

## Đường 1 — Copy as cURL *(ưu tiên, nhanh nhất)*

### B1. Đăng nhập
Mở Firefox → `https://app.rollyapp.ai` → đăng nhập bằng đúng tài khoản đang dùng trên điện thoại.

### B2. Mở Network trước khi bấm gì thêm
`F12` (hoặc `Ctrl+Shift+E`) → tab **Network** (Mạng).

Bật hai thứ trên thanh công cụ của tab:
- **Persist Logs** / *Lưu nhật ký* — để log không bị xoá khi app đổi màn hình
- Ô lọc **XHR**

### B3. Ép app gọi API
Bấm sang màn **danh sách giao dịch** (Transactions / Giao dịch). Cuộn xuống vài lần cho chắc.

Trong Network sẽ thấy các dòng tới `ilcayaumqidkbjpecfhq.supabase.co`. Gõ `supabase` vào ô lọc để chỉ còn chúng.

### B4. Copy as cURL
Chuột phải một request bất kỳ tới `ilcayaumqidkbjpecfhq.supabase.co` → **Copy** → **Copy as cURL**.

> Không cần chọn đúng request "transactions". Bất kỳ request nào tới host đó cũng chứa `apikey` và `Authorization: Bearer …` — đó là tất cả những gì cần.

### B5. Dán vào file, **đừng dán vào khung chat**
```bash
# Dán rồi lưu lại:
gedit ~/Tony/TonyFino/raw_rolly/rolly-curl.txt
# hoặc:  nano ~/Tony/TonyFino/raw_rolly/rolly-curl.txt
```
`raw_rolly/` đã gitignore nên không bao giờ vào git.

**Vì sao dán file chứ không dán chat:** lệnh cURL chứa JWT phiên đăng nhập của bạn. Dán vào chat là nó nằm vĩnh viễn trong transcript. Để trong file thì đọc xong xoá là hết. Token Supabase mặc định hết hạn sau **1 giờ**, nên làm liền các bước sau.

### B6. Báo "đã lưu curl"
Claude đọc file, rút `apikey` + JWT, rồi kéo **toàn bộ** các bảng về `raw_rolly/*.json`.

---

## Đường 2 — HAR *(dự phòng, nếu Copy as cURL không ra)*

1. Làm B1–B3 như trên.
2. Cuộn **hết** lịch sử giao dịch, tháng cũ nhất tới tháng mới nhất, để mọi trang phân trang đều được gọi.
3. Chuột phải vào bất kỳ dòng nào trong Network → **Save All As HAR**.
4. Lưu vào `~/Tony/TonyFino/raw_rolly/rolly-2026-08-21.har`.

HAR bắt được **mọi** response đã tải kèm URL gốc, nên tái dựng được cấu trúc phân trang. Nhược: chỉ có những gì UI đã tải — cuộn thiếu là mất dữ liệu.

> ⚠️ HAR cũng chứa token. Vẫn để trong `raw_rolly/`, đừng gửi cho ai.

---

## Số đối chiếu — làm trước khi rời Rolly

Đây là **oracle nghiệm thu** cho importer ở Phase 9. Không có nó thì không có cách nào biết bộ import đúng hay sai.

Mở Rolly (app điện thoại hoặc web), vào màn báo cáo/thống kê, ghi lại vào `docs/rolly-schema.md`:

- **Tổng số giao dịch** (nếu UI có hiện)
- **Tổng chi và tổng thu của TỪNG THÁNG** đang có dữ liệu
- **Số dư hiện tại của từng ví**

Chụp màn hình luôn cũng được — miễn là con số đọc ra từ **chính UI Rolly**, không phải từ file JSON ta vừa kéo. Cả hai nguồn khớp nhau mới là bằng chứng.

---

## Ảnh chụp màn hình

Lưu vào `docs/rolly-screens/`. Cần 4 màn: **danh sách giao dịch**, **báo cáo/biểu đồ**, **màn chat AI**, **ngân sách**.

Mục đích là đối chiếu thiết kế — TonyFino phải đẹp hơn hẳn, mà muốn đánh giá "hơn" thì phải có bản gốc để so.

---

## Thang dự phòng

| Bậc | Cách | Tình trạng |
|---|---|---|
| **1** | Web app + Copy as cURL / HAR | ⬅️ đang ở đây |
| 2 | Nút share/report trong app mobile không bị paywall (kể cả PDF từng tháng) → parse | chưa thử |
| 3 | `adb backup` / pull app data | **gần như chắc hỏng** — Android 12+ chặn trừ khi app khai `android:debuggable`, mà app Play Store không bao giờ khai |
| 4 | Dựng lại thủ công: chỉ nhập số dư đầu kỳ, sổ mới bắt đầu từ hôm nay, giữ Rolly làm kho lưu trữ chỉ-đọc | phương án cuối |

**Cổng quyết định:** bậc 1–3 hỏng hết ⇒ v1 ship **không có** import, dời sang Phase 15. Ngày giao hàng không trượt vì việc này.

---

## Dọn dẹp sau khi xong

Token trong `raw_rolly/rolly-curl.txt` và file `.har` sẽ hết hạn sau ~1 giờ, nhưng cứ xoá cho sạch:

```bash
shred -u ~/Tony/TonyFino/raw_rolly/rolly-curl.txt
```

Các file `*.json` dữ liệu giao dịch thì **giữ lại** — Phase 9 cần chúng. Chúng không chứa token.
