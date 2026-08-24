/// `IconData`/`Icon` sống ở `package:flutter/widgets.dart` — framework lõi,
/// KHÔNG phải Material (khác `Icons.*` của `material.dart`). An toàn cho
/// Luật #10 giống `curves.dart`.
///
/// Style **Rounded** (đặc tả design system § Package UI — khớp bo góc rộng
/// toàn hệ thống). `package:material_symbols_icons`'s `Symbols.xxx` mặc định
/// trỏ font *Outlined*; codepoint giống hệt cả 3 style, chỉ khác font file,
/// nên viết thẳng `IconData` Rounded bằng const literal ở đây — const thật
/// (không qua hàm helper hay `.codePoint` runtime) để icon tree-shaking
/// (`--tree-shake-icons`, mặc định ở release build) nhận diện và rút gọn
/// đúng các glyph thực dùng thay vì giữ nguyên cả font Rounded. Codepoint
/// xác nhận từ `material_symbols_icons/lib/symbols.dart` bản 4.2960.0.
library;

import 'package:flutter/widgets.dart' show IconData;

const _fontFamily = 'MaterialSymbolsRounded';
const _fontPackage = 'material_symbols_icons';

const kIconRestaurant = IconData(
  0xe56c,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconDirectionsCar = IconData(
  0xeff7,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconHome = IconData(
  0xe9b2,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconFamilyRestroom = IconData(
  0xf1a2,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconShoppingBag = IconData(
  0xf1cc,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconDevices = IconData(
  0xe326,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconHealthAndSafety = IconData(
  0xe1d5,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSpa = IconData(
  0xeb4c,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSchool = IconData(
  0xe80c,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconTheaterComedy = IconData(
  0xea66,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconMoreHoriz = IconData(
  0xe5d3,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);

/// Danh mục con mặc định "Tiêu vặt" (Phase 22 addendum). Codepoint xác nhận
/// từ `material_symbols_icons-4.2960.0/lib/symbols.dart:26269`.
const kIconLocalCafe = IconData(
  0xeb44,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconPayments = IconData(
  0xef63,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconQuestionMark = IconData(
  0xeb8b,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);

// ── Icon UI dùng chung ────────────────────────────────────────────────────
const kIconExpandMore = IconData(
  0xe5cf,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconUndo = IconData(
  0xe166,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCheck = IconData(
  0xe668,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconMic = IconData(
  0xe31d,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconArrowUpward = IconData(
  0xe5d8,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconChat = IconData(
  0xe0c9,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconReceiptLong = IconData(
  0xef6e,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconBarChart = IconData(
  0xe26b,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSavings = IconData(
  0xe2eb,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSettings = IconData(
  0xe8b8,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconAdd = IconData(
  0xe145,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconDelete = IconData(
  0xe92e,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconInbox = IconData(
  0xe156,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconEdit = IconData(
  0xf097,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconContentCopy = IconData(
  0xe14d,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCheckCircle = IconData(
  0xf0be,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconError = IconData(
  0xf8b6,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconVisibility = IconData(
  0xe8f4,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconVisibilityOff = IconData(
  0xe8f5,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconTune = IconData(
  0xe429,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCalendarToday = IconData(
  0xe935,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconClose = IconData(
  0xe5cd,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconTrendingUp = IconData(
  0xe8e5,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCategory = IconData(
  0xe72c,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconChevronLeft = IconData(
  0xe5cb,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconChevronRight = IconData(
  0xe5cc,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconAddCircle = IconData(
  0xe990,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconFingerprint = IconData(
  0xe90d,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCloudDone = IconData(
  0xe2bf,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconWarning = IconData(
  0xf083,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconEventRepeat = IconData(
  0xeb7b,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconAccountBalanceWallet = IconData(
  0xe850,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconAccountBalance = IconData(
  0xe84f,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCreditCard = IconData(
  0xe8a1,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconDragHandle = IconData(
  0xe25d,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconMerge = IconData(
  0xeb98,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconArchive = IconData(
  0xe149,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconUnarchive = IconData(
  0xe169,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSwapHoriz = IconData(
  0xe8d4,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCallSplit = IconData(
  0xe0b6,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconBookmark = IconData(
  0xe8e7,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconHandshake = IconData(
  0xebcb,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconFlag = IconData(
  0xf0c6,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSearch = IconData(
  0xef7a,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSell = IconData(
  0xf05b,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconAddAPhoto = IconData(
  0xe439,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconImage = IconData(
  0xe3f4,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);

/// `iconCode` lưu trong `categories.iconCode` (Phase 4 seed) → `IconData`
/// Rounded. Khớp đúng 12 mã ở `lib/data/db/seed/category_seed.dart`.
const Map<String, IconData> categoryIconByCode = {
  'restaurant': kIconRestaurant,
  'directions_car': kIconDirectionsCar,
  'home': kIconHome,
  'family_restroom': kIconFamilyRestroom,
  'shopping_bag': kIconShoppingBag,
  'devices': kIconDevices,
  'health_and_safety': kIconHealthAndSafety,
  'spa': kIconSpa,
  'school': kIconSchool,
  'theater_comedy': kIconTheaterComedy,
  'more_horiz': kIconMoreHoriz,
  'payments': kIconPayments,
  'local_cafe': kIconLocalCafe,
  // Hai mã thêm ở v13 cho HŨ (`kDefaultJarSeeds`) — hũ dùng chung bộ icon
  // với danh mục nên phải có mặt ở đây, nếu không `resolveCategoryIcon` trả
  // dấu hỏi.
  'savings': kIconSavings,
  'handshake': kIconHandshake,
};

IconData resolveCategoryIcon(String iconCode) =>
    categoryIconByCode[iconCode] ?? kIconQuestionMark;

/// Bản 3D của cùng những `iconCode` đó (Microsoft Fluent Emoji, MIT — xem
/// `assets/icons3d/NOTICE.md`). CỐ Ý khoá theo `iconCode` chứ không theo tên
/// danh mục: `iconCode` mới là danh tính hình ảnh mà mọi màn đã dựa vào từ
/// Phase 4 (D10), nên bộ 3D chỉ là một CÁCH VẼ khác của cùng danh tính —
/// thiếu file nào thì [resolveCategoryIcon] glyph đơn sắc vẫn là đường lùi
/// đầy đủ, không màn nào vỡ.
const Map<String, String> categoryIcon3dByCode = {
  'restaurant': 'assets/icons3d/categories/restaurant.png',
  'directions_car': 'assets/icons3d/categories/directions_car.png',
  'home': 'assets/icons3d/categories/home.png',
  'family_restroom': 'assets/icons3d/categories/family_restroom.png',
  'shopping_bag': 'assets/icons3d/categories/shopping_bag.png',
  'devices': 'assets/icons3d/categories/devices.png',
  'health_and_safety': 'assets/icons3d/categories/health_and_safety.png',
  'spa': 'assets/icons3d/categories/spa.png',
  'school': 'assets/icons3d/categories/school.png',
  'theater_comedy': 'assets/icons3d/categories/theater_comedy.png',
  'more_horiz': 'assets/icons3d/categories/more_horiz.png',
  'payments': 'assets/icons3d/categories/payments.png',
  'local_cafe': 'assets/icons3d/categories/local_cafe.png',
  'savings': 'assets/icons3d/categories/savings.png',
  'handshake': 'assets/icons3d/categories/handshake.png',
};

String resolveCategoryIcon3d(String iconCode) =>
    categoryIcon3dByCode[iconCode] ??
    'assets/icons3d/categories/question_mark.png';

/// `iconCode` lưu trong `wallets.iconCode` (Phase 13).
const Map<String, IconData> walletIconByCode = {
  'account_balance_wallet': kIconAccountBalanceWallet,
  'account_balance': kIconAccountBalance,
  'credit_card': kIconCreditCard,
  'payments': kIconPayments,
  'savings': kIconSavings,
  'more_horiz': kIconMoreHoriz,
};

IconData resolveWalletIcon(String iconCode) =>
    walletIconByCode[iconCode] ?? kIconAccountBalanceWallet;
