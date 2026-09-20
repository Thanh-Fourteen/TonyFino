# TonyFino — Nhật ký quyết định

Ghi lại **quyết định và lý do**, để sau này không ai lật lại một lựa chọn vì đã quên vì sao nó được chọn. Đặc tả đầy đủ nằm trong [`TODOS.md`](../TODOS.md); file này là lịch sử.

---

## D1 — Tên & applicationId
**Chốt:** tên hiển thị `TonyFino`; `applicationId = dev.tony.tonyfino`; bản debug thêm `applicationIdSuffix ".dev"` và label `TonyFino (dev)`.

**Vì sao:** `applicationId` **bất biến trọn đời app** — đổi sau là Android coi như app khác, cài song song, dữ liệu cũ mắc kẹt. `dev.*` là quy ước cho app cá nhân không sở hữu tên miền; chiếm chỗ `com.*` trên một cái tên mình không kiểm soát thì tệ hơn.

Suffix `.dev` **không phải chuyện thẩm mỹ**: nó khiến bản trên emulator và bản thật là hai package Android riêng, hai thư mục dữ liệu riêng. Nghĩa là không đời nào một bản debug xoá nhầm lịch sử tài chính thật, và cài được cả hai trên cùng máy.

---

## D2 — `git init` ngay từ đầu
**Chốt:** khởi tạo git ở Phase 1. Identity cấp repo: `Tony <thanhfourteen@gmail.com>` (khớp git global đang dùng).

**Vì sao:** ba thứ trong dự án này bắt buộc phải có lịch sử — `drift_schemas/*.json` (không vào git thì migration test vô nghĩa), corpus parser 300+ ca (sẽ tinh chỉnh hàng tháng, cần blame), và file `*.g.dart` sinh tự động (cần diff sạch để phát hiện codegen trôi khi nâng version package).

`.gitignore` chặn `raw_rolly/` (dữ liệu tài chính thật), `dist/`, `*.jks`, `key.properties`. **Cố ý không chặn** `drift_schemas/`, `test/fixtures/`, `*.g.dart`, `assets/fonts/`.

---

## D3 — Keystore phát hành riêng, không dùng debug keystore
**Chốt:** `~/keystores/tonyfino-release.jks`, RSA 4096, PKCS12, hiệu lực 10000 ngày. Mật khẩu ngẫu nhiên 40 ký tự. Gradle **fail lớn** nếu thiếu `android/key.properties`.

**Đây là quyết định rủi ro cao nhất tài liệu này.** Trên Android, APK ký bằng key khác với bản đang cài thì buộc phải gỡ cài trước — mà gỡ cài là **xoá sạch dữ liệu**. Với app giữ bản sao duy nhất lịch sử tài chính, đổi key ký là một sự kiện mất dữ liệu.

**Vì sao không dùng debug keystore:** `~/.android/debug.keystore` tự sinh lại nếu bị xoá. Xoá `~/.android` một lần — cài lại máy, dọn SDK, đổi máy — là mọi bản build sau đó thành uninstall-only. Hỏng âm thầm, phát hiện muộn, thảm hoạ. Tệ hơn: **template Gradle của Flutter lặng lẽ rơi về `signingConfigs.debug` khi thiếu `key.properties`**, nên "build được" không cho bạn tín hiệu nào rằng đang đi đường mong manh. Phải chặn tường minh ở Phase 3.

**Sao lưu — đã tạo và xác minh fingerprint từ chính vị trí sao lưu (2026-08-21):**

| # | Vị trí | Trạng thái |
|---|---|---|
| 1 | `~/keystores/tonyfino-release.jks` (SSD) | ✅ đã xác minh |
| 2 | `/mnt/data1tb/backups/tonyfino/` (ổ vật lý khác) | ✅ đã xác minh |
| 3 | `~/keystores/tonyfino-keystore-backup-2026-08-21.tar.gz.gpg` (AES256) | ✅ giải mã ra và xác minh |

SHA256: `A7:98:A2:9D:62:67:C1:C3:F6:3B:77:4B:79:04:56:28:F9:7F:67:93:B7:3D:E5:F4:32:8B:1D:89:00:E4:32:4A`

> ⚠️ **Bản 3 hiện vẫn nằm trên chính máy này** nên chưa thật sự là nơi thứ ba. Tony cần chép nó ra ngoài (điện thoại / cloud / USB) và lưu mật khẩu vào trình quản lý mật khẩu. Chưa làm thì thực chất mới có **hai** bản sao trên hai đĩa cùng một máy.

**Giảm nhẹ thật sự là ở kiến trúc, không phải ở quy trình:** vòng export → xoá → import phải được **test** từ Phase 4, không phải Phase 13. Restore chạy được thì mất keystore hạ từ "thảm hoạ" xuống "phiền phức". Càng quan trọng vì `allowBackup="false"` (bắt buộc, do lỗi `InvalidKeyException` của `flutter_secure_storage`) khiến Google auto-backup và `adb backup` đều không cứu được — **file backup trong app là đường phục hồi duy nhất tồn tại**.

---

## D4 — Đánh version
`versionCode` là số nguyên tăng đơn điệu, tăng tay mỗi lần cài lên máy thật. `versionName` semver theo phase, `1.0.0` ở bản giao đầu. Mọi build nhúng `--dart-define=GIT_SHA=…`, hiện ở Settings → About.

**Vì sao:** tự deploy không qua store thì "APK nào đang nằm trên máy?" thành câu hỏi thật chỉ sau hai tuần. Không dùng versionCode theo ngày (`20260821`) — một khi đã dùng là mắc kẹt với số 8 chữ số vĩnh viễn; không dùng `git rev-list --count` — hỏng nếu lịch sử bị viết lại. `schemaVersion` của drift **độc lập**, không gắn với version app.

---

## D5 — Cắt 4 package khỏi v1
Bỏ `workmanager`, `flutter_local_notifications`, `permission_handler`, `local_auth` khỏi phạm vi v1.

**Vì sao:** cả bốn phục vụ tính năng đã hoãn (nhắc hoá đơn, khoá vân tay). Mỗi cái là một plugin 0.x nằm chắn đường tới APK đầu tiên. Auto-backup v1 dùng **kiểm tra khi app resume** — vốn đã là đường chính đáng tin, `workmanager` chỉ là đai an toàn thêm (OEM Android và iOS BGTaskScheduler đều giết định kỳ tuỳ hứng).

---

## D6 — Universal APK, không `--split-per-abi`
**Vì sao:** emulator là `x86_64`, Redmi Note 13 Pro là `arm64-v8a`. Split nghĩa là **file đã test kỹ không phải file đem cài**. Quan trọng gấp bội ở dự án này vì sqlite3mc **biên dịch từ nguồn C theo từng ABI** qua Dart build hooks. Đổi lại ~8 MB — không đáng bận tâm khi sideload.

---

## D7 — Số dư là giá trị dẫn xuất, không bao giờ lưu
Không có cột `balance` ở bất cứ đâu. Balance = `SUM(amount_minor)` phát qua drift `Stream`.

**Vì sao:** than phiền số 1 về Rolly, áp đảo, là **số dư sai và không cập nhật sau khi thêm giao dịch**. Đó không phải một bug cần cẩn thận — đó là một quyết định schema. Không có cache thì không thể sai. Kèm theo: mọi write trả `Result<T, AppError>`, zero fire-and-forget, lỗi hiện blocking dialog và ghi vào bảng `app_events`.

---

## D8 — AI proxy host trên tailnet, không dùng Cloudflare Worker
**Vì sao:** Worker là endpoint public giữ key tính tiền ⇒ kéo theo rủi ro lạm dụng, phải tự viết quota/rate-limit, phải đặt trần chi tiêu, phải có tài khoản Cloudflare + `wrangler login` (cần browser — máy chỉ có Firefox). Trong khi đó **điện thoại đã ở trên tailnet**, `tailscale serve` mặc định chỉ trong tailnet ⇒ đã xác thực ở tầng mạng theo danh tính thiết bị, **APK không chứa credential nào**. Base URL cấu hình được trong Settings nên đổi sang Worker sau này là cắm-vào-là-chạy.

**Quyền riêng tư:** free tier Gemini **dùng prompt để train**, mà prompt ở đây là `"Ăn trưa với sếp 250k"` gắn với người thật. Nên: dùng key **paid tier** (ở mức fallback-của-fallback chỉ vài xu/tháng) **và** mặc định TẮT cloud fallback.

---

## D9 — Không fork, không mua template
**Vì sao:** đã rà toàn bộ GitHub. App Flutter finance **đẹp** thì đều copyleft — Cashew GPL-3.0 (4.5k★, và bundle cả font Avenir có bản quyền thương mại), Monekin AGPL-3.0, BeeCount Business Source. App **license dùng được** thì đều nhìn tầm thường — sossoldi MIT, totals MIT, waterfly-iii MIT. Không có cái nào vừa đẹp vừa dùng được.

Template CodeCanyon $7–29 là code Flutter-3.0-era `setState`/GetX với màu hardcode rải khắp widget; gắn vào Riverpod 3 + drift + `ThemeExtension` tốn công hơn viết mới, chưa kể không template nào nghĩ tới tiếng Việt. ~15 widget riêng ≈ 2–3 ngày, và đó chính là chỗ tạo khác biệt.

---

## D10 — Lưu `categoryColorId INTEGER`, không lưu chuỗi hex
**Vì sao:** đây là sai lầm **không thể đảo ngược** phổ biến nhất trong app quản lý chi tiêu. Lưu hex thì dark mode sai, không đổi được cả bảng màu trong một file, không thêm được theme AMOLED hay tương phản cao sau này. Lưu ID rồi resolve qua `ThemeExtension` thì tất cả những cái đó thành miễn phí.

---

# Quyết định phát sinh trong lúc thực hiện

## 2026-08-21 · Phase 1 · Keystore dùng PKCS12 thay vì JKS
`keytool` cảnh báo JKS là định dạng độc quyền và khuyến nghị PKCS12. Đã chuyển. **Fingerprint SHA256 giữ nguyên** — cùng một khoá, chỉ đổi vỏ chứa. Gradle đọc PKCS12 y hệt; giữ đuôi `.jks` để đường dẫn trong tài liệu không đổi.

## 2026-08-21 · Phase 1 · Chia đĩa SSD/HDD thay vì dời tất
Máy có SSD Kingston 109 GB (còn 25 GB) và HDD Apple 5400rpm 916 GB (còn 503 GB). Ý định ban đầu là "dời cache sang ổ 1TB cho rộng", nhưng `cat /sys/block/sdb/queue/rotational` = `1` — nó là **đĩa quay**, không phải SSD.

Nên chỉ dời **kho lạnh**: `~/Android/Sdk/system-images` (4,2 GB, chỉ đọc tuần tự lúc emulator boot) → `/mnt/data1tb/android-dev/system-images`, symlink lại. `~/.gradle`, `~/.pub-cache`, `~/.android/avd`, `build/` **ở lại SSD** vì chúng là IO ngẫu nhiên nặng.

Kết quả: SSD 25 GB → **29 GB trống**, và image API 36 (~2 GB) tải về cũng rơi thẳng sang HDD.

## 2026-08-21 · Phase 1 · Xác minh font bằng dữ liệu, không bằng niềm tin
Research cảnh báo `DM Sans` và `Figtree` không có bộ tiếng Việt, và để ngỏ câu hỏi Be Vietnam Pro có `tnum` hay không. Đã kiểm bằng `fontTools` trên chính file đã tải:

| Font | 134 ký tự có dấu | `₫ — ·` | `tnum` | Trục biến thiên |
|---|---|---|---|---|
| BeVietnamPro-Regular/Medium/SemiBold/Bold | ✅ 134/134 | ✅ | — | (tĩnh) |
| Inter-Variable | ✅ 134/134 | ✅ | **✅** | `opsz 14–32`, `wght 100–900` |

Xác nhận cặp font đã chọn là đúng: **Be Vietnam Pro không có `tnum`** — đúng như nghi ngờ — nên Inter gánh toàn bộ chữ số, và Inter thì có đủ cả `tnum` lẫn tiếng Việt. Ảnh render thử ở mọi cỡ không cho thấy tofu hay cắt dấu.

## 2026-08-21 · Phase 1 · `clang`/`ninja` chưa cài — chưa gỡ được
`sudo` trên máy này cần mật khẩu nên không chạy `apt install` tự động được. **Đây là blocker cứng cho Phase 3** (Dart build hooks gọi `clang`, không phải `gcc`; thiếu là `flutter test` biên dịch sqlite3mc cho `linux-x64` sẽ hỏng). Tony phải tự chạy:

```bash
sudo apt install -y clang ninja-build
```

Phương án lùi nếu không muốn cài: NDK có sẵn clang tại `~/Android/Sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/clang`, và `ninja` có tại `~/Android/Sdk/cmake/3.22.1/bin/ninja`. Cả hai có thể đưa vào `PATH` qua `tool/env.sh`. **Chưa kiểm chứng** clang của NDK build được host `linux-x64` hay không — nếu Tony chọn đường này, phải thử ngay trong spike F1 ở Phase 3 trước khi tin.

## 2026-08-21 · Phase 1 · Template Flutter 3.44.1 đã mặc định đúng — không cần ghi đè

Phần "nghiên cứu trước" của Phase 1 hoá ra là tin tốt. Đọc thẳng
`packages/flutter_tools/lib/src/android/gradle_utils.dart` trong SDK cục bộ:

| Hằng số | Giá trị mặc định | Plan cần | Khớp? |
|---|---|---|---|
| `compileSdkVersionInt` | **36** | 36 | ✅ |
| `targetSdkVersion` | **36** | 36 | ✅ |
| `minSdkVersionInt` | **24** | 24 | ✅ |
| `ndkVersion` | **28.2.13676358** | (đã cài sẵn) | ✅ |
| `templateDefaultGradleVersion` | **9.1.0** | (đã cache sẵn) | ✅ |
| `templateAndroidGradlePluginVersion` | 9.0.1 | — | — |
| `templateKotlinGradlePluginVersion` | 2.3.20 | — | — |

Nghĩa là ở Phase 3, `flutter create` phát ra **đúng** `compileSdk 36` / `targetSdk 36` /
`minSdk 24` mà không phải sửa gì. Hạn chót Play "target API 36 từ 2026-08-31" coi như
đã thoả sẵn. NDK 28.2.13676358 đã có trên máy và Gradle 9.1.0 đã nằm trong
`~/.gradle/wrapper/dists` — Phase 3 sẽ không phải tải Gradle.

Phase 3 vẫn phải tự tay thêm: `applicationId`, `applicationIdSuffix ".dev"`,
release signing đọc `key.properties` và fail lớn khi thiếu, `allowBackup="false"`,
`dataExtractionRules`, và khai báo `fonts:`.

## 2026-08-21 · Phase 1 · clang/ninja đã cài — blocker E3 gỡ xong
Tony tự chạy `sudo apt install -y clang ninja-build`. Kết quả: **clang 18.1.3**, **ninja 1.11.1**.

Đã smoke-test đúng đường mà Dart build hook sẽ đi, chứ không chỉ nhìn `--version`:
biên dịch một file C thành shared library cho `linux-x64` bằng `clang -shared -fPIC`,
rồi `dlopen` và gọi hàm qua `ctypes` — chạy đúng. Đây chính là chuỗi mà `sqlite3` với
`user_defines.source = sqlite3mc` sẽ thực hiện khi `flutter test` chạy trên host ở Phase 3.

`flutter doctor` vẫn báo đỏ mục "Linux toolchain" vì thiếu `libgtk-3-dev` và `mesa-utils`.
**Không liên quan** — hai thứ đó chỉ cần khi build app Flutter cho *Linux desktop*, mà dự án
này chỉ nhắm Android rồi iOS. Không cài.

## 2026-08-21 · Phase 1 · Bản sao keystore đã ra khỏi máy — Taildrop và cái bẫy SAF
Đã Taildrop `tonyfino-keystore-backup-2026-08-21.tar.gz.gpg` sang `redmi-note-13-pro` lúc 12:26.
Giờ keystore tồn tại trên **hai thiết bị vật lý độc lập**, không phải ba bản trên cùng một thùng máy.

**Vì sao hai lần đầu treo, ghi lại để lần sau không mất thời gian:** phía gửi hoàn toàn khoẻ —
`TaildropTarget = 1 (Available)`, tailnet có sẵn cap `file-sharing`, `tailscale ping` pong 272ms.
Nguyên nhân nằm ở máy nhận: từ tailscale-android **1.84**, file đến phải ghi qua Storage Access
Framework. Chưa từng cấp thư mục thì `ShareFileHelper.openFileWriter()` gọi
`waitUntilTaildropDirReady()` — hàm này `await()` một `CompletableDeferred` **không có timeout**,
nên handler treo vĩnh viễn và bên gửi không nhận được lỗi nào.

Nặng hơn: nếu từng huỷ hộp thoại chọn thư mục một lần, `notifyDirectoryReady()` không bao giờ được
gọi, cờ `directoryReady.isActive` kẹt `true`, và guard trong code chặn luôn mọi lần hiện hộp thoại
sau đó. Mở lại app bao nhiêu lần cũng vô ích — phải **force-stop** mới reset.

Cách sửa: force-stop Tailscale → Settings → Permissions → **Taildrop directory access** →
*Pick a different directory* → Downloads. Trước khi cấp, dòng đó hiện `No access`.
App **không có** nút bật/tắt Taildrop; việc cấp thư mục chính là bước "bật", chỉ là bị giấu kỹ.

**Chẩn đoán nhanh cho lần sau:**
```bash
tailscale status --json | jq -r '.Peer[] | "\(.HostName) TaildropTarget=\(.TaildropTarget)"'
#   1 = Available (phía gửi OK)   9 = OwnedByOtherUser   5 = Offline
curl -v --max-time 10 -X PUT --data 'x' 'http://<ip-máy-nhận>:1/v0/put/probe.txt'
#   kết nối được nhưng treo  => handler bên nhận bị chặn, không phải lỗi mạng
```
Ghi chú: peerAPI của Android luôn báo **port 1** — đó là listener giả, netstack chặn lấy. Bình thường.

**Phát hiện phụ đáng lưu:** node `pc.tail6efea7.ts.net` trong tailnet thuộc tài khoản khác
(`nguyenvanthanhdat1810@`), `TaildropTarget = 9 OwnedByOtherUser`. Nghĩa là tailnet này **dùng chung**.
Hệ quả cho Phase 6/12/14: `tailscale serve` phơi nội dung ra cho **mọi** node trong tailnet, kể cả
node đó. Với APK thì chấp nhận được; với bất cứ thứ gì nhạy cảm thì phải mã hoá payload chứ đừng
trông vào phạm vi mạng. Và tuyệt đối không dùng `tailscale funnel` — nó phơi ra Internet công cộng.

## 2026-08-21 · Phase 3 · SPIKE F1 THÀNH CÔNG — sqlite3mc chạy cả host lẫn Android
Cổng rủi ro nhất (H4/E3) đã vượt qua **sạch**, không phải dùng phương án lùi.

- **Host** (`flutter test test/spike/sqlite3mc_spike_test.dart`): clang biên dịch sqlite3mc cho
  linux-x64 qua Dart build hooks, `PRAGMA key` mã hoá thật — file trên đĩa KHÔNG chứa plaintext
  ("bí mật tài chính" không tìm thấy trong bytes), sai key thì `SELECT` ném lỗi.
- **Emulator API 36** (`flutter test integration_test/sqlite3mc_device_test.dart`): NDK biên dịch
  sqlite3mc cho x86_64 Android, cùng test mã hoá pass.

Kết luận: **v1 SẼ mã hoá DB tại chỗ** bằng sqlite3mc + `PRAGMA key`, không cần lùi sang chỉ-mã-hoá-backup.
Khoá 32-byte sẽ nằm trong flutter_secure_storage (Phase 4).

Cách kích hoạt (đã xác nhận cú pháp trong sqlite3-3.5.2/doc/hook.md):
```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

## 2026-08-21 · Phase 3 · Toolchain: bỏ riverpod codegen, dùng provider viết tay
Flutter 3.44.1 ghim `meta 1.18.0` / `test_api 0.7.11`. Bản mới nhất của `riverpod_generator 4.x`
và `riverpod_lint 3.1.8` cần `analyzer 13.3+` (→ meta 1.18.3), xung đột không giải được với
`build_runner` + `flutter_test` SDK. Đã cô lập bằng probe pubspec: chỉ cần
`drift_dev 2.34.5 + flutter_riverpod 3.x` cùng lúc là vỡ.

Quyết định (không chắp vá, không ép version xung đột):
- **Giữ `flutter_riverpod 3.4.2`** (bản mới, có Notifier hợp nhất) — nhưng **viết provider bằng tay**,
  KHÔNG dùng `@riverpod` codegen. Riverpod chính thức coi codegen là tùy chọn.
- **Bỏ `riverpod_annotation`, `riverpod_generator`, `riverpod_lint`.**
- **`drift_dev` lùi patch 2.34.5 → 2.34.0** (vẫn cùng dòng 2.34, khớp `drift 2.34.3` runtime),
  `build_runner` để pub tự chọn → 2.15.1, `analyzer 12.1.0` (meta 1.18.0 ✓).
- Bù cho việc mất `riverpod_lint`: grep-lint tự viết (đã bắt buộc trong TODOS) chặn đúng thứ
  ta cần — `dart:io`/`Platform.`/`DateTime.now()` trong features, `material.dart` trong theme/tokens.

Thêm lại riverpod codegen/lint khi nào nâng Flutter lên bản dùng meta ≥1.18.3.

## 2026-08-21 · Phase 3 · compileSdk 37, targetSdk 36
`flutter_secure_storage 11.0.0` yêu cầu **compileSdk 37** (Android 16 QPR). Đã tải platform
android-37. Đặt `compileSdk = 37` (chỉ để biên dịch) nhưng giữ **`targetSdk = 36`** — bản đã
test trên emulator, hành vi runtime ổn định, thoả hạn chót Play "≥36 từ 31/08/2026". Đây là cấu
hình chuẩn: compile cao, target ổn định.

Cũng phải bật `buildFeatures { resValues = true }` (AGP 9 tắt mặc định) để `resValue` cấp
`app_name` khác nhau cho bản dev vs release. Và bỏ `kotlinOptions.jvmTarget` (Kotlin 2.3 biến
nó thành lỗi) — Java 17 trong `compileOptions` là đủ.

## 2026-08-21 · Phase 3 · Renderer trên emulator = Impeller (OpenGLES)
`flutter run` trên emulator tonyfino36 log rõ:
`Using the Impeller rendering backend (OpenGLES)`.

Không phải Skia, cũng không phải Impeller-Vulkan. Trên SwiftShader (máy không có GPU dùng được,
xem E5) Flutter 3.44 rơi về Impeller-GLES và chạy được. Nghĩa là:
- App KHỞI ĐỘNG và render bình thường trên emulator — không cần cờ `--enable-impeller=false`.
- Golden test (Phase 5+) chạy dưới Impeller-GLES trên emulator. Vì đây vẫn là Impeller (khác
  engine với Skia mà một số CshelfI runner dùng), coi golden trên emulator là tham khảo layout;
  pixel-perfect vẫn nên xác thực bằng dogfood APK trên máy thật (Redmi, GPU thật). Khớp H7.

## 2026-08-21 · Phase 4 · Số dư = SUM(amount_minor) CÓ DẤU, không cột `type`
`transactions.amount_minor` là số nguyên **có dấu** (dương = thu, âm = chi), không phải trị
tuyệt đối + cột `type` như bảng `input` của Rolly. Đây là điều khiến D7 đúng bằng đúng MỘT
phép `SUM()`, không cần `CASE WHEN type = 'Expense' THEN -amount ELSE amount END` — ít chỗ để
sai hơn, và tránh hẳn cạm bẫy "quên đảo dấu ở một chỗ" mà chính bug số 1 của Rolly có thể bắt
nguồn từ đó.

## 2026-08-21 · Phase 4 · `drift` và `drift_dev` PHẢI cùng patch 2.34.0 — CLI vỡ nếu lệch
Đã tự tay xác minh (không đoán): pin `drift: ^2.34.3` (Phase 3) + `drift_dev: ^2.34.0` (đã lùi
patch cũng ở Phase 3, vì lý do khác — xung đột `meta`/`analyzer` với `flutter_riverpod`) khiến
**toàn bộ CLI `dart run drift_dev ...` biên dịch lỗi**, mọi subcommand, không riêng
`make-migrations`: `verifier_common.dart` của `drift_dev` 2.34.0 gọi vào lớp `GeneratedDatabase`
nội bộ (`drift3_preview`) theo hình dạng API mà bản `drift` 2.34.1–2.34.3 đã đổi
(`allSchemaEntities` → getter `schema` trừu tượng). Đây là builder qua `package:build`
(`dart run build_runner build`) vẫn chạy tốt — chỉ CLI độc lập của `drift_dev` bị AOT-compile
nguyên khối nên vỡ cả gói dù chỉ cần một subcommand.

Đã thử pin `drift_dev` lên khớp patch runtime (`2.34.3`) — pub solver từ chối: mọi
`drift_dev >=2.34.1+1` cần `analyzer ^13.0.0`, xung đột thẳng với `meta 1.18.0` mà Flutter
3.44.1 ghim (chính xung đột đã buộc bỏ riverpod codegen ở Phase 3). Vậy chỉ còn một hướng đi:
lùi `drift` xuống ĐÚNG PATCH `2.34.0` (không phải `^2.34.0`) để khớp `drift_dev: 2.34.0` — cả
hai cùng ngày phát hành, cùng hình dạng API. `drift_flutter: 0.3.1` chấp nhận `drift ^2.30.0`
nên không xung đột thêm. Đã xác minh CLI chạy được sau khi pin (`dart run drift_dev
make-migrations` sinh đúng `drift_schemas/app_database/drift_schema_v1.json`).

**Bài học cho các phase sau:** khi nâng cấp `drift`/`drift_dev`, LUÔN nâng cả hai lên **cùng
version string chính xác** cùng lúc, không riêng lẻ theo `^` — nới lỏng ràng buộc dễ khiến
patch của một bên đi trước bên kia và vỡ CLI mà `flutter analyze`/`flutter test` không hề báo
(vì chúng đi qua builder, không qua CLI).

## 2026-08-21 · Phase 4 · Không có migration test v(N-1)→vN thật ở v1 — tự viết test tương đương
`dart run drift_dev make-migrations` (sau khi thông ở trên) chỉ sinh `drift_schema_v1.json` cho
lần chạy đầu; nó không sinh step-migration file hay test so sánh vì chưa có phiên bản trước để
diff — công cụ generate những thứ đó chỉ từ v2 trở đi. Vì Phase 4 là lúc TẠO schema, không phải
lúc sửa nó, nên "migration test" ở v1 tự viết bằng tay
(`test/data/db/schema_migration_test.dart`): mở DB trong bộ nhớ, chạy `onCreate`, đối chiếu
từng bảng/cột LIVE với JSON đã commit qua `PRAGMA table_info`. Bài test này đỏ ngay nếu ai đổi
`tables.dart` mà quên bump `schemaVersion` + chạy lại `make-migrations` — tác dụng tương đương,
chỉ khác cơ chế sinh.

## 2026-08-21 · Phase 4 · `closeStreamsSynchronously` thuộc `DatabaseConnection`, không phải `NativeDatabase.memory()`
TODOS.md ghi `NativeDatabase.memory(closeStreamsSynchronously: true)` — tham số này **không**
tồn tại trên factory đó ở bất kỳ bản `drift` nào (2.34.0–2.34.3 đều không có). Đọc thẳng source
(`connection.dart`) thì cờ này thuộc constructor `DatabaseConnection`, dùng khi bọc một
`QueryExecutor` lại — đúng cơ chế Tony mô tả (tránh treo timer 1 event-loop mà drift dùng để
không đóng stream sớm khi `StreamBuilder` reconnect), chỉ đặt sai chỗ trong câu lệnh mẫu. Cách
dùng đúng, đã gói vào `test/support/open_test_database.dart`:

```dart
AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
)
```

## 2026-08-21 · Phase 4 · file_picker 12 THỰC SỰ hỗ trợ persistable SAF grant — chỉ ẩn sau package khác
H6 lo grant SAF "chết âm thầm sau reboot" nếu `file_picker` không lộ
`takePersistableUriPermission()`. Đọc thẳng source (không đoán): `file_picker` 12's
`getDirectoryPath()` gọi `FilePickerAndroidOptions(safOptions: AndroidSAFOptions(...))` xuống
tới `android_file_picker` 1.0.1, và implementation Kotlin ở đó CÓ gọi
`contentResolver.takePersistableUriPermission()` — nhưng chỉ khi `AndroidSAFOptions(grant:
AndroidSAFGrant.lifetime, persistGrant: true)` được truyền tường minh; mặc định
(`AndroidOptions()` rỗng) thì KHÔNG, và khi đó Android resolve một filesystem path tạm bằng
reflection (`getFullPathFromTreeUri`) — không bền, đúng như H6 lo.

Cái bẫy thật không phải "file_picker thiếu API" mà là: `AndroidSAFOptions`/
`FilePickerAndroidOptions` sống trong package `android_file_picker` (implementation Android của
`file_picker`, thường chỉ là transitive dependency), và **`file_picker.dart` (barrel chính)
KHÔNG re-export chúng** — `src/file_picker.dart` chỉ `import` chứ không `export`. Phải thêm
`android_file_picker` làm dependency TRỰC TIẾP trong `pubspec.yaml` mới import được. Không có gì
trong tài liệu `file_picker` nói rõ điều này.

**Quyết định:** dùng thẳng `AndroidSAFOptions(grant: lifetime, accessMode: readWrite,
persistGrant: true)` qua `getDirectoryPath()` — không cần package `saf` ngoài, không cần platform
channel Kotlin CHO PHẦN CẤP QUYỀN. Nhưng persistable grant chỉ cho phép *đọc lại* cây thư mục,
không tự nhiên cho `dart:io File` ghi file mới vào URI `content://` — phần ĐÓ mới cần platform
channel Kotlin nhỏ (`SafBackupChannel.kt`, ~55 dòng, dùng `DocumentsContract`, không cần thêm
Gradle dependency vì đó là API framework), ghi/ghi-đè file trong cây đã cấp quyền. Đã biên dịch
qua `./gradlew :app:compileDebugKotlin`, chưa chạy trên thiết bị thật (việc đó thuộc Phase 6+
khi màn backup có UI).

## 2026-08-21 · Phase 4 · `NumberFormat.currency(locale:'vi_VN')` chèn NBSP (U+00A0), không phải dấu cách thường
`"35.000 ₫"` nhìn giống hệt trên terminal dù ký tự trước `₫` là U+00A0 (non-breaking space) chứ
không phải U+0020. Xác nhận bằng `.codeUnits` thật, không bằng mắt — nếu viết test bằng string
literal dấu cách thường sẽ luôn đỏ dù code đúng. `Money.format()` không cần biết điều này (nó
chỉ gọi `NumberFormat`), nhưng bất kỳ test hay UI nào so sánh chuỗi định dạng tiền phải nhớ.

## 2026-08-21 · Phase 6 · `SliverPersistentHeader(pinned: true)` ném lỗi hình học khi danh sách ngắn hơn viewport — bắt bằng widget test, KHÔNG phải đoán
Header ngày dính (`DayHeader` trong `TransactionsScreen`) ban đầu ném
`"layoutExtent exceeds paintExtent"` mỗi khi danh sách chỉ có 1 ngày (ngắn hơn màn hình) — tái hiện
được cả ở viewport test mặc định (800×600) lẫn viewport điện thoại thật (393×852), nên đây KHÔNG
phải artefact môi trường test mà là bug thật sẽ crash trên máy Tony với vài giao dịch đầu tiên
(đúng kịch bản dogfood).

Nguyên nhân, đọc thẳng `RenderSliverPinnedPersistentHeader.performLayout`
(`flutter/src/rendering/sliver_persistent_header.dart`): `paintExtent = min(childExtent,
remainingPaintExtent)` nhưng `layoutExtent` dùng `maxExtent` khai báo trong delegate — nếu widget
`build()` trả về KHÔNG BỊ ép đúng chiều cao `maxExtent` (ở đây `DayHeader` cao thật ~33px trong khi
delegate khai `maxExtent: 44`), `childExtent` đo được (33) lệch khỏi `layoutExtent` (44) → vỡ bất
biến sliver. Sửa bằng cách bọc `SizedBox(height: maxExtent, child: ...)` trong `build()` của
delegate — luật chung: `SliverPersistentHeaderDelegate.build()` PHẢI trả về widget cao ĐÚNG BẰNG
`maxExtent`, không phải "đủ chứa nội dung".

Thử `SliverMainAxisGroup` bọc header+list (tưởng đây mới là nguyên nhân) KHÔNG sửa được gì — giữ
lại cấu trúc đơn giản hơn: nhiều `SliverPersistentHeader(pinned: true)` tuần tự thẳng trong
`slivers:` của `CustomScrollView`, không nhóm — đây vốn là cách kinh điển làm sticky-section-header
trong Flutter thuần, từ trước khi `SliverMainAxisGroup` tồn tại.

## 2026-08-21 · Phase 6 · FAB bị thanh nav nổi che — chỉ thấy được khi chụp ảnh thiết bị thật
Widget test không bắt được: FAB của `TransactionsScreen` (Scaffold LỒNG bên trong `body:` của
`AppShell`) định vị mặc định theo chiều cao của CHÍNH Scaffold lồng đó — nhưng vì `extendBody:
true` ở cả hai tầng Scaffold, chiều cao đó kéo dài tới tận đáy vật lý màn hình, đúng chỗ
`AppBottomNav` (thanh nav nổi kiểu pill trên `GlassSurface`) che lên. Ảnh chụp trên emulator
`tonyfino36` cho thấy FAB bị khuất gần hết sau thanh nav.

Sửa: bọc `floatingActionButton` trong `Padding(bottom: kBottomNavReservedHeight +
viewPadding.bottom)`. Đây đúng là lớp lỗi mà TODOS.md đã cảnh báo trước ("xử lý inset theo TỪNG
scroll view, không SafeArea bao trùm") — chỉ khác là lỗi rơi vào FAB chứ không phải nút Save như dự
đoán ban đầu. Nút Save trong bottom sheet (`TransactionFormSheet`) đã đúng ngay từ đầu — ảnh chụp
với bàn phím thật mở trên emulator xác nhận nút "Lưu" luôn nổi trên bàn phím.

**Bài học:** widget test (kể cả viewport giả lập kích thước điện thoại) không bắt được lớp lỗi
"hai Scaffold lồng nhau tương tác với `extendBody`" — chỉ ảnh chụp trên thiết bị/emulator thật mới
lộ ra. Đây chính là lý do H7/H8 (TODOS.md) coi dogfood APK là kênh kiểm tra thị giác không thể thay
thế bằng test tự động.

## 2026-08-21 · Phase 6 · Cài đè giữ nguyên database — xác minh bằng ảnh chụp, không chỉ log cài đặt
`adb install -r` báo "Success" cả khi cài mới lẫn cài đè, nên tự nó không chứng minh gì. Xác minh
thật: thêm 1 giao dịch (-65.000 đ, Ăn uống) ở v0.1.0+1, `adb install -r` bản +2 (không gỡ cài
trước, không xoá data), mở lại app, chụp ảnh — hero card và hàng giao dịch vẫn nguyên. Đối chiếu
thêm bằng `dumpsys package dev.tony.tonyfino | grep versionCode` → `versionCode=2`, xác nhận đúng
là bản mới, không phải cùng bản cũ chưa cài lại.

## 2026-08-21 · Phase 6 · Nút Lưu "biến mất" khi không có bàn phím — `showModalBottomSheet` push nhầm Navigator NHÁNH của `go_router`, không phải bug layout
Sau khi Tony yêu cầu bấm thử mọi tính năng trên emulator: mở form SỬA (không tự động mở bàn
phím) thì hàng nút Lưu/Xoá hoàn toàn biến mất, bị thanh nav nổi (`AppBottomNav`/`GlassSurface`)
đè lên — dù cây widget đúng, `flutter analyze` sạch, và test viewport giả lập cỡ điện thoại cũng
không bắt được. Tái hiện lại ở cả form THÊM một khi bấm nút Back để tắt bàn phím đi — xác nhận đây
không phải khác biệt thêm/sửa mà là khác biệt CÓ/KHÔNG bàn phím.

Thử "sửa" đầu tiên — ép `ConstrainedBox(maxHeight: 92% màn hình)` quanh nội dung sheet, nghĩ là
overflow — KHÔNG có tác dụng gì, dù đây vẫn là một cải thiện đáng giữ lại (form dài trên máy màn
hình thấp giờ cuộn được thay vì tràn).

Nguyên nhân thật, tìm bằng `uiautomator dump` (không đoán): phần tử "Lưu" và tab "Giao dịch" của
bottom nav BÁO CÙNG TỌA ĐỘ chồng lấn nhau trong accessibility tree — nghĩa là cả hai đang được vẽ,
chỉ là cái này đè lên cái kia. `showAppBottomSheet` gọi `showModalBottomSheet(context: context,
...)` với `context` lấy từ sâu trong `TransactionsScreen` — nằm trong Navigator RIÊNG mà
`StatefulShellRoute` dựng cho mỗi nhánh (tab), sống bên trong `body:` của `AppShell`'s `Scaffold`
ngoài. `Navigator.of(context)` mặc định tìm Navigator GẦN NHẤT — tức Navigator nhánh — nên sheet
bị push vào lớp `body`, CÙNG LỚP với nội dung cuộn. `AppShell`'s `bottomNavigationBar` được
Scaffold NGOÀI cố ý vẽ ĐÈ LÊN `body` (để cho phép cuộn xuyên qua thanh nav mờ, xem `extendBody`)
— nên nó đè luôn lên phần dưới của sheet, bất kể sheet còn thừa chỗ hay không.

**Sửa:** `showModalBottomSheet(..., useRootNavigator: true)` — đẩy sheet lên `Overlay` GỐC, phía
trên toàn bộ `AppShell`. Đây là bẫy kinh điển của `go_router`'s `StatefulShellRoute`: bất kỳ modal
nào mở từ bên trong một nhánh (`showDialog`, `showModalBottomSheet`, `showMenu`, ...) PHẢI dùng
`useRootNavigator: true`/`rootNavigator: true`, nếu không sẽ bị chrome của shell (bottom nav, có
khi cả app bar) đè lên mà không có cảnh báo nào ở bản release.

## 2026-08-21 · Phase 6 · Thiếu `localizationsDelegates` — `DatePicker` ra tiếng Anh dù mọi chữ CỦA app đã tiếng Việt
Bắt được khi bấm "Đổi ngày" trên emulator: `showDatePicker` (widget Material có sẵn) hiện
"Select date"/"Cancel"/"OK" tiếng Anh, dù toàn bộ chữ TonyFino tự viết đều tiếng Việt cứng.
Nguyên nhân: `MaterialApp.router` chưa khai báo `localizationsDelegates`/`supportedLocales`/
`locale`, nên `MaterialLocalizations` (nơi các widget Material có sẵn như DatePicker/TimePicker
tra nhãn) rơi về mặc định `en`. Đây đúng là khoảng trống mà Bàn giao Phase 6 đã nêu ("l10n mặc
định vi") nhưng dễ bỏ sót vì app KHÔNG có màn hình nào tự nó "trông có vẻ" cần l10n — chỉ lộ ra
khi chạm đúng một widget Material chưa tự viết lại.

**Sửa:** thêm `flutter_localizations`' `GlobalMaterialLocalizations.delegate` +
`GlobalWidgetsLocalizations.delegate` + `GlobalCupertinoLocalizations.delegate` vào
`localizationsDelegates`, `locale: Locale('vi')`, `supportedLocales: [vi, en]`. Xác nhận lại bằng
ảnh chụp: DatePicker ra đúng "Chọn ngày"/"Huỷ"/"OK", tên tháng "tháng 8 năm 2026", và thứ tự tuần
Việt Nam bắt đầu Thứ Hai (`T2 T3 T4 T5 T6 T7 CN`).

## 2026-08-21 · Phase 7 · `amount_evaluator` cộng sai khi hàng trăm trộn số+chữ (`"2 trăm 50 nghìn"`)
Ví dụ chính Tony chỉ đích danh trong prompt Phase 7 ("regex sẽ chết ở `1 triệu 2 trăm 50 nghìn`")
ban đầu ra **1.050.200** thay vì 1.250.000 khi chạy `flutter test` trên
`test/features/quick_add/domain/parser/smoke_test.dart` — bắt được ngay từ lần chạy test đầu
tiên, không phải đọc code mà thấy.

Nguyên nhân: `_tryParseCoefficient` có hai đường xử lý hàng trăm tách biệt — một cho chữ viết
đầy đủ (`"hai trăm năm mươi"`, gộp đúng thành hệ số 250) và một ngầm định cho token số trần
(`"2"`) đi với từ đơn vị `trăm` ở TẦNG NGOÀI của vòng lặp chính, coi `"2 trăm"` là MỘT NHÓM CỘNG
ĐỘC LẬP (2×100=200, cộng thẳng vào tổng) rồi mới thấy `"50 nghìn"` (50×1.000) như một nhóm khác —
thay vì nhận ra `"2 trăm 50"` phải ghép thành hệ số 250 CHO `"nghìn"` nhân lên (250×1.000).

**Sửa:** tổng quát hoá cả hàm hàng-trăm lẫn hàm chục-đơn-vị để chấp nhận token SỐ TRẦN ở bất kỳ vị
trí nào (hàng trăm, hàng chục-đơn vị), không chỉ chữ-với-chữ — `"2 trăm 50"` giờ tự ghép thành hệ
số 250 giống hệt đường xử lý `"hai trăm năm mươi"`. Xác nhận lại bằng
`test/features/quick_add/domain/parser/corpus_test.dart` (311 ca, gồm cả biến thể số/chữ trộn
nhau của cùng luật này) và `robustness_test.dart` (fuzz 10.000 chuỗi + property test).

## 2026-08-21 · Phase 7 · `segmenter.dart` tách nhầm bên trong số có dấu phẩy phân cách nghìn
`"ăn trưa 35,000"` (một khoản, dùng dấu phẩy Mỹ làm phân cách nghìn) bị `segmenter.dart` tách
thành HAI đoạn tại dấu phẩy — phát hiện qua `corpus_test.dart` báo sai số lượng draft, không phải
đọc code.

Nguyên nhân: `segmenter.dart` soi ranh giới đoạn ở tầng KÝ TỰ THÔ, TRƯỚC khi token hoá — bất kỳ
dấu phẩy nào cũng bị coi là ranh giới, không biết gì về luật "dấu phẩy đi kèm đúng 3 chữ số theo
sau là phân cách nghìn, không phải ranh giới" mà `tokenizer.dart` đã cài đúng. Đây là một dạng
trùng lặp logic ngầm giữa hai file — cả hai đều phải "biết" ý nghĩa của một dấu phẩy, nhưng chỉ
một nơi cài đúng.

**Sửa:** nhân bản chính xác điều kiện gộp nhóm của `tokenizer.dart` (đứng sau chữ số, có đúng 3
chữ số theo sau, ký tự kế tiếp không phải chữ số) vào hàm nhận diện dấu phẩy của `segmenter.dart`.
**Rủi ro còn lại:** nếu luật gộp nhóm ở `tokenizer.dart` đổi sau này (vd hỗ trợ định dạng phân cách
khác), phải nhớ sửa `segmenter.dart` theo — hai nơi cài cùng một luật, không có nguồn chân lý
chung. Ghi lại ở đây để không quên.

## 2026-08-21 · Phase 8 · `StreamProvider` tự `pause` khi không ai `ref.watch()` — khớp danh mục lặng lẽ luôn ra `null` trên máy thật
Gõ `"an trua 35k"`/`"an trua 40k"` trên emulator (không dấu vì `adb shell input text` không gõ
được tiếng Việt có dấu — xem `feedback_hands_on_device_testing`) khớp đúng từ khoá seed
`an_uong`, nhưng thẻ luôn hiện "Chưa phân loại". `flutter test` với 468/468 test xanh KHÔNG bắt
được ca này — chỉ lộ ra khi gõ thật trên thiết bị.

Nguyên nhân: Riverpod 3 tự `pause` subscription của một `StreamProvider` khi không có ai đang
`ref.watch()` nó activenly (xác nhận qua CHANGELOG.md chính thức của `riverpod`: "**Breaking**:
`StreamProvider` now pauses its `StreamSubscription` when the provider is not actively listened").
`categoryKeywordEntriesProvider` (bọc `CategoryRepository.watchAllKeywords()`, nguồn sống của
`category_matcher.dart`) trước đó chỉ bị `QuickAddController.sendMessage` gọi
`ref.read(...).value` — đọc snapshot, không tạo listener sống — nên stream drift đứng yên vĩnh
viễn, không bao giờ thật sự chảy dữ liệu vào. Không ném lỗi, không log gì bất thường; mọi test
parser/matcher hiện có gọi THẲNG `category_matcher`/`CategoryRepository`, chưa từng đi qua đúng
đường dây provider này nên không bắt được.

**Sửa:** thêm `ref.watch(categoryKeywordEntriesProvider)` vào `QuickAddController.build()` — một
dòng, kèm doc comment giải thích nguyên nhân để không ai xoá nhầm vì "trông như không dùng để làm
gì". Xác nhận trên thiết bị thật (gỡ cài + cài lại APK, gõ lại đúng câu, khớp đúng "Ăn uống"), và
khoá lại bằng assertion `categoryId != null` cho từng giao dịch trong
`test/features/quick_add/quick_add_screen_test.dart` — xác nhận có FAIL đúng với thông điệp này
khi tạm revert dòng `watch` đi rồi chạy lại test.

**Bài học chung:** một `ref.read(streamProvider).value` ở NƠI KHÔNG CÓ AI KHÁC `watch` cùng
provider đó là một class bug hoàn toàn vô hình với unit test gọi thẳng tầng dưới — chỉ lộ ra khi
đi qua đúng đường dây Riverpod thật, và chỉ trên thiết bị thật mới buộc mình đi đúng đường dây đó.

## 2026-08-21 · Phase 8 · Thẻ "đã lưu" trong CÙNG phiên chat không nhấn-giữ được — thiếu handler, không phải bug layout
Sau khi sửa bug khớp danh mục ở trên, thử nhấn giữ một thẻ vừa co lại ("Ăn uống ✓") ngay trong
phiên chat hiện tại để mở sheet Sửa/Nhân đôi/Xoá — không có gì xảy ra. Phát hiện ngay sau khi vừa
xác nhận bug #1 đã sửa, trong cùng một vòng gõ-thử trên thiết bị thật.

Nguyên nhân: `DraftCard._buildSaved` (trạng thái co lại của một thẻ VỪA tạo trong phiên) và
`SavedTransactionRow` (một hàng đến từ LỊCH SỬ, `transactionsWithCategoryProvider`) là hai widget
khác nhau vẽ ra layout gần giống hệt nhau, nhưng chỉ `SavedTransactionRow` có
`onTap`/`onLongPress` gắn sheet hành động — `_buildSaved` được viết chỉ để HIỂN THỊ, không ai gắn
handler. Vì vậy một giao dịch tạo qua chat mất khả năng Sửa/Nhân đôi/Xoá cho tới khi khởi động lại
app (lúc đó nó render lại qua stream lịch sử, thành `SavedTransactionRow` thật, mới lại nhấn-giữ
được).

**Sửa:** tách `showTransactionActionsSheet(BuildContext, WidgetRef, TransactionWithCategory)`
thành một hàm top-level dùng chung ở `saved_transaction_row.dart`. `_buildSaved` tra ngược
`TransactionWithCategory` thật qua `widget.card.savedTransactionId` trong
`transactionsWithCategoryProvider` hiện có (không tự dựng bản giả từ state cục bộ, tránh lệch nếu
giao dịch vừa bị sửa nơi khác) rồi gắn cùng `onTap`/`onLongPress` như `SavedTransactionRow`. Xác
nhận trên thiết bị thật: nhấn giữ thẻ co lại → sheet hiện đúng, "Sửa" mở đúng `TransactionFormSheet`
với dữ liệu đã điền sẵn.

**Bài học chung:** hai widget "trông giống nhau" cho cùng MỘT khái niệm (giao dịch đã lưu) dễ lệch
hành vi nếu viết độc lập — cùng loại rủi ro với bug dấu phẩy của `segmenter.dart` ở Phase 7 (hai
nơi phải "biết" cùng một luật). Không phải bug logic nghiệp vụ nên `flutter test` xanh hoàn toàn
không nói lên điều gì về nó — chỉ lộ ra khi thật sự chạm vào widget trên thiết bị.

## 2026-08-21 · Phase 9 · Bảng ánh xạ field Rolly `input` → TonyFino `Transaction` (viết TRƯỚC khi code, theo yêu cầu prompt)

Nguồn duy nhất: `docs/rolly-schema.md` (Phase 2, quan sát từ payload thật) + đối chiếu chéo trực
tiếp trên `raw_rolly/input.json` (362 dòng thật) trước khi viết bất kỳ dòng importer nào.

| Field Rolly | → TonyFino | Quy tắc chuyển đổi |
|---|---|---|
| `id` (int) | `Transactions.sourceId` (cột mới) | `'rolly:' + id` — khoá PK ổn định của Rolly, dùng làm khoá idempotent |
| `amount` (float, LUÔN ≥0, **major unit** theo schema doc) | `amountMinor` | ép `int` (assert giá trị nguyên vẹn — Rolly luôn phát `.0`, ném lỗi nếu không); VND `currencyScale=0` nên major == minor về mặt số |
| `type` (`Expense`/`Income`/`Savings`) | **dấu** của `amountMinor` | `Expense`→âm, `Income`→dương, `Savings` (chỉ dòng GIỮ LẠI sau khử trùng lặp)→âm. **Dấu lấy trực tiếp từ `type`, KHÔNG suy ra từ danh mục đã map** — khác hẳn heuristic `category.kind` của quick-add Phase 8, vì ở đây `type` là sự thật gốc đáng tin hơn |
| `date` (`"YYYY-MM-DD"`, đã là ngày lịch giờ VN theo schema doc) | `occurredAt` | `DateTime(y, m, d)` — KHÔNG cộng/trừ giờ gì thêm, KHÔNG dùng `created_at`. Đây là field schema doc cảnh báo rõ nhất |
| `created_at` (UTC) | *(không dùng cho `occurredAt`)* | chỉ mang tính tham khảo; `Transactions.createdAt/updatedAt` của TonyFino để mặc định = lúc import thật (qua `Clock`), không phải thời điểm Rolly tạo dòng |
| `item` | `note` | trim; rỗng → `null` |
| `category_id` | `categoryId` | qua bảng ánh xạ do Tony xác nhận trong UI (§ dưới) — bắt buộc giải quyết mọi `category_id` THẬT SỰ xuất hiện trong 362 dòng trước khi commit được |
| `linking_transfer_id` (chỉ có ở `Savings`) | khử trùng lặp cặp transfer | mỗi cặp ghép chéo bằng `id ↔ linking_transfer_id` (xác nhận bằng dữ liệu thật, xem dưới) — CHỈ giữ dòng có `wallet_id != null` (chiều ra khỏi ví chính), bỏ dòng còn lại (chiều vào tiết kiệm, `wallet_id: null`) |
| `subcategory_id`, `wallet_id`, `source_wallet_id`, `destination_wallet_id`, `savings_id`, `debt_id`, `loan_id`, `challenge_id`, `is_audio`, `is_recurring`, `note`\*, `image_url`, `version`, `client_uuid`, `message_out` | *(bỏ)* | không có khái niệm tương ứng ở TonyFino v1 (một ví duy nhất, không subcategory/nợ/vay/challenge). `note` gốc của Rolly trong payload thật luôn `null` — không nhầm với `item` (mới là field có nội dung, map vào `note` TonyFino) |
| `message_in` | *(bỏ, không import)* | giá trị nằm ở việc làm corpus Phase 7 (đã khai thác riêng), không phải dữ liệu giao dịch sống |

**Xác nhận lại cạm bẫy transfer bằng chính `raw_rolly/input.json`** (không chỉ tin schema doc): 8
dòng `Savings` tạo đúng 4 cặp, ghép chéo `id ↔ linking_transfer_id` (không phải cùng chia sẻ MỘT
`linking_transfer_id` chung như câu chữ schema doc dễ gây hiểu lầm — mỗi dòng trỏ sang `id` của
dòng kia). Mỗi cặp luôn có đúng một dòng `wallet_id` khác null — quy tắc "giữ dòng `wallet_id !=
null`" xác định 100% trên cả 4 cặp thật.

**Báo cáo đối chiếu (khớp oracle Phase 2) định nghĩa là gì:** tổng Chi + tổng Thu theo THÁNG, tính
CHỈ từ các dòng `type=Expense`/`type=Income` (354/362 dòng) — **loại `Savings` hoàn toàn**, đúng
cách oracle `docs/rolly-schema.md` tự định nghĩa hai cột "Expense"/"Income" của nó (không gộp
Savings). Số dòng import được (sau khử trùng lặp transfer) sẽ là 354 + 4 = 358, KHÔNG phải 362 —
đây là kết quả ĐÚNG của việc khử trùng lặp, không phải sai lệch cần điều tra.

**Ánh xạ danh mục:** 16 (không phải 21) danh mục Rolly THẬT SỰ được 354 dòng Expense/Income tham
chiếu (kiểm bằng cách đếm `category_id` distinct trên `input.json`, không dùng con số tĩnh
`input_count` của `category_view` vì trường đó có thể lệch thực tế). TonyFino v1 chỉ có 12 danh
mục seed (11 chi + 1 thu duy nhất "Lương") — v1 KHÔNG có màn tạo danh mục mới (Backlog), nên màn
ánh xạ chỉ cho chọn trong 12 danh mục có sẵn HOẶC "Chưa phân loại" (categoryId null — trạng thái
hợp lệ, hiển thị được, không phải "bỏ qua âm thầm"). Gợi ý tự động CHỈ khi tên đã chuẩn hoá (fold
dấu + hạ chữ) trùng KHỚP TUYỆT ĐỐI với tên danh mục TonyFino (9/16 trùng: Gia đình, Phát sinh, Mua
sắm, Điện tử, Lương, Làm đẹp, Sức khỏe, Giáo dục, Giải trí) — mọi phỏng đoán ngữ nghĩa khác (vd
"Thức ăn & Đồ uống" ≈ "Ăn uống") ĐỀU KHÔNG tự chọn, để lại cho Tony tự quyết trong màn xem trước,
đúng tinh thần "không tự động commit một kết quả suy đoán" (Luật bắt buộc #7). Dòng
`Savings`-đã-khử-trùng-lặp (không có `category_id` gốc nào ở Rolly) cũng xuất hiện trong cùng màn
này như một mục cần quyết định.

**Cột DB mới bắt buộc:** `Transactions.sourceId TEXT NULLABLE` + unique index — `schemaVersion`
1→2. Idempotency dựa hoàn toàn vào cột này: import lần hai gặp `sourceId` đã tồn tại thì bỏ qua
dòng đó (không insert, không lỗi) thay vì chèn trùng.

## 2026-08-21 · Phase 9 · `CategoryBucketKey` — gộp nhầm "Savings không category" và "Expense/Income category null" vào chung khoá `null`
`test/fixtures/rolly/sample.json` (Phase 2) cố tình có cả hai ca: một cặp `Savings` (không category
gốc nào ở Rolly) và một dòng `Expense` với `category_id: null` (không quan sát thấy trong dữ liệu
thật nhưng vẫn là trường hợp hợp lệ theo schema). Bản đầu của `RollyCategoryUsage`/`MappingChoice`
dùng thẳng `int? rollyCategoryId` làm khoá nhóm — cả hai ca trên đều có `rollyCategoryId == null`
nên bị GỘP CHUNG một bucket trong màn ánh xạ, cộng dồn sai số đếm và chỉ cho Tony chọn MỘT lựa chọn
cho hai khái niệm khác nhau. Bắt được ngay khi viết `rolly_json_parser_test.dart` dựa trên
`sample.json`, trước khi chạm thiết bị thật.

**Sửa:** thêm kiểu `CategoryBucketKey` (const constructors `.category(id)` / `.uncategorized()` /
`.savingsTransfer()`, có `==`/`hashCode` riêng) thay cho `int?` trần làm khoá xuyên suốt
`StagedRollyTransaction`, `RollyCategoryUsage`, và `Map` ánh xạ trong controller/UI.

## 2026-08-21 · Phase 9 · `ref.watch` trong `Notifier.build()` xoá sạch state đang xây dở — bắt lại đúng bug này trong Phase 8 đã SHIP
`ImportController.build()` gọi `ref.watch(categoriesProvider)` (giữ subscription sống theo đúng bài
học "`ref.read` không giữ `StreamProvider` chảy" của Phase 8) — nhưng `watch` bên trong `build()`
của một `Notifier` có tác dụng phụ khác hẳn `ref.read`/`.value`: mỗi khi provider được `watch` phát
giá trị MỚI, Riverpod HUỶ VÀ DỰNG LẠI TOÀN BỘ instance của chính notifier đang gọi `watch` đó, gọi
lại `build()` để lấy state khởi tạo mới. Một coroutine (`pickRollyFile`, `commit`, ...) đang chạy
dở trên instance CŨ (đã bị huỷ) thì mọi `state = ...` sau đó gán vào một instance không ai còn xem —
widget tree lúc này đang xem instance MỚI với state vừa `build()` trả về (`ImportIdle`). Toàn bộ
wizard "biến mất" giữa chừng, không ném lỗi, không log gì.

Tái hiện thật trên widget test: DB test mới mở → `categoriesProvider` (stream trên
`db.select(db.categories).watch()`) phát emission ĐẦU (rỗng hoặc đang tải) rồi phát emission THỨ
HAI khi seed 12 danh mục hoàn tất — đúng lúc `confirmMapping()`/`pickRollyFile()` đang chạy dở, xoá
sạch state. Nút "Tiếp tục → xem trước" không bao giờ chuyển màn dù nhấn đúng toạ độ — mất hàng chục
lượt debug (kể cả nghi ngờ toạ độ tap, kiểm tra `FilePickerPlatform.instance`, đọc logcat) trước khi
nhận ra nguyên nhân thật.

**Soát lại toàn bộ codebase tìm cùng lớp bug** (grep `ref.watch` bên trong `Notifier.build()`) —
phát hiện **`QuickAddController.build()` (Phase 8, ĐÃ SHIP, Tony đang dùng thật) dính CHÍNH XÁC bug
này, còn nghiêm trọng hơn**: nó `ref.watch(categoryKeywordEntriesProvider)`, mà bảng
`category_keywords` KHÔNG chỉ phát emission một lần lúc khởi động — nó GHI liên tục qua vòng lặp
học (`correctCategory` → `recordKeywordCorrection`) mỗi khi Tony sửa danh mục một thẻ ở màn chat.
Nghĩa là: sửa danh mục MỘT thẻ sẽ xoá sạch `state.messages` — mọi thẻ chờ/lỗi KHÁC trong cùng phiên
biến mất khỏi UI (dữ liệu đã lưu vẫn còn trong DB, chỉ mất khỏi phiên hiện tại vì tự "chữa lành" khi
render lại qua stream lịch sử — nhưng thẻ lỗi giữ chữ gõ dở thì mất thật). Bug đã tồn tại từ lúc
Phase 8 ship, không bị phát hiện vì `docs/decisions.md`/test Phase 8 trước đó chỉ kiểm DB, chưa bao
giờ assert `state.messages` sống sót qua một lần sửa danh mục.

**Sửa cả hai nơi:** thay `ref.watch(...)` bằng `ref.listen(..., (_, _) {})` trong `build()` — giữ
subscription sống (đúng mục đích ban đầu, coi như "đang có người nghe" theo CHANGELOG pause
behavior) nhưng KHÔNG kích hoạt lại `build()` của chính notifier khi giá trị đổi. Khoá lại bằng test
mới ở cả hai nơi: `test/features/settings/import/import_screen_test.dart` (toàn bộ wizard 5 bước
qua `FilePicker` giả) và `test/features/quick_add/quick_add_screen_test.dart` ("sửa danh mục KHÔNG
được xoá mất thẻ khác đang chờ trong CÙNG phiên").

**Bài học chung:** `ref.watch(provider)` bên trong `Notifier.build()`/`AsyncNotifier.build()` không
chỉ "đăng ký lắng nghe" như trong một widget — nó biến MỌI emission của provider đó thành một lần
huỷ-và-tái-tạo notifier hiện tại. Bất kỳ notifier nào giữ state tích luỹ qua nhiều lần gọi method
(không chỉ tính lại từ `build()`) mà cần giữ một provider khác sống chỉ để đọc `.value` sau này thì
PHẢI dùng `ref.listen`, không phải `ref.watch` — quy tắc này cần rà lại ở mọi notifier tương lai
từng áp dụng "bài học Phase 8" (giữ stream sống) một cách máy móc.

## 2026-08-21 · Phase 9 · `DropdownButton` ném assertion vì `MappingChoice` thiếu value equality
Màn ánh xạ danh mục ném `AssertionError` ("There should be exactly one item with value") ngay khi
mở, chỉ lộ ra qua widget test render `DropdownButton` thật (mọi test logic thuần trước đó không
đụng tới widget Material này). Hai nguyên nhân cộng lại:
1. `MappingToCategory`/`MappingUncategorized`/`MappingUndecided` không override `==`/`hashCode` —
   `value` (đọc từ `state.mapping`, một instance) và từng `DropdownMenuItem.value` (dựng mới mỗi
   lần build) là hai instance khác nhau dù cùng `categoryId`, so bằng danh tính mặc định luôn lệch.
2. Khi chưa quyết định, `value` truyền thẳng `MappingUndecided()` — nhưng `items` chỉ liệt kê
   `MappingToCategory`/`MappingUncategorized`, không có `MappingUndecided`, nên `value` không khớp
   item nào (đáng lẽ phải là `null` để `DropdownButton` tự hiện `hint`).

**Sửa:** thêm `==`/`hashCode` cho cả ba lớp `MappingChoice`; đổi biểu thức `value:` thành `switch`
map `MappingUndecided`/`null` → `null`, giữ nguyên hai loại còn lại.

## 2026-08-21 · Phase 10 · `Expression<DateTime>.year/.month/.date` mặc định gộp theo UTC — bắt buộc `.modify(DateTimeModifier.localTime())`
Xác minh trực tiếp trong mã nguồn `drift` (`lib/src/runtime/query_builder/expressions/datetimes.dart`,
docstring `{@template drift_datetime_timezone}`): "Even if the date time stored was in a local
timezone, this format returns the formatted value in UTC." `transactions.occurredAt` lưu ở chế độ
unix-timestamp mặc định (không bật `storeDateTimeAsText`), và mọi `DateTime` chèn vào (quick-add,
importer Rolly Phase 9) là **local naive** rồi drift tự `.toUtc()` khi ghi — nên một giao dịch lúc
2h sáng giờ VN (UTC+7) ngày 1 đầu tháng, nếu gộp bằng `.year`/`.month` thẳng, sẽ bị `strftime` tính
thành 19h ngày CUỐI THÁNG TRƯỚC theo UTC → gộp nhầm sang tháng sai, đúng loại "bug ngày/tháng" mà
TODOS.md cảnh báo và chính review Rolly than phiền.

**Xác minh cả SQLite bundle**: `sqlite3` nhúng qua Dart build hooks (sqlite3mc, Phase 3) là bản
**3.53.4** (đo trực tiếp bằng `SELECT sqlite_version()` qua `openTestDatabase()`, không đoán) — đủ
mới cho cả `strftime(..., 'localtime')` (đã có từ SQLite cổ) lẫn `SUM(x) FILTER (WHERE ...)` (cần
≥3.30). Máy dev này (và AVD/điện thoại Tony) đều đặt múi giờ hệ thống `Asia/Ho_Chi_Minh`, nên
modifier `localtime` của SQLite (đọc timezone OS lúc TRUY VẤN) khớp đúng với timezone lúc GHI —
vòng lặp local→UTC→local đóng kín chính xác, miễn app không đổi múi giờ hệ thống giữa hai lần.

**Quyết định:** `ReportsRepository.watchMonthlyTrend`/`watchDailySpend` luôn gọi
`t.occurredAt.modify(const DateTimeModifier.localTime())` trước khi `.year`/`.month`/`.date` —
khoá lại bằng test dựng đúng tình huống biên (giao dịch `DateTime(2026, 1, 1, 2, 0)` phải gộp vào
tháng 1, không phải tháng 12/2025) trong `test/data/repositories/reports_repository_test.dart`.

## 2026-08-21 · Phase 10 · fl_chart 1.2.0: PieChart/LineChart/BarChart đều tự tween nội bộ — phải tắt bằng `duration: Duration.zero` để tự điều khiển animation
Đọc thẳng `fl_chart-1.2.0/lib/src/chart/*/**.dart` (không theo tutorial/blog — 1.x đổi API hoàn
toàn so với 0.6x như TODOS.md cảnh báo): cả ba widget `PieChart`/`LineChart`/`BarChart` đều
`extends ImplicitlyAnimatedWidget`, mặc định `duration: Duration(milliseconds: 150)` — MỌI lần
`ChartData` đổi (kể cả chỉ đổi `radius` một section) chúng tự nội suy (tween) từ giá trị cũ sang
mới. Ba quyết định animation bắt buộc của Phase 10 (tròn animate bán kính chứ không góc quét; đường
animate bằng clip trái→phải; cột animate lệch pha 30ms) đều cần một `AnimationController` RIÊNG của
ứng dụng điều khiển, không phải animation nội bộ của fl_chart — nếu không tắt, hai lớp animation
chồng lên nhau (tween nội bộ CHẠY THÊM một lần nữa mỗi khi `AnimatedBuilder` của ta đổi `radius`),
cho cảm giác giật/kéo dài không kiểm soát được.

**Quyết định:** mọi `PieChart`/`LineChart`/`BarChart` trong `lib/features/reports/widgets/` đều
truyền `duration: Duration.zero` — dữ liệu đưa vào chart LUÔN Ở TRẠNG THÁI CUỐI (tĩnh), animation
"vẽ vào" hoàn toàn do `AnimationController` riêng của từng widget con điều khiển (radius/clip-rect/
per-bar growth factor), chạy đúng MỘT LẦN ở `initState`. Icon trên mỗi lát bánh dùng
`PieChartSectionData.badgeWidget` (xác nhận có tồn tại từ source, không phải đoán) thay vì cố nhét
icon vào `title` (chỉ nhận `String`).

## 2026-08-21 · Phase 10 · Sentinel `categoryColorId = -1` cho "Khác"/"Chưa phân loại" tận dụng `%` không âm của Dart
Biểu đồ tròn cần hai khái niệm KHÔNG PHẢI danh mục thật đều tô màu xám trung tính: lát "Khác" (gộp
danh mục hạng 7 trở đi, bài học `CategoryBucketKey` ở Phase 9 — không được lẫn với khái niệm dưới)
và "Chưa phân loại" (`categoryId IS NULL` ở DB). Cả hai dùng `categoryColorId = -1` — số NGOÀI dải
0–11 của `paletteCategoryColors` một cách CÓ CHỦ ĐÍCH. `reportCategoryColor()` resolve màu bằng
đúng công thức modulo `CategoryAvatar` đã dùng (`fills[categoryColorId % fills.length]`), và vì
toán tử `%` trên `int` ở Dart LUÔN trả kết quả không âm khi chia cho số dương (khác Java/C, đã xác
minh bằng test), `-1 % 12 == 11` — trúng ngay chỉ số màu xám cuối bảng, không cần nhánh `if` riêng
cho sentinel. Quyết định giữ nguyên field `Category.categoryColorId` là `int` không nullable (D10)
mà không cần đổi kiểu hay thêm enum — sentinel nằm gọn trong không gian giá trị sẵn có.

## 2026-08-21 · Phase 10 · Bento filter: preset khoảng ngày (không phải calendar picker), category multi-select qua sheet
Đặc tả "Bottom-sheet-first" (design system) nói chọn ngày phải qua sheet, không phải dialog Material
— nhưng không bắt buộc PHẢI là lịch hai đầu tự do. Cân nhắc chi phí/lợi ích: dựng một calendar range
picker tuỳ biến (không package nào có sẵn kiểu sheet, `showDateRangePicker` là dialog Material)
tốn công không tương xứng với một màn báo cáo cá nhân. **Quyết định:** sheet liệt kê 5 preset (7
ngày/30 ngày/3 tháng/6 tháng/Tất cả) — đủ cho mọi nhu cầu xem báo cáo cá nhân, và mặc định "6 tháng
qua" cho ra dữ liệu có ý nghĩa ngay khi mở tab (khớp khoảng dữ liệu Rolly đã import ở Phase 9, ~4
tháng). Danh mục lọc qua sheet multi-select dạng `AppChip`, không phải dialog checkbox Material.

## 2026-08-21 · Phase 10 · Xác minh hiệu năng + trực quan bằng dữ liệu THẬT đã import (Phase 9)
Đo tự động (`test/features/reports/reports_performance_real_data_test.dart`, SKIP nếu
`raw_rolly/input.json` không có trên máy): 354 giao dịch thật (loại trừ cặp Savings-transfer) qua
đủ 4 truy vấn SQL của `ReportsRepository` + xử lý domain (gộp lát bánh, dựng lưới heatmap) — **69ms
trên máy dev**, dưới xa ngưỡng 500ms yêu cầu (dù máy dev nhanh hơn Redmi Note 13 Pro nhiều, đây là
bằng chứng SQL aggregation không suy biến theo khối lượng thật, không phải chỉ dữ liệu mẫu vài dòng).

Quan trọng hơn: verify TRỰC TIẾP trên emulator với DB THẬT của Tony (dữ liệu đã import từ Phase 9,
vẫn còn nguyên trên emulator) — cài đè APK v0.4.0 lên bản đang chạy (KHÔNG schemaVersion bump lần
này, không có migration nào chạy, rủi ro dữ liệu thấp hơn cả lần cài v0.3.0 ở Phase 9), mở tab Báo
cáo: `Tổng thu +97.280.000 ₫` khớp CHÍNH XÁC oracle Phase 9/Phase 2; lịch heatmap những tuần đầu
(trước khi Tony bắt đầu dùng Rolly) đúng là trống — không phải bug, là phản ánh thật của dữ liệu;
chạm biểu đồ tròn mở đúng sheet "Toàn bộ danh mục" liệt kê hết 11 danh mục thay vì chỉ 7 lát rút gọn.

⚠️ **Rủi ro chưa giải quyết, mang sang phase sau:** Tony yêu cầu tường minh "backup dữ liệu trước
khi cài" kể từ build này — nhưng KHÔNG có cơ chế backup nào dùng được thật trên thiết bị: `adb
backup` bị chặn bởi `allowBackup=false` (cố ý, D3, bảo mật); `adb shell run-as` thất bại vì release
build không debuggable (đã ghi từ Phase 9); UI backup trong Settings vẫn chưa được gắn (service layer
có từ Phase 4, Backlog). Cài v0.4.0 lần này CHẤP NHẬN ĐƯỢC vì không có migration (rủi ro thấp hơn
Phase 9's v1→v2), nhưng khoảng trống này cần đóng TRƯỚC khi có phase nào khác động vào schema.

## 2026-08-21 · Phase 11 · Kỳ ngân sách — QUYẾT ĐỊNH TRƯỚC KHI CODE (yêu cầu tường minh của prompt)
Ba câu hỏi bắt buộc trả lời trước khi viết `BudgetRepository`, đúng chỗ TODOS.md cảnh báo là "chỗ
trú của loại bug ngày/tháng":

**1. Kỳ ngân sách: THÁNG THEO LỊCH, không phải cửa sổ cuốn chiếu.** Không thực sự là một lựa chọn
mở — bảng `budgets` đã tồn tại từ Phase 4 với cột `year_month TEXT` (`'YYYY-MM'`) + UNIQUE
`(category_id, year_month)`, không có cột "ngày bắt đầu kỳ" nào để mô hình một cửa sổ N-ngày cuốn
chiếu. Tôn trọng schema đã có thay vì thiết kế lại — và tháng lịch khớp cách người Việt nghĩ về
lương/tiền nhà/chi tiêu hàng tháng, khớp luôn "chi tiêu từ đầu tháng" đã dùng ở hero card từ Phase 6.

**2. KHÔNG carry-over phần dư sang tháng sau.** Mỗi kỳ độc lập hoàn toàn: `amountMinor` của tháng
sau không phái sinh từ số dư tháng trước, phải nhập lại (hoặc để trống nếu Tony không đặt). Carry-
over về bản chất là một biến trạng thái CỘNG DỒN qua các tháng — đúng thứ D7 cấm ("không lưu bộ đếm,
không có cache thì không thể sai"): nếu cho carry-over, "ngân sách hiệu lực" của tháng 8 phụ thuộc
kết quả tính của tháng 7, của tháng 6, ... một chuỗi suy ra ngược vô hạn thay vì một con SUM độc lập.
Cũng là hành vi mặc định của đa số app ngân sách phổ biến (YNAB là ngoại lệ có chủ đích, không phải
chuẩn ngầm định) nên không bất ngờ với người dùng.

**3. Ranh giới tháng: LOCAL wall-clock (Asia/Ho_Chi_Minh), tính bằng SO SÁNH KHOẢNG, không phải
strftime.** Khác Phase 10 (`watchMonthlyTrend`/`watchDailySpend` phải TRÍCH năm/tháng từ cột
`occurredAt` bằng `strftime`, nên cần `.modify(DateTimeModifier.localTime())` để tránh lệch UTC),
`BudgetRepository.watchBudgetsForPeriod` chỉ SO SÁNH `occurredAt` với hai mốc
`DateTime(year, month, 1)`/`DateTime(year, month + 1, 1)` — dựng bằng ĐÚNG constructor `DateTime(...)`
mà mọi nơi khác trong app dùng để chèn `occurredAt` (quick-add, importer). Không có bước trích xuất
qua SQL string nào ở giữa nên không có chỗ cho UTC-vs-local lệch nhau xen vào — phép so sánh số
nguyên (epoch) tự nhất quán ở cả hai đầu ghi/đọc. Xác nhận bằng test biên: giao dịch đúng 00:00 đầu
tháng sau KHÔNG được tính, giao dịch 23:59:59 cuối tháng CÓ được tính, và ranh giới chuyển năm
(tháng 12 → tháng 1 năm sau) không lẫn dữ liệu — `test/data/repositories/budget_repository_test.dart`.
`BudgetPeriod.end` dùng `DateTime(year, month + 1, 1)` (Dart tự chuẩn hoá `month: 13` thành tháng 1
năm sau) và `daysInMonth` dùng mẹo `DateTime(year, month + 1, 0).day` — cả hai xác nhận đúng bằng
test bao gồm năm nhuận (2024) và năm thường (2026), không đoán từ trí nhớ về lịch.

## 2026-08-22 · Phase 13 · Chiến lược migration 3→4: `alterTable`/`TableMigration` cho `walletId`, `addColumn` thường cho phần còn lại
`transactions.walletId` là cột **NOT NULL** có FK, cần backfill một giá trị chỉ biết được LÚC CHẠY
migration (id của "Ví mặc định" vừa `INSERT`, không phải hằng số biên dịch) — `m.addColumn()` không
xử lý được ca này vì SQLite chỉ cho `ALTER TABLE ADD COLUMN ... NOT NULL` khi có `DEFAULT` là hằng số
tĩnh. Giải pháp đúng (đọc thẳng `drift-2.34.0/lib/src/runtime/query_builder/migration.dart`, không
đoán): `Migrator.alterTable(TableMigration(...))` — dựng lại bảng dưới tên tạm, `INSERT INTO ... SELECT`
copy toàn bộ cột cũ + cột mới qua `columnTransformer` (một `Expression`, ở đây là `Constant(defaultWalletId)`
— giá trị runtime nhúng thẳng vào), `DROP` bảng cũ, đổi tên bảng tạm — và tự động dựng lại mọi
index/trigger gắn với bảng đó (đọc từ `sqlite_master`), nên `idx_transactions_source_id` (Phase 9)
sống sót qua bước này mà không cần tự tay tạo lại.

`isTransfer` (có default `Constant(false)`) và `linkedTransactionId` (nullable, không default) dùng
`m.addColumn()` thường — an toàn với bảng đã có dữ liệu vì SQLite cho phép `ADD COLUMN` nullable
hoặc có `DEFAULT` hằng số trên bảng không rỗng, đúng tiền lệ `sourceId` (Phase 9) và `isActive`
(Phase 12). `categories.parentCategoryId` (nullable, tự tham chiếu `Categories.id`) và `sortOrder`
(default `0`) cũng dùng `addColumn` thường — không cột nào trong hai cột này cần giá trị runtime.

Thứ tự các bước TRONG `onUpgrade(from < 4)`: (1) `createTable(wallets)`, (2) `INSERT` "Ví mặc định"
lấy `defaultWalletId`, (3) `alterTable` cho `transactions.walletId` dùng `defaultWalletId` vừa có,
(4) `addColumn` cho `isTransfer`/`linkedTransactionId`, (5) `addColumn` cho hai cột mới của
`categories`. Bọc test bằng dữ liệu THẬT (358 giao dịch Phase 9 đã import) — không chỉ fixture nhỏ —
đếm đúng N dòng trước/sau, `SUM(amountMinor)` khớp tuyệt đối, 100% `walletId` khác NULL trỏ đúng ví
mặc định.

## 2026-08-22 · Phase 13 · Chuyển khoản: cặp giao dịch liên kết, `categoryId: null`, loại khỏi báo cáo qua MỘT điều kiện lọc thêm
Chuyển khoản giữa 2 ví tạo **hai dòng `transactions` thật**, không phải một dòng có cờ ẩn số tiền đối
ứng: ví nguồn nhận một dòng `amountMinor` ÂM, ví đích nhận một dòng `amountMinor` DƯƠNG, cả hai
`isTransfer: true` và `linkedTransactionId` trỏ NHAU (insert dòng nguồn trước với `linkedTransactionId
= null`, insert dòng đích với `linkedTransactionId = id dòng nguồn`, rồi `UPDATE` dòng nguồn trỏ
ngược lại — an toàn với FK tự tham chiếu vì SQLite kiểm tra ràng buộc theo TỪNG câu lệnh, không hoãn
lại, và tại mỗi bước dòng được tham chiếu đã tồn tại).

**`categoryId: null` cho cả hai dòng** — chuyển khoản không phải khoản chi hay khoản thu, không có
danh mục, giống hệt cách Phase 9 đã phải tách riêng bucket "Savings/transfer" của Rolly khỏi khái
niệm "chưa phân loại" (`CategoryBucketKey.savingsTransfer()`) vì gộp chung `null` sẽ trộn hai khái
niệm khác nhau.

**Loại khỏi báo cáo/ngân sách CHỈ bằng cách thêm `& t.isTransfer.equals(false)` vào predicate đã có**
của `ReportsRepository` (`watchCategoryBreakdown`, `watchMonthlyTrend`, `watchDailySpend`,
`watchPeriodSummary`), `BudgetRepository.watchBudgetsForPeriod`, và
`TransactionRepository.watchMonthToDateSummary` (hero card) — không viết lại logic gộp SQL đã có,
đúng yêu cầu tường minh của prompt. **`TransactionRepository.watchBalance()` KHÔNG được đụng vào** —
tổng tiền toàn app đã tự nhiên bất biến qua một lượt chuyển khoản (`-X + X = 0`) mà không cần lọc gì,
và nếu sau này có số dư THEO TỪNG VÍ, số dư đó PHẢI tính cả hai dòng chuyển khoản (chuyển khoản có
tác động thật lên số dư của từng ví, chỉ không phải "thu/chi" ở góc nhìn TOÀN VÍ).

## 2026-08-22 · Phase 13 · Bộ lọc ví: mặc định TẤT CẢ VÍ ở mọi màn, KHÔNG thêm bộ chọn ví trong phase này
"Mọi màn hình đang giả định một ví duy nhất... cần bộ lọc ví (mặc định: tất cả ví, hoặc ví đang chọn
— quyết định UX cụ thể khi code)" — quyết định: **luôn luôn tất cả ví** (hero card, Báo cáo, Ngân
sách đều `SUM`/`JOIN` qua toàn bộ `transactions` không lọc theo `walletId`), không thêm UI chọn một
ví cụ thể ở phase này. Lý do: trước phase này app vốn chỉ có MỘT ví ẩn (không có khái niệm ví) — hành
vi "tất cả ví" giữ nguyên trải nghiệm hiện tại 100%, không có gì bị lùi cấp; thêm bộ chọn ví là một
tính năng lọc MỚI, không phải yêu cầu bắt buộc để migration này không phá vỡ gì. Để dành cho phase
sau nếu Tony thật sự cần "xem báo cáo riêng một ví" (ví dụ khi có ≥2 ví thật). Ngân sách đặc biệt
KHÔNG có chiều ví — ngân sách gắn với danh mục, không gắn với ví, nên không có khái niệm "lọc ngân
sách theo ví" để bàn ở đây.

## 2026-08-22 · Phase 13 · Gộp danh mục: LUÔN reassign rồi archive nguồn, KHÔNG BAO GIỜ xoá cứng
Gộp danh mục A vào B: chuyển hết `transactions.categoryId`, `recurringTransactions.categoryId` từ A
sang B; với `budgets` — nếu B đã có ngân sách cùng `yearMonth` thì XOÁ ngân sách đó của A (giữ của B,
tránh vi phạm UNIQUE `(categoryId, yearMonth)`), ngược lại reassign sang B; với `categoryKeywords` —
nếu B đã có cùng `keyword` thì XOÁ khoá đó của A (giữ của B, tránh vi phạm UNIQUE
`(categoryId, keyword)`), ngược lại reassign sang B. Sau khi reassign xong, đặt `A.isArchived = true`
— **KHÔNG** `DELETE` hàng A. Lý do nhất quán với triết lý "archive, không xoá cứng" đã áp dụng cho ví
(D-checklist Phase 13) và cho chính `categories.isArchived` (có từ Phase 4, giờ mới thật sự dùng):
xoá cứng một danh mục đã có lịch sử giao dịch tham chiếu (dù đã reassign hết) làm mất khả năng truy
vết "khoản này từng thuộc danh mục nào trước khi gộp" nếu sau này cần audit/export, và một `id` đã
archive vẫn an toàn để backup/restore round-trip qua đúng `id` (giữ nguyên tinh thần Phase 9's
"restore là thay thế toàn bộ, không phải merge" — id ổn định xuyên suốt).

## 2026-08-22 · Phase 13 · Danh mục con CHỈ MỘT CẤP — `parentCategoryId` không được trỏ tới một danh mục đã có `parentCategoryId`
Ngăn từ tầng ứng dụng (validate ở `CategoryRepository.insert`/`update`, không phải CHECK constraint
DB): một danh mục ĐÃ có `parentCategoryId != null` không được chọn làm cha của danh mục khác — chỉ
danh mục CẤP GỐC (`parentCategoryId == null`) mới được chọn làm cha. Lý do: "Nhóm danh mục 3 tầng" là
một mục Backlog RIÊNG, KHÁC với "danh mục con" của Phase 13 (xem `docs/competitor-feature-research.md`
mục 1 vs mục 4) — cho phép lồng sâu vô hạn ở đây là tự ý mở rộng phạm vi ngoài checklist đã chốt.
UI kéo-thả sắp xếp (`sortOrder`) áp dụng cho danh mục CẤP GỐC; danh mục con hiển thị lồng dưới cha,
sắp theo `sortOrder` riêng nhưng KHÔNG có UI kéo-thả cho chúng ở v1 (cắt phạm vi có chủ đích — giá trị
thấp so với công sức thêm một `ReorderableListView` lồng nhau, ghi rõ ở đây để không ai tưởng đây là
thiếu sót).

## 2026-08-22 · Phase 13 · "Ví/danh mục mặc định" cho quick-add và importer: ví có `id` NHỎ NHẤT, không thêm cột `isDefault`
Quick-add (chat NLP) và importer CSV/Rolly (Phase 9) không có khái niệm chọn ví trong luồng của
chúng — cả hai cần MỘT walletId hợp lệ để thoả `NOT NULL`. Quyết định: "ví mặc định" = ví có `id`
nhỏ nhất hiện có (`WalletRepository.defaultWalletId()`, `SELECT id FROM wallets ORDER BY id LIMIT 1`),
KHÔNG thêm cột `isDefault` boolean mới — luôn có ít nhất một ví (migration/`onCreate` đảm bảo), và
ví đầu tiên tạo ra ("Ví mặc định") tự nhiên có `id` nhỏ nhất, không cần cờ riêng để đánh dấu. Không
thêm bộ chọn ví vào màn quick-add ở phase này — ngoài phạm vi Phase 13 (quản lý ví + gán ví thủ công
ở form sửa), rethinking luồng NLP là việc của phase khác nếu Tony cần.

## 2026-08-21 · Phase 12 · Package: bản mới nhất tương thích Flutter 3.44.1, KHÔNG bản mà blog/ví dụ cũ vẫn dùng
Đọc trực tiếp `CHANGELOG.md` + source trong `~/.pub-cache` cho cả 4 package trước khi viết dòng nào
(luật nghiên cứu trước) — `flutter pub get` với `^` caret ban đầu tự chọn bản CŨ hơn bản mới nhất
(vd. `local_auth 2.3.0` dù `3.0.2` đã có), phải tự nâng ràng buộc và pub get lại để xác nhận bản mới
nhất thật sự resolve được trên `meta 1.18.0`/Flutter 3.44.1 trước khi chốt.

**`local_auth: ^3.0.2`** (không phải 2.x — gần như mọi ví dụ trên mạng vẫn dùng 2.x). **BREAKING ở
3.0.0**: `authenticate()` ném `LocalAuthException` (không còn trả `false`/`PlatformException` cho
lỗi hệ thống — chỉ trả `false` khi người dùng thất bại thử thách xác thực thật, KHÔNG side effect
nào khác) và bỏ `AuthenticationOptions` object, thay bằng tham số đặt tên rời (`biometricOnly`,
`sensitiveTransaction`, `persistAcrossBackgrounding`). Xuống cấp êm dựa vào bắt các mã
`LocalAuthExceptionCode.noBiometricHardware`/`.noBiometricsEnrolled`/`.noCredentialsSet` — ba mã
riêng biệt, không gộp một `false` chung chung.

**`workmanager: ^0.10.9`**. `0.10.0` là breaking (nâng Flutter tối thiểu lên 3.38, đã thoả 3.44.1).
API `Workmanager().initialize()`/`registerPeriodicTask()`/`executeTask()` không đổi hình dạng từ
0.9.x — an toàn để nâng thẳng bản mới nhất mà không đổi code gọi. KHÔNG cần Application class riêng
(đã kiểm chứng bằng cách đọc thẳng `AndroidManifest.xml` bundled trong `workmanager_android` — chỉ
merge permission + service, không đòi `Configuration.Provider` tự viết).

**`flutter_local_notifications: ^22.3.0`**. Loạt breaking `20.0.0`→`21.0.0` đổi hầu hết tham số vị
trí (positional) sang tham số đặt tên (named) ở `initialize()`/`zonedSchedule()`/... — đã viết code
theo đúng named-parameter hiện tại, xác nhận bằng cách đọc thẳng
`lib/src/flutter_local_notifications_plugin.dart`, không theo ví dụ cũ trên mạng.

**`permission_handler: ^13.0.1`** — không breaking đáng kể ảnh hưởng `Permission.notification`.

## 2026-08-21 · Phase 12 · Auto-backup: KHÔNG hứa "chạy đúng giờ mỗi ngày" — giới hạn thật của Doze/App Standby
`Workmanager().registerPeriodicTask(frequency: Duration(hours: 24))` (AndroidX WorkManager phía
dưới) **không đảm bảo chạy đúng 24h** — hệ thống có quyền trì hoãn đáng kể khi máy vào Doze/App
Standby (đặc biệt nếu Tony không mở máy/sạc pin nhiều giờ liền), và khoảng linh hoạt tối thiểu của
WorkManager cho periodic work là 15 phút, không phải một mốc giờ cụ thể. Quyết định: **health-check
mỗi lần app resume (H6, xem TODOS.md) mới là lưới an toàn CHÍNH**, `workmanager` chỉ là "đai an toàn
thêm" — đúng tinh thần D5 ghi từ Phase 1 khi tính năng này còn bị hoãn. Copy Settings **không bao giờ
in con số "sao lưu lúc HH:MM mỗi ngày"** — chỉ hiện "Sao lưu tự động: đang bật" + thời điểm sao lưu
GẦN NHẤT thực sự chạy (đọc từ `shared_preferences`, ghi lại mỗi lần worker chạy xong), không hứa giờ
tương lai.

**Local notification nhắc giao dịch định kỳ dùng `AndroidScheduleMode.inexactAllowWhileIdle`**, không
phải `exact`/`exactAllowWhileIdle` — hai mode "exact" đòi quyền `SCHEDULE_EXACT_ALARM` (Android 12+,
cần khai báo Play Console + có thể bị thu hồi), đổi lấy một quyền hạn chế cho một tính năng chỉ là
NHẮC (không phải báo thức) là không đáng. `inexactAllowWhileIdle` vẫn nổ được trong Doze, chỉ lệch
vài phút — chấp nhận được cho "nhắc đến hạn giao dịch định kỳ", không chấp nhận được cho báo thức.

## 2026-08-21 · Phase 12 · `recurring_transactions.next_occurrence_date` là NGOẠI LỆ có chủ đích với D7, không phải vi phạm
D7 cấm lưu **giá trị dẫn xuất được** (như `balance = SUM(amountMinor)`) vì cache thì có thể sai lệch
khỏi nguồn sự thật. `nextOccurrenceDate` KHÔNG phải giá trị dẫn xuất — nó là một **con trỏ lịch
trình** (scheduling cursor): một khi cho phép tạm dừng/bỏ qua một kỳ (tính năng hợp lý cho giao dịch
định kỳ, dù chưa xây UI ở phase này), giá trị này không còn tính lại được thuần tuý từ
`createdAt + frequency + thời gian hiện tại` nữa — nó phụ thuộc lịch sử thao tác, giống hệt
`versionCode`/con trỏ trạng thái máy trạng thái hữu hạn, không giống `balance`. Mỗi lần một giao
dịch định kỳ "đến hạn" được xử lý (dù chỉ là nhắc, xem quyết định dưới), `advanceToNextOccurrence()`
tính lại bằng `computeNextOccurrence(current, frequency)` và GHI ĐÈ — một phép chuyển trạng thái
tường minh, không phải một cache im lặng có thể lệch.

## 2026-08-21 · Phase 12 · Nhắc định kỳ CHỈ là thông báo, KHÔNG tự động tạo giao dịch
Theo đúng tinh thần LUẬT #7 ("không bao giờ tự động commit một kết quả parse — luôn hiện thẻ xác
nhận sửa được"): thông báo local đến hạn chỉ MỞ app tới màn quản lý giao dịch định kỳ, KHÔNG tự
`INSERT` một dòng vào `transactions`. Tony phải xác nhận thủ công (qua quick-add hoặc form, tái
dùng luồng đã có) — nhất quán với việc app không bao giờ tự ý ghi sổ mà không qua một bước xác nhận
của con người, dù nguồn là parser tiếng Việt (Phase 7/8) hay một giao dịch định kỳ đã lên lịch.
Hệ quả: bảng `recurring_transactions` KHÔNG cần cột liên kết ngược tới `transactions` đã tạo từ nó —
chưa có khái niệm "giao dịch này sinh ra từ mẫu định kỳ nào" ở phase này (để lại cho phase sau nếu
cần).

## 2026-08-21 · Phase 12 · Khoá vân tay: test bằng `LocalAuthPlatform` giả, không cần cảm biến thật trên emulator
`tonyfino36` (AVD) không chắc có cảm biến vân tay ảo được cấu hình sẵn — và bản thân TODOS.md yêu
cầu tường minh "test khoá vân tay bằng `local_auth` GIẢ (thành công/thất bại/không có cảm biến)",
không phải test tay trên thiết bị thật. Ba kịch bản (thành công, thất bại xác thực, không có phần
cứng — ném `LocalAuthExceptionCode.noBiometricHardware`) test bằng cách override
`LocalAuthPlatform.instance` bằng một fake trong widget test, cùng kỷ luật đã dùng cho
`FilePickerPlatform`/`SharedPreferencesAsync` (Phase 8/9) — không cần platform channel thật chạy
trên máy host hay device thật. Việc còn lại chỉ xác nhận toggle Settings HIỂN THỊ đúng và không
crash trên emulator thật (không xác nhận luồng xác thực sinh trắc học thật, máy dev không có).

## 2026-08-21 · Phase 11 · Vạch nhịp: diễn giải "4 trạng thái golden" thành 4 ví dụ trực quan của CÙNG 3 màu
Đặc tả liệt kê 3 màu (xanh/vàng/đỏ, tương ứng `computeBudgetPaceState` → `onTrack`/`trendingOver`/
`over`) nhưng mục Xác minh lại nói "golden vòng ngân sách ở 4 trạng thái (dưới nhịp / trên nhịp /
cảnh báo / vượt)". Không có mô tả nào cho một MÀU thứ 4 — quyết định: đây là 4 CẶP (progress, pace)
minh hoạ cụ thể, không phải 4 giá trị enum. "Trên nhịp" và "cảnh báo" đều là `trendingOver` (vàng)
nhưng ở hai mức độ khác nhau (trên nhịp nhẹ ở giữa tháng · cảnh báo khi tiến sát 100% dù còn vài
ngày) để bao phủ dải hình ảnh rộng hơn, không phải vì có logic màu riêng. Golden ở
`test/ui/widgets_golden_test.dart` (`budget_ring`).

## 2026-08-22 · Phase 14 · Migration 4→5: hai bảng MỚI hoàn toàn, cùng mức rủi ro thấp như v2→v3
`transaction_lines` + `transaction_templates` không đụng cột nào của 7 bảng cũ — không có backfill
nào cần lo, không cần `alterTable`/`TableMigration` (khác migration lớn Phase 13). Test hand-written
`migration_test.dart` xác nhận dữ liệu cũ (danh mục + ví + giao dịch) sống sót nguyên vẹn, hai bảng
mới tồn tại nhưng trống sau nâng cấp.

## 2026-08-22 · Phase 14 · Tách giao dịch: hai đường dữ liệu cùng tồn tại qua MỘT "hàng hiệu lực" hợp nhất bằng UNION ALL
`ReportsRepository`/`BudgetRepository` gộp theo danh mục ở 5 chỗ, tất cả trước đây đọc thẳng
`transactions.category_id`/`amount_minor`. Giao dịch tách dòng (Phase 14) cần gộp theo
`transaction_lines.category_id` của TỪNG dòng con thay vì một `category_id` duy nhất của giao dịch
cha (giờ luôn `NULL` khi có dòng con — xem quyết định kế tiếp). Viết lại toàn bộ 5 query để đọc hai
nguồn song song là trùng lặp logic nguy hiểm (dễ lệch khi một bên sửa mà quên bên kia). Chốt:
`lib/data/repositories/effective_category_amounts.dart` — một hàm trả về một `Subquery` drift hợp
nhất bằng `UNION ALL`: nhánh 1 là giao dịch KHÔNG có dòng con nào (`transaction.id NOT IN (SELECT
transaction_id FROM transaction_lines)`, đọc `transactions.category_id`/`amount_minor`), nhánh 2 là
`transaction_lines` JOIN `transactions` (đọc `transaction_lines.category_id`/`amount_minor`, cùng
`occurred_at`/`is_transfer` mượn từ giao dịch cha). Một giao dịch chỉ rơi vào ĐÚNG MỘT nhánh — không
bao giờ cả hai — vì `TransactionRepository.insert`/`update` LUÔN set `transactions.category_id =
NULL` ngay khi giao dịch có dòng con. Cả 5 query chỉ cần đổi `_db.transactions` → subquery này rồi
`.ref(_db.transactions.xxx)` để đọc cột, KHÔNG viết lại logic gộp/JOIN/FILTER đã có (đúng yêu cầu gốc
— chỉ thêm, không viết lại). `watchPeriodSummary`'s "N giao dịch" đổi từ `COUNT(*)` sang
`COUNT(DISTINCT transactionId)` — một giao dịch tách N dòng sinh N hàng hiệu lực, đếm thô sẽ báo sai
số giao dịch dù không sai số tiền.

**Cạm bẫy đã bắt được bằng cách in SQL thật, không đoán:** khi statement gốc là `selectOnly(subquery)`
(bắt buộc cho `Subquery` — không có `select(subquery)`), JOIN thêm vào (vd. `categories`) mặc định
KHÔNG tự đưa cột của bảng đó vào kết quả (khác `select(t).join(...)`, luôn tự làm điều đó) — thiếu
`useColumns: true` ở `leftOuterJoin`, `row.readTableOrNull(categories)` luôn trả `null` dù JOIN khớp
đúng ở tầng SQL. Xem chi tiết ở `ReportsRepository.watchCategoryBreakdown`.

## 2026-08-22 · Phase 14 · Giao dịch tách dòng: `transactions.category_id` cha luôn `NULL`, không giữ "danh mục đại diện" nào
Cân nhắc giữ `categoryId` gốc trên giao dịch cha (để hiển thị nhanh không cần JOIN `transaction_lines`
mỗi lần), nhưng bỏ — một khi đã tách, không còn "một danh mục đúng" nào cho cả giao dịch, giữ lại một
giá trị cũ dễ đọc nhầm là "danh mục thật" ở bất kỳ chỗ nào quên kiểm tra `linesCount`/dòng con trước.
`NULL` buộc mọi call site phải tự hỏi "giao dịch này có tách không" thay vì âm thầm dùng sai giá trị.
UI (`TransactionRow`/`SavedTransactionRow`/`DraftCard`) phân biệt "chưa phân loại" (categoryId null,
linesCount 0) với "đã tách" (categoryId null, linesCount > 0) qua `TransactionWithCategory.isSplit`
— một cột đếm dòng con qua subquery vô hướng, không phải cột lưu cứng.

## 2026-08-22 · Phase 14 · Nhân đôi giao dịch: viết lại từ "chèn ngay + Hoàn tác" (Phase 8) sang "mở sheet Thêm điền sẵn"
Bản Phase 8 (`duplicateTransactionWithUndo`) chèn bản sao NGAY LẬP TỨC rồi cho 6 giây Hoàn tác qua
SnackBar — hợp lý khi "nhân đôi" chỉ là một nút phụ trong sheet hành động nhấn giữ (quick-add). Yêu
cầu Phase 14 tường minh khác: "tạo bản sao... mở sẵn sheet sửa để chỉnh trước khi lưu thật" — tức là
PHẢI cho chỉnh (số tiền/danh mục/ngày/ghi chú, kể cả tách dòng) TRƯỚC khi ghi thật, không phải
ghi-trước-sửa-sau. Đổi hẳn cơ chế: `TransactionFormPrefill` (số tiền/danh mục/ghi chú/ví, KHÔNG có
ngày — ngày luôn là hôm nay) mở `TransactionFormSheet` ở chế độ THÊM (không phải SỬA) đã điền sẵn.
Không ghi gì vào DB cho tới khi tự bấm "Lưu". `openDuplicateTransactionSheet` thay thế
`duplicateTransactionWithUndo` ở cả hai lối vào cũ (nút "Nhân đôi" trong sheet Sửa, mục "Nhân đôi"
trong sheet hành động nhấn giữ của quick-add) — chỉ một cơ chế, dùng chung cho cả hai chỗ.

## 2026-08-22 · Phase 14 · Mẫu giao dịch: snapshot lúc tạo, KHÔNG có FK ngược từ `transactions` — xoá là xoá thật
`transaction_templates` không có cột nào tham chiếu ngược từ `transactions` (khác `budgets`/
`category_keywords`, đều `references(Categories, #id)`) — "áp dụng mẫu" đơn thuần là đọc snapshot của
mẫu rồi mở `TransactionFormSheet` Thêm điền sẵn (cùng cơ chế `TransactionFormPrefill` với "Nhân đôi"
ở trên), sau đó Tony tự bấm Lưu để tạo MỘT giao dịch bình thường — không có bảng nào ghi lại "giao
dịch X được tạo từ mẫu Y". Nhờ cấu trúc này, "sửa/xoá một mẫu không ảnh hưởng giao dịch đã tạo từ nó
trước đây" đúng THEO THIẾT KẾ (không có gì để xoá theo, không có gì để lệch), không cần logic bảo vệ
riêng. Hệ quả: `TransactionTemplateRepository.delete` là xoá cứng thật sự (khác `wallets`/
`categories`, luôn lưu trữ chứ không xoá) — mẫu không phải dữ liệu tài chính, chỉ là một khuôn điền
sẵn, không có lý do giữ lại bản đã xoá.

## 2026-08-22 · Phase 15 · Carry-over — QUYẾT ĐỊNH TRƯỚC KHI CODE (đảo quyết định Phase 11, cần lý do MỚI)

Phase 11 chốt KHÔNG carry-over với lý do cụ thể (xem § Phase 11 ở trên): "carry-over về bản chất là
một biến trạng thái CỘNG DỒN qua các tháng... nếu cho carry-over, 'ngân sách hiệu lực' của tháng 8
phụ thuộc kết quả tính của tháng 7, của tháng 6, ... một chuỗi suy ra ngược VÔ HẠN thay vì một con
SUM độc lập". Đó không phải phản đối "carry-over nói chung" — đó là phản đối một thiết kế carry-over
CỤ THỂ: kiểu "envelope" đệ quy, nơi số dư một danh mục cộng dồn xuyên suốt lịch sử không giới hạn
(giống YNAB), buộc mỗi lần tính phải lần ngược vô hạn kỳ trước.

**Lý do MỚI (không phải "vì có trong backlog"): tồn tại một thiết kế carry-over BỊ CHẶN (bounded),
không đệ quy, giải quyết ĐÚNG phản đối kỹ thuật của Phase 11 mà vẫn giữ được tính năng.** Quyết định:
carry-over chỉ nhìn về ĐÚNG MỘT kỳ liền trước, không xa hơn —

```
carryInMinor(kỳ N) = carryOver bật? (ngân sách GỐC kỳ N−1) − |đã chi kỳ N−1| : 0
effectiveBudget(kỳ N) = ngân sách GỐC kỳ N + carryInMinor(kỳ N)
```

Điểm mấu chốt: `carryInMinor(kỳ N)` CHỈ đọc **ngân sách GỐC** (`budgets.amount_minor`, không phải
`effectiveBudget`) và chi tiêu thật của kỳ N−1 — không bao giờ đọc `carryInMinor(kỳ N−1)`. Một khoản
dư kỳ 6 đẩy sang kỳ 7 rồi BIẾN MẤT khỏi công thức — kỳ 8 chỉ so ngân sách gốc kỳ 7 với chi tiêu thật
kỳ 7, không "thừa kế" khoản dư kỳ 6 nữa dù kỳ 7 cũng bật carry-over. Vì vậy công thức luôn là một
JOIN/subquery đúng HAI kỳ (kỳ đang xem + kỳ liền trước), một hằng số độ sâu, không phải một chuỗi
dài dần theo lịch sử dùng app — đúng yêu cầu "một con SUM độc lập" Phase 11 đặt ra, chỉ mở rộng độ
sâu từ 1 kỳ lên 2 kỳ thay vì giữ nguyên 1. Vẫn tính 100% từ SQL mỗi lần `watch()` phát (hai
`subqueryExpression` vô hướng tương quan theo `categoryId`, xem `BudgetRepository`), KHÔNG lưu cột
"ngân sách hiệu lực" nào — nếu Tony sửa một giao dịch tháng trước, carry-in tháng này tự động phản
ánh đúng ở lần watch kế tiếp, không có gì "đông cứng" lúc kỳ trước đóng lại.

Đánh đổi CÓ CHỦ Ý so với carry-over kiểu "envelope" thật (đa số app tiết kiệm/ngân sách phổ biến):
một khoản dư lớn chỉ được hưởng lợi đúng MỘT kỳ kế tiếp rồi mất, không tích luỹ vô hạn qua nhiều
tháng liên tiếp không tiêu. Chấp nhận được vì mục tiêu chính ở đây là tín hiệu "tháng trước
dư/vượt, tháng này nới/xiết theo" (đúng tinh thần PocketGuard mà TODOS.md dẫn), không phải một quỹ
tiết kiệm dài hạn per-category (đã có tính năng riêng ở Phase 16 "Mục tiêu tiết kiệm").

**Carry-over ÂM (kỳ trước vượt ngân sách): CỘNG DỒN vào kỳ sau (phạt kỳ sau), KHÔNG kẹp về 0.**
Chọn đối xứng: một kỳ dư được thưởng thêm ngân sách kỳ sau, một kỳ vượt thì bị trừ bớt ngân sách kỳ
sau — cùng một công thức `carryInMinor` không cần nhánh `if` phân biệt dấu (giống tinh thần comment
gốc ở `tables.dart`: "`amountMinor` CÓ DẤU... khiến `SUM` đúng mà không cần CASE theo `type`"). Kẹp
về 0 (chỉ thưởng, không bao giờ phạt) tạo lệch hệ thống: ngân sách hiệu lực trung bình theo thời gian
sẽ luôn trôi LÊN (mọi kỳ dư đều cộng thêm, không kỳ vượt nào từng bị trừ), khiến con số ngân sách
dần mất liên hệ với ngân sách gốc Tony thật sự đặt — không trung thực bằng việc phản ánh đúng cả hai
chiều. Rủi ro thật của lựa chọn PHẠT: một kỳ vượt rất nặng có thể đẩy `effectiveBudget` kỳ sau xuống
âm — chấp nhận được, UI hiển thị đúng "đã vượt" ngay từ đầu kỳ thay vì che giấu, nhất quán với luật
"không bao giờ mã hoá sai lệch bằng cách làm tròn để trông đỡ tệ hơn".

`carryOver` là cờ BOOLEAN **theo từng danh mục** (cột mới trên `budgets`, mặc định `false`) — không
phải cờ toàn app, đúng yêu cầu TODOS.md "carry-over tuỳ chọn theo từng danh mục". Danh mục không bật
cờ hành xử ĐÚNG HỆT Phase 11 (carryInMinor luôn 0) — không có thay đổi hành vi ngầm nào cho ngân sách
đã đặt trước Phase 15.

## 2026-08-22 · Phase 15 · Số "An toàn để tiêu hôm nay" — công thức & vì sao không cần lọc `isTransfer`

```
netKỳNày   = SUM(transactions.amount_minor) trong [kỳ.start, kỳ.end)  — CÓ DẤU, mọi ví, KHÔNG lọc isTransfer
sắpTới     = SUM(recurring_transactions.amount_minor) VỚI is_active VÀ next_occurrence_date
             TRONG [kỳ.start, kỳ.end) — CÓ DẤU (không riêng "hoá đơn", income định kỳ cộng thêm)
antoanHomNay = (netKỳNày + sắpTới) / số_ngày_còn_lại_trong_kỳ (từ hôm nay tới kỳ.end, tối thiểu 1)
```

**Vì sao `netKỳNày` không cần `& isTransfer.equals(false)`, khác 5 query gộp-theo-danh-mục của
Phase 13/14:** đây là tổng TOÀN VÍ (không nhóm theo danh mục), và một cặp chuyển khoản luôn là HAI
dòng liên kết cùng thời điểm với dấu ngược nhau (+X ở ví đến, −X ở ví đi) — cộng vào MỘT SUM chung,
chúng tự triệt tiêu về đúng 0, không cần loại trừ tường minh. Đây là ĐÚNG lý do
`TransactionRepository.watchBalance()` (Phase 4/13) cũng không lọc `isTransfer` — số dư TOÀN VÍ vốn
"transfer-invariant" một cách tự nhiên. `netKỳNày` cùng bản chất: một tổng toàn ví, không phải một
tổng theo danh mục (nơi một chân chuyển khoản CÓ THỂ rơi vào bucket của một danh mục nếu không lọc —
đó là lý do 5 query kia PHẢI lọc).

**Vì sao `netKỳNày` đọc thẳng `transactions.amount_minor`, không qua `effectiveCategoryAmounts`
(Phase 14):** `effectiveCategoryAmounts` tồn tại để gộp ĐÚNG theo DANH MỤC khi một giao dịch bị tách
dòng (mỗi dòng con một danh mục riêng). Ở đây không gộp theo danh mục nào cả — chỉ cộng tổng toàn ví
— và tổng các dòng con LUÔN bằng đúng `amountMinor` của giao dịch cha (validate bắt buộc lúc lưu,
Phase 14), nên `SUM(transactions.amount_minor)` trực tiếp trên bảng cha đã đúng tuyệt đối, không cần
đi qua UNION ALL phức tạp hơn để đổi lấy một con số giống hệt. Cùng lớp nhận thức với gotcha đã ghi
ở Phase 11: "không phải query nào cũng cần cùng một cách xử lý — kiểm tra trước khi áp dụng lại thứ
đã đúng ở chỗ khác".

**Vì sao `sắpTới` CỘNG (không CHỈ trừ hoá đơn) dù đặc tả gốc chỉ nói "trừ hoá đơn/định kỳ chưa xảy
ra":** `recurring_transactions.amount_minor` vốn CÓ DẤU giống hệt `transactions` (thu dương/chi âm,
xem `recurring_add_sheet.dart`), nên cộng thẳng nó vào `netKỳNày` tự động "trừ hoá đơn" (số âm cộng
vào = trừ) VÀ "cộng thu định kỳ đã biết trước" (số dương cộng vào) bằng CÙNG một phép cộng, không cần
nhánh `if` theo dấu — đúng nguyên tắc "một SUM có dấu, không CASE theo loại" đã dùng cho `balance` từ
D7. Đây là mở rộng nhất quán với quy ước sẵn có của app, không phải đổi phạm vi: mọi hoá đơn (số âm)
vẫn bị trừ đúng như đặc tả yêu cầu; phần cộng thêm chỉ áp dụng cho các dòng định kỳ Tony tự đánh dấu
là thu (`_isExpense = false` ở form Phase 12), không có gì mới cần Tony cấu hình.

**Lọc theo kỳ, KHÔNG theo "hôm nay":** một dòng định kỳ với `next_occurrence_date` đã QUA (quá hạn
nhưng Tony chưa xác nhận giao dịch thật) vẫn tính là "chưa xảy ra" — đúng nghĩa đen, nó THẬT SỰ chưa
được ghi vào `transactions` (Phase 12: nhắc định kỳ không bao giờ tự ghi sổ). Lọc theo "hôm nay" sẽ
âm thầm bỏ sót một hoá đơn quá hạn Tony vẫn còn nợ, làm con số "an toàn để tiêu" LẠC QUAN SAI. Lọc
theo kỳ (`[kỳ.start, kỳ.end)`) là đủ và đúng — không cần so sánh với `Clock.now()` cho vế này.

Tính bằng MỘT query duy nhất (`SafeToSpendRepository`, `_db.selectOnly(_db.transactions)` làm bảng
dẫn, hai `subqueryExpression` vô hướng cho phần định kỳ) — không lưu bộ đếm nào, chia cho số ngày
còn lại là phép toán vô hướng cuối cùng ở tầng Dart (cùng lớp với `BudgetProgress.remainingMinor`
đã làm phép trừ ở tầng Dart sau khi SQL trả `spentMinor`/`budgetAmountMinor` — D7 cấm LƯU giá trị dẫn
xuất, không cấm TÍNH nó từ các SUM SQL).

## 2026-08-22 · Phase 15 · Kỳ ngân sách theo ngày neo: cấu hình TOÀN APP qua `shared_preferences`, KHÔNG phải cột DB

`anchorDay` (mặc định 1, tương thích ngược tuyệt đối với Phase 11) đặt ở `AppSettingsController` —
cùng tầng lưu trữ với `themeMode`/`amoled`/`biometricLockEnabled` (Phase 5/12), KHÔNG phải một cột
mới trên `budgets` hay bảng cấu hình riêng. Lý do: ngày lương là MỘT giá trị áp dụng cho TOÀN BỘ ứng
dụng (không theo từng danh mục/ví/ngân sách), thuần tuý là tuỳ chọn hiển thị/tính kỳ — không phải dữ
liệu tài chính cần sống trong DB mã hoá, và không cần lịch sử/đối chiếu qua các bản backup JSON.
`budgets.year_month` GIỮ NGUYÊN ý nghĩa "tháng lịch mà kỳ đó BẮT ĐẦU" bất kể `anchorDay` — ví dụ
`anchorDay = 25`: kỳ "2026-08" luôn là 25/8 → 25/9, không phải 1/8 → 1/9. `BudgetPeriod.of(reference,
anchorDay: ...)` tự quy đổi: `reference.day >= anchorDay` → kỳ hiện tại là tháng của `reference`;
ngược lại → kỳ hiện tại là THÁNG TRƯỚC. Nhãn hiển thị (`BudgetPeriod.label`) đổi từ "Tháng 8 2026"
(khi `anchorDay == 1`, giữ nguyên chữ Phase 11) sang khoảng ngày cụ thể "25/8 – 24/9" khi
`anchorDay != 1` — chỉ hiện tên tháng lịch khi kỳ thực sự trùng tháng lịch, tránh gây hiểu lầm.

**Neo > số ngày thực trong một tháng cụ thể (vd. neo 31, tháng 2 chỉ có 28/29 ngày): KẸP về ngày
cuối cùng của đúng tháng đó**, dùng lại mẹo `DateTime(year, month + 1, 0).day` đã kiểm chứng từ Phase
11 (không cần bảng tra 28/30/31 riêng) — cùng cách billing-cycle của thẻ tín dụng xử lý "ngày sao kê
31" vào tháng 2. Hệ quả CÓ CHỦ Ý: độ dài kỳ có thể ngắn hơn ở tháng kế cận tháng 2 (vd. neo 31: kỳ
tháng 1 dài 28 ngày vì kẹp ở đầu tháng 2, nhưng kỳ tháng 2 lại dài 31 ngày vì kẹp ở đầu tháng 3) —
chấp nhận được, đúng bản chất "neo theo NGÀY", không phải "kỳ luôn N ngày cố định".

**Đổi `anchorDay` giữa chừng có thể làm ngân sách cũ (`budgets.year_month` đã lưu) đọc theo ranh giới
NGÀY khác với lúc đặt** — vd. Tony đổi neo từ 1 sang 25: một giao dịch ngày 20/8 trước đây thuộc kỳ
"2026-08" (neo 1: 1/8–1/9) nay lại rơi vào kỳ "2026-07" (neo 25: 25/7–25/8). Đây là hệ quả tự nhiên
của việc đổi chu kỳ lương giữa chừng (giống đổi ngày sao kê thẻ tín dụng giữa chừng) — không phải
lỗi, không cần migration/backfill gì, chỉ cần Tony hiểu khi đổi cài đặt này. Không cảnh báo riêng ở
phase này (có thể thêm sau nếu gây nhầm lẫn thật khi dùng).

## 2026-08-22 · Phase 15 · `effectiveCategoryAmounts` nhận thêm tham số `alias` tuỳ chọn

`BudgetRepository.watchBudgetsForPeriod` giờ cần GỌI HAI LẦN `effectiveCategoryAmounts(_db)` trong
CÙNG một câu lệnh (kỳ đang xem, cho `spentMinor` — JOIN như cũ; kỳ liền trước, cho carry-in — một
`subqueryExpression` tương quan lồng bên trong, không phải JOIN, để tránh nhân đôi hàng qua GROUP BY
chung khi cả hai "bảng ảo" đều có thể khớp nhiều hàng cho cùng một danh mục — xem cảnh báo Cartesian
product bên dưới). Thêm tham số `alias` (mặc định giữ nguyên `'effective_category_amounts'`, không
đổi hành vi 5 call site cũ) để lần gọi thứ hai dùng bí danh khác (`'effective_category_amounts_prev'`),
tránh mọi nhập nhằng bí danh dù về lý thuyết SQL cho phép trùng tên ở hai phạm vi subquery lồng nhau
độc lập.

**Cảnh báo kỹ thuật đã tránh được TRƯỚC KHI viết, không phải sửa sau khi vỡ:** thử nghiệm ban đầu
định JOIN thẳng `effPrev` (bảng ảo kỳ trước) vào CÙNG câu lệnh đã JOIN `eff` (kỳ đang xem) rồi
`GROUP BY budgets.id` một lần — sẽ tạo tích Descartes nội bộ mỗi khi MỘT danh mục có nhiều hơn một
giao dịch hiệu lực ở CẢ HAI kỳ (rất phổ biến): N hàng khớp `eff` × M hàng khớp `effPrev` nhân thành
N×M hàng trong nhóm, khiến `SUM(spentExpr)` bị nhân M lần và `SUM(prevSpentExpr)` bị nhân N lần —
sai âm thầm, không lỗi cú pháp nào báo. Giải pháp: giữ NGUYÊN JOIN `eff` hiện có (đã test, đúng —
không đổi), thêm carry-in bằng HAI `subqueryExpression` vô hướng tương quan theo `categoryId` (mỗi
cái luôn trả đúng một hàng/giá trị, không thể fan-out ra hàng ngoài) thay vì JOIN — cùng kỹ thuật
`linesCountExpr` đã dùng ở Phase 14 (`TransactionRepository.watchAllWithCategory`), chỉ khác là tương
quan sâu hơn một tầng (subquery lồng trong subquery).

## 2026-08-22 · Phase 16 · Chuyển migration hand-rolled sang `stepByStep` — bắt buộc, không phải dọn dẹp

Thêm `transactions.goal_id`/`debt_id` (hai cột nullable mới) làm lộ ra một lỗi CẤU TRÚC tiềm ẩn từ
Phase 13, không phải lỗi mới: `Migrator.alterTable(TableMigration(table, newColumns: [...]))` dựng
lại bảng theo hình dạng của CHÍNH ĐỐI TƯỢNG `table` truyền vào. Toàn bộ migration viết tay từ Phase 9
tới Phase 15 truyền thẳng getter bảng SỐNG (`transactions`, `categories`, ...) — đối tượng đó LUÔN
phản ánh class Dart MỚI NHẤT tại thời điểm build, bất kể migration đó được viết ở phase nào. Hệ quả
phát hiện được khi thêm `goalId`/`debtId` (Phase 16) vào class `Transactions`: bước `alterTable` của
v3→v4 (viết từ Phase 13) đột nhiên "nhìn thấy" hai cột này trong đối tượng `transactions` sống, dù
Phase 13 chưa từng biết tới chúng —

- Không liệt kê `goalId`/`debtId` vào `newColumns` của bước v3→v4 → bước copy dữ liệu cố `SELECT
  goal_id` từ bảng v3 (không có cột đó) → `SqliteException: no such column: "goal_id"`.
- Liệt kê chúng vào `newColumns` (để tránh lỗi trên) → bảng KẾT QUẢ ở v4 (thời điểm trung gian) có
  thừa 2 cột so với hình dạng v4 THẬT (snapshot `drift_schemas/app_database/drift_schema_v4.json`)
  → `SchemaVerifier` của drift_dev bắt được ngay: `"Contains the following unexpected entries:
  goal_id, debt_id"` khi test giả lập một upgrade dừng ở v4 (chính cơ chế `to` bị chặn thấp hơn
  `schemaVersion` thật đã ghi ở Phase 13, giờ lộ ra một lớp lỗi MỚI, sâu hơn "chỉ chạy nhầm nhánh
  if").

Hai yêu cầu (không "no such column" LẪN không thừa cột ở phiên bản trung gian) không thể cùng thoả
nếu `table` luôn là đối tượng SỐNG — về bản chất, MỌI `alterTable` từng viết sẽ tái diễn đúng lỗi này
mỗi khi một phase SAU thêm cột mới vào CÙNG bảng đã từng bị `alterTable`, vĩnh viễn, không chỉ lần
này. Giải pháp ĐÚNG (không phải vá tạm): sinh `lib/data/db/schema_versions.steps.dart` bằng `dart run
drift_dev schema steps drift_schemas/app_database lib/data/db/schema_versions.steps.dart` (đọc từ
chính các snapshot JSON đã có từ Phase 4–15, không cần dữ liệu mới) — file này export `Schema2`...
`Schema7`, mỗi lớp là một đối tượng bảng ĐÓNG BĂNG đúng hình dạng của PHIÊN BẢN ĐÓ, cùng hàm
`stepByStep({from1To2, from2To3, ..., from6To7})` chạy đúng closure tương ứng, tự động nối chuỗi
nhiều bước cho một upgrade nhảy nhiều phiên bản (vd v3→v7 chạy lần lượt from3To4→from4To5→from5To6→
from6To7). Viết lại toàn bộ `AppDatabase.migration.onUpgrade` từ `(m, from, to) async { if (...) {...}
}` tự tay sang `stepByStep(from1To2: (m, schema) async {...}, ...)`, mỗi closure dùng `schema.xxx`
(hình dạng ĐÓNG BĂNG) thay vì getter bảng sống cho MỌI thao tác DDL (`createTable`/`addColumn`/
`alterTable`) — chỉ riêng bước INSERT dữ liệu thật (tạo "Ví mặc định" ở v3→v4) vẫn dùng getter sống
`wallets`/`WalletsCompanion` vì `into()` cần kiểu Insertable đúng (`Shape7` chỉ là `TableInfo<Table,
QueryRow>` chung chung, không gõ được `WalletsCompanion`).

**File sinh ra KHÔNG được sửa tay** (đầu file tự ghi "GENERATED BY drift_dev, DO NOT MODIFY") — mọi
lần schema đổi (mọi phase sau), quy trình bắt buộc là: sửa `tables.dart` → `dart run drift_dev
make-migrations` (sinh snapshot JSON version mới) → `dart run drift_dev schema steps
drift_schemas/app_database lib/data/db/schema_versions.steps.dart` (sinh lại TOÀN BỘ file steps, tự
thêm `SchemaN+1`/`fromNToN+1` mới) → thêm ĐÚNG MỘT closure mới vào `stepByStep(...)` trong
`database.dart` cho bước migration mới, không đụng các closure cũ. Xác nhận đã sửa đúng bằng cách
chạy lại toàn bộ ma trận `simple database migrations from X to Y` (tự sinh bởi `SchemaVerifier`,
`GeneratedHelper.versions`) — 27 tổ hợp (từ 21 trước Phase 16) đều xanh sau khi viết lại, bao gồm cả
`migration_v3_v4_real_data_test.dart` (dữ liệu Rolly thật 354 giao dịch) vẫn khớp tuyệt đối.

## 2026-08-22 · Phase 16 · Mục tiêu tiết kiệm & nợ vay — công thức tiến độ, KHÔNG dùng `ABS()`

Cả `savings_goals` lẫn `debts` tái dùng chính cột `transactions.amount_minor` CÓ DẤU đã có (thêm
`goal_id`/`debt_id` nullable trỏ tới, độc lập với `category_id` — một giao dịch có thể vừa có danh
mục vừa gắn một mục tiêu/khoản vay) thay vì một bảng "đóng góp" riêng — đúng tinh thần D7, tiến độ là
MỘT `SUM` trên dữ liệu đã có, không thêm khái niệm ghi sổ song song.

**Mục tiêu tiết kiệm**: `savedMinor = -SUM(amount_minor WHERE goal_id = ?)`. Đóng góp (tiền RỜI ví
chi tiêu, hướng về mục tiêu) ghi như một giao dịch CHI bình thường (âm) gắn `goalId`; rút khỏi mục
tiêu ghi như một giao dịch THU (dương) gắn CÙNG `goalId`. Phép trừ dấu ÂM ở công thức tự động lật
đúng chiều — không cần `ABS()`/CASE: một chuỗi chi rồi rút một phần vẫn cho kết quả đúng (vd chi
500k, rút 200k → SUM = -300k → saved = 300k, đúng số THỰC SỰ còn "để dành"), khác `ABS(SUM(...))` sẽ
sai nếu có nhiều dòng dấu trái nhau triệt tiêu một phần rồi lại đảo dấu net.

**Nợ/cho vay**: `principalMinor` là một trường TĨNH trên `debts` (không phải một giao dịch) — số gốc
lúc phát sinh khoản vay, không đổi. `remainingMinor` phụ thuộc `kind`: `'debt'` (mình nợ, trả là giao
dịch CHI âm) → `remaining = principal + SUM(amount_minor)`; `'loan'` (mình cho vay, thu là giao dịch
THU dương) → `remaining = principal - SUM(amount_minor)`. Không gộp hai công thức bằng `ABS()` vì lý
do y hệt mục tiêu tiết kiệm ở trên — một khoản trả thừa rồi được hoàn lại một phần (dấu trái chiều
với trả bình thường) vẫn phải cộng dồn đúng, `ABS(SUM(...))` sẽ cho kết quả sai trong ca đó dù hiếm.

**Vòng tiến độ tái dùng HÌNH HỌC (`CustomPainter`) của `BudgetRing` (Phase 11), tách riêng MÀU/nhãn**
— theo đúng yêu cầu "ưu tiên không lặp code hình học, tách nếu màu/nhãn khác biệt đủ nhiều": logic
màu của `BudgetRing` so [progress] với [paceFraction] (nhịp thời gian trong THÁNG) — khái niệm không
tồn tại cho mục tiêu/nợ (không có "kỳ" nào, chỉ có một đích tĩnh). Tách phần vẽ (track/cung
gradient/vạch nhịp TUỲ CHỌN) ra `lib/ui/progress_ring.dart` (`ProgressRing`, nhận thẳng `ringColor`
đã tính sẵn + `paceFraction`/`paceMarkColor` NULLABLE — bỏ vẽ vạch nhịp nếu null); `BudgetRing` giữ
nguyên API công khai, bên trong chỉ còn tính màu theo nhịp rồi gọi `ProgressRing`. Mục tiêu/nợ dùng
thẳng `ProgressRing` không truyền `paceFraction` (không vạch nhịp), tự tính màu ĐƠN GIẢN (xanh
`budgetOk` xuyên suốt khi đang tiến triển, không có trạng thái "cảnh báo"/"vượt" kiểu ngân sách vì
tiến độ tăng luôn là tin tốt ở đây, không phải tin xấu như chi tiêu vượt ngân sách).

## 2026-08-22 · Phase 17 · Tìm kiếm FTS5 — bảng ảo khai qua `.drift` file, KHÔNG qua Dart Table

**API FTS5 thật của drift (đọc source `drift-2.34.0/lib/src/dsl/columns.dart`, không đoán):** drift's
Dart `Table` DSL KHÔNG có bất kỳ API nào cho virtual table — grep toàn bộ `lib/` của package `drift`
cho "fts5"/"Fts5"/"VirtualTable" chỉ ra đúng MỘT chỗ dùng được: `VirtualTableInfo`, một base class
CHỈ được sinh ra bởi drift_dev từ một khai báo SQL thô `CREATE VIRTUAL TABLE ... USING fts5(...) AS
TênLớp;` trong file `.drift` (xác nhận bằng chính test suite của drift, `test/extensions/
fts5_integration_test.dart` + `test/generated/tables.drift`). Đây là dự án ĐẦU TIÊN của TonyFino dùng
`.drift` file — mọi bảng khác từ Phase 4 đều là Dart `Table` class thuần, và điều đó KHÔNG đổi: FTS5
là trường hợp DUY NHẤT bắt buộc phải lệch quy ước, vì bản thân drift không cho cách nào khác.

**`lib/data/db/transactions_fts.drift`** khai `CREATE VIRTUAL TABLE transactions_fts USING fts5(
note_ascii, transaction_id UNINDEXED) AS TransactionsFts;`, nạp vào `AppDatabase` qua `@DriftDatabase(
include: {'transactions_fts.drift'}, queries: {'searchTransactionIds': 'SELECT transaction_id FROM
transactions_fts WHERE transactions_fts MATCH :term'})`. Cần thêm `sql: { options: { modules: [fts5]
} }` vào `build.yaml` — thiếu dòng này, `build_runner`/`make-migrations` lỗi ngay ("Unknown column"/
lỗi deserialize nội bộ khi phân giải `transactions_fts`/`MATCH`), xác nhận bằng cách chạy thử TRƯỚC
khi thêm rồi so log, không đoán. Thử `sqlite: { modules: [fts5] }` (khoá cấp cao nhất) trước — lỗi
rõ ràng "The sqlite field cannot be used together the `sql` option. Try moving it to `sql.options`."
— chuyển đúng theo gợi ý đó thì chạy.

**KHÔNG dùng bảng FTS5 "external content" (`content='transactions', content_rowid='id'`) + 3 trigger
SQL đồng bộ tay** — đây là kiểu SQLite hay khuyến nghị nhất cho FTS5 gắn với một bảng có sẵn, và ban
đầu đây là thiết kế dự định. Đổi ý vì hai lý do: (1) `noteAscii` (cột nguồn) đã có quy ước SẴN từ
Phase 4 — "giữ đồng bộ ở tầng repository, không ở DB" (xem comment gốc ở `tables.dart`) — trigger SQL
đi ngược quy ước đó, tạo một cơ chế đồng bộ MỚI song song với cơ chế đã có thay vì tái dùng; (2) 3
trigger tay phải đúng ở MỌI đường ghi `transactions` (quick-add, import Rolly, nhân đôi, tách dòng,
sửa tay, xoá — Phase 6-16 đã tích luỹ rất nhiều đường ghi) mà không có gì buộc một trigger mới thêm
sau này phải nhất quán — đúng lớp rủi ro "hai widget cùng khái niệm nhưng chỉ một cái nối logic" đã
gặp ở Phase 8 (`SavedTransactionRow`/`DraftCard._buildSaved`, xem `project_tonyfino_gotchas.md`), chỉ
khác đây là trigger SQL thay vì widget. Thay vào đó: bảng FTS5 tự giữ bản sao `note_ascii` + một cột
`transaction_id UNINDEXED` để tra ngược, đồng bộ tường minh trong CÙNG `_db.transaction()` với mỗi
lần `TransactionRepository.insert`/`update`/`delete` — một điểm sự thật duy nhất ở tầng repository,
đúng nơi `noteAscii` chính nó đã luôn được đồng bộ.

**Cạm bẫy kiểu dữ liệu xác nhận qua generated code, không đoán:** FTS5 KHÔNG hỗ trợ khai kiểu cột (kể
cả cột `UNINDEXED`) — SQLite lưu MỌI cột FTS5 dưới dạng văn bản, nên `TransactionsFtsCompanion` sinh
ra `transactionId` kiểu `String`, không phải `int` như `transactions.id` thật — `TransactionRepository`
phải `.toString()` lúc ghi và `int.parse()` lúc đọc lại kết quả tìm kiếm.

**Migration v7→v8 cần BACKFILL tường minh** — bảng FTS5 mới tạo RỖNG, không tự "nhìn thấy" các giao
dịch NHẬP TỪ TRƯỚC Phase 17 (import Rolly 354 giao dịch, quick-add cũ...) — thiếu bước này thì mọi
ghi chú cũ sẽ vô hình với tìm kiếm cho tới khi Tony tự sửa lại từng giao dịch, một kiểu mất dữ liệu
ÂM THẦM. Đọc dữ liệu cũ bằng `customSelect` thô (chỉ 2 cột ổn định từ v1/v2, không phải `alterTable`
nên không dính bẫy "đối tượng bảng sống" của Phase 16) rồi chèn qua `TransactionsFtsCompanion` sống
(bảng vừa tạo đúng hình dạng NGAY trong bước này, an toàn — cùng lý do `WalletsCompanion` ở bước
v3→v4 dùng được getter sống). Xác nhận: `SchemaVerifier`'s ma trận "simple database migrations from
X to Y" tăng từ 27 lên 36 tổ hợp, tất cả xanh — bao gồm mọi cặp (X, 8) — không có "unexpected
entries" nào phát sinh từ bảng ảo hay 4 bảng shadow nội bộ của nó (`_data`/`_idx`/`_docsize`/
`_config`), nghĩa là `virtualTables`/`Fts5Extension` của `SchemaVerifier` nhận diện đúng bảng khai
qua `.drift` là một `DatabaseSchemaEntity` thật, không phải một side-effect SQL nằm ngoài mọi công cụ.

## 2026-08-22 · Phase 17 · Dynamic color — `dynamic_color` phải PIN 1.9.0, không phải `^2.1.0` như TODOS.md đã nghiên cứu

TODOS.md § Design system (nghiên cứu Phase 5) ghi `dynamic_color ^2.1.0` là bản đã duyệt. Cài đúng
bản đó (mới nhất hiện có) rồi nối `DynamicColorBuilder` vào `appTheme` → lỗi biên dịch NGAY:
`ColorScheme? (material_ui) không gán được cho ColorScheme? (flutter/material.dart)`. Đọc source xác
nhận: `dynamic_color` 2.0.0 (CHANGELOG "Migrate to material_ui package version 1.0.1") đổi hẳn kiểu
trả về của `DynamicColorBuilder.builder` từ `ColorScheme` chuẩn của Flutter SDK sang `ColorScheme` của
`package:material_ui` — một package MỚI, riêng, đang được Google phát triển làm bản kế nhiệm cho
`material.dart` (chính là gói TODOS.md từng nhắc tới ở mục Material 3 Expressive: "material_ui 1.0.1
cài được trên 3.44 nhưng không chứa component Expressive nào" — lúc đó chỉ ghi nhận nó TỒN TẠI, chưa
biết `dynamic_color` sẽ phụ thuộc nó). Hai lớp `ColorScheme` này không tương thích, không có hàm
convert qua lại. `appTheme`/toàn bộ `app_theme.dart` xây trên `ColorScheme` chuẩn Flutter (đúng luật
"file token chỉ import dart:ui/painting.dart... KHÔNG đuổi theo material_ui" — TODOS.md § Package UI)
— **pin `dynamic_color: 1.9.0`** (bản CUỐI CÙNG trước migration, xác nhận `flutter pub get` giải
quyết sạch, `cupertino_ui`/`material_ui` không còn bị kéo vào transitive nữa) thay vì đuổi theo
`material_ui`, giữ đúng ranh giới đã chốt ở Phase 5.

**Ranh giới "chỉ lái primary/surface trung tính" (D9) thực thi thế nào:** `appTheme` nhận thêm
`ColorScheme? dynamicScheme` — khi có, ghi đè các field `primary`/`onPrimary`/`primaryContainer`/
`onPrimaryContainer`/`surface`/`onSurface`/`surfaceContainer*`/`outline*` của `ColorScheme` TRẢ VỀ,
không đụng gì khác. An toàn CÓ CẤU TRÚC (không phải kỷ luật viết code): mọi màn hình trong app đọc màu
qua `context.colors` (`ThemeExtension<AppColors>` — bảng `canvas`/`card`/12 màu danh mục/`income`/
`expense` cố định, xây độc lập với `ColorScheme` ngay trong `_build()`) chứ không qua
`context.scheme`/`colorScheme.*` — grep toàn bộ `lib/` xác nhận `context.scheme.*` chỉ xuất hiện ở
đúng 3 chỗ (`ColorSwatchPicker`'s viền ô đã chọn, `NavigationBarThemeData.indicatorColor`, một chip
đã chọn ở `quick_add_input_bar.dart`), không chỗ nào trong đó là màu danh mục/thu-chi. Vì vậy đè
`ColorScheme` không có ĐƯỜNG NÀO chạm được tới bảng màu biểu đồ, dù `dynamicScheme` trả về màu gì —
không cần kỷ luật "nhớ đừng đụng vào" ở từng call site, vi phạm D9 sẽ là lỗi biên dịch/kiến trúc chứ
không phải lỗi runtime âm thầm.

`DynamicColorBuilder` bọc LUÔN quanh `MaterialApp.router` (không điều kiện theo cờ bật/tắt) — hỏi hệ
điều hành là một platform channel call rẻ, và giữ cây widget không đổi hình dạng khi Tony bật/tắt
`AppSettings.dynamicColorEnabled` ở Settings tránh mất state điều hướng do rebuild lại từ gốc. Cờ chỉ
quyết định có TRUYỀN `lightDynamic`/`darkDynamic` vào `appTheme` hay truyền `null` (giữ nguyên bảng
tím cố định) — mặc định `false` (D9 "mặc định TẮT").

## 2026-08-22 · Phase 18 · OCR hoá đơn: ON-DEVICE (`google_mlkit_text_recognition`), Gemini Vision KHÔNG cắm ở phase này

**Quyết định (viết TRƯỚC khi code, đúng yêu cầu):** chạy OCR ON-DEVICE bằng `google_mlkit_text_recognition`
0.17.1 (`TextRecognitionScript.latin`), KHÔNG gửi ảnh qua Gemini Vision trên proxy AI fallback (Phase
22). Lý do, xác nhận bằng nguồn thật chứ không suy đoán:

- **Tiếng Việt được ML Kit hỗ trợ CHÍNH THỨC ở bộ nhận dạng Latin**, xác nhận trực tiếp từ trang
  ["Supported languages"](https://developers.google.com/ml-kit/vision/text-recognition/v2/languages)
  của Google — "Tiếng Việt" (mã `vi`) nằm trong danh sách 44 ngôn ngữ script Latin có bộ nhận dạng
  riêng, KHÔNG cần thêm gói ngôn ngữ phụ (những gói `TextRecognitionChinese/Devanagari/Japanese/Korean`
  README nhắc tới chỉ dành cho 4 script khác, script Latin — bao gồm tiếng Việt có dấu — đã có sẵn
  mặc định).
- License MIT (`google_mlkit_text_recognition`), mô hình chạy hoàn toàn cục bộ qua Play Services ML
  Kit trên máy — không cần mạng, đúng triết lý offline-first của app; không tốn quota/API key.
- Gemini Vision (Phase 23, qua proxy AI fallback) mặc định TẮT theo D8 — dùng nó làm đường CHÍNH cho
  một tính năng "chụp ảnh → điền form" sẽ khiến tính năng không hoạt động được cho phần lớn người
  dùng (kể cả Tony, nếu chưa bật cloud fallback), ngược lại hoàn toàn với việc on-device luôn sẵn
  sàng ngay sau khi cài đặt.

**Chưa cắm Gemini Vision fallback trong phase này** (đúng khuyến nghị prompt: "chỉ là dự phòng NẾU
độ chính xác không đủ") — chờ xác minh trên hoá đơn tiếng Việt thật trước, không xây dự phòng cho một
vấn đề chưa chứng minh là có thật. Nếu độ chính xác on-device không đủ sau khi Tony tự thử trên hoá
đơn thật của mình, việc thêm nhánh Gemini Vision (Phase 23 đã có `AiParseFallback`-kiểu interface làm
mẫu) là một thay đổi nhỏ, không cần thiết kế lại `ReceiptOcrService`.

**Giọng nói (`speech_to_text` 7.4.0) — một cạm bẫy đáng ghi lại tuy prompt không yêu cầu quyết định
riêng cho phần này:** khác ML Kit, `speech_to_text` KHÔNG đảm bảo chạy on-device — nó gọi thẳng
`SpeechRecognizer` cấp hệ điều hành Android, bản thân dịch vụ đó CÓ THỂ dùng máy chủ Google tuỳ theo
gói ngôn ngữ đã tải về máy (README của package tự nêu cần khai `android.permission.INTERNET` "vì
speech recognition có thể dùng dịch vụ từ xa"; tham số `onDevice: true` tồn tại nhưng "nếu máy không
làm được thì lần nghe đó THẤT BẠI hẳn", không phải suy giảm êm). TODOS.md không yêu cầu on-device bắt
buộc cho giọng nói (chỉ yêu cầu văn bản ra đẩy thẳng qua parser có sẵn) nên KHÔNG ép `onDevice: true`
— dùng cấu hình mặc định (máy tự chọn đường tốt nhất có sẵn), chấp nhận giọng nói có thể cần mạng tuỳ
máy, khác hẳn OCR (luôn 100% cục bộ, không có nhánh nào cần mạng).

**Kết quả OCR PHẢI dừng ở "điền sẵn form, chờ xác nhận" (Luật #7)** — tái dùng CHÍNH `TransactionFormPrefill`/
`TransactionFormSheet` đã có từ Phase 14 (chưa ghi gì cho tới khi bấm Lưu), KHÔNG viết một đường ghi
riêng. Giọng nói thì đẩy thẳng qua `QuickAddController.sendMessage()` có sẵn từ Phase 8 — đây KHÔNG
phải một ngoại lệ với Luật #7: `sendMessage` chính nó đã luôn là "ghi lạc quan CÓ THỂ sửa/hoàn tác qua
chip + hẹn giờ co lại", chưa từng là "tự động commit không cho sửa" — coi văn bản từ giọng nói giống
hệt văn bản gõ tay là đúng tinh thần "giọng nói chỉ là một cách gõ khác" mà prompt yêu cầu, không cần
thêm một lớp xác nhận mới chỉ vì nguồn văn bản khác.

**Cạm bẫy build release đã gặp (R8/ProGuard):** `flutter build apk --release` (minify bật, D3) lỗi
ngay `Missing class ... ChineseTextRecognizerOptions/DevanagariTextRecognizerOptions/
JapaneseTextRecognizerOptions/KoreanTextRecognizerOptions` — code Kotlin của
`google_mlkit_text_recognition` tham chiếu class của CẢ 5 script trong một switch nội bộ, dù app chỉ
khai gradle dependency cho Latin (đúng quyết định ở trên — 4 script kia không cần cho tiếng Việt).
Fix bằng ĐÚNG rule Google tự sinh ra trong `build/app/outputs/mapping/release/missing_rules.txt` lúc
build lỗi (8 dòng `-dontwarn com.google.mlkit.vision.text.<script>.<Options>Recognizer[$Builder]`),
thêm vào `android/app/proguard-rules.pro` — không phải suy đoán rule, đọc thẳng từ file Gradle tự tạo.

**Xác minh trên thiết bị thật (2026-08-22):** cài `0.12.0+13` đè lên app đang chạy, không có migration
nào (Phase 18 không đổi schema) — hero card giữ nguyên `-34.559.000₫/+29.533.000₫`, xác nhận không mất
dữ liệu. FAB nhấn giữ → sheet "Thêm nhanh" hiện đúng "Quét hoá đơn"/"Quản lý mẫu giao dịch" (kể cả khi
0 mẫu — đúng thay đổi hành vi so với Phase 14). Chọn "Quét hoá đơn" → sheet nguồn ảnh (Chụp/Chọn có
sẵn) → chọn một ảnh (không có hoá đơn thật trên máy ảo, dùng tạm ảnh chụp màn hình có sẵn để kiểm tra
CƠ CHẾ, không phải độ chính xác) → ML Kit chạy KHÔNG crash trên bản release đã qua R8 (xác nhận
proguard fix ở trên đúng) → mở sheet Thêm điền sẵn, ảnh vừa quét tự động thành ảnh hoá đơn đính kèm
(đúng thiết kế `TransactionFormPrefill.fromReceiptScan`) → **không tự lưu gì cả**, đúng Luật #7. Nhập
giọng nói: bấm mic → xin quyền `RECORD_AUDIO` đúng lúc lần đầu → cấp quyền → mic chuyển màu tím đặc,
hint đổi "Đang nghe…", chấm ghi âm xanh hiện ở status bar hệ thống — toàn bộ luồng bật/tắt nghe hoạt
động đúng. Máy ảo không có micro thật nên KHÔNG kiểm chứng được văn bản nhận dạng thực tế qua luồng
này — đúng giới hạn đã biết trước của môi trường test, không phải một khoảng trống mới phát sinh.

**⚠️ CHƯA xác minh được** yêu cầu bắt buộc "test OCR trên hoá đơn tiếng Việt THẬT (siêu thị/quán ăn)"
— Claude không có camera/quyền truy cập hoá đơn giấy thật của Tony, không thể tự chụp hay tạo dữ liệu
này. Cần Tony tự chụp vài hoá đơn thật rồi cung cấp ảnh (hoặc tự chạy thử trên máy thật của mình) để
đóng nốt hạng mục xác minh này — xem báo cáo cuối phase.

## 2026-08-22 · Phase 19 · Bảng ánh xạ field — đọc THẬT trước khi code, đúng kỷ luật Phase 9

Đọc trực tiếp bằng `python3 -c "import json; ..."` từng file còn lại trong `raw_rolly/` mà Phase 9
chưa từng phân tích. Phát hiện quan trọng nhất, đổi hẳn phạm vi phase này: **3/6 file RỖNG**
(`budget.json`, `debt_with_total.json`, `recurring_transactions_view.json` đều là `[]`) — Tony chưa
từng tạo ngân sách/khoản nợ/giao dịch định kỳ nào trong Rolly. Điều này thực ra đã được ghi lại từ
**Phase 2** (`docs/rolly-schema.md` dòng "Đã kéo về... `budget`/`debt`/`recurring` đều rỗng (Tony
chưa dùng)") nhưng chưa từng được đối chiếu lại với checklist Phase 19 cho tới bây giờ.

### `budget.json`, `debt_with_total.json`, `recurring_transactions_view.json` — RỖNG, không có gì để import

Không viết importer cho ba nguồn này. Lý do KHÔNG phải lười — viết importer cho một schema chưa từng
quan sát được dù chỉ một dòng thật sẽ là ĐOÁN SCHEMA, đúng điều luật Phase 9 (nhắc lại nguyên văn ở
prompt Phase 19) cấm tuyệt đối, và không có cách nào test thật (không có dữ liệu để chạy import, không
có oracle để đối chiếu). Nếu sau này Tony tạo ngân sách/nợ/giao dịch định kỳ trong Rolly (không chắc
còn dùng Rolly nữa) và export lại được dữ liệu THẬT có ít nhất 1 dòng, một phase sau có thể viết
importer đúng kỷ luật này — bảng ánh xạ field khi đó viết từ dữ liệu thật lúc đó, không suy diễn từ ba
dòng mô tả trong TODOS.md gốc.

### `savings.json` / `savings_with_total.json` → `savings_goals` — bảng ánh xạ field

Có ĐÚNG 1 bản ghi (mục tiêu "CCTG", đã hoàn thành 2026-08-05). `savings_with_total.json` là bản mở
rộng của `savings.json` (thêm đúng 1 field `total_amount`) — parser (`rolly_savings_parser.dart`)
nhận cả hai hình dạng, `total_amount` optional.

| Field Rolly | Kiểu | → Field TonyFino (`savings_goals`) | Ghi chú |
|---|---|---|---|
| `id` | int | `sourceId = 'rolly-savings:$id'` | Idempotency, mới thêm cột (xem migration bên dưới) |
| `title` | str | `name` | — |
| `achieve_amount` | float, major VND | `targetAmountMinor` | Cùng bất biến `input.amount` (Phase 9): luôn ≥0, nguyên — vi phạm thì báo issue, bỏ dòng |
| `currency_code` | str | `currency`/`currencyScale` | CHỈ chấp nhận `'VND'` (→ scale 0) — khác thì báo issue, bỏ qua, không đoán scale cho currency lạ |
| `achieve_date` | str `YYYY-MM-DD`/null | `targetDate` | Parse thủ công 3 phần, không `DateTime.parse` — cùng lý do múi giờ Phase 9 |
| `completed` | bool | `isArchived` | Mục tiêu đã đạt ở Rolly → vào thẳng "Đã lưu trữ" ở TonyFino, không lẫn vào danh sách đang hoạt động |
| `total_amount` (chỉ có ở `_with_total`) | float | *(không lưu — chỉ dùng làm oracle đối chiếu lúc test/import, xem dưới)* | Đúng D7: tiến độ luôn là SUM trên `transactions`, không cache |
| *(không có trong `savings.json`)* | — | *(nguồn đóng góp)* | Xem mục tiếp theo — phải lấy từ `input.json`, KHÔNG có trong `savings.json` |

**Phát hiện cấu trúc quan trọng nhất của phase này**: Rolly không lưu "đã đóng góp bao nhiêu" trên
bản ghi mục tiêu — số đó là do UI Rolly tự tính bằng SUM các dòng `input` có `type: 'Savings'` mà
`linking_savings_id` trỏ về mục tiêu (đối chiếu bằng `raw_rolly/input_savings_view.json`, một VIEW
Rolly tự join sẵn — xác nhận cùng 8 dòng, cùng `linking_savings_id: 49755`). 8 dòng này **đã được
Phase 9 import thành `transactions` thường từ trước** (bucket "Chuyển khoản/Tiết kiệm", 4 cặp sau khử
trùng lặp `linking_transfer_id`, `sourceId = 'rolly:$id'` của dòng walletLeg — id khớp:
`rolly:12450889`, `rolly:13061034`, `rolly:13381944`, `rolly:11916359`). Vì vậy Phase 19 KHÔNG tạo
giao dịch mới nào cho tiết kiệm — chỉ gắn `goalId` NGƯỢC vào 4 giao dịch đã có, qua `sourceId`
(`mapSavingsContributionSourceIds` đọc `input.json`, nhóm sourceId theo `linking_savings_id`). Tổng
`amountMinor` của 4 giao dịch này (7.000.000+16.200.000+10.000.000+10.000.000 = 43.200.000₫) khớp
**tuyệt đối** với `total_amount` mà chính Rolly đã tính — hai nguồn độc lập trùng khớp, xác nhận bằng
test thật đọc trực tiếp `raw_rolly/` (`rolly_real_savings_import_reconciliation_test.dart`).

**Migration v8→v9**: thêm `savings_goals.source_id` (nullable, unique index `idx_savings_goals_
source_id`) — bảng này chưa từng có khái niệm nguồn gốc import trước Phase 19, khác `transactions`
(có từ Phase 9). Cùng mẫu tách `addColumn` rồi `createIndex` hai bước (SQLite từ chối `ALTER TABLE ADD
COLUMN ... UNIQUE` trực tiếp), sinh qua đúng quy trình `stepByStep` đã chốt ở Phase 16 (`dart run
drift_dev make-migrations` → `dart run drift_dev schema steps ...` → thêm closure `from8To9`). 36 tổ
hợp migration test xanh (từ 27).

**Idempotency xác minh bằng test chạy IMPORT HAI LẦN thật** (`savings_goal_rolly_import_test.dart`),
không chỉ đọc code: `SavingsGoalRepository.importFromRolly` tính trước `sourceId` nào đã tồn tại
(giống `TransactionRepository.insertImportBatch`), lần chạy thứ hai `insertedGoals: 0` và KHÔNG tạo
thêm giao dịch nào — `UPDATE ... SET goal_id = ?` gán lại đúng giá trị cũ là phép idempotent tự nhiên
(khác INSERT, không cần logic "bỏ qua nếu đã liên kết" riêng).

### `chat_history_with_input_view.json` — QUYẾT ĐỊNH: không import, chỉ ghi nhận là log hội thoại

Đọc thật 741 dòng: 358 `role: 'user'` (tin nhắn Tony gõ, vd `"cafe 20k"`), 383 `role: 'assistant'`
(bình luận/lời khuyên AI Rolly tự sinh, vd với giao dịch "gửi xe 6k": *"Gửi xe là một khoản chi tiêu
cần thiết... hãy cân nhắc đi bộ..."*). 368/741 dòng có `is_transaction: true` + `transaction_id` trỏ
sang bảng `input` — nhưng đây chỉ là bản sao thông tin giao dịch ĐÍNH KÈM vào ngữ cảnh chat (để AI trả
lời đúng), KHÔNG phải một nguồn dữ liệu vận hành độc lập: `amount`/`category_id`/`date`... của các
dòng này chỉ lặp lại đúng dữ liệu `input` đã import ở Phase 9 (qua `transaction_id`), import lại sẽ
chỉ là trùng lặp vô nghĩa.

**Quyết định**: KHÔNG import vào bất kỳ bảng vận hành nào — đúng phán đoán ban đầu của prompt Phase
19. Bản chất đây là log hội thoại người-dùng/AI, không map được vào bất kỳ khái niệm nào TonyFino có
(không có bảng "chat log" — D9 không fork/copy tính năng AI-chatbot của Rolly, TonyFino cố tình không
có "AI trả lời" nào, xem Phase 8: "một sổ cái tình cờ nhận câu văn"). **Không commit file thô 741 dòng
vào git** — đây là nội dung chat CÁ NHÂN thật của Tony (giống lý do `raw_rolly/` bị gitignore từ Phase
2), khác `docs/rolly-schema.md` vốn chỉ trích 1-2 dòng ví dụ đã ẩn danh `user_id`. `docs/rolly-schema.
md § "chat_history_with_input_view"` (viết từ Phase 2, còn nguyên giá trị) đã ghi đúng: "Không cần
import, nhưng cực giá trị cho Phase 7" — giữ nguyên vai trò đó (nguồn tham khảo câu gõ tiếng Việt thật
cho corpus parser), không cần thêm tài liệu nào khác cho quyết định này.

## 2026-08-22 · Phase 20 · Thống kê theo danh mục con — 4 quyết định thiết kế, viết TRƯỚC KHI CODE

**Đọc lại code thật trước khi quyết định** (không tin tóm tắt ở TODOS.md § Phase 20, đọc trực tiếp):
`Categories.parentCategoryId` (Phase 13, CHỈ MỘT CẤP) đã đầy đủ CRUD; giao dịch đã gán được vào danh
mục con qua mọi picker hiện có (chúng đều đọc `categoriesProvider`/`activeCategoriesProvider`, cả hai
đều trả về danh sách PHẲNG gồm cả cha lẫn con, không phân biệt). `ReportsRepository.
watchCategoryBreakdown` gộp phẳng theo đúng `categoryId` gán trên giao dịch (qua `effectiveCategoryAmounts`,
Phase 14) — một danh mục con có giao dịch sẽ ra một hàng RIÊNG, độc lập với hàng của danh mục cha, dù
Category Chart mảng nào cũng vậy: pie chỉ đơn giản vẽ mọi hàng nó nhận được. `category_pie_card.dart`
chỉ có MỘT điểm chạm: cả biểu đồ (`GestureDetector` bọc `PieChart`, `PieTouchData(enabled: false)` nên
KHÔNG có touch theo từng lát) mở `_FullBreakdownSheet` — một danh sách PHẲNG tất cả danh mục, không
lồng cấp, không bấm tiếp được. `BudgetRepository.watchBudgetsForPeriod` cũng gộp theo `categoryId`
đúng của TỪNG hàng `budgets` — không có khái niệm "cha bao con" nào tồn tại; `budgets_screen.dart` đã
dùng `activeCategoriesProvider` (phẳng) nên **về mặt kỹ thuật Tony đã có thể đặt ngân sách riêng cho
một danh mục con từ trước phase này**, dù chưa chắc đã thử.

### Câu hỏi 1 — Giao dịch gán THẲNG vào danh mục cha có tính vào tổng cha không?

**Có, và không cần một "bucket ẩn danh" riêng.** Một giao dịch gán thẳng vào cha (không qua con nào)
đã có sẵn một hàng `CategorySourceAmount` với đúng tên/màu/icon CỦA CHÍNH danh mục cha đó (từ
`watchCategoryBreakdown` hiện tại, không đổi). Khi rollup lên cấp cha để vẽ pie chính, hàng này CỘNG
vào tổng cha; khi mở sheet xem chi tiết các danh mục con của cha đó, hàng này XUẤT HIỆN LUÔN trong
danh sách con — dùng đúng tên cha làm nhãn (vd "Thức ăn & Đồ uống: 500.000đ" nằm cùng danh sách với
"Ăn trưa thiết yếu: 480.000đ"), không bịa thêm nhãn "chưa phân loại con" nào — người dùng đọc là hiểu
ngay, không cần khái niệm mới.

### Câu hỏi 2 — Ngân sách: đặt được ở cấp cha tự động bao hết con, hay giữ độc lập từng danh mục?

**QUYẾT ĐỊNH: giữ NGUYÊN — độc lập theo từng danh mục (cha lẫn con đều là MỘT hàng `budgets` riêng),
KHÔNG thêm cơ chế "cha tự bao con".** Lý do:
1. **Không nằm trong phạm vi Tony yêu cầu** — yêu cầu gốc là thống kê/báo cáo, không phải ngân sách.
   Đổi ngữ nghĩa ngân sách là một quyết định lớn, riêng biệt (cùng lớp với Phase 15's carry-over),
   không nên bó vào một phase báo cáo.
2. **Tránh rủi ro đếm đôi thật sự nguy hiểm**: nếu cho phép "cha tự bao con" VÀ Tony (vô tình hoặc cố
   ý) đặt CẢ ngân sách cho cha LẪN ngân sách riêng cho một con của nó, một đồng chi tiêu ở con đó sẽ
   trừ vào CẢ HAI ngân sách cùng lúc — đây chính xác là lớp lỗi "double count" mà kỷ luật dự án luôn
   cảnh giác (Phase 15 carry-over, Phase 17 tag filter). Giữ nguyên độc lập loại bỏ hoàn toàn khả năng
   này.
3. **Không phá vỡ hành vi đã có**: `activeCategoriesProvider` phẳng đã cho phép đặt ngân sách trên
   danh mục con từ Phase 13 — nếu Tony đã/sẽ dùng tính năng đó, "cha tự bao con" sẽ âm thầm đổi ý
   nghĩa ngân sách con đã đặt trước, một kiểu breaking change không xin phép.
Nếu sau này Tony THẬT SỰ muốn ngân sách cấp cha bao hết con, đó nên là một quyết định + phase riêng,
đúng kỷ luật "quyết định trước khi code" đã áp dụng ở đây.

### Câu hỏi 3 — Biểu đồ chính: chỉ vẽ theo danh mục CHA (gộp hết con) hay giữ phẳng + thêm breakdown khi bấm?

**QUYẾT ĐỊNH: biểu đồ chính (pie + legend + "xem đầy đủ") chuyển sang vẽ theo danh mục CHA (rollup con
vào cha), đúng UX Rolly Tony đã minh hoạ bằng ảnh chụp — bấm vào MỘT hàng cha (không phải cả biểu đồ)
mở sheet xem breakdown các con của riêng cha đó (số tiền + % trên tổng CHA, không phải % trên tổng
toàn bộ).** "Chưa phân loại" (categoryId null) và lát "Khác" (>6 danh mục cha) giữ nguyên hành vi cũ,
không có breakdown con.

**Kỹ thuật rollup: làm ở tầng DART thuần, KHÔNG sửa SQL của `watchCategoryBreakdown`.** Đây là quyết
định kỹ thuật quan trọng nhất, chọn CHỦ ĐÍCH để loại bỏ hoàn toàn rủi ro Cartesian fan-out (JOIN nhân
đôi SUM) mà Tony cảnh báo — nếu làm rollup NGAY TRONG SQL (JOIN `categories` hai lần để tự tra cứu
danh mục cha rồi `groupBy` theo cha), sẽ tái tạo đúng lớp bẫy đã gặp ở Phase 15/17. Thay vào đó:
`watchCategoryBreakdown` giữ NGUYÊN 100% (vẫn gộp phẳng theo `categoryId`, đã test kỹ, đang phục vụ cả
bộ lọc `categoryIds`/`tagIds` của toàn màn Báo cáo — đổi ngữ nghĩa của nó sẽ ảnh hưởng dây chuyền tới
heatmap/period summary/bộ lọc, không chỉ pie chart) — một hàm THUẦN DART mới
(`rollupToRootCategories`, `lib/features/reports/domain/category_slice.dart`) nhận List phẳng đã ĐÚNG
TỪNG SỐ từ SQL + danh sách `Category` (để biết `parentCategoryId` của từng hàng), rồi CHỈ CỘNG LẠI các
số ĐỘC LẬP đã đúng sẵn theo nhóm `parentCategoryId ?? id` — không JOIN, không groupBy SQL nào thêm,
nên KHÔNG THỂ fan-out (mỗi số hạng chỉ được cộng đúng MỘT lần, tự nhiên đúng bằng phép `fold` cộng
dồn). `categoriesProvider` (đã có, `watchAll()` KHÔNG lọc `isArchived`) là nguồn danh sách category —
cố tình không dùng `activeCategoriesProvider`, vì lịch sử báo cáo phải hiện đúng tên danh mục CŨ dù đã
lưu trữ (đúng hành vi hiện có của `watchCategoryBreakdown`'s JOIN, không lọc archive).

### Câu hỏi 4 — Giữ giới hạn danh mục con MỘT CẤP, hay cho nhiều cấp hơn?

**QUYẾT ĐỊNH: giữ nguyên MỘT CẤP** (không đổi gì ở `CategoryRepository`/schema). Cả ảnh Rolly Tony gửi
lẫn yêu cầu gốc đều chỉ thể hiện đúng hai tầng (danh mục lớn → danh mục phụ), không có tầng ba nào.
Phase này CHỈ thêm báo cáo trên cấu trúc 1-cấp đã có từ Phase 13, không đụng CRUD/schema danh mục —
mở rộng nhiều cấp (nếu cần) là một quyết định kiến trúc riêng, tốn một migration khác, ngoài phạm vi
yêu cầu "thống kê theo danh mục con" ban đầu.

## 2026-08-22 · Ngay sau Phase 20 · Khôi phục danh mục phụ cho lịch sử Rolly — Phase 9 đã bỏ sót một field

Sau khi báo Phase 20 xong, Tony chỉ ra hiểu lầm: câu hỏi "đã có tính năng tạo danh mục con chưa" không
phải hỏi về NĂNG LỰC (đã có từ Phase 13/20) mà về việc DỮ LIỆU THẬT của Tony đã có sẵn cấu trúc này ở
Rolly nhưng chưa xuất hiện trong TonyFino. Đối chiếu lại `raw_rolly/subcategory.json` +
`raw_rolly/input.json` xác nhận: **324/362 giao dịch thật (90%)** có gắn `subcategory_id` ở Rolly (vd
"Giao thông → Xăng/Gửi xe/Sửa chữa", "Thức ăn & Đồ uống → Ăn sáng/trưa/tối thiết yếu" — đúng khớp ví
dụ Tony đưa ra), nhưng **`rolly_json_parser.dart` (Phase 9) chưa từng đọc field `subcategory_id`**,
chỉ lấy `category_id` — nên toàn bộ 358 giao dịch đã nhập từ Phase 9 hiện chỉ có danh mục CẤP GỐC, mất
sạch thông tin danh mục phụ gốc. Đây chính là lý do khi xác minh Phase 20 trên máy thật thấy "chưa có
danh mục con nào đang dùng" — không phải tính năng thiếu, mà dữ liệu lịch sử chưa được khôi phục.

**Quyết định (Tony chọn "làm ngay", không chờ lên lịch Phase riêng)**: viết một bước khôi phục bổ sung
(`rolly_subcategory_parser.dart` + `CategoryRepository.backfillSubcategoriesFromRolly`), KHÔNG tạo
giao dịch mới — chỉ gán lại `categoryId` của các giao dịch ĐÃ CÓ (tìm qua `sourceId` đã ghi từ Phase 9)
từ danh mục cha sang danh mục con tương ứng (tạo mới danh mục con nếu chưa có, tái sử dụng nếu đã có
đúng tên dưới đúng cha).

**Idempotency KHÔNG dùng cột đánh dấu riêng — suy ra từ hình dạng dữ liệu hiện tại**: một giao dịch chỉ
được xử lý nếu `categoryId` HIỆN TẠI của nó trỏ tới một danh mục CẤP GỐC (`parentCategoryId == null`);
nếu đã là danh mục con (đã chạy backfill trước đó, hoặc Tony tự sửa tay) thì bỏ qua nguyên vẹn. Cách
này tự nhiên loại trừ một lỗi logic thật đã suýt mắc: nếu chạy lại và cứ lấy "danh mục hiện tại làm
cha" một cách mù quáng, lần chạy thứ hai sẽ cố tạo "danh mục con của danh mục con" — vi phạm giới hạn
1 cấp của Phase 13 và bị `CategoryRepository` chặn lỗi. Xác nhận bằng test chạy backfill HAI LẦN thật.

**Tên trùng khác cha KHÔNG được gộp nhầm**: dữ liệu thật của Tony có "Phát sinh" vừa là danh mục con
của "Giao thông" vừa là danh mục con của "Mua sắm" (hai id Rolly khác nhau) — khoá tra cứu/tạo mới
dùng CẶP `(parentCategoryId, tên)`, không phải tên đơn lẻ, nên hai "Phát sinh" này tạo thành hai danh
mục con độc lập, không lẫn vào nhau. UI mới: mục "Danh mục phụ Rolly" trong `ImportScreen`, cùng quy
ước file gộp `{"subcategory": [...], "input": [...]}` đã dùng ở Phase 19.

## 2026-08-22 · Phase 25 · Hai câu hỏi mở từ nghiên cứu UI/UX Rolly — quyết định TRƯỚC KHI CODE

**Câu 1 — Chỉ số "sức khoẻ tài chính" tổng hợp ở Home: KHÔNG làm.** Rolly có một thước đo màu/phần
trăm tổng hợp "Health" ở trang chủ. TonyFino KHÔNG thêm tương đương. Lý do: Phase 8 đã chốt tông giọng
"một sổ cái tình cờ nhận câu văn" — trung thực, không phán xét, không gamification (không avatar/typing
indicator/lời chào). Một "chỉ số sức khoẻ" buộc phải có công thức chấm điểm chủ quan (ngưỡng nào là
"tốt"? trọng số ra sao giữa tiết kiệm/ngân sách/nợ?) — khác hẳn "An toàn để tiêu hôm nay" (Phase 15,
đã có), vốn chỉ là MỘT phép tính số học khách quan (dòng tiền còn lại ÷ số ngày còn lại), không phán
xét tốt/xấu. Thêm một chỉ số tổng hợp mới sẽ đi ngược tông giọng đã chốt từ Phase 8 mà không có yêu cầu
cụ thể nào từ Tony đủ mạnh để đánh đổi. Nếu sau này Tony thật sự muốn, đây nên là một quyết định + phase
riêng, không lồng vào đây.

**Câu 2 — `credit_limit`/`due_date` cho ví kiểu thẻ tín dụng: KHÔNG làm, để Backlog.** Dữ liệu thật của
Tony hiện chỉ có đúng 1 ví `"cash"` (`raw_rolly/wallet_view.json`) — chưa có nhu cầu thật nào cho ví
thẻ tín dụng. Đúng nguyên tắc "không xây cho yêu cầu giả định" — thêm 2 cột schema (`credit_limit`,
`due_date`) cho một nhu cầu chưa xác nhận là một migration không cần thiết lúc này. Ghi vào `TODOS.md`
§ Backlog để không quên, làm khi Tony thật sự cần theo dõi thẻ tín dụng.

## 2026-08-22 · Phase 21 · Package widget Android cho Flutter — research thật trước khi chọn

**Chọn `home_widget` (pub.dev) bản `0.9.3`**, đọc trực tiếp `CHANGELOG.md` + Android source thật
trên GitHub (`github.com/ABausG/home_widget`, monorepo `packages/home_widget/`), không theo trí nhớ
về "cách làm widget Flutter" — API mảng này đổi nhanh (đúng cảnh báo của prompt). Bằng chứng cụ thể
đã đọc, không suy đoán:
- `0.7.0+1` (fix log): "Runtime error when starting App from Widget on **Android 15**" — trực tiếp
  liên quan tới rủi ro Android 15/16 mà Phase 21 lo ngại.
- `0.9.2`: "Support Android Gradle Plugin **9.x**" — khớp đúng Gradle 9.1/9.5 dự án đã cache (E-note
  Phase 1), không phải may mắn tương thích ngược.
- `0.5.0`: Jetpack Glance support (không dùng ở đây — xem lý do bên dưới).
- README ghi rõ: "HomeWidget does **not** allow writing Widgets with Flutter itself. It still
  requires writing the Widgets with native code" — package chỉ là cầu nối dữ liệu
  (`saveWidgetData`/`updateWidget`/SharedPreferences), KHÔNG tự vẽ UI hộ mình.

**Vì sao package này KHÔNG vi phạm D9** ("không fork, không mua template, tự viết design system"):
D9 nói về UI KIT làm hộ giao diện — `home_widget` không làm việc đó, giao diện widget 100% là
`SpendingWidgetProvider.kt` + `res/layout/spending_widget.xml` tự viết tay (màu copy từ đúng bảng
màu light/dark trong TODOS.md § Design system, bo góc 18dp khớp `radii.lg`, KHÔNG đổ bóng vì RemoteViews
không hỗ trợ `BoxShadow` tuỳ ý — dùng viền hairline 1dp thay, đúng tinh thần luật 11). Chỉ dùng
`HomeWidgetLaunchIntent.getActivity()` (một hàm tiện ích mở Activity, không phải UI) để mở app khi
chạm widget.

**Vì sao AppWidgetProvider + RemoteViews cổ điển, không phải Jetpack Glance** (dù package hỗ trợ cả
hai, thấy rõ qua `packages/home_widget/android/src/.../HomeWidgetGlanceWidgetReceiver.kt` và ví dụ
`glance/` trong repo): Glance cần thêm phụ thuộc Jetpack Compose vào Android build — dự án này không
dùng Compose ở đâu khác (100% Flutter UI + Kotlin thuần cho phần native ít ỏi), và widget chỉ hiện
MỘT dòng số + một dòng nhãn — không đủ phức tạp để đáng đánh đổi thêm một dependency graph mới. Bản
CHANGELOG xác nhận Glance chỉ là TÙY CHỌN kể từ 0.5.0, RemoteViews cổ điển vẫn được hỗ trợ đầy đủ.

**Nguồn dữ liệu — tái dùng, không tính lại**: `HomeWidgetSyncHook` lắng nghe đúng `monthSummaryProvider`
(cùng provider backing hero card `_HeroCard` ở `transactions_screen.dart`, Phase 6) qua
`ref.listenManual(..., fireImmediately: true)`. Gửi thẳng `MonthSummary.expense.format()` (nguyên văn
`Money.format()`) sang native dưới dạng CHUỖI đã định dạng sẵn — phía Kotlin chỉ hiển thị chuỗi, không
parse lại số hay tự làm tròn/định dạng VND theo cách riêng. Loại trừ hoàn toàn rủi ro hai nơi tính
tiền lệch nhau.

**Độ trễ cập nhật — đo thật, không hứa "real-time"**: xem TODOS.md § Phase 21 "Kết quả" cho 2 số đo
thật (64ms, 156ms) và giải thích tại sao nhanh (cập nhật kích hoạt từ app đang mở nền trước, không
qua đường nền bị Android 15/16 giới hạn).

## 2026-08-22 · Phase 22 · Chọn hướng "đẹp, 3D, thú vị" — TRƯỚC KHI CODE, hỏi Tony trực tiếp

Đúng yêu cầu của prompt ("đây là quyết định thẩm mỹ có tác động lớn... DỪNG LẠI hỏi Tony thay vì tự
đoán"), đã hỏi Tony trực tiếp qua 2 câu hỏi có preview trước khi viết bất kỳ dòng code nào.

**Quyết định 1 — Hướng chọn: "Hướng 1 kết hợp một phần Hướng 3"** (đúng đề xuất mạnh nhất của
`docs/design-research-2.md` § D, Tony xác nhận chọn khi được trình bày cả 4 lựa chọn — 3 hướng gốc +
bản kết hợp). Cụ thể:
- **Vùng dữ liệu dày (danh sách giao dịch, form, biểu đồ Báo cáo, hàng ngân sách): giữ nguyên 100%**,
  không đổi một pixel nào — đúng luật bất biến của phase.
- **Hero card màn Giao dịch** (`_HeroCard` trong `transactions_screen.dart`): thêm nền gradient
  mesh/shader động, CHỈ ở đây — không chạy trong lúc cuộn danh sách (né đúng hồi quy GPU
  `BackdropFilter`/Impeller đã ghi trong nghiên cứu).
- **Mascot** (khái niệm mới, xem Quyết định 2 bên dưới về công cụ): xuất hiện ở empty state (màn
  Giao dịch/mục tiêu tiết kiệm khi chưa có dữ liệu), onboarding (màn hình mới, chưa từng tồn tại), và
  khoảnh khắc ăn mừng khi đạt mục tiêu tiết kiệm (`SavingsGoalProgress.isAchieved` đã có sẵn từ Phase
  16, chỉ thiếu phần "phản ứng" khi CHUYỂN sang trạng thái đó).
- **3-6 icon 3D chọn lọc** (Fluent Emoji, MIT — xác nhận license tại
  `github.com/microsoft/fluentui-emoji`): dùng cho glyph danh mục nổi bật hoặc khoảnh khắc ăn mừng,
  KHÔNG BAO GIỜ trong hàng giao dịch/danh sách — implement qua field tuỳ chọn mới trên
  `CategoryAvatar` (cùng khuôn mẫu field `emoji` đã có: mặc định `null`, mọi call site không truyền
  gì giữ nguyên pixel-identical).
- Loại **Hướng 2** (mở rộng kính) vì đúng như nghiên cứu tự đánh giá: đọc ra "cao cấp/lạnh" chứ không
  "vui" — lệch chữ THÚ VỊ mà Tony yêu cầu gốc.

**Quyết định 2 — Mascot dùng Flutter thuần (`CustomPainter`/`AnimationController`), KHÔNG dùng
package `rive` như TODOS.md/nghiên cứu ban đầu đề xuất.** Đây là một lệch chuẩn có chủ đích so với kế
hoạch gốc, hỏi Tony trực tiếp trước khi quyết — lý do: mascot Rive cần được VẼ và dựng state machine
trong **Rive Editor**, một công cụ đồ hoạ tương tác — không phải thứ viết được bằng code. Hai lựa
chọn khác đã bị loại: (a) dùng asset Rive có sẵn từ cộng đồng — rủi ro đúng thứ D9 cấm ("không fork,
không mua template"), và license không rõ ràng cho từng file riêng lẻ; (b) dựng hạ tầng tích hợp
`rive` + để placeholder chờ Tony tự vẽ sau — bị loại vì phase sẽ không thể coi là hoàn tất phần mascot
("thú vị" — đúng phần khớp nhất theo nghiên cứu — sẽ vắng mặt). Tony chọn (c): thay hoàn toàn bằng
animation Flutter thuần, giữ NGUYÊN hành vi/state machine đã định (idle/streak/celebrate phản ứng
theo dữ liệu thật, streak tính theo NGÀY GIAO DỊCH THẬT không phải ngày nhập — đúng yêu cầu tránh lỗi
Rolly đã ghi trong `docs/rolly-product-research.md`), chỉ đổi CÔNG CỤ vẽ. Vẽ bằng hình học/màu lấy
trực tiếp từ `lib/theme/tokens/palette.dart` (tím `paletteVioletLight/Dark`, không màu mới), animation
dùng token có sẵn (`appDurations`/`appCurves`), giữ đúng D9 "tự viết, không template".

**"Đạt mục tiêu" cần một tín hiệu CHUYỂN TRẠNG THÁI (edge-triggered), không phải trạng thái tĩnh** —
`SavingsGoalProgress.isAchieved`/`DebtProgress.isSettled` (đã có, Phase 16) chỉ là boolean tính lại
mỗi lần build, không tự phân biệt "đã đạt từ trước" với "vừa đạt xong" — phần mascot ăn mừng cần logic
mới so sánh giá trị TRƯỚC/SAU để chỉ kích hoạt animation đúng một lần tại thời điểm chuyển.

**KHÔNG dùng trạng thái `BudgetPaceState.over` cho "ăn mừng ngân sách"** — với ngân sách, "over" nghĩa
là ĐÃ VƯỢT (xấu, tô đỏ), ngược hoàn toàn với "ăn mừng". Không thêm khái niệm "ngân sách ăn mừng" nào
trong phase này (không có yêu cầu cụ thể, và "giữ trong ngân sách tới cuối kỳ" không có tín hiệu
CHUYỂN TRẠNG THÁI rõ ràng như goal — chỉ biết chắc vào đúng lúc kỳ kết thúc) — mascot ăn mừng chỉ gắn
với mục tiêu tiết kiệm/nợ vay (Phase 16), nơi tín hiệu đã rõ ràng.

## 2026-08-22 · Addendum sau Phase 22 · "Tiêu vặt" — danh mục con mặc định đầu tiên

Tony test app trên ĐIỆN THOẠI THẬT (chưa từng import Rolly ở đó — hoàn toàn trống) và báo trực tiếp:
gõ "cafe 20k" phải vào "Ăn uống → Tiêu vặt", không phải chỉ "Ăn uống". Không phải phase mới — một sửa
dữ liệu/seed nhỏ, theo đúng khuôn "làm ngay" đã dùng ở addendum sau Phase 20.

**Phát hiện gốc rễ**: `_seedDefaultCategories` (chạy 1 lần lúc `onCreate`) chỉ từng tạo 12 danh mục
CẤP GỐC — chưa từng seed danh mục con nào theo mặc định. Máy thật của Tony vì vậy có 12 danh mục gốc,
0 danh mục con — "Tiêu vặt" (tên Tony tự dùng trong Rolly thật, đã thấy trên emulator qua backfill
Phase 20 addendum) không tồn tại cho tới khi tự tay tạo. `category_matcher`/`recordKeywordCorrection`
(vòng lặp học) đã hỗ trợ TRỎ THẲNG vào danh mục con từ trước — không cần sửa logic khớp, chỉ cần DỮ
LIỆU (danh mục con + từ khoá) tồn tại sẵn.

**Quyết định**: seed thêm CHÍNH XÁC một danh mục con mặc định — "Tiêu vặt" dưới "Ăn uống" — với 4 từ
khoá chuyển từ danh mục gốc sang: `cà phê`/`cafe`/`cf` (weight 1.3/1.3/1.1, nguyên vẹn) + `ăn vặt`
(weight 1.1, cùng nghĩa "tiêu vặt"). Cố ý KHÔNG đoán thêm danh mục con nào khác Tony chưa yêu cầu.

**Schema v9→v10** (`from9To10`, thuần DML — không đổi cột/bảng nào nên dùng thẳng getter SỐNG
`categories`/`categoryKeywords`, không cần `schema.xxx`, an toàn vì không có rủi ro "thừa cột ở phiên
bản trung gian" của Phase 16). Idempotent theo TÊN: nếu "Tiêu vặt" đã tồn tại dưới "Ăn uống" (đúng
tình huống emulator — đã có từ backfill Rolly thật, Phase 20 addendum), TÁI SỬ DỤNG thay vì tạo
trùng — xác nhận trực tiếp trên emulator: "Danh mục con: 7" trước và sau khi cài bản mới, không tăng
lên 8. `_seedDefaultCategories` (đường cài MỚI) cũng seed y hệt, cho user hoàn toàn mới sau này.

**Xác minh trên CẢ HAI máy**: emulator (nâng cấp, đã có "Tiêu vặt" thật từ trước) — không tạo trùng,
dữ liệu/tổng tiền giữ nguyên tuyệt đối. Test mới (`quick_add_screen_test.dart`): DB HOÀN TOÀN MỚI,
gõ "cafe 20k" → `categoryId` khớp thẳng "Tiêu vặt" (không phải "Ăn uống"), không cần sửa tay lần nào
— đúng khớp yêu cầu gốc của Tony. `pubspec.yaml` → `0.19.1+20`.

## 2026-08-22 · Phase 23 · AI fallback — model/endpoint Gemini xác nhận qua docs sống, không theo trí nhớ

**Nghiên cứu trước khi code (yêu cầu tường minh của phase này)** — tra trực tiếp `ai.google.dev` thay
vì tin model ID từng biết trước 2026:

- **Endpoint dùng: `models/{model}:generateContent`** (REST cổ điển, `POST
  https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key=API_KEY`), CỐ Ý
  KHÔNG dùng Interactions API mới (`v1beta2/interactions`) dù đó là hướng Google khuyến nghị cho tích
  hợp MỚI — trang migrate-to-interactions của Google tự xác nhận `generateContent` "vẫn được hỗ trợ đầy
  đủ" (`fully supported`), và 4 lý do Google đưa ra để chọn Interactions API (server-side history đa
  lượt, observable execution steps, tool-use tác tử, tác vụ nền dài) đều KHÔNG áp dụng cho việc này —
  đây là một cuộc gọi ĐƠN, KHÔNG TRẠNG THÁI (không lịch sử hội thoại, không tool, không tác vụ nền).
  `generateContent` đơn giản hơn, khớp đúng yêu cầu "JSON schema PHẲNG" của phase.
- **Model chọn: `gemini-3.5-flash-lite`** — Firebase AI Logic (`firebase.google.com/docs/ai-logic/models`,
  đọc trực tiếp) mô tả đây là "high-volume, cost-sensitive workhorse model", tức chính là hạng mà Google
  đang chủ động khuyến nghị cho use-case rẻ/khối lượng lớn. **Cố tình KHÔNG chọn `gemini-2.5-flash-lite`**
  dù giá per-token thấy trên trang pricing (đọc trực tiếp `ai.google.dev/gemini-api/docs/pricing`) rẻ hơn
  một chút ($0.10/$0.40 mỗi triệu token vào/ra so với $0.30/$2.50 của 3.5-flash-lite) — vì tra chéo thêm
  cho thấy **cả họ Gemini 2.5 đã bị đánh dấu deprecated, dự kiến retire tháng 10/2026** (chưa đầy 2 tháng
  kể từ lúc code phase này), một model sắp gãy dịch vụ không phải lựa chọn hợp lý dù rẻ hơn vài xu. Ở quy
  mô gọi thật (fallback-của-fallback, ~10% số câu, mỗi câu vài chục token) chênh lệch giá giữa hai lựa
  chọn là không đáng kể — vài xu/tháng theo đúng ước tính D8.
- **JSON schema PHẲNG**: `generationConfig.responseMimeType: "application/json"` +
  `generationConfig.responseSchema` — 7 field vô hướng (`amount_found` bool, `amount_minor` int,
  `confident` bool, `date_iso` string, `date_explicit` bool, `category_id` string với `enum` là danh
  sách id danh mục THẬT của Tony kèm `"none"`, `note` string), KHÔNG object/array lồng nhau — đúng yêu
  cầu "phẳng" của phase, và ép Gemini không thể bịa category ngoài danh sách nhờ ràng buộc `enum` ở tầng
  schema (không phải chỉ dặn trong prompt).

**Kiến trúc proxy (D8, đọc trước khi code)**: một Dart CLI ĐỘC LẬP ở `ai_proxy/` (KHÔNG phải một phần
`lib/` — không đi qua Luật #4 vì không phải code Flutter chạy trên điện thoại, đây là dịch vụ chạy trên
MÁY TÍNH của Tony) — `HttpServer` thuần `dart:io`, bind CHỈ `127.0.0.1` (không expose ra ngoài dù
`tailscale serve reset` có lỡ chạy — lớp phòng thủ thứ hai ngoài xác thực mạng của tailnet). Nhận bất kỳ
request POST nào (không khoá cứng đường dẫn `/parse` — tránh đoán tailscale `--set-path` có strip prefix
hay không, để bên nhận tự khoan dung với path). Đọc API key từ biến môi trường `GEMINI_API_KEY`
(`ai_proxy/.env`, đã nằm trong `.gitignore` sẵn — mẫu `.env.example` mới thêm, có commit). **Khoá thật
Tony phải tự cấp** — không có cách nào một agent tạo được khoá paid-tier gắn với tài khoản Google Cloud
billing của Tony; mục checklist "Key paid tier" chỉ có thể LÀM SẴN CƠ CHẾ (đọc từ env, không hardcode,
lỗi rõ ràng nếu thiếu), không thể tự cấp khoá — Tony tạo khoá ở [Google AI Studio], bật billing (paid
tier, không train), dán vào `ai_proxy/.env`.

**Sheet đồng ý một lần**: `cloudFallbackEnabled` (bool, mặc định `false`) + `cloudFallbackConsentAsked`
(bool, mặc định `false`) + `aiFallbackBaseUrl` (string, mặc định URL tailnet của máy này) — 3 field mới
trên `AppSettingsController`, cùng khuôn 6 bước các field khác đã dùng (Phase 17/22). Sheet
(`showCloudFallbackConsentSheet`) tự bật lần đầu MỘT thẻ trong `quick_add_screen` cần fallback (không
hiểu hoặc không chắc số tiền) VÀ `cloudFallbackConsentAsked == false` — chấp nhận thì bật cờ + retry
NGAY thẻ đó qua fallback thật; từ chối thì chỉ đánh dấu đã hỏi, hành vi giữ nguyên y hệt trước phase này
(thẻ lỗi sửa tay, không có gì thay đổi). Bật/tắt tay qua Cài đặt cũng tự đánh dấu đã hỏi, để sheet không
bật lại đè lên một lựa chọn đã tường minh.

**Xuống cấp im lặng**: `TailnetFallback.tryParse` bọc TOÀN BỘ lời gọi mạng (kết nối/timeout 10s/JSON
hỏng/status khác 200) trong một `try/catch` DUY NHẤT trả `null` — đúng hợp đồng có sẵn của
`AiParseFallback` (`null` = "không cải thiện được gì", tầng gọi giữ nguyên kết quả cục bộ) — không có
đường nào ở đây có thể khiến app treo/crash vì mạng.

**Việc CHƯA làm được, tương tự khoảng hở Phase 18 OCR**: không có khoá Gemini paid-tier thật trong tay ở
phiên này, nên "Xác minh: end-to-end câu tiếng Việt mơ hồ giải quyết qua fallback thật" KHÔNG thể tự kiểm
chứng — chỉ kiểm chứng được bằng HTTP client giả (unit test) + chế độ máy bay/proxy-không-với-tới (test
bắt buộc còn lại, tự chạy được không cần khoá). Để lại checklist "Key paid tier" ở dạng "cơ chế đã sẵn
sàng, chờ Tony dán khoá thật", không tự đánh dấu xong bằng cách giả lập.

[Interactions API vs generateContent](https://ai.google.dev/gemini-api/docs/migrate-to-interactions) ·
[generateContent REST reference](https://ai.google.dev/api/generate-content) ·
[Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing) ·
[Firebase AI Logic supported models](https://firebase.google.com/docs/ai-logic/models)

## 2026-08-22 · Phase 24 · R8/ProGuard cho drift + sqlite3mc — KHÔNG rule nào cần, 2 rule cũ là no-op

**Nghiên cứu trước khi code (yêu cầu tường minh của phase)** — đọc trực tiếp source `drift-2.34.0`,
`sqlite3-3.5.2`, `drift_flutter-0.3.1` trong `~/.pub-cache`, không suy đoán:

- Cả ba package **100% Dart thuần** — không một file `.java`/`.kt`/`.gradle` nào, không khai
  `flutter.plugin` platform channel nào trong `pubspec.yaml`. R8/ProGuard chỉ xử lý bytecode JVM đã
  biên dịch — không có bề mặt nào ở đây để nó động vào.
- `sqlite3mc` (native lib mã hoá) load qua cơ chế **Dart native-assets/build-hooks** (`hooks.user_defines`
  đã cấu hình sẵn từ Phase 3) — `lib/src/ffi/bindings.dart` dùng binding `@Native` thẳng, không qua
  `System.loadLibrary`/JNI của Java. Việc load này do chính Dart VM/Flutter engine xử lý, ngoài tầm với
  của R8.
- Không tìm thấy issue/changelog nào của `simolus3/drift` hay `simolus3/sqlite3.dart` về R8/ProGuard.
- **2 rule cũ trong `proguard-rules.pro` đều là no-op, đã XOÁ**: `org.sqlite.**` là rule của một package
  JNI HOÀN TOÀN KHÁC (`requery/sqlite-android`, dòng cũ mà `sqflite`-kiểu-cũ hay dùng) — không liên quan
  gì tới drift/sqlite3.dart, `grep` xuyên cả 3 package xác nhận chuỗi `org.sqlite` không xuất hiện ở đâu
  cả. `com.tony.**` gõ sai namespace thật (`dev.tony.tonyfino`, không phải `com.tony.*`) — kể cả gõ đúng
  thì code của chính app cũng không cần keep rule (không phải bề mặt API thư viện ai đó gọi vào qua
  reflection).

**Kết luận**: không thêm rule R8 nào mới cho drift/sqlite3mc — không cần. Rủi ro release-mode thật sự
(nếu có) nằm ở các plugin Kotlin/Java khác (ML Kit đã xử lý Phase 18) hoặc ở tầng shrinkResources/asset,
không phải ở tầng thư viện DB. Xác minh thật vẫn là build+chạy bản release trên emulator (mục tiếp theo
của Phase 24), không dừng ở suy luận tĩnh.

## 2026-08-22 · Phase 24 · Diễn tập backup→gỡ cài→restore lộ ra: backup thiếu 7 bảng + 2 cột — vá NGAY, không lùi lại

**Phát hiện sống, không phải suy luận**: kéo file backup thật từ máy Tony (emulator, sản xuất) qua
"Sao lưu ngay" rồi đọc trực tiếp JSON — `savingsGoals` (mục tiêu "CCTG"/"Xe máy" thật của Tony),
`debts`, `tags`, `transactionTags`, `recurringTransactions`, `transactionLines`, `transactionTemplates`
đều KHÔNG có trong file, và `transactions[].goalId`/`.debtId` cùng `budgets[].carryOver` cũng vắng mặt
dù các cột này đã tồn tại từ Phase 15/16. Đây chính là khoảng hở đã được flag từ Phase 17 ("found but
explicitly NOT fixed") — nhưng diễn tập của Phase 24 biến nó từ một dòng ghi chú thành một sự kiện CỤ
THỂ: mục tiêu tiết kiệm thật của Tony sẽ biến mất vĩnh viễn nếu anh phải restore từ backup hôm nay.

**Quyết định: vá ngay trong Phase 24, không lùi sang phase khác.** Lý do — đây chính là phạm vi của
phase này ("CỔNG trước khi giao hàng", diễn tập backup là mục quan trọng nhất được Tony tự tay nhấn
mạnh: "file backup trong app là đường phục hồi DUY NHẤT tồn tại"). Một cổng hardening mà phát hiện
đường phục hồi duy nhất bị hỏng rồi vẫn cho qua vì "không thuộc phạm vi phase" là tự mâu thuẫn với mục
đích tồn tại của chính phase đó.

**Cách vá**: thêm export/import cho cả 7 bảng + 2 cột thiếu vào `BackupService`, giữ NGUYÊN
`formatVersion = 1` (không đổi cấu trúc key CŨ, chỉ CỘNG THÊM key mới — đúng tiền lệ đã dùng cho
`wallets`/`parentCategoryId`/`sortOrder`/`emoji`/`receiptImageFilename` ở các phase trước: mỗi khoá mới
đọc qua `?? const []`/`as T?`, backup CŨ thiếu khoá vẫn import được, coi như "không có dòng nào" thay vì
lỗi). Thứ tự xoá/nạp lại theo đúng hướng phụ thuộc khoá ngoại LOGIC (dù DB chưa bật `PRAGMA
foreign_keys` nên không bắt buộc) — con trước cha lúc xoá, cha trước con lúc nạp.

**Xác minh**: 2 test mới trong `backup_roundtrip_test.dart` — (1) tạo đủ dữ liệu ở cả 7 bảng mới +
`goalId`/`debtId`/`carryOver`, export → xoá sạch → import → so khớp TỪNG BẢNG; (2) giả lập một backup
CŨ (xoá đúng 7 khoá mới khỏi một export thật) vẫn import thành công, các bảng mới rỗng chứ không lỗi —
chứng minh khả năng tương thích ngược với backup Tony đã lỡ tạo trước Phase 24. 852/852 test pass.

## 2026-08-22 · Phase 24 · Diễn tập lộ ra bug thứ hai: "database is locked" trên cài mới — chính là bug đã flag "trước v1.0.0" ở Phase 21, giờ tái hiện được

**Bắt SỐNG qua diễn tập**: ngay sau khi gỡ cài + cài lại (bản đã vá backup ở trên) rồi bấm Khôi phục,
app crash với `SqliteException(5): database is locked` ngay ở `PRAGMA user_version = 10` — trước cả
khi `BackupService.importFromJson` kịp chạy. Đây CHÍNH XÁC là lớp lỗi đã flag từ Phase 21 nhưng chưa
sửa: *"fresh-install-only race condition (`idx_transactions_source_id already exists`, unresolved,
flag before v1.0.0)"* — cùng một nguyên nhân gốc, chỉ khác triệu chứng cụ thể lần này.

**Nguyên nhân, đọc thẳng từ logcat + source, không suy đoán**: `bootstrap.dart` gọi
`AutoBackupScheduler().initialize()` VÔ ĐIỀU KIỆN (không phụ thuộc cờ "Sao lưu tự động" có bật hay
không) — hàm này `Workmanager().registerPeriodicTask(...)` không có `initialDelay`, và WorkManager
CÓ THỂ chạy lần đầu gần như ngay sau khi đăng ký (không mặc định đợi hết `frequency`). Trên một lần
CÀI MỚI, điều đó khiến isolate nền của `AutoBackupScheduler` (tự mở `openAppDatabase()` riêng, đúng
kiến trúc Phase 12 — mỗi isolate một connection) đua với isolate chính (cũng đang mở
`openAppDatabase()` lần đầu cho DB HOÀN TOÀN MỚI) để cùng tạo schema trên MỘT file — không có `PRAGMA
busy_timeout` thì SQLite ném "database is locked" ngay lập tức thay vì đợi, thay vì báo lỗi index đã
tồn tại (Phase 21) lần này rơi đúng vào bước `PRAGMA user_version = ...` của drift's migration runner.

**Vá theo 2 lớp** (`lib/data/db/open_database.dart`, `lib/data/services/backup/auto_backup_worker.dart`):
(1) **gốc rễ** — thêm `PRAGMA busy_timeout = 5000;` vào `openAppDatabase()`'s `setup:` callback (áp
dụng cho MỌI connection đi qua hàm này, cả isolate chính lẫn isolate nền) — SQLite giờ ĐỢI tới 5s cho
lock giải phóng thay vì ném lỗi ngay, đúng công dụng chuẩn của pragma này cho ứng dụng nhiều connection.
(2) **phòng thủ thêm** — `registerPeriodicTask` thêm `initialDelay: Duration(minutes: 1)`, giảm khả
năng va chạm xảy ra ngay từ đầu (không phải sửa gốc, chỉ giảm tần suất cần tới lớp (1)).

**Xác minh**: diễn tập lại TOÀN BỘ chu trình gỡ cài→cài lại→khôi phục trên đúng bản đã vá — không còn
crash, dữ liệu thật (hero card, mục tiêu CCTG, 4 giao dịch liên kết) khớp tuyệt đối oracle sau restore
(xem TODOS.md § Phase 24 "Kết quả" cho số liệu đầy đủ). `flutter test` 852/852 vẫn xanh sau vá — không
có test tự động nào tái hiện được race điều kiện đa-isolate này (bản chất cần 2 tiến trình OS thật,
đúng lý do bug tồn tại "vô hình" suốt từ Phase 21 tới giờ dù test suite luôn xanh) — bằng chứng DUY
NHẤT là diễn tập trên thiết bị thật, đúng lý do Phase 24 yêu cầu diễn tập này chứ không chỉ tin test.

## 2026-08-25 · Sau v1.0.1 · "hủ tíu trưa 30k" không xuống được danh mục con — hai bug độc lập cùng chặn tầng hai

**Tony báo**: *"Tôi nhấn 'hủ tíu trưa 30k' chỉ có thể chọn được thư mục đồ ăn, chưa chọn được thư mục
con là đồ ăn trưa."* Sổ thật của Tony có sẵn `Thức ăn & Đồ uống › Ăn trưa thiết yếu` (một trong 30
danh mục con nhập từ Rolly, xem `dist/tonyfino_subcategory_bundle.json`), nên đây không phải chuyện
thiếu dữ liệu. Đào ra **ba** nguyên nhân tách biệt, không cái nào là hệ quả của cái nào.

### 1. Bộ khớp danh mục chấm điểm PHẲNG, nên cha luôn đè con
`category_matcher.matchCategory` argmax trên từng `categoryKey` rời rạc, hoàn toàn không biết
`categories.parentCategoryId` tồn tại. Với "hủ tíu trưa": cha ăn 6.0 điểm (`hủ tíu`, từ khoá seed),
con ăn 4.8 (`trưa`) → cha thắng, và **không có câu nào** đủ sức đưa xuống con trừ khi câu chứa
nguyên tên con.

**Chốt:** chấm điểm **theo NHÁNH**. Cộng điểm mọi con về nhánh của cha → chọn nhánh thắng (quyết định
quan trọng nhất: sai nhánh là sai hẳn danh mục) → trong nhánh, con nào có điểm riêng cao nhất thì lấy
con, không con nào có điểm thì lấy cha. `CategoryKeywordEntry` thêm `parentKey` để tầng parser thuần
dựng lại được cây mà vẫn không phụ thuộc drift.

**Vì sao không đơn giản "ưu tiên con":** con của một nhánh THUA sẽ cướp mất câu — "gửi xe trưa 5k"
phải là Di chuyển, không phải bữa trưa. Cộng về nhánh trước rồi mới xét trong nhánh giữ được cả hai
tính chất; có test riêng cho đúng ca này.

### 2. Không có gì nối chữ "trưa" trong câu với danh mục con tên "Ăn trưa …"
Tên đầy đủ của danh mục đã là từ khoá 2.0 (quyết định trước đó, § "TÊN danh mục là từ khoá mạnh nhất")
— nhưng không ai viết "ăn trưa thiết yếu 30k", người ta viết tên món + đúng một chữ "trưa".

**Chốt:** `categoryKeywordEntriesProvider` sinh thêm từ khoá cho **danh mục CON** có tên chứa một từ
chỉ buổi, lấy từ đúng tập đóng `timeOfDayWords` đã có sẵn trong parser (`sáng/trưa/chiều/tối/khuya`),
trọng số 1.2. Hoạt động với mọi cách đặt tên ("Ăn trưa", "Đồ ăn trưa", "Ăn trưa thiết yếu") vì so theo
TỪ trong tên, không so cả tên.

**Vì sao chỉ tập từ đóng, không tách mọi từ trong tên con:** tách "đồ"/"tiền"/"khác" thành từ khoá là
đúng lớp lỗi mà `category_seed.dart` đã trả giá bằng dữ liệu đo thật với `'ăn'`/`'nước'`/`'cháo'` trần
— thêm câu sai nhiều hơn câu đúng. Buổi trong ngày thì rõ nghĩa và đã được parser mô hình hoá sẵn.

**Vì sao không seed thêm danh mục con "Ăn sáng/trưa/tối" mặc định:** Tony đã có bộ con riêng, seed
thêm là tạo danh mục trùng ý nghĩa trong sổ thật. Cơ chế tổng quát chạy trên danh mục Tony đang có.

### 3. Nhãn buổi nằm trong cụm NGÀY thì bị cắt mất trước khi tới bộ khớp
`findDate` nuốt "trưa nay"/"tối qua" nguyên cụm, nên "hủ tíu trưa 30k" xuống được con còn "hủ tíu
**trưa nay** 30k" thì không — cùng một ý, hai kết quả. `TimeOfDayLabel` vốn có doc comment ghi rõ nó
là "TÍN HIỆU cho category_matcher", nhưng chưa ai nối dây.

**Chốt:** `parser.dart` nối lại từ chỉ buổi vào chuỗi đem đi CHẤM ĐIỂM. `leftoverText` **giữ nguyên**
— nó còn là note của giao dịch và là thứ vòng lặp học ghi vào `category_keywords`, nhét thêm chữ vào
đó là làm bẩn dữ liệu học.

### 4. Sheet chọn danh mục "chọn xong đóng ngay" làm tầng hai không bao giờ hiện ra
Đây mới là thứ chặn Tony **sửa tay**. `TwoLevelCategoryPicker` đúng — hàng danh mục con của nó chỉ
hiện SAU KHI đã chọn một cha — nhưng cả hai chỗ mở nó dạng sheet (`showCategoryPickerSheet` ở màn
chat, sheet chọn danh mục cho dòng tách ở `transaction_form_sheet`) đều `Navigator.pop` ngay trong
`onChanged`. Đúng cái frame hàng con lẽ ra hiện lên thì sheet đã đóng. Tầng hai chỉ nhìn thấy được
khi thẻ VỐN ĐÃ mang sẵn một danh mục con.

**Chốt:** một sheet dùng chung `lib/ui/two_level_category_picker_sheet.dart` giữ lựa chọn trong state
của chính nó, chỉ đóng khi lựa chọn đã dứt điểm: chọn CON → đóng; chọn CHA không có con → đóng (giữ
nguyên tốc độ cũ); chọn CHA có con → ở lại, hiện hàng con + nút chốt `Dùng "…"` cho người muốn dừng ở
mức cha. Cả hai chỗ gọi chuyển sang dùng nó — cùng lý do đã gom `TwoLevelCategoryPicker` về một widget
ở Phase 25: sửa từng chỗ một là chắp vá và chắc chắn sót.

**Xác minh**: 15 test mới, mỗi test đã kiểm là **ĐỎ trên bản trước khi sửa** (`git stash push lib/`,
chạy lại) chứ không chỉ xanh sau khi sửa — 5 test đơn vị cho chấm điểm theo nhánh, 6 test qua cây sản
xuất thật (`QuickAddScreen` + DB thật) gồm cả tên con thật "Ăn trưa thiết yếu" và ca "không được kéo
sang nhánh khác", 4 test widget cho sheet hai tầng. `transaction_split_test` phải sửa theo (nó chọn
danh mục cha CÓ con và dựa vào việc sheet đóng ngay) — dùng nút chốt mới. 999/999 test xanh,
`flutter analyze` không thêm cảnh báo nào, `check_arch.sh` PASS.

**Chưa kiểm trên máy**: emulator `tonyfino36` chưa bật trong phiên này (`adb devices` rỗng), nên toàn
bộ bằng chứng ở trên là test tự động. Cần một lượt bấm tay đúng câu "hủ tíu trưa 30k" trên sổ thật
trước khi coi là xong.

## 2026-08-25 (tiếp) · Tony thử tiếp: "bún chả ăn sáng", "Ốc chung Oxytoxin" — hai lỗ hổng còn lại

Đo trước, sửa sau: dựng `test/tooling/probe_subcategory_match.dart` chạy bộ khớp thật lên SỔ THẬT
(12 danh mục gốc seed + 30 danh mục con nhập từ Rolly, ánh xạ y hệt importer Phase 9) rồi in câu nào
rơi vào đâu. "bún chả ăn sáng" đã đúng ngay nhờ tín hiệu buổi; "Ốc chung Oxytoxin" thì không.

### 5. Chỉ tách TỪNG TỪ trong tên danh mục con là không đủ — có ca chỉ CỤM mới phân biệt được
Sổ Tony có `Gia đình › Oxytocin` VÀ `Ăn uống › Ăn chung oxytocin` — hai danh mục cùng chứa một tên
riêng, khác nhau đúng chữ "chung". Xét từng từ rời thì "chung" bị loại (quá phổ thông) và "oxytocin"
bị loại (dùng chung giữa hai danh mục), nên "ốc chung oxytocin" rơi vào Gia đình — sai.

**Chốt:** ngoài từng từ đặc trưng, sinh thêm một entry là **CỤM** còn lại của tên con sau khi bỏ các
từ đã có trong tên cha ("Ăn chung oxytocin" dưới "Ăn uống" → `chung oxytocin`). Cụm không cần lọc
"dùng chung giữa nhiều danh mục": đủ dài là đã đủ đặc trưng, và điểm `weight × độ dài` tự thưởng cho
cụm dài. Ba bộ lọc cho từ rời (bỏ từ trùng tên cha, bỏ từ xuất hiện ở nhiều danh mục — trừ từ chỉ
buổi, bỏ từ ≤3 ký tự và từ chức năng) giữ nguyên và có ghi rõ lý do từng cái tại chỗ.

### 6. Tên riêng gõ sai một ký tự thì trượt hoàn toàn
Tony gõ "Oxyto**x**in", danh mục là "Oxyto**c**in" — so khớp chuỗi con thì đây là hai chuỗi không
liên quan.

**Chốt:** đổi so khớp từ *substring có đệm khoảng trắng* sang **so khớp theo TỪ**, và cho phép một từ
trong dãy sai/thiếu/thừa **đúng một ký tự** — nhưng CHỈ với từ **≥ 6 ký tự** (`kFuzzyMinWordLength`),
và điểm nhân 0.8 (`kFuzzyMatchScoreFactor`) để khớp đúng luôn thắng khớp mờ.

**Vì sao ngưỡng 6 ký tự là thứ giữ nó khỏi phá mọi thứ:** tiếng Việt bỏ dấu đầy cặp từ ngắn cách nhau
một ký tự (`xang`/`xong`, `bun`/`bum`, `me`/`mo`) — mờ ở đó là mời gọi khớp bậy. Từ 6 ký tự trở lên
gần như luôn là tên riêng/từ mượn (`oxytocin`, `katinat`, `starbucks`), đúng chỗ người ta gõ sai.
Có test riêng cho ca "xong viec roi" KHÔNG được khớp `xăng`.

**Vì sao so theo từ chứ không nới substring:** ràng buộc biên từ (từ khoá `"xe"` không được khớp giữa
`"xem"`) là thứ phải giữ; so theo từ giữ được nó *và* mở đường cho khớp mờ trong cụm nhiều từ, việc
đệm-khoảng-trắng-rồi-`indexOf` không làm được.

**Xác minh hồi quy trên dữ liệu thật, không chỉ test tự viết**: `audit_category_keywords.dart` chạy
bộ khớp lên 209 ghi chú Tony đã gõ trong Rolly cho **ĐÚNG=146 THIẾU=28 SAI=34 trước và sau, y hệt** —
đổi cả cơ chế so khớp mà không làm xấu tầng seed. Thêm 9 test hồi quy (2 ca Tony đưa + tên riêng
đứng một mình + 6 test đơn vị cho khớp mờ), tất cả đã kiểm là đỏ trên bản trước. 1008/1008 xanh,
`flutter analyze` giữ nguyên 15 info có sẵn, `check_arch.sh` PASS.

Phần dựng từ khoá tách khỏi provider thành `lib/features/quick_add/domain/category_keyword_entries.dart`
(hàm thuần) chính vì lý do trên: nó quyết định câu nào rơi vào danh mục nào, nên phải chạy được trong
công cụ soi trên sổ thật mà không cần dựng Riverpod/DB.

## 2026-08-27 · Vòng lặp học: HỎI trước khi nhớ, nhớ theo CỤM, và gỡ được

Tony đề xuất: sửa danh mục xong thì hỏi có muốn lưu hành vi để lần sau không nhầm. Hai phần ba việc
đó đã chạy từ Phase 8 — `correctCategory` gọi `recordKeywordCorrection` mỗi lần sửa. Nhưng nó chạy
**âm thầm**, và đó chính là chỗ hỏng.

### Ba khuyết điểm của vòng lặp học cũ
1. **Nhớ sau lưng người dùng.** Không có dấu hiệu nào cho biết app vừa học gì.
2. **Nhớ cả cụm `leftoverText` làm MỘT khoá.** Sửa "hủ tíu trưa" → nhớ nguyên chuỗi đó; lần sau gõ
   "hủ tíu" hay "bún chả trưa" học được đúng con số không.
3. **Chỉ cộng, không gỡ.** Sửa nhầm một lần là nhớ cái sai, và cách duy nhất để đè là dạy đúng nhiều
   lần cho tới khi trọng số vượt lên. Không màn nào liệt kê từ khoá đã học.

### Chốt
**Hỏi bằng snackbar 6 giây, không bấm gì = không học gì** (`DraftCard._offerToLearn`). Snackbar chứ
không phải dialog là cố ý: sửa danh mục là việc làm liên tục, chặn tay mỗi lần bằng một hộp thoại
Có/Không biến tính năng giúp đỡ thành phiền toái. Hai lối ra: *Nhớ* (lưu ngay đề xuất mặc định) và
*Chọn từ* (mở sheet tinh chỉnh). Không hỏi lại thứ đã nhớ rồi (`CategoryRepository.hasKeyword`).

**Nhớ theo CỤM LIÊN TIẾP, không theo từ rời** (`groupIntoPhrases`). 🚨 Tiếng Việt ghép từ bằng khoảng
trắng: chọn từng từ rồi lưu từng từ sẽ tách "hủ tíu" thành "hủ" và "tíu" — hai chuỗi một mình vô
nghĩa, lại khớp bậy vào "hủ nút"/"tíu tít". Bỏ một từ ở GIỮA thì cụm đứt làm hai: "bún chả với tee"
bỏ "với" cho ra `bún chả` và `tee`, KHÔNG phải `bún chả tee` (chuỗi đó không tồn tại trong câu nào,
`category_matcher` đòi các từ phải liên tiếp).

**Bộ lọc từ khi HỌC rộng hơn bộ lọc khi TỰ RÚT** — cố ý, đừng gộp. `_isNoiseWord` (dùng cho việc app
tự rút từ trong tên danh mục con) bỏ mọi từ ≤3 ký tự vì ở đó đoán sai là âm thầm làm hỏng phân loại.
Áp ngưỡng đó vào đây thì "phở", "ốc", "bún" — những món tên ngắn nhất — sẽ bị im lặng từ chối dạy.
Khi học thì chỉ loại từ chức năng (`_learnStopWords`: và, với, cho, của…).

**Mục "Từ khoá đã học" trong `CategoryDetailScreen`** — liệt kê kèm trọng số, xoá từng dòng, có Hoàn
tác. `restoreKeyword` giữ NGUYÊN trọng số cũ thay vì gọi lại `learnKeywords`: hoàn tác mà âm thầm hạ
một khoá đã dạy ba lần (2.5) về mặc định (1.5) thì không phải hoàn tác.

**Bug bắt được khi viết test**: `hasKeyword` ban đầu dùng `getSingleOrNull` → ném `Bad state: Too many
elements` giữa luồng sửa danh mục, vì một danh mục HOÀN TOÀN có thể có hai khoá trùng nhau sau khi bỏ
dấu — seed "Ăn uống" có cả "bách hoá xanh" lẫn "bách hóa xanh". Đã có test khoá đúng ca đó.

**Xác minh**: 1014 test xanh (thêm 6 test mới, gồm cả test cũ "học từ khoá" phải viết lại vì hành vi
đổi có chủ ý), `flutter analyze` giữ nguyên 15 info có sẵn, `check_arch.sh` PASS.

## 2026-09-04 · Ba báo lỗi cùng lượt: quá ít icon, "thưởng 1tr" ra −1tr, chat không hiểu "vào tiết kiệm"

### 1. Bộ icon danh mục: 15 → 114 mã, chia nhóm, khung cuộn riêng

15 mã seed vừa đủ cho 12 danh mục mặc định, nên mọi danh mục Tony tự tạo đều phải mượn lại một hình
đã có — nhìn danh sách thì hàng nào cũng giống hàng nào. Thêm 99 mã: mỗi mã có ĐỦ hai cách vẽ mà
`CategoryAvatar` cần — glyph Material Symbols Rounded (const literal, để `--tree-shake-icons` còn
rút gọn được) và một PNG 3D Microsoft Fluent Emoji (MIT) cùng tên trong `assets/icons3d/categories/`.

🚨 **Thiếu file 3D thì icon mới hiện thành DẤU HỎI, im lặng.** `resolveCategoryIcon3d` trả
`question_mark.png` cho mã lạ — file đó TỒN TẠI nên `Image.asset` không lỗi và `errorBuilder`
(đường lùi về glyph đơn sắc) không bao giờ chạy. `test/theme/tokens/category_icons_test.dart` khoá
đúng chỗ đó: mọi `iconCode` phải có file 3D thật trên đĩa, và phải nằm đúng một nhóm của bộ chọn.

Bộ chọn (`AppIconPicker`) nhận thêm `groups`: 114 icon trải phẳng là 13 hàng không mốc, mà tệ hơn là
nó đẩy nút Lưu của sheet đi cả nghìn pixel — đúng lớp lỗi đã làm nút chọn danh mục cha bị khuất ở
v13. Nay bảng icon nằm trong khung cao cố định 240px có thanh cuộn riêng, nên bộ icon lớn thêm bao
nhiêu cũng không đổi chiều dài phần còn lại của sheet.

### 2. "thưởng 1tr" ghi ra −1.000.000 — ba lỗ hổng nối nhau quanh `Categories.kind`

Dấu tiền của một thẻ quick-add lấy đúng từ `Categories.kind` (`QuickAddController._resolveMoney`).
Ba chỗ hỏng, mỗi chỗ đủ để gây ra triệu chứng:

1. **`CategoryRepository.update` không nhận `kind` gì cả.** Sheet sửa danh mục vẫn vẽ nút gạt
   "Chi/Thu", Tony bấm "Thu", bấm Lưu, sheet đóng như đã thành công — cột `kind` không hề đổi. Không
   có đường nào sửa được từ trong app.
2. **Danh mục CON có `kind` riêng, độc lập với cha.** Mà `kind` của con KHÔNG hiện ra ở đâu cả:
   `TwoLevelCategoryPicker` lọc theo `kind` ở CẤP GỐC rồi hiện tất cả con của gốc đang chọn, màn
   Danh mục cũng xếp con theo nhóm Thu/Chi của gốc. Một con `expense` nằm dưới gốc `income` vì thế
   là cái bẫy im lặng hoàn hảo: nó hiện trong mục "Danh mục thu", chọn được như danh mục thu, rồi
   ghi ra một khoản CHI.
3. **Sổ đang dùng đã có sẵn hàng sai** — sửa code không tự dọn dữ liệu cũ.

**Chốt**: `kind` của danh mục con LUÔN bằng `kind` của cha
(`CategoryRepository.kindIsInheritedFromParent`), ép ở cả `insert` lẫn `update` (đổi `kind` của một
gốc kéo theo mọi con trong cùng một `transaction()`); sheet bỏ hẳn nút gạt khi đã chọn cha và nói rõ
"Danh mục THU — theo danh mục cha"; `repairSubcategoryKinds` chạy trong `beforeOpen` MỖI lần mở sổ.

Vì sao repair chạy mỗi lần mở chứ không một lần rồi thôi như `backfillSeedKeywords`: cái này là BẤT
BIẾN, không phải "bù dữ liệu mới". Không có ý định nào của người dùng để làm hỏng (`kind` của con
không hiện ra ở đâu), còn dữ liệu sai thì vẫn có thể quay lại từ một bản khôi phục sao lưu cũ hoặc
một lần import. Một câu UPDATE trên bảng vài chục hàng, chỉ động vào hàng lệch.

### 3. Màn chat hiểu "chuyển 5tr vào tiết kiệm"

Trước bản này gõ câu đó ở màn chat thì `category_matcher` chấm điểm như mọi câu khác và ghi ra một
khoản CHI thường — mục tiêu tiết kiệm không nhúc nhích. Lối vào duy nhất là nút "+" bên màn Quỹ,
hoặc chip "Chuyển quỹ" (mà nó lại mở sheet chuyển giữa hai VÍ, khác hẳn).

`savings_matcher.dart` (Dart thuần, cùng thư mục `parser/`) nhận danh sách mục tiêu đang hoạt động
từ tầng gọi và trả `SavingsMatch` — thẻ sinh ra mang `goalId`, KHÔNG có `categoryId`, đúng hình dạng
màn Quỹ (Phase 16) đang ghi, nên tiến độ mục tiêu, "Còn lại" ở Trang chủ và báo cáo Chi/Thu tự động
tính đúng. "rút … từ tiết kiệm" là chiều ngược lại (dòng THU cùng `goalId`).

🚨 **Thận trọng là mặc định.** Nhận nhầm một khoản chi thành khoản để dành tệ hơn nhiều so với không
nhận ra: khoản chi biến mất khỏi báo cáo VÀ thổi phồng tiến độ một mục tiêu. Nên:

- Động từ chuyển tiền MỘT MÌNH chưa đủ — "chuyển khoản tiền nhà 2tr" phải vẫn là khoản chi. Phải có
  thêm giới từ chỉ đích ("vào"/"sang"/"qua") hoặc một từ nói thẳng ("tiết kiệm", "để dành", "quỹ").
- Tên mục tiêu ngắn (<4 ký tự đã bỏ dấu) không được tự nó làm bằng chứng: mục tiêu tên "Nhà" sẽ khớp
  vào "tiền nhà", "Xe" khớp vào "xe ôm".
- Không gọi tên mục tiêu nào thì chỉ dám tự chọn khi trong sổ đúng MỘT mục tiêu. Hai trở lên là tung
  đồng xu — thà để câu chạy như khoản chi bình thường.
- Thẻ để dành KHÔNG đi đường AI fallback: fallback trả về `ParsedDraft` thường (không biết `savings`
  là gì) và `SessionDraftCard.fromDraft` dựng lại thẻ từ chính draft đó, tức `goalId` bị xoá sạch.

### Ngoài lề, phát hiện lúc chạy test

`transactions_screen_test.dart` đã ĐỎ SẴN từ 1/9/2026: nó đóng băng đồng hồ ở 25/8/2026 (để bộ lọc
kỳ ổn định) nhưng lại seed giao dịch bằng `DateTime.now()` — hai tháng khác nhau nên hàng seed nằm
ngoài kỳ và biến mất. Đúng cái bẫy mà chính comment đầu file cảnh báo, chỉ là ở nửa còn lại. Đã seed
bằng `_frozenClock.now()`.

### Xác minh

1043 test xanh (thêm 23 test mới), `flutter analyze` giữ nguyên 13 info có sẵn, `check_arch.sh` PASS.
**Chưa chạy tay được trên máy ảo**: AVD `tonyfino36` không còn trên máy này (`emulator -list-avds`
rỗng), nên phần thị giác của bộ icon mới và thẻ để dành ở màn chat vẫn chờ Tony bấm thật.

---

## 2026-09-07 · Quỹ tiết kiệm: nạp/rút khó, lịch sử không có, và "Hoàn tác" làm bốc hơi tiền

Tony báo bốn thứ cùng lúc về quỹ: *"thêm bớt tiền vào đó cũng khó, đó không liên quan danh mục…
lịch sử cũng khó xem, chuyển từ ví vào quỹ tiết kiệm cũng khó"*. Chạy tay trên `tonyfino36` (v1.0.5+46,
dữ liệu test: ví −10.000.000, quỹ "Mua nha" 5.000.000/50.000.000) thì cả bốn đều đúng, và lộ thêm
một lỗi MẤT TIỀN mà Tony chưa gặp.

### 1. 🚨 "Hoàn tác" sau khi xoá làm bốc hơi tiền

Đo được, không phải suy luận: nạp 1tr vào quỹ (ví −11tr, quỹ 6tr) → xoá giao dịch → bấm **Hoàn tác**
→ ví vẫn **−11tr** nhưng quỹ tụt về **5tr**. Một triệu biến mất khỏi sổ, lại còn hiện ra thành một
khoản chi "Chưa phân loại" trong Báo cáo (Tổng chi 6 tháng nhảy từ −6tr lên −7tr).

`deleteTransactionWithUndo` chèn lại đúng năm cột (`amount/occurredAt/walletId/categoryId/note`) và
bỏ rơi `goalId`, `debtId`, các dòng con của giao dịch tách (Phase 14), thẻ (Phase 17) và ảnh hoá đơn.
Ba thứ sau KHÔNG nằm trong `Transaction` (bảng khác; ảnh ở đĩa) và `delete()` xoá cả ba, nên bản sửa
phải **đọc hết ra TRƯỚC khi gọi `delete`** — sau đó thì không còn gì để đọc. Ảnh ghi lại bằng
`writeImageWithFilename` (đúng tên file cũ) chứ không phải `saveImage` (tự sinh tên mới), để hàng
khôi phục mang lại chính `receiptImageFilename` cũ.

Bài học lặp lại D7 theo chiều ngược: không lưu bộ đếm thì tiến độ không thể sai, nhưng nó chỉ đúng
khi **giao dịch nguồn được khôi phục nguyên vẹn**. Một undo "gần đúng" nguy hiểm hơn không có undo.

### 2. Nạp/rút quỹ: sheet RIÊNG, không phải form ghi khoản điền sẵn

Nút "+" trên thẻ quỹ mở nguyên `TransactionFormSheet`. Nó hỏi sáu thứ, **năm thứ vô nghĩa** với một
lần nạp quỹ: nút gạt Chi/Thu (nạp tiền để dành bị gọi là "Chi"), lưới 11 danh mục chiếm nửa màn,
"Tách giao dịch", Thẻ, Ảnh hoá đơn. Thứ duy nhất thật sự cần — nạp từ ví nào — thì lại ẩn khi sổ mới
có một ví. Tiêu đề vẫn ghi "Thêm giao dịch".

Lưới danh mục không chỉ thừa, nó là **cái bẫy**: gán một danh mục vào khoản để dành là vừa thổi phồng
chi tiêu của danh mục đó vừa làm khoản đó trông như đã tiêu mất. Chốt: `SavingsContributionSheet`
riêng (số tiền + ví + ngày + ghi chú), bỏ hẳn lưới đi thì không ai chọn nhầm được nữa. Dữ liệu ghi ra
y hệt hình dạng cũ (giao dịch mang `goalId`, không `categoryId`) nên tiến độ/báo cáo không cần biết
gì về sheet này — đây thuần tuý là một lối vào hẹp hơn.

Hai factory `TransactionFormPrefill.forGoalContribution`/`forGoalWithdrawal` bị **xoá hẳn**, không để
lại làm lối vào chết: giữ chúng là mời đúng lỗi này quay lại.

Form ghi khoản vẫn phải mở được một khoản quỹ CŨ (sửa/xoá), nên khi `goalId != null` nó giấu cả khối
danh mục lẫn "Tách giao dịch", và hiện "Gắn với quỹ: …". Tên quỹ trước đây chỉ đọc từ prefill nên mở
từ danh sách là mất sạch dấu vết quỹ — giờ tra ngược từ `goalId`.

### 3. Lịch sử quỹ: trước đây KHÔNG có, không phải "khó xem"

Bấm vào thẻ quỹ mở sheet sửa tên/số tiền cần đạt; `watchAllWithCategory` không có tham số lọc theo
quỹ nào cả. Nghĩa là không đường nào xem một quỹ đã nạp/rút những gì, cũng không đường nào sửa một
lần nạp sai ngoài việc mò trong danh sách chung.

Chốt: thêm `watchAllWithCategory(goalId:)` + `SavingsGoalDetailScreen` (tiến độ trên, lịch sử theo
ngày dưới, hai nút Nạp/Rút có nhãn bằng CHỮ). **Đổi chỗ hai hành động trên thẻ**: bấm thẻ giờ mở lịch
sử, còn sửa/lưu trữ lùi vào menu ⋮ của màn chi tiết — "quỹ này đã nạp gì" là câu hỏi hàng ngày, "đổi
tên quỹ" thì vài tháng một lần. Thẻ cũng chỉ còn MỘT nút icon: ba nút không nhãn chen nhau là chỗ bấm
nhầm, cái mũi tên quay lui (rút về ví) đọc y như "hoàn tác".

Tiến độ ở màn chi tiết vẫn là `SavingsGoalProgress` (SQL aggregate, D7) chứ không cộng tay từ danh
sách bên dưới — hai nguồn cho cùng một con số là hai chỗ để nó trôi.

### 4. Danh sách giao dịch gọi mọi khoản quỹ là "Chưa phân loại"

Màn chat đã hiện đúng "Để dành › Mua nha" kèm icon con heo từ 2026-09-04, nhưng **bốn màn danh sách
thì không**: tab Giao dịch, Trang chủ "Gần đây", Tìm kiếm, Chi tiết danh mục — cả bốn chép tay cùng
một đoạn ba-điều-kiện và đã lệch nhau thật (tab Giao dịch có `emoji`, Trang chủ không; Tìm kiếm bỏ
chip danh mục con khi tách dòng, Trang chủ không), và không màn nào biết khoản quỹ là gì.

Chốt theo đúng luật "sửa tận gốc": một hàm `transactionRowDisplay` ở
`features/transactions/domain/transaction_row_display.dart`, cả năm màn (kể cả màn Lịch sử quỹ mới)
đi qua nó. BA khái niệm cùng có `category == null` và không suy ra được từ `category`: gắn quỹ
(`goal != null`), tách dòng (`isSplit`), và "chưa phân loại" thật.

`watchAllWithCategory` LEFT JOIN thêm `savings_goals` để tên quỹ ra tới UI trong cùng một query.

### 5. Chip "Chuyển quỹ" mở sheet chuyển giữa hai VÍ

Đây chính là chỗ Tony đi tìm khi nói "chuyển từ ví vào quỹ tiết kiệm cũng khó": nút duy nhất hứa hẹn
đúng việc lại làm việc khác. (`savings_matcher.dart` đã ghi nhận sự nhầm lẫn này từ 2026-09-04 nhưng
chưa sửa.) Chốt: nhãn đổi thành "Chuyển ví" — nói đúng thứ nó làm — và thêm chip "Nạp quỹ" riêng.
Không quỹ nào thì ẩn chip; đúng một quỹ thì vào thẳng sheet nạp, không bắt chọn giữa một lựa chọn;
từ hai trở lên mới hỏi.

### 6. Snackbar "Đã xoá giao dịch" không bao giờ tự tắt

Đo trên máy thật: nằm lại **hơn 4 phút**, sống qua cả chuyển tab lẫn vuốt-đóng, che thanh điều hướng
dưới; chỉ khởi động lại app mới hết. Xảy ra khi xoá **từ sheet Sửa**, và `_delete()` làm đúng cái
việc mà `_duplicate()` ngay bên dưới nó đã ghi chú là không được làm: `Navigator.pop()` trước, rồi
đưa `context` của route đang bị gỡ cho một hàm chạy tiếp — hàm đó gọi `ScaffoldMessenger.of(context)`.
Chữa bằng đúng cách `_duplicate()` đã chữa: giữ context của Navigator GỐC trước khi pop.

Nhân tiện: `hideCurrentSnackBar()` trước khi hiện cái mới (xoá liên tiếp hai hàng thì cái thứ hai xếp
hàng đợi, nút "Hoàn tác" đang hiện lại thuộc về giao dịch TRƯỚC — bấm vào là khôi phục nhầm hàng);
thời lượng nói rõ 8 giây thay vì mặc định 4 (đây là cửa sổ DUY NHẤT để lấy lại một giao dịch); và
`textColor: Colors.white` cho nút — màu `secondary` mặc định là teal đậm trên nền thanh gần đen, gần
như không đọc được.

### Không sửa: dấu của "Tiết kiệm" ở Trang chủ/tab Giao dịch

"Tiết kiệm −5.000.000 đ" đọc như một khoản mất, trong khi thẻ quỹ ghi "5.000.000 đ" — nhìn thì lệch.
Nhưng đo lại thì Thu + Chi + Tiết kiệm = Còn lại khớp chính xác (1 − 6 − 5 = −10). Đảo dấu để "đẹp"
sẽ phá đúng phép cộng mà comment ở `transactions_screen.dart` đã cố ý dựng lên. Để nguyên.

---

## 2026-09-19 · Hũ: % sai gốc, danh mục con khác hũ cha, hũ tiết kiệm; thêm "Gom theo thẻ" và sửa thứ tự "Gần đây"

Tony báo năm việc cùng lượt. Schema lên **v14**.

### 1. 🚨 Phần trăm hũ không tính trên "Thu" của kỳ

`JarRepository.watchProgress` cộng MỌI dòng dương làm thu nhập — kể cả dòng dương gắn `goal_id`, tức
tiền RÚT từ quỹ về ví. Ô "Thu" ở Trang chủ (`watchPeriodSummary`) thì loại dòng gắn quỹ. Hai màn chia
từ hai con số khác nhau; rút 6tr từ quỹ là mọi hũ phình thêm 6tr × %. Sửa: cùng bộ lọc
`goal_id IS NULL`. Chiều chi cũng vậy: một lần nạp quỹ mang danh mục "Phát sinh" (đúng dữ liệu Rolly
thật) bị đếm là chi của hũ chứa "Phát sinh" — giờ loại ra, vì nó thuộc về hũ tiết kiệm (mục 3).

Và màn Hũ giờ **hiện luôn con số gốc** ("Tổng thu của kỳ … mỗi hũ nhận đúng phần trăm của con số
này"). Lỗi này sống được lâu chính vì không có chỗ nào cho thấy 10% là 10% của cái gì.

### 2. Danh mục con thuộc hũ KHÁC danh mục cha

Không cần đổi schema: `categories.jar_id` vốn nằm trên mọi hàng, truy vấn vốn đã là
`COALESCE(con, cha)`. Chỉ có bảng chọn là khoá ở cấp gốc. Giờ bảng hai cấp, luật ở
`lib/features/jars/domain/jar_membership.dart`:

- Con chưa xếp riêng → theo hũ của cha (ô tick khoá, ghi "Theo "Ăn uống" — muốn tách, chọn nó ở hũ
  khác"). Không có trạng thái "con không thuộc hũ nào khi cha có hũ": mã hoá nó cần một giá trị canh
  gác trong `jar_id` (kiểu `0`) — vá víu, và nghiệp vụ không cần: cha đã vào hũ thì cả họ có chỗ.
- Tick con vào đúng hũ của cha → ghi `NULL` chứ không chép id, để dời cha thì con đi theo.
- Chỉ liệt kê danh mục CHI — danh mục thu trong hũ không bao giờ cộng được đồng nào.

### 3. Hai loại hũ: hũ tiêu và hũ tiết kiệm (v14)

`jars.kind` (`'spend'`/`'saving'`, mặc định `'spend'` — đúng với mọi hũ có trước) + `jars.goal_id`.
Hũ tiết kiệm đo **tiền gửi RÒNG vào quỹ gắn kèm trong kỳ** (`-SUM(amount)` các dòng mang `goal_id`
đó: nạp trừ rút). Mọi lần nạp — từ sheet quỹ, từ màn chat "chuyển … vào tiết kiệm" — tự tính vào, vì
nó đọc chính dòng giao dịch chứ không cần ai "báo" cho hũ. Gửi vượt mức là **đạt** (không tô đỏ).
Đổi hũ tiêu thành hũ tiết kiệm thì gỡ các danh mục khỏi nó trong cùng transaction — nếu không chúng kẹt
ở một hũ không còn bảng chọn danh mục. Sao lưu mang hai khoá mới; bản sao lưu cũ khôi phục thành hũ
tiêu (có test).

### 4. Trang chủ: đủ mọi hũ; tab Giao dịch: "Chi theo hũ"

Thẻ Hũ ở Trang chủ trước chỉ vẽ 4 hũ đầu, mỗi hũ một thanh + %. Giờ đủ mọi hũ, mỗi hũ "còn X", thanh,
"đã tiêu a / b", cuối thẻ là dòng tổng (tổng hũ · đã dùng · còn lại). Tab Giao dịch thêm dải ô "Chi
theo hũ"; bấm một ô là lọc danh sách đúng những khoản làm nên con số của hũ đó (`categoryIdsInJar` —
cùng công thức COALESCE; hũ tiết kiệm lọc theo `goal_id`). Hũ rỗng lọc ra danh sách rỗng, KHÔNG rơi
về "không lọc".

### 5. Biểu đồ tròn: "Gom theo thẻ"

Khoản có thẻ gom theo thẻ, khoản không thẻ vẫn theo danh mục (cấp gốc). Gộp theo **TỔ HỢP thẻ**
(khoản gắn "Du lịch" + "Gia đình" thành nhóm "#Du lịch + #Gia đình"), không cộng vào từng thẻ — cộng
vào từng thẻ là đếm hai lần, tổng các lát vượt tổng chi. Test khẳng định hai nửa cộng lại đúng bằng
tổng chi ở chế độ thường. Công tắc dùng chung Trang chủ ↔ Báo cáo, và ẩn khi sổ chưa có thẻ.

### 6. "Gần đây" trong một ngày bị ngược

Màn chat và bộ nhập Rolly ghi `occurred_at` là NGÀY TRẦN (00:00), mọi truy vấn danh sách chỉ
`ORDER BY occurred_at DESC` — hàng hoà nhau, SQLite trả theo rowid tăng dần: khoản buổi sáng lên đầu.
Thêm tiêu chí phụ `created_at DESC, id DESC` ở MỘT chỗ (`TransactionRepository._newestFirst`) cho mọi
danh sách. Đã chứng minh test mới đỏ với thứ tự cũ (ra đúng "cà phê sáng" trên cùng) trước khi sửa.

### Bẫy tái diễn

Dải "Chi theo hũ" làm 2 test màn Giao dịch treo 10 phút: `watchProgress` gọi `watchActive(...).first`
bên trong `asyncMap` — đúng bẫy "Stream.first ngoài ngữ cảnh watch làm pumpAndSettle treo" đã ghi.
Đổi sang `.get()`.

### Kiểm chứng

1091 test xanh (+35), `check_arch.sh` PASS, analyze không thêm cảnh báo nào. Chạy tay trên
`tonyfino36` (cài đè 1.0.6 → bản này, migration v13→v14 giữ nguyên dữ liệu cũ): dùng mẫu 6 hũ, tách
"Tiêu vặt" sang Hưởng thụ khi "Ăn uống" ở Thiết yếu, đổi "Tiết kiệm dài hạn" thành hũ tiết kiệm gắn
quỹ "Mua nha" (tự nhận 5tr đã nạp trong tháng), ghi hai khoản qua chat (thứ tự "Gần đây" đúng, mỗi
khoản rơi đúng hũ), lọc tab Giao dịch theo hũ, tạo thẻ + bật "Gom theo thẻ" ở Báo cáo.

## 2026-09-19 (tiếp) · Màn Chi tiết hũ, bỏ trang Hạn mức, kéo thả thứ tự hũ

**Chi tiết hũ** (`lib/features/jars/jar_detail_screen.dart`). Tony: *"khi nhấn vô 1 hũ, ở dưới sẽ có
tất cả giao dịch theo danh mục danh mục con, như bảng theo danh mục ở trang chủ"*. Bấm thẻ hũ (màn
Hũ) hoặc từng hũ ở Trang chủ giờ mở màn này: tóm tắt hạn mức/đã dùng/còn lại, biểu đồ "Theo danh mục"
(cùng `CategoryPieCard` với Trang chủ) CHỈ gồm phần thuộc hũ, rồi mọi giao dịch nhóm theo ngày. Sửa
hũ và chọn danh mục chuyển lên thanh tiêu đề.

- Bấm một danh mục cha trong biểu đồ KHÔNG mở màn Chi tiết danh mục như Trang chủ: hũ có thể chỉ chứa
  vài con của "Ăn uống", màn đó lại cộng mọi con — hai con số lệch nhau. Thêm tham số
  `CategoryPieCard.onOpenCategory`; màn hũ mở bảng các con thuộc hũ, con mới mở tiếp được màn của nó.
- "Giao dịch của một hũ" giờ có MỘT định nghĩa (`watchJarTransactions`) dùng chung cho bộ lọc hũ ở tab
  Giao dịch và màn này.
- `_groupByDay` từng bị chép ở 3 màn; màn này sẽ là bản thứ tư, nên gom về
  `transactions/domain/day_groups.dart` và thay cả ba bản cũ.

**Bỏ trang Hạn mức** (Tony: *"xoá trang hạn mức đi"*). Gỡ tab trong Túi tiền, mục trong Quản lý,
route `/budgets`, thẻ Hạn mức ở Trang chủ (và công tắc của nó), dòng "còn … trong ngân sách" ở thẻ
xác nhận màn chat — không còn chỗ tạo/sửa hạn mức thì dòng đó sẽ là một con số không ai quản được.
**Giữ** bảng `budgets`, `BudgetRepository` và phần sao lưu: đây là dữ liệu của Tony, xoá bảng là thao
tác không đảo ngược được mà không ai yêu cầu. `BudgetPeriod` (kỳ theo ngày neo) vẫn là nền của "Tháng
này", nên cài đặt đổi nhãn thành "Kỳ tháng bắt đầu ngày". Tab Túi tiền còn Ví · Quỹ · Hũ — nhân tiện
khớp lại chỉ số mà thẻ Quỹ/Hũ ở Trang chủ vẫn dùng (trước đó lệch một nấc vì tab Hạn mức chen giữa).

**Kéo thả thứ tự hũ.** Nhấn giữ một thẻ hũ rồi kéo. `JarRepository.reorder` ghi lại `sortOrder` cho
MỌI hũ trong một transaction. Phần tĩnh (chip kỳ, thẻ tổng, dòng %) nằm ở `header`/`footer` của
`ReorderableListView`, không làm con của danh sách (bẫy lệch chỉ số đã dính ở màn Danh mục). Màn giữ
thứ tự tạm tới khi stream DB bắt kịp để thẻ không giật về chỗ cũ lúc thả tay. Mọi nơi khác (Trang chủ,
dải "Chi theo hũ") đọc theo `sortOrder` nên tự theo.

Chạy tay trên `tonyfino36`: kéo "Tiết kiệm dài hạn" lên đầu → khởi động lại app vẫn giữ thứ tự; chi
tiết Thiết yếu chỉ có "an sang 30k" (không có "Tiêu vặt" đã tách sang Hưởng thụ); chi tiết Hưởng thụ
có đúng "Tiêu vặt 20k".

## 2026-09-20 · Hũ tiết kiệm gom NHIỀU quỹ (v15), thẻ hũ hiện hai con số, trang Ghi chú (v16)

### 1. Một hũ tiết kiệm ↔ nhiều quỹ, mỗi quỹ một tỉ lệ (schema v15)

Tony: *"ví dụ tôi có quỹ khám bệnh, hũ liên kết với hũ đó, số tiền hũ bằng tổng các quỹ liên quan.
hoặc nếu không tổng các quỹ liên quan thì mỗi quỹ bao nhiêu % mặc định 100%. hũ đó có thể chiếm 0%
1 tháng"*.

`jars.goal_id` (v14, đúng một quỹ) chuyển thành bảng nối `jar_goals(jar_id, goal_id, percent)`.
Migration chuyển dữ liệu TRƯỚC rồi mới `alterTable` bỏ cột — làm ngược là mất sạch dây nối mà không
báo gì. `percent` mặc định 100: cứ tick một quỹ là gom cả quỹ; đặt 50 khi một quỹ dùng chung phải
chia cho hai hũ, để tổng các hũ không đội lên.

Hũ tiết kiệm giờ có HAI con số (hỏi Tony chọn, trả lời "cả hai"):
- **Đã gửi kỳ này** = tổng tiền vào các quỹ của hũ TRONG KỲ (đã nhân tỉ lệ) — so với hạn mức kỳ.
- **Tổng quỹ đang có** = số dư tích luỹ của các quỹ đó (mọi thời gian, đã nhân tỉ lệ).

**Hũ 0%**: hợp lệ với hũ tiết kiệm (hũ tiêu vẫn phải ≥1% — 0% là hũ không bao giờ nhận đồng nào, gần
như chắc chắn gõ nhầm). Khi 0% thì không có mốc "kỳ này phải gửi bao nhiêu", nên thanh tiến độ
chuyển sang đo **tiền đã để dành / tổng đích các quỹ** (Tony: "vẫn có thanh, số tiền tiết kiệm được
từ các quỹ"), và ô "còn cần gửi" đổi thành "Còn thiếu" so với đích.

### 2. Thẻ hũ hiện "đã tiêu / tổng nên tiêu" bằng số

Trước: một số lớn duy nhất là HẠN MỨC. Một mình nó không nói được tháng này đang đi tới đâu, mà
người ta nhìn vào thẻ hũ chính là để hỏi câu đó. Giờ góc phải là `đã tiêu / hạn mức`; dòng dưới thôi
lặp lại "đã tiêu", chỉ còn phần còn lại (hũ tiết kiệm: tổng quỹ đang có / đích).

### 3. Trang Ghi chú (schema v16)

Bảng `notes(title, body, is_pinned, created_at, updated_at)`, vào từ Quản lý → Ghi chú. Cố ý KHÔNG
dính gì tới giao dịch: không danh mục, không số tiền, không ngày. Mỗi trường bắt phải điền là một lý
do để thôi ghi chú. Tiêu đề để trống được — danh sách tự lấy dòng đầu của nội dung làm nhãn
(`noteDisplayTitle`) và bỏ đúng dòng đó khỏi phần xem trước để không lặp. Ghim KHÔNG đụng
`updatedAt`: ghim không phải sửa nội dung, để nó đẩy ghi chú lên đầu danh sách "mới sửa" là nói sai.
Soạn ghi chú là MÀN RIÊNG, không phải sheet — nội dung dài thì bàn phím ăn gần hết sheet.

Cả `jar_goals` lẫn `notes` vào `BackupService` ngay trong cùng bản (luật đã trả giá một lần với bảng
`jars`), có test round-trip và test "bản sao lưu cũ không có khoá này vẫn khôi phục được".

Kiểm chứng: 1132 test xanh (+41), analyze sạch, `check_arch.sh` PASS. Chạy tay trên `tonyfino36`:
cài đè 1.0.8, gom hũ "Tiết kiệm dài hạn" vào 2 quỹ (Mua nha 50%, Kham benh 100%) và đặt hũ 0% →
"Đã gửi kỳ này 2.500.000" (đúng 5tr × 50%), thanh đo theo đích 45tr; tạo/sửa/ghim/xoá ghi chú.

## 2026-09-20 (tiếp) · Hũ quỹ có HAI CHIỀU (v17), Ghi chú thành trang rời

### Hai chiều: nạp vào quỹ / tiêu từ quỹ

Tony: *"hũ liên quan tới quỹ có 2 dạng: nạp tiền vào quỹ, sài tiền từ quỹ"*. Thêm `jars.goal_flow`
(`'in'`/`'out'`, mặc định `'in'` — đúng với mọi hũ quỹ đang có).

- **Nạp vào quỹ** (như cũ): đo tiền bỏ vào quỹ trong kỳ, mốc là phần trăm thu nhập (hoặc đích các
  quỹ khi hũ 0%). Gửi nhiều là tốt.
- **Tiêu từ quỹ**: đo tiền RÚT TỪ quỹ ra tiêu trong kỳ. Mốc tự nhiên là tiền CÒN trong quỹ — "quỹ
  khám bệnh còn bao nhiêu" mới là câu hỏi. Đặt phần trăm > 0 thì đó là TRẦN rút của kỳ (vượt trần =
  đỏ như hũ tiêu); để 0 thì thanh đo phần quỹ đã tiêu trong kỳ so với chính quỹ đó đầu kỳ.

Truy vấn tách hai chiều bằng hai `SUM(...) FILTER` (nạp là dòng âm, rút là dòng dương) thay vì chỉ
lấy số ròng — số ròng một mình không trả lời được cả hai câu hỏi.

🚨 **Sửa sau khi bấm thật**: bản đầu tính "đã rút" theo số RÒNG (rút − nạp, kẹp ở 0). Trên máy, quỹ
vừa được nạp 5tr trong kỳ nên rút 500k xong hũ vẫn hiện "Đã rút 0 ₫" — vô nghĩa. Chiều "tiêu từ quỹ"
phải đọc TỔNG tiền rút: tháng này nạp thêm 1tr rồi lấy 300k đi khám thì "tiêu từ quỹ" là 300k, không
phải 0. Chiều "nạp vào" vẫn đọc phần ròng (bỏ vào được bao nhiêu). Không bài test nào bắt được cái
này vì cả hai cách đều "trông hợp lý" trên dữ liệu test cân bằng.

Nhãn đi theo chiều ở cả ba chỗ (thẻ hũ, Trang chủ, màn chi tiết): "Đã rút kỳ này" · "Còn trong quỹ" ·
nút "Rút từ quỹ này" thay cho "Gửi vào quỹ này". Hũ không đặt mức của kỳ thì bỏ hẳn vế "/ 0 ₫".

### Ghi chú là trang rời

Tony: *"trang note là trang rời"*. Thêm icon Ghi chú vào thanh trên cùng (thấy từ mọi tab), bên cạnh
Tìm kiếm/Ẩn số tiền/Quản lý/Cài đặt — năm icon vẫn vừa một hàng ở 1080px, đã chụp màn kiểm. Giữ cả
lối vào trong Quản lý vì màn đó là mục lục đầy đủ. KHÔNG thêm tab thứ năm ở thanh dưới (TODOS.md D:
"5 tab là lúc nav bắt đầu trông như thanh công cụ bảng tính").

### Bẫy tái diễn

Test migration dừng ở phiên bản TRUNG GIAN (v13→v14, v14→v15) đọc dữ liệu bằng `db.select(db.jars)`
— lớp bảng SỐNG luôn mang hình dạng mới nhất, nên thêm `goal_flow` ở v17 làm hai bài test cũ nổ "Null
check operator used on a null value". Đọc bằng `customSelect('SELECT … FROM jars')` ở những bài dừng
giữa chừng; cùng họ bẫy với `alterTable` dùng getter bảng sống (Phase 16).
