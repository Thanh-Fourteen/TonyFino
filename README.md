# TonyFino

App quản lý chi tiêu cá nhân. Flutter, Android trước, iOS sau. Bản thay thế miễn phí cho **Rolly** — dữ liệu nằm hoàn toàn trên máy, không tài khoản, không server, không chi phí định kỳ.

Nhập chi tiêu bằng tiếng Việt tự nhiên (`cà phê 35k`, `ăn trưa bún bò 85k hôm qua`, `2tr5`), parser chạy offline nên tức thì và không gửi gì lên mạng.

## Trạng thái

**Phase 1/14 xong** — môi trường, repo, keystore, font. Chưa có code app.
Lộ trình đầy đủ: [`TODOS.md`](TODOS.md). Quyết định và lý do: [`docs/decisions.md`](docs/decisions.md).

## Bắt đầu

```bash
source tool/env.sh      # ANDROID_HOME, JAVA_HOME, PATH (không đụng ~/.bashrc)
tool/emulator.sh        # boot AVD tonyfino36 (API 36), headless
tool/clean.sh           # dọn SSD khi chật (mặc định chạy thử, --yes để xoá thật)
```

## Vài điều dễ vấp

| | |
|---|---|
| **`applicationId`** | `dev.tony.tonyfino` — **bất biến**. Đổi = app khác = mất toàn bộ dữ liệu người dùng |
| **Keystore** | `~/keystores/tonyfino-release.jks`. Mất nó là **không bao giờ cập nhật được app nữa**. 3 bản sao, xem `docs/decisions.md` § D3 |
| **Đĩa** | `/` là SSD; `/mnt/data1tb` là **HDD 5400rpm**. Chỉ để kho lạnh trên HDD. Đừng dời `.gradle`/`.pub-cache`/`avd`/`build` sang đó |
| **`tailscale serve`** | Đường `/` thuộc project khác. Dùng `/tonyfino/`. **Không bao giờ** chạy `tailscale serve reset` |
| **Font** | Bundle cục bộ trong `assets/fonts/`. **Không** dùng `google_fonts` (tải HTTP lúc chạy). **Không** dùng DM Sans hay Figtree — cả hai thiếu bộ tiếng Việt |
| **Emulator** | Máy không có GPU dùng được → `-gpu swiftshader_indirect`. Golden test có thể chỉ bảo đảm layout, không bảo đảm pixel |

## Giấy phép

Dự án cá nhân, chưa cấp phép. Font trong `assets/fonts/` theo **SIL OFL 1.1** (kèm bản gốc `OFL-*.txt`).
