/// Hex thô từ Radix Colors (MIT, radix-ui/colors), zero ngữ nghĩa — file này
/// KHÔNG BAO GIỜ import `material.dart` (Luật #10, TODOS.md). `app_colors.dart`
/// là nơi gán ý nghĩa (thu/chi/danh mục/...) cho các hằng số dưới đây.
///
/// Giá trị lấy đúng từ bảng "🎨 Design system — đặc tả chốt" trong TODOS.md —
/// không tự suy ra thang Radix đầy đủ, chỉ giữ đúng các bậc màu đã chốt dùng.
library;

import 'dart:ui' show Color;

// ── Nền trung tính ──────────────────────────────────────────────────────
const paletteCanvasLight = Color(0xFFFBFBFD);
const paletteCanvasDark = Color(0xFF0C0D10);
const paletteCardLight = Color(0xFFFFFFFF);
const paletteCardDark = Color(0xFF14161A);
const paletteSubtleLight = Color(0xFFF3F3F6); // surfaceContainer
const paletteSubtleDark = Color(0xFF1A1D22);
const paletteOverlayLight = Color(0xFFEBEBF0); // sheets
const paletteOverlayDark = Color(0xFF22262C);
const paletteHairlineLight = Color(0xFFE4E4E9);
const paletteHairlineDark = Color(0xFF2A2F36);
const paletteInkLight = Color(0xFF16161A); // onSurface
const paletteInkDark = Color(0xFFEDEEF0);
const paletteInkMutedLight = Color(0xFF61616B); // onSurfaceVariant
const paletteInkMutedDark = Color(0xFF9BA1A6);

/// Dark AMOLED tuỳ chọn — thay `paletteCanvasDark` khi Tony bật "Đen tuyền".
const paletteCanvasAmoled = Color(0xFF000000);

// ── Thương hiệu: CAM GẠCH (terracotta / bột gạch mài) ───────────────────
//
// Mọi cặp dưới đây đã đo tương phản WCAG thật, không chọn bằng mắt:
//   NỀN nút #F4700A  · chữ #06202E trên nó   5.72:1
//   CHỮ trên canvas #CC4400                     4.62:1
//   #FF9166 trên canvas tối   8.79:1  · chữ #06202E trên nó 7.57:1
//   #0F4557 trên #FFEDE5      9.21:1  · #FFD5C2 trên #0C3341  9.93:1
// Tất cả đều vượt ngưỡng 4.5:1 cho chữ thường.
//
// 🚨 HAI tông cam, KHÔNG phải một — vì chữ và nền có ngưỡng khác nhau:
//
//   [paletteBrickLight] #F4700A — CAM SÁNG, chỉ làm NỀN (nút, FAB, chip).
//     Chữ trên nó là #2B0F02 (nâu rất tối), 6.12:1. Đây là kiểu M3 hiện
//     đại: nền rực + chữ tối, thay vì nền trầm + chữ trắng.
//   [paletteBrickTextLight] #CC4400 — làm CHỮ/ICON trên nền sáng, 4.62:1.
//
// Vì sao phải tách: đẩy nền lên #F4700A thì chính nó chỉ còn 2.83:1 so với
// canvas — dùng làm chữ là không đọc được. Ngược lại giữ một tông đủ tối để
// làm chữ thì nút không bao giờ "tươi" được. Một token không thoả cả hai.
//
// Tông "bột gạch" dịu hơn (#C86B4A) CỐ Ý không dùng làm primary: nó chỉ đạt
// 3.59:1 trên nền sáng — trượt chuẩn khi làm chữ. Nó sống ở
// [paletteBrickDust], dành riêng cho quầng nền/trang trí, nơi không có chữ
// nào phải đọc trên đó.
const paletteBrickLight = Color(0xFFF4700A);

/// 🚨 CHỮ/ICON nhấn KHÔNG phải cam — mà là XANH PETROL, màu ĐI CẶP với cam.
///
/// Trước đây token này là #CC4400: đúng là cam, nhưng cam ở độ sáng 40% mắt
/// người đọc ra NÂU. Nó nằm ở tiêu đề mục Cài đặt, nhãn tab, mọi nút chữ —
/// nên cả app ám nâu, đúng chỗ Tony kêu "không thích màu cam nâu".
///
/// Không thể sửa bằng cách làm nó sáng hơn: cam sáng thì rơi xuống dưới
/// 4.5:1 (chính là lý do phải tách hai token ngay từ đầu). Lối ra là ĐỔI
/// TÔNG, không đổi độ sáng — Tony chốt "giữ cam, thay nâu bằng màu hay đi
/// cùng với cam".
///
/// #0F6C87 — petrol/xanh mòng két đậm, đo thật:
///   · 5.78:1 trên canvas sáng (cao hơn #CC4400 cũ 4.62:1)
///   · hue 194°, gần đối xứng với cam 26° trên vòng màu → cặp bổ túc kinh
///     điển, cam càng rực petrol càng làm nền cho nó nổi
///   · cách chàm "tiền thu" (#1C4ED8, hue 224°) 30° — hai màu cùng họ lạnh
///     nhưng petrol thiên lam-lục và nhạt màu, chàm thì rực và ngả tím, đặt
///     cạnh nhau vẫn tách được; hơn nữa số dương LUÔN có dấu `+` đi kèm nên
///     màu không phải thứ duy nhất mang nghĩa (xem `MoneyText`)
const paletteBrickTextLight = Color(0xFF0F6C87);
const paletteBrickDark = Color(0xFFFF9166);

/// Cặp petrol cho nền TỐI — 11.12:1 trên #0C0D10.
const paletteBrickTextDark = Color(0xFF63D3E8);

/// Chữ TRÊN nút cam. Trước là nâu rất tối #2B0F02; giờ là chàm-đen #06202E
/// (5.72:1 trên #F4700A) — Tony yêu cầu bỏ nâu ở MỌI chỗ, và đây là chỗ nâu
/// lộ nhất: nhãn tab đang chọn ở thanh điều hướng dưới nằm trên viên cam.
const paletteBrickContrastLight = Color(0xFF06202E);
const paletteBrickContrastDark = Color(0xFF06202E); // 7.57:1 trên #FF9166
const paletteBrickSoftLight = Color(0xFFFFEDE5); // primaryContainer
const paletteBrickSoftDark = Color(0xFF0C3341); // chữ #FFD5C2 trên nó 9.93:1
const paletteBrickSoftContrastLight = Color(0xFF0F4557); // 9.21:1 trên #FFEDE5
const paletteBrickSoftContrastDark = Color(0xFFFFD5C2);

/// Bột gạch — chỉ trang trí (quầng nền), KHÔNG bao giờ có chữ đặt lên trên.
const paletteBrickDust = Color(0xFFF2764A);

// ── Ngữ nghĩa thu/chi/ngân sách ────────────────────────────────────────
//
// 🚨 "Tiền thu" và "trong hạn mức" là CHÀM, không phải xanh lá.
//
// Xanh lá là quy ước mặc định của app tài chính, nhưng xanh lá + cam là một
// cặp không ăn nhau (hai màu ấm-lạnh cách nhau nửa vòng nhưng cùng độ rực,
// nhìn chói và rẻ tiền). Tony yêu cầu đổi sang xanh dương hợp tone cam.
// Chàm #1C4ED8 hue 224° đối xứng gần như hoàn hảo với cam 26° (chênh 198°,
// bổ túc lý tưởng là 180°) nên đứng cạnh cam thì tôn nhau lên.
//
// Không mất thông tin gì khi bỏ xanh lá: nghĩa thu/chi được mã hoá bằng DẤU
// `+`/`−` tường minh chứ không chỉ bằng sắc độ (xem doc của `MoneyText`) —
// vốn là yêu cầu tiếp cận cho người mù màu đỏ-lục ngay từ đầu.
const paletteIncomeTextLight = Color(0xFF1C4ED8); // 6.49:1 trên canvas sáng
const paletteIncomeTextDark = Color(0xFF8AB0FF); // 9.01:1 trên canvas tối
const paletteIncomeFill = Color(0xFF3B76E8); // giống cả hai theme
const paletteRedTextLight = Color(0xFFCD2B31);
const paletteRedTextDark = Color(0xFFFF6369);
const paletteRedFill = Color(0xFFE5484D); // giống cả hai theme
const paletteAmberFill = Color(0xFFFFB224); // giống cả hai theme

// ── 12 màu danh mục (Radix bậc 9) — GIỐNG NHAU ở cả hai theme để legend
// biểu đồ không nhảy khi đổi theme. Thứ tự khớp đúng bảng trong TODOS.md;
// `categoryColorId` (D10) là chỉ số vào danh sách này, không phải tên. ──────
const paletteCategoryOrange = Color(0xFFF76B15); // "Ăn uống" trong design doc
const paletteCategoryAmber = Color(0xFFFFB224); // "Cà phê"
const paletteCategoryBlue = Color(0xFF0091FF); // "Đi lại"
const paletteCategoryPink = Color(0xFFD6409F); // "Mua sắm"
const paletteCategoryIndigo = Color(0xFF3E63DD); // "Hóa đơn"
const paletteCategoryPlum = Color(0xFF8E4EC6); // "Giải trí"
const paletteCategoryTeal = Color(0xFF12A594); // "Sức khỏe"
const paletteCategoryCyan = Color(0xFF05A2C2); // "Giáo dục"
/// Ô "trung tính" của bảng 12 màu — trước là nâu #AD7F58, nay là XANH XÁM.
///
/// Giữ vai trò cũ (một màu trầm, ít rực, để cạnh 11 màu rực không bị chìm)
/// nhưng thuộc họ lạnh. CỐ Ý chọn tông xỉn: bảng đã có Blue #0091FF, Indigo
/// #3E63DD, Teal #12A594, Cyan #05A2C2 — thêm một xanh RỰC nữa là 5 màu
/// xanh chen nhau trong cùng một biểu đồ tròn, không ai phân biệt nổi.
const paletteCategoryBrown = Color(0xFF5F7E9E); // "Nhà cửa"
const paletteCategoryCrimson = Color(0xFFE93D82); // "Quà tặng"
const paletteCategoryGrass = Color(0xFF46A758); // "Tiết kiệm"
const paletteCategoryGray = Color(0xFF8D8D8D); // "Khác"

const List<Color> paletteCategoryColors = [
  paletteCategoryOrange,
  paletteCategoryAmber,
  paletteCategoryBlue,
  paletteCategoryPink,
  paletteCategoryIndigo,
  paletteCategoryPlum,
  paletteCategoryTeal,
  paletteCategoryCyan,
  paletteCategoryBrown,
  paletteCategoryCrimson,
  paletteCategoryGrass,
  paletteCategoryGray,
];

// ── Heatmap 5 bậc ─────────────────────────────────────────────────────────
// 🚨 Thang lịch chi tiêu: PETROL, không phải cam.
//
// Lưới này là ~370 ô, mảng màu LỚN NHẤT trong app. Thang cam cũ ở dark mode
// (#3A1B0C → #C2601F) là nâu từ đầu tới cuối — cam mà giảm độ sáng thì
// thành nâu, không có cách nào tránh. Đó chính là "còn nhiều màu nâu" Tony
// thấy. Dùng họ petrol của thương hiệu: tối đi vẫn là xanh, không ngả nâu.
//
// Chọn PETROL (lam-lục) chứ không phải chàm #1C4ED8 của "tiền thu": ô đậm ở
// đây nghĩa là TIÊU NHIỀU, dùng đúng màu đang mang nghĩa "tiền vào" là mời
// người ta đọc ngược. Mỗi bậc cách bậc trước ≥1.2x độ chói nên phân biệt
// được, kể cả ở ô 16px.
const List<Color> paletteHeatmapLight = [
  Color(0xFFE4F2F7),
  Color(0xFFB6DCE8),
  Color(0xFF7CBFD6),
  Color(0xFF3C93B3),
  Color(0xFF0F6C87),
];
const List<Color> paletteHeatmapDark = [
  Color(0xFF0E2630),
  Color(0xFF164352),
  Color(0xFF1E6076),
  Color(0xFF2E8FAC),
  Color(0xFF63D3E8),
];

// ── Viền/highlight trắng mờ dùng riêng cho elevation ở dark mode (không đổ
// bóng — độ sáng bề mặt + hairline, xem app_shadows.dart) ─────────────────
const paletteWhiteHairline6 = Color(0x0FFFFFFF); // #FFFFFF0F
const paletteWhiteHairline8 = Color(0x14FFFFFF); // #FFFFFF14
const paletteWhiteHairline4 = Color(0x0AFFFFFF); // #FFFFFF0A

// ── Đổ bóng light mode (dark mode không đổ bóng — luật #11) ───────────────
const paletteShadowCard = Color(0x0D0B1220); // bậc 1: card — lớp toả (ambient)
const paletteShadowSheet = Color(0x1A0B1220); // bậc 2: sheet/menu

// Lớp TIẾP XÚC (contact) — bóng ngắn, đậm hơn, sát ngay dưới mép card. Bóng
// thật ngoài đời luôn có hai lớp: một vệt tối sắc sát vật thể + một quầng
// rộng mờ. Chỉ có lớp toả thì card trông như "trôi", không "đặt trên" mặt
// phẳng — đây là thứ tạo cảm giác khối thật sự.
const paletteShadowCardContact = Color(0x140B1220);
const paletteShadowSheetContact = Color(0x260B1220);

// Bóng cho DARK MODE. Quy ước cũ của dự án là dark không đổ bóng bao giờ,
// nhưng đó là lý do màn tối trông phẳng lì: trên nền gần đen, bóng ĐEN ĐẬM
// (alpha cao) vẫn đọc được rõ — chính cách Mercury tạo chiều sâu
// (`0 4px 24px rgba(0,0,0,0.4)`). Kèm một vệt sáng mép trên để card trông
// như được chiếu sáng từ trên xuống.
const paletteShadowCardDark = Color(0x66000000);
const paletteShadowCardDarkContact = Color(0x4D000000);
const paletteShadowSheetDark = Color(0x80000000);
