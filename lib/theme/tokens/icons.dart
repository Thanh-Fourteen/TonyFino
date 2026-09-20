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

// ── Bộ icon danh mục MỞ RỘNG ──────────────────────────────────────────────
//
// 114 icon (trước đây 15). Tony: "ít icon cho danh mục quá" — 15 mã seed đủ
// cho 12 danh mục mặc định nhưng không đủ để đặt tên hình cho danh mục tự
// tạo, nên mọi danh mục mới trông giống hệt nhau.
//
// Mỗi mã ở đây có ĐỦ HAI cách vẽ, đúng hợp đồng của [CategoryAvatar]: glyph
// Material Symbols Rounded (const literal, để `--tree-shake-icons` rút gọn
// được) VÀ một file 3D Fluent Emoji trong `assets/icons3d/categories/` cùng
// tên — thiếu file 3D thì avatar rơi về `question_mark.png`, tức mọi icon
// mới sẽ hiện thành dấu hỏi, nên hai bảng bên dưới PHẢI luôn đi cùng nhau.
// Codepoint xác nhận từ `material_symbols_icons/lib/symbols.dart` 4.2960.0.

const kIconFastfood = IconData(
  0xe57a,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconRamenDining = IconData(
  0xea64,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconRiceBowl = IconData(
  0xf1f5,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconLocalPizza = IconData(
  0xe552,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconBakeryDining = IconData(
  0xea53,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconIcecream = IconData(
  0xea69,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCake = IconData(
  0xe7e9,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconLocalBar = IconData(
  0xe540,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSportsBar = IconData(
  0xf1f3,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconWineBar = IconData(
  0xf1e8,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconEmojiFoodBeverage = IconData(
  0xea1b,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconLocalDrink = IconData(
  0xe544,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSetMeal = IconData(
  0xf1ea,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconNutrition = IconData(
  0xe110,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconEggAlt = IconData(
  0xeac8,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconTwoWheeler = IconData(
  0xe9f9,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconMoped = IconData(
  0xeb28,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconLocalGasStation = IconData(
  0xe546,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconLocalTaxi = IconData(
  0xe559,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconDirectionsBus = IconData(
  0xeff6,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconTrain = IconData(
  0xe570,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconFlight = IconData(
  0xe539,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconPedalBike = IconData(
  0xeb29,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconDirectionsBoat = IconData(
  0xeff5,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconLocalShipping = IconData(
  0xe558,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconBolt = IconData(
  0xea0b,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconWaterDrop = IconData(
  0xe798,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconWifi = IconData(
  0xe63e,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCleaningServices = IconData(
  0xf0ff,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSoap = IconData(
  0xf1b2,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconChair = IconData(
  0xefed,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconBed = IconData(
  0xefdf,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconKitchen = IconData(
  0xeb47,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconConstruction = IconData(
  0xea3c,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconHandyman = IconData(
  0xf10b,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconKey = IconData(
  0xe73c,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconApartment = IconData(
  0xea40,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconPottedPlant = IconData(
  0xf8aa,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconLightbulb = IconData(
  0xe90f,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconShoppingCart = IconData(
  0xe8cc,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconStore = IconData(
  0xe8d1,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCheckroom = IconData(
  0xf19e,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconDiamond = IconData(
  0xead5,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconWatch = IconData(
  0xe334,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCardGiftcard = IconData(
  0xe8f6,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconLocalMall = IconData(
  0xe54c,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconShoppingBasket = IconData(
  0xe8cb,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconLocalFlorist = IconData(
  0xe545,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconMedication = IconData(
  0xf033,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconVaccines = IconData(
  0xe138,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconLocalHospital = IconData(
  0xe548,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconStethoscope = IconData(
  0xf805,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconContentCut = IconData(
  0xe14e,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconScience = IconData(
  0xea4b,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSportsSoccer = IconData(
  0xea2f,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSportsEsports = IconData(
  0xea28,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSportsTennis = IconData(
  0xea32,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconMovie = IconData(
  0xe684,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconMusicNote = IconData(
  0xe405,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconHeadphones = IconData(
  0xf01f,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconPhotoCamera = IconData(
  0xe412,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconPalette = IconData(
  0xe40a,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconConfirmationNumber = IconData(
  0xe638,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconTv = IconData(
  0xe63b,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCasino = IconData(
  0xeb40,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCelebration = IconData(
  0xea65,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconHotel = IconData(
  0xe549,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconBeachAccess = IconData(
  0xeb3e,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconLuggage = IconData(
  0xf235,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconHiking = IconData(
  0xe50a,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconTerrain = IconData(
  0xe564,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconMenuBook = IconData(
  0xea19,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconWork = IconData(
  0xe943,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconComputer = IconData(
  0xe31e,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSmartphone = IconData(
  0xe7ba,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconNewspaper = IconData(
  0xeb81,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconCurrencyExchange = IconData(
  0xeb70,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconAttachMoney = IconData(
  0xe227,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconWallet = IconData(
  0xf8ff,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconMonetizationOn = IconData(
  0xe263,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconPaid = IconData(
  0xf041,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconPets = IconData(
  0xe91d,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconChildCare = IconData(
  0xeb41,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconFavorite = IconData(
  0xe87e,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconGroups = IconData(
  0xf233,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconChurch = IconData(
  0xeaae,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconEco = IconData(
  0xea35,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconAgriculture = IconData(
  0xea79,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSmokingRooms = IconData(
  0xeb4b,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconUmbrella = IconData(
  0xf1ad,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconPark = IconData(
  0xea63,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconMail = IconData(
  0xe159,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconInventory2 = IconData(
  0xe1a1,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconStar = IconData(
  0xf09a,
  fontFamily: _fontFamily,
  fontPackage: _fontPackage,
);
const kIconSchedule = IconData(
  0xefd6,
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
/// Ghim ghi chú (v16). Codepoint xác nhận trong
/// `material_symbols_icons-4.2960.0/lib/symbols.dart` (`push_pin`), không
/// đoán — cùng kỷ luật với mọi icon khác ở file này.
const kIconPushPin = IconData(
  0xf10d,
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

/// `iconCode` lưu trong `categories.iconCode` → `IconData` Rounded.
/// Thứ tự = thứ tự hiện trong bộ chọn, xem [categoryIconGroups].
const Map<String, IconData> categoryIconByCode = {
  // Ăn uống
  'restaurant': kIconRestaurant,
  'fastfood': kIconFastfood,
  'ramen_dining': kIconRamenDining,
  'rice_bowl': kIconRiceBowl,
  'local_pizza': kIconLocalPizza,
  'bakery_dining': kIconBakeryDining,
  'set_meal': kIconSetMeal,
  'nutrition': kIconNutrition,
  'egg_alt': kIconEggAlt,
  'icecream': kIconIcecream,
  'cake': kIconCake,
  'local_cafe': kIconLocalCafe,
  'emoji_food_beverage': kIconEmojiFoodBeverage,
  'local_drink': kIconLocalDrink,
  'local_bar': kIconLocalBar,
  'sports_bar': kIconSportsBar,
  'wine_bar': kIconWineBar,
  // Đi lại
  'directions_car': kIconDirectionsCar,
  'two_wheeler': kIconTwoWheeler,
  'moped': kIconMoped,
  'pedal_bike': kIconPedalBike,
  'local_taxi': kIconLocalTaxi,
  'directions_bus': kIconDirectionsBus,
  'train': kIconTrain,
  'flight': kIconFlight,
  'directions_boat': kIconDirectionsBoat,
  'local_gas_station': kIconLocalGasStation,
  'local_shipping': kIconLocalShipping,
  // Nhà cửa & hoá đơn
  'home': kIconHome,
  'apartment': kIconApartment,
  'key': kIconKey,
  'chair': kIconChair,
  'bed': kIconBed,
  'kitchen': kIconKitchen,
  'bolt': kIconBolt,
  'water_drop': kIconWaterDrop,
  'wifi': kIconWifi,
  'cleaning_services': kIconCleaningServices,
  'soap': kIconSoap,
  'handyman': kIconHandyman,
  'construction': kIconConstruction,
  'potted_plant': kIconPottedPlant,
  'lightbulb': kIconLightbulb,
  // Mua sắm & đồ dùng
  'shopping_bag': kIconShoppingBag,
  'local_mall': kIconLocalMall,
  'shopping_cart': kIconShoppingCart,
  'shopping_basket': kIconShoppingBasket,
  'store': kIconStore,
  'checkroom': kIconCheckroom,
  'diamond': kIconDiamond,
  'watch': kIconWatch,
  'card_giftcard': kIconCardGiftcard,
  'local_florist': kIconLocalFlorist,
  'devices': kIconDevices,
  'smartphone': kIconSmartphone,
  'computer': kIconComputer,
  // Sức khoẻ & bản thân
  'health_and_safety': kIconHealthAndSafety,
  'local_hospital': kIconLocalHospital,
  'medication': kIconMedication,
  'vaccines': kIconVaccines,
  'stethoscope': kIconStethoscope,
  'spa': kIconSpa,
  'content_cut': kIconContentCut,
  'science': kIconScience,
  // Giải trí
  'theater_comedy': kIconTheaterComedy,
  'movie': kIconMovie,
  'tv': kIconTv,
  'music_note': kIconMusicNote,
  'headphones': kIconHeadphones,
  'sports_soccer': kIconSportsSoccer,
  'sports_tennis': kIconSportsTennis,
  'sports_esports': kIconSportsEsports,
  'casino': kIconCasino,
  'photo_camera': kIconPhotoCamera,
  'palette': kIconPalette,
  'confirmation_number': kIconConfirmationNumber,
  'celebration': kIconCelebration,
  // Du lịch
  'hotel': kIconHotel,
  'beach_access': kIconBeachAccess,
  'luggage': kIconLuggage,
  'hiking': kIconHiking,
  'terrain': kIconTerrain,
  'park': kIconPark,
  'umbrella': kIconUmbrella,
  // Học & làm
  'school': kIconSchool,
  'menu_book': kIconMenuBook,
  'work': kIconWork,
  'newspaper': kIconNewspaper,
  'mail': kIconMail,
  'inventory_2': kIconInventory2,
  // Tiền bạc
  'payments': kIconPayments,
  'savings': kIconSavings,
  'wallet': kIconWallet,
  'account_balance': kIconAccountBalance,
  'credit_card': kIconCreditCard,
  'monetization_on': kIconMonetizationOn,
  'attach_money': kIconAttachMoney,
  'paid': kIconPaid,
  'currency_exchange': kIconCurrencyExchange,
  'trending_up': kIconTrendingUp,
  'receipt_long': kIconReceiptLong,
  'handshake': kIconHandshake,
  // Gia đình & khác
  'family_restroom': kIconFamilyRestroom,
  'child_care': kIconChildCare,
  'pets': kIconPets,
  'favorite': kIconFavorite,
  'groups': kIconGroups,
  'church': kIconChurch,
  'eco': kIconEco,
  'agriculture': kIconAgriculture,
  'smoking_rooms': kIconSmokingRooms,
  'star': kIconStar,
  'schedule': kIconSchedule,
  'more_horiz': kIconMoreHoriz,
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
  // Ăn uống
  'restaurant': 'assets/icons3d/categories/restaurant.png',
  'fastfood': 'assets/icons3d/categories/fastfood.png',
  'ramen_dining': 'assets/icons3d/categories/ramen_dining.png',
  'rice_bowl': 'assets/icons3d/categories/rice_bowl.png',
  'local_pizza': 'assets/icons3d/categories/local_pizza.png',
  'bakery_dining': 'assets/icons3d/categories/bakery_dining.png',
  'set_meal': 'assets/icons3d/categories/set_meal.png',
  'nutrition': 'assets/icons3d/categories/nutrition.png',
  'egg_alt': 'assets/icons3d/categories/egg_alt.png',
  'icecream': 'assets/icons3d/categories/icecream.png',
  'cake': 'assets/icons3d/categories/cake.png',
  'local_cafe': 'assets/icons3d/categories/local_cafe.png',
  'emoji_food_beverage': 'assets/icons3d/categories/emoji_food_beverage.png',
  'local_drink': 'assets/icons3d/categories/local_drink.png',
  'local_bar': 'assets/icons3d/categories/local_bar.png',
  'sports_bar': 'assets/icons3d/categories/sports_bar.png',
  'wine_bar': 'assets/icons3d/categories/wine_bar.png',
  // Đi lại
  'directions_car': 'assets/icons3d/categories/directions_car.png',
  'two_wheeler': 'assets/icons3d/categories/two_wheeler.png',
  'moped': 'assets/icons3d/categories/moped.png',
  'pedal_bike': 'assets/icons3d/categories/pedal_bike.png',
  'local_taxi': 'assets/icons3d/categories/local_taxi.png',
  'directions_bus': 'assets/icons3d/categories/directions_bus.png',
  'train': 'assets/icons3d/categories/train.png',
  'flight': 'assets/icons3d/categories/flight.png',
  'directions_boat': 'assets/icons3d/categories/directions_boat.png',
  'local_gas_station': 'assets/icons3d/categories/local_gas_station.png',
  'local_shipping': 'assets/icons3d/categories/local_shipping.png',
  // Nhà cửa & hoá đơn
  'home': 'assets/icons3d/categories/home.png',
  'apartment': 'assets/icons3d/categories/apartment.png',
  'key': 'assets/icons3d/categories/key.png',
  'chair': 'assets/icons3d/categories/chair.png',
  'bed': 'assets/icons3d/categories/bed.png',
  'kitchen': 'assets/icons3d/categories/kitchen.png',
  'bolt': 'assets/icons3d/categories/bolt.png',
  'water_drop': 'assets/icons3d/categories/water_drop.png',
  'wifi': 'assets/icons3d/categories/wifi.png',
  'cleaning_services': 'assets/icons3d/categories/cleaning_services.png',
  'soap': 'assets/icons3d/categories/soap.png',
  'handyman': 'assets/icons3d/categories/handyman.png',
  'construction': 'assets/icons3d/categories/construction.png',
  'potted_plant': 'assets/icons3d/categories/potted_plant.png',
  'lightbulb': 'assets/icons3d/categories/lightbulb.png',
  // Mua sắm & đồ dùng
  'shopping_bag': 'assets/icons3d/categories/shopping_bag.png',
  'local_mall': 'assets/icons3d/categories/local_mall.png',
  'shopping_cart': 'assets/icons3d/categories/shopping_cart.png',
  'shopping_basket': 'assets/icons3d/categories/shopping_basket.png',
  'store': 'assets/icons3d/categories/store.png',
  'checkroom': 'assets/icons3d/categories/checkroom.png',
  'diamond': 'assets/icons3d/categories/diamond.png',
  'watch': 'assets/icons3d/categories/watch.png',
  'card_giftcard': 'assets/icons3d/categories/card_giftcard.png',
  'local_florist': 'assets/icons3d/categories/local_florist.png',
  'devices': 'assets/icons3d/categories/devices.png',
  'smartphone': 'assets/icons3d/categories/smartphone.png',
  'computer': 'assets/icons3d/categories/computer.png',
  // Sức khoẻ & bản thân
  'health_and_safety': 'assets/icons3d/categories/health_and_safety.png',
  'local_hospital': 'assets/icons3d/categories/local_hospital.png',
  'medication': 'assets/icons3d/categories/medication.png',
  'vaccines': 'assets/icons3d/categories/vaccines.png',
  'stethoscope': 'assets/icons3d/categories/stethoscope.png',
  'spa': 'assets/icons3d/categories/spa.png',
  'content_cut': 'assets/icons3d/categories/content_cut.png',
  'science': 'assets/icons3d/categories/science.png',
  // Giải trí
  'theater_comedy': 'assets/icons3d/categories/theater_comedy.png',
  'movie': 'assets/icons3d/categories/movie.png',
  'tv': 'assets/icons3d/categories/tv.png',
  'music_note': 'assets/icons3d/categories/music_note.png',
  'headphones': 'assets/icons3d/categories/headphones.png',
  'sports_soccer': 'assets/icons3d/categories/sports_soccer.png',
  'sports_tennis': 'assets/icons3d/categories/sports_tennis.png',
  'sports_esports': 'assets/icons3d/categories/sports_esports.png',
  'casino': 'assets/icons3d/categories/casino.png',
  'photo_camera': 'assets/icons3d/categories/photo_camera.png',
  'palette': 'assets/icons3d/categories/palette.png',
  'confirmation_number': 'assets/icons3d/categories/confirmation_number.png',
  'celebration': 'assets/icons3d/categories/celebration.png',
  // Du lịch
  'hotel': 'assets/icons3d/categories/hotel.png',
  'beach_access': 'assets/icons3d/categories/beach_access.png',
  'luggage': 'assets/icons3d/categories/luggage.png',
  'hiking': 'assets/icons3d/categories/hiking.png',
  'terrain': 'assets/icons3d/categories/terrain.png',
  'park': 'assets/icons3d/categories/park.png',
  'umbrella': 'assets/icons3d/categories/umbrella.png',
  // Học & làm
  'school': 'assets/icons3d/categories/school.png',
  'menu_book': 'assets/icons3d/categories/menu_book.png',
  'work': 'assets/icons3d/categories/work.png',
  'newspaper': 'assets/icons3d/categories/newspaper.png',
  'mail': 'assets/icons3d/categories/mail.png',
  'inventory_2': 'assets/icons3d/categories/inventory_2.png',
  // Tiền bạc
  'payments': 'assets/icons3d/categories/payments.png',
  'savings': 'assets/icons3d/categories/savings.png',
  'wallet': 'assets/icons3d/categories/wallet.png',
  'account_balance': 'assets/icons3d/categories/account_balance.png',
  'credit_card': 'assets/icons3d/categories/credit_card.png',
  'monetization_on': 'assets/icons3d/categories/monetization_on.png',
  'attach_money': 'assets/icons3d/categories/attach_money.png',
  'paid': 'assets/icons3d/categories/paid.png',
  'currency_exchange': 'assets/icons3d/categories/currency_exchange.png',
  'trending_up': 'assets/icons3d/categories/trending_up.png',
  'receipt_long': 'assets/icons3d/categories/receipt_long.png',
  'handshake': 'assets/icons3d/categories/handshake.png',
  // Gia đình & khác
  'family_restroom': 'assets/icons3d/categories/family_restroom.png',
  'child_care': 'assets/icons3d/categories/child_care.png',
  'pets': 'assets/icons3d/categories/pets.png',
  'favorite': 'assets/icons3d/categories/favorite.png',
  'groups': 'assets/icons3d/categories/groups.png',
  'church': 'assets/icons3d/categories/church.png',
  'eco': 'assets/icons3d/categories/eco.png',
  'agriculture': 'assets/icons3d/categories/agriculture.png',
  'smoking_rooms': 'assets/icons3d/categories/smoking_rooms.png',
  'star': 'assets/icons3d/categories/star.png',
  'schedule': 'assets/icons3d/categories/schedule.png',
  'more_horiz': 'assets/icons3d/categories/more_horiz.png',
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

/// Một NHÓM icon trong bộ chọn — nhãn tiếng Việt + các `iconCode` thuộc nhóm.
///
/// Có nhóm vì bộ icon đã lên 114 mã: một `Wrap` phẳng dài 13 hàng thì tìm
/// icon bằng cách lướt mắt qua cả bảng, còn chia nhóm thì nhảy thẳng tới
/// đúng chủ đề. Thuần dữ liệu (không `material.dart`) để giữ Luật #10.
class CategoryIconGroup {
  const CategoryIconGroup(this.label, this.codes);

  final String label;
  final List<String> codes;
}

/// Mọi mã trong [categoryIconByCode], chia nhóm theo chủ đề — bộ chọn icon
/// (`AppIconPicker`) vẽ theo đúng danh sách này.
const List<CategoryIconGroup> categoryIconGroups = [
  CategoryIconGroup('Ăn uống', [
    'restaurant',
    'fastfood',
    'ramen_dining',
    'rice_bowl',
    'local_pizza',
    'bakery_dining',
    'set_meal',
    'nutrition',
    'egg_alt',
    'icecream',
    'cake',
    'local_cafe',
    'emoji_food_beverage',
    'local_drink',
    'local_bar',
    'sports_bar',
    'wine_bar',
  ]),
  CategoryIconGroup('Đi lại', [
    'directions_car',
    'two_wheeler',
    'moped',
    'pedal_bike',
    'local_taxi',
    'directions_bus',
    'train',
    'flight',
    'directions_boat',
    'local_gas_station',
    'local_shipping',
  ]),
  CategoryIconGroup('Nhà cửa & hoá đơn', [
    'home',
    'apartment',
    'key',
    'chair',
    'bed',
    'kitchen',
    'bolt',
    'water_drop',
    'wifi',
    'cleaning_services',
    'soap',
    'handyman',
    'construction',
    'potted_plant',
    'lightbulb',
  ]),
  CategoryIconGroup('Mua sắm & đồ dùng', [
    'shopping_bag',
    'local_mall',
    'shopping_cart',
    'shopping_basket',
    'store',
    'checkroom',
    'diamond',
    'watch',
    'card_giftcard',
    'local_florist',
    'devices',
    'smartphone',
    'computer',
  ]),
  CategoryIconGroup('Sức khoẻ & bản thân', [
    'health_and_safety',
    'local_hospital',
    'medication',
    'vaccines',
    'stethoscope',
    'spa',
    'content_cut',
    'science',
  ]),
  CategoryIconGroup('Giải trí', [
    'theater_comedy',
    'movie',
    'tv',
    'music_note',
    'headphones',
    'sports_soccer',
    'sports_tennis',
    'sports_esports',
    'casino',
    'photo_camera',
    'palette',
    'confirmation_number',
    'celebration',
  ]),
  CategoryIconGroup('Du lịch', [
    'hotel',
    'beach_access',
    'luggage',
    'hiking',
    'terrain',
    'park',
    'umbrella',
  ]),
  CategoryIconGroup('Học & làm', [
    'school',
    'menu_book',
    'work',
    'newspaper',
    'mail',
    'inventory_2',
  ]),
  CategoryIconGroup('Tiền bạc', [
    'payments',
    'savings',
    'wallet',
    'account_balance',
    'credit_card',
    'monetization_on',
    'attach_money',
    'paid',
    'currency_exchange',
    'trending_up',
    'receipt_long',
    'handshake',
  ]),
  CategoryIconGroup('Gia đình & khác', [
    'family_restroom',
    'child_care',
    'pets',
    'favorite',
    'groups',
    'church',
    'eco',
    'agriculture',
    'smoking_rooms',
    'star',
    'schedule',
    'more_horiz',
  ]),
];
