# TonyFino — Nghiên cứu & quyết định thiết kế (Phase 5)

Đặc tả đầy đủ (font, bảng màu Radix, thang bo góc, khoảng cách, đổ bóng, motion) sống trong
`TODOS.md` § "🎨 Design system — đặc tả chốt". File này ghi lại **lý do** đằng sau các quyết định
thực thi cụ thể — chỗ mà lúc thực thi phải tự quyết vì đặc tả không (và không thể) nói hết chi
tiết. Đọc cùng `docs/decisions.md` (D1–D10 + quyết định phát sinh mọi phase).

---

## Vì sao tách `lib/theme/tokens/` nghiêm đến vậy

Luật #10 (`TODOS.md`) cấm `material.dart` trong `lib/theme/tokens/`. Lý do không phải thẩm mỹ —
Flutter đã đóng băng phát triển `material.dart` (Google công bố Material 3 Expressive 5/2025,
Flutter tạm dừng đưa nó vào SDK 7/2025) và đang chuyển hướng sang package `material_ui` tách rời.
Nếu token màu/khoảng cách/bo góc "sạch" (không phụ thuộc `ThemeData`/`ColorScheme` của
`material.dart`), migration sau này chỉ là đổi một dòng import ở `app_theme.dart` — nơi DUY NHẤT
lắp token vào `ThemeData`.

**Hai ngoại lệ có chủ đích, cả hai đều đã kiểm chứng bằng cách đọc thẳng SDK Flutter cục bộ**
(`packages/flutter/lib/*.dart`), không đoán:

- `curves.dart` import `package:flutter/animation.dart` để lấy `Curve`/`Curves`. Đây là thư viện
  animation LÕI của framework (`src/animation/curves.dart`), khác hẳn `src/material/curves.dart`
  (easing riêng của M3) — file sau này mới là thứ luật #10 thật sự muốn cấm.
- `icons.dart` import `package:flutter/widgets.dart` để lấy `IconData`/`Icon`. Cả hai lớp này
  sống ở `src/widgets/icon.dart` + `icon_data.dart`, KHÔNG phải Material — `Icons.*` (bộ icon có
  sẵn) mới thuộc `material.dart`, và ta không dùng nó (dùng `material_symbols_icons` qua
  `IconData` tự khai báo).

## Icon: tại sao viết `IconData` bằng const literal thay vì gọi API của package

`material_symbols_icons` 4.2960.0's `Symbols.xxx` mặc định trỏ font **Outlined**. Đặc tả chốt
style **Rounded**. Codepoint giống hệt cả ba style (Outlined/Rounded/Sharp) — chỉ font file khác
— nên đáng lẽ chỉ cần đổi `fontFamily`. Package có sẵn `SymbolsGet.get(name, SymbolStyle.rounded)`
làm đúng việc này, NHƯNG đọc kỹ `lib/get.dart` thì nó đòi hoặc tắt hẳn `--tree-shake-icons`, hoặc
import `symbols_map.dart` (ép tham chiếu toàn bộ 4.264 icon để né tree-shaking) — quá đắt cho một
bộ 12 icon danh mục cố định.

Giải pháp: lấy codepoint hex trực tiếp từ `symbols.dart` (grep, không đoán — vd `restaurant =
0xe56c`), viết `const IconData(0xe56c, fontFamily: 'MaterialSymbolsRounded', fontPackage:
'material_symbols_icons')` bằng tay trong `lib/theme/tokens/icons.dart`. Vẫn là `const` thật nên
icon tree-shaker (bật mặc định ở release build) nhận diện đúng, chỉ giữ lại glyph thực dùng thay
vì cả font Rounded.

## `AppShadows.lerp`: `BoxShadow.lerpList` co HÌNH HỌC, không mờ ALPHA

Bất ngờ khi viết test: `BoxShadow.lerpList([shadow], [], t)` ở `t=0.5` giữ nguyên alpha màu gốc,
chỉ co `blurRadius`/`spreadRadius`/`offset` về nửa giá trị — khác trực giác "mờ dần alpha" ban
đầu. Đọc `BoxShadow.lerp`/`.scale()` xác nhận: khi một đầu là `null`, nó gọi `.scale(1-t)`, và
`.scale()` chỉ nhân hình học, không đụng màu. Vẫn là nội suy THẬT (Luật #3) — chỉ là trục nội suy
khác: một shadow co về 0-blur/0-spread/0-offset thì hình dạng của nó trên màn hình cũng biến mất
dần y hệt, dù giá trị alpha trong struct không đổi. `test/theme/theme_extension_lerp_test.dart`
kiểm bằng `blurRadius`, không phải `color.a`, vì lý do này.

## Vì sao `categoryFills` (12 màu) không cần khớp tên 12 danh mục seed ở Phase 4

Phase 4 seed 12 danh mục theo dữ liệu dùng thật (rút từ `raw_rolly/`): Ăn uống, Di chuyển, Nhà
cửa, Gia đình, Mua sắm, Điện tử, Sức khỏe, Làm đẹp, Giáo dục, Giải trí, Phát sinh, Lương. Bảng màu
trong đặc tả design system liệt kê 12 màu theo tên KHÁC (Ăn uống, Cà phê, Đi lại, Mua sắm, Hóa
đơn, Giải trí, Sức khỏe, Giáo dục, Nhà cửa, Quà tặng, Tiết kiệm, Khác) — hai danh sách không khớp
1-1, và đó là **đúng ý** D10: `categoryColorId` là một CHỈ SỐ nguyên vô nghĩa, không phải tên màu.
`AppColors.categoryFills` chỉ là "12 màu Radix theo đúng thứ tự trong TODOS.md", độc lập hoàn
toàn với việc danh mục ở vị trí đó tên là gì. Phase 4 đã gán `colorId 0..11` tuần tự khi seed —
khớp tự nhiên, không cần đổi gì ở đây hay ở đó.

## `NumberFormat.currency(locale:'vi_VN')` chèn NBSP — lặp lại cạm bẫy từ Phase 4

Ký tự trước `₫` là U+00A0 (non-breaking space), không phải dấu cách thường U+0020 — đã xác nhận
lại bằng `.codeUnits` ở `test/ui/money_text_test.dart` (không tin vào việc gõ lại đúng ký tự bằng
mắt lần thứ hai, vì lần đầu ở Phase 4 chính vì nhìn giống hệt mà dễ chép sai).

## Golden test: alchemist CI/platform, tại sao setup `flutter_test_config.dart` ngay từ Phase 5

`goldenTest` mặc định ghi ảnh vào `goldens/<platform>/*.png` (chữ thật, phụ thuộc máy — chỉ để
dev soi mắt, KHÔNG commit) và cần bật thêm CI config để ghi song song `goldens/ci/*.png` (font
Ahem, ổn định xuyên nền tảng — commit vào git). Thiết lập đúng ngay từ ảnh golden ĐẦU TIÊN của dự
án để không phải dọn lại về sau khi có CI thật. `.gitignore` chặn `goldens/{linux,macos,windows}/`,
giữ lại `goldens/ci/`.

Bốn ảnh `text_styles_*` (light/dark × 1.0×/1.3×) là bài test bắt buộc quan trọng nhất phase này —
mỗi ảnh là một "specimen sheet" xếp đủ 10 text style (6 `TextTheme` + 4 money) cùng chuỗi
`Đồng Nai — ế ữ ỗ ặ ỡ Ế Ữ Ỗ · 1.234.567 ₫`, đã soi bằng mắt qua công cụ `Read` (đọc PNG) — không
thấy dấu chồng nào bị cắt ở bất kỳ style/scale/theme nào.

## Style Gallery: gác cổng ở đâu

`StyleGalleryScreen` (`lib/debug/style_gallery.dart`) tự nó KHÔNG kiểm tra `kDebugMode` — nếu
làm vậy thì chính widget này không test được ở mọi build mode. Gác cổng nằm ở call site
(`lib/main.dart`): `home: kDebugMode ? StyleGalleryScreen() : _ScaffoldPlaceholder()`. Widget vẫn
export bình thường, `test/debug/style_gallery_test.dart` pump trực tiếp không qua cổng đó.

## Phạm vi cố ý bỏ qua ở Phase 5

- **`AppBottomSheet` không có golden riêng.** Nó là một hàm mở modal (`showModalBottomSheet`),
  không phải một widget tĩnh render được độc lập có ý nghĩa trong khung golden — golden test cho
  chrome/shape của nó chỉ lặp lại đúng thứ `BudgetRing`/`AppCard` đã chứng minh (bo góc, màu, tự
  vẽ). Sẽ có ý nghĩa hơn khi có nội dung sheet thật ở Phase 6+.
- **`AppChip`/`AppBottomSheet` không nằm trong checklist "Widget nguyên tử" gốc** của Phase 5
  (khác với danh sách `MoneyText`/`CategoryAvatar`/.../`CountUpText`) nhưng vẫn được viết đầy đủ
  vì `Bàn giao` liệt kê chúng là file bắt buộc, và Phase 8 (màn chat) cần `AppChip` ngay — làm
  luôn ở đây rẻ hơn quay lại sau.
