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
