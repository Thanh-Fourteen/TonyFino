# TonyFino v1.0.1 — hồ sơ phát hành

Bản phát hành đầu tiên đầy đủ, kết thúc chuỗi 26 phase. Tệp này là bản ghi
**bất biến** của đúng file APK đã giao cho Tony — mọi con số dưới đây đều đọc
được lại từ chính file đó, không phải chép tay.

## Danh tính bản dựng

| | |
|---|---|
| Phiên bản | `1.0.1+42` |
| versionName | `1.0.1` |
| versionCode | `42` |
| Git SHA | `2eee52ca` (`2eee52ca90d2d4f225033a1c732fef64dc89e42e`) |
| Thời điểm build | `2026-08-24T02:33:33Z` |
| Toolchain | Flutter 3.44.1 • channel stable • https://github.com/flutter/flutter.git |
| minSdk / targetSdk | 24 / 36 |

## APK

| | |
|---|---|
| Tên file | `tonyfino-1.0.1+42.apk` |
| Kích thước | 110M |
| SHA-256 | `4bb9aec97229bef5c1969129a5feaf95a906340ae237036517f40ce359b5ed0e` |
| ABI | `arm64-v8a`, `armeabi-v7a`, `x86_64` (**universal**, KHÔNG split-per-abi — D6) |

```sh
sha256sum tonyfino-1.0.1+42.apk
# 4bb9aec97229bef5c1969129a5feaf95a906340ae237036517f40ce359b5ed0e
```

**Vì sao universal:** emulator `tonyfino36` là x86_64 còn Redmi Note 13 Pro
là arm64-v8a. Split-per-abi nghĩa là file đã test kỹ KHÔNG phải file đem cài —
một class lỗi không thể bắt được bằng test.

## Keystore (D3)

| | |
|---|---|
| File | `~/keystores/tonyfino-release.jks` |
| Alias | `` |
| Chủ thể | CN=TonyFino, OU=Personal, O=TonyFino, L=Ho Chi Minh City, ST=Ho Chi Minh, C=VN |
| Hiệu lực | 21/08/2026 → 06/01/2054 |
| SHA-256 | `A7:98:A2:9D:62:67:C1:C3:F6:3B:77:4B:79:04:56:28:F9:7F:67:93:B7:3D:E5:F4:32:8B:1D:89:00:E4:32:4A` |
| SHA-1 | `B3:4D:94:09:70:E8:75:17:B6:0D:F8:20:B4:78:C0:4B:E5:CB:5F:95` |

🚨 Mọi bản cập nhật sau này PHẢI ký bằng đúng keystore này. Ký bằng khoá khác
thì Android từ chối nâng cấp đè, và đường duy nhất còn lại là gỡ cài — tức là
xoá sạch dữ liệu của Tony.

## Phân phối

- URL: <https://tony.tailfcdcfc.ts.net/tonyfino/>
- File mới nhất: `tonyfino-latest.apk` — **file thật, không phải symlink**
  (path-serving của tailscale có thể không đi theo symlink).
- Chỉ trong tailnet, không công khai ra Internet.

## Đã xác minh trước khi giao

Cổng Phase 24 chạy LẠI toàn bộ trên chính bản dựng này (không dựa vào lần tick trước):

- `flutter analyze` sạch (0 lỗi, 0 cảnh báo) · `flutter test` **979/979 xanh** ·
  `tool/check_arch.sh` PASS
- `integration_test/` xanh trên `tonyfino36`: sqlite3mc trên thiết bị thật,
  hiệu năng cuộn hero + thanh nav
- Ma trận thiết bị: `tonyfino36` (API 36) + `test34` (API 34)
- Khởi động nguội **1.64–1.89s** (< 2s) đo bằng `am start -W`, trên SwiftShader
- Cỡ chữ hệ thống **1.3× và 2.0×** — bắt được và sửa 2 lỗi thật: số thống kê
  gãy dòng ở trang chủ, và nhãn tab "Hạn mức" bị cắt cụt thành "Hạn mứ"
- **Diễn tập backup → gỡ cài → cài lại → khôi phục** với dữ liệu THẬT của Tony
  (358 giao dịch · 39 danh mục · 351 từ khoá · 1 quỹ · **6 hũ**) — lần đầu tiên
  bảng Hũ sống sót, nhờ bản vá bỏ sót bảng này khỏi backup
- Health-check đích backup: banner đỏ tắt, file thăm dò ghi/đọc lại được
- Smoke test bản 1.0.0+41 **đúng file đem giao**: bốn tab, ghi nhanh "cafe 25k"
  → xếp đúng "Ăn uống › Tiêu vặt", xoá lại sạch

## Sửa trong 1.0.1 — tất cả đều do một tấm ảnh hoá đơn THẬT phơi ra

Tony gửi ảnh hoá đơn Emart Sala Thủ Thiêm (12 mặt hàng, tổng 414.000đ) để
đóng ô cuối của Phase 18. Chạy thử trên chính hoá đơn đó lộ ra **bốn** lỗi
mà không lỗi nào bị bắt bởi 979 test trước đó:

1. **Bộ trích xuất nhặt MÃ VẠCH làm số tiền.** Không có nhãn "tổng" nào
   khớp (Emart in "Tổng số" — chưa có trong danh sách), nên nó rơi xuống
   nhánh "lấy số lớn nhất", và trên hoá đơn siêu thị số lớn nhất LUÔN là mã
   vạch EAN-13. App đề nghị **8.936.136.116.143đ**. Đã chặn số ≥10 chữ số
   không có dấu phân cách, và nhánh dự phòng giờ chỉ xét số CÓ dấu phân cách.
2. **Thiếu nhãn "Tổng số".** Đã thêm.
3. **🚨 OCR CHẾT HẲN Ở BẢN RELEASE.** ML Kit ném `NullPointerException`
   trong code đã bị R8 đổi tên; người dùng chỉ thấy form mở ra TRỐNG. Luật
   ProGuard cũ chỉ `-dontwarn` 4 script không dùng, không GIỮ lớp nào. Xác
   định thủ phạm bằng thí nghiệm đối chứng: cùng ảnh đó chạy đúng trên bản
   debug (không R8). Đã thêm `-keep` cho `com.google.mlkit.**` và
   `com.google.android.gms.internal.mlkit_**`.
4. **Hoá đơn quét được bị xếp thành khoản THU.** `extractReceiptInfo` trả về
   ĐỘ LỚN (dương), mà form suy chiều tiền từ dấu của số điền sẵn nên
   `isExpenseHint: true` bị bỏ qua. Giờ chỉ giao dịch ĐANG SỬA mới suy từ dấu.

Kết quả trên bản release, chính ảnh của Tony: **Chi · 414.000đ · ghi chú
"emart"**, không lỗi ML Kit nào trong logcat.

Cộng thêm 2 lỗi bố cục Tony chụp màn hình chỉ ra: số trong thẻ hero tab Giao
dịch dính sát nhau (hạ cỡ chữ + thêm khe), và ghost số tiền ở thanh nhập đè
lên chữ đang gõ (chuyển từ lớp `Stack` sang `suffix` chiếm chỗ thật).

## Chưa xong

- Cài lên **redmi-note-13-pro** và xác nhận nâng cấp đè lên v0.17.0 mà dữ liệu
  còn nguyên — máy cần được bật lên tailnet trước (lần cuối online: 2 ngày trước).
  Đây là mục cuối của Phase 26, chỉ Tony mới làm được.
- Phase 18 còn 1/6: thử OCR trên ảnh hoá đơn tiếng Việt THẬT (cần Tony gửi ảnh).
