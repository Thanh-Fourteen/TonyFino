import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sáng / Tối / Theo hệ thống + toggle Đen tuyền (AMOLED) — cả hai chỉ ảnh
/// hưởng `darkTheme` (AMOLED không có ý nghĩa ở light mode).
/// Các khối có thể bật/tắt ở Trang chủ.
///
/// Tên (`name`) là thứ được LƯU XUỐNG prefs — đổi tên một giá trị là mất
/// lựa chọn của người dùng, thêm giá trị mới thì an toàn.
enum HomeSection {
  budgets('Hạn mức', 'Tiến độ từng danh mục trong kỳ'),
  jars('Hũ chia thu nhập', 'Tỉ lệ chia mỗi khoản thu'),
  goals('Quỹ & mục tiêu', 'Tiến độ tiết kiệm có đích'),
  chart('Biểu đồ chi theo danh mục', 'Vòng tròn tỉ trọng chi trong kỳ'),
  recent('Giao dịch gần đây', 'Vài khoản ghi gần nhất');

  const HomeSection(this.label, this.description);
  final String label;
  final String description;
}

@immutable
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.amoled,
    required this.biometricLockEnabled,
    required this.budgetAnchorDay,
    required this.dynamicColorEnabled,
    required this.hasSeenOnboarding,
    required this.cloudFallbackEnabled,
    required this.cloudFallbackConsentAsked,
    required this.aiFallbackBaseUrl,
    required this.homeSections,
    required this.hideAmounts,
  });

  final ThemeMode themeMode;
  final bool amoled;

  /// Những khối Tony muốn thấy ở Trang chủ. Chứa các giá trị của
  /// [HomeSection]; thiếu một giá trị = khối đó ẩn.
  ///
  /// Lưu dạng TẬP HỢP CÁC KHOÁ ĐANG BẬT chứ không phải một chuỗi cờ theo vị
  /// trí: thêm khối mới sau này chỉ là thêm một giá trị enum, không phá được
  /// lựa chọn cũ đã lưu.
  final Set<HomeSection> homeSections;

  /// Che mọi số tiền bằng `•••` cho tới khi bấm con mắt (Phase 26 — Tony:
  /// "các số tiền khi show khá nhạy cảm"). CHỈ là lớp che thị giác, không
  /// phải bảo mật: khoá thật là khoá vân tay + mã hoá DB.
  final bool hideAmounts;

  /// Dynamic color Material You (Phase 17) — opt-in, mặc định TẮT (D9): bảng
  /// màu danh mục/thu-chi cố định phải giữ nguyên để biểu đồ đọc được, bật
  /// cờ này chỉ đổi `primary`/các vai trò `surface` trung tính của
  /// `ColorScheme` chuẩn — xem `appTheme`'s `dynamicScheme` param.
  final bool dynamicColorEnabled;

  /// Khoá vân tay/khuôn mặt/mã khoá thiết bị khi mở app (Phase 12) — CHỈ có
  /// ý nghĩa nếu `BiometricService.isSupported()` cũng true; Settings tự ẩn/
  /// tắt toggle nếu máy không hỗ trợ, không dựa riêng vào cờ này.
  final bool biometricLockEnabled;

  /// Ngày trong tháng bắt đầu một kỳ ngân sách mới (Phase 15, "kỳ theo ngày
  /// lương") — 1–31, mặc định `1` (đầu tháng lịch, hành vi Phase 11). Áp
  /// dụng TOÀN APP, không theo từng ngân sách/danh mục — xem
  /// docs/decisions.md § Phase 15 "Kỳ ngân sách theo ngày neo" cho lý do vì
  /// sao đây là một tuỳ chọn `shared_preferences`, không phải cột DB.
  final int budgetAnchorDay;

  /// Đã xem màn chào mừng lần đầu chưa (Phase 22) — `false` mặc định trên
  /// bản cài mới; app cũ nâng cấp lên cũng đọc `false` (key chưa từng tồn
  /// tại trong prefs), nhưng `OnboardingGate` chỉ hiện màn chào khi ĐỒNG THỜI
  /// chưa có giao dịch nào — người dùng cũ nâng cấp lên có dữ liệu thật thì
  /// không bao giờ thấy lại.
  final bool hasSeenOnboarding;

  /// Cloud AI fallback (Phase 23, D8) — mặc định TẮT. Chỉ bao giờ được gọi
  /// khi parser cục bộ không chắc (`amount == null` hoặc `!confident`, xem
  /// `aiParseFallbackProvider`) — bật cờ này KHÔNG nghĩa là mọi câu đều qua
  /// mạng, chỉ mở khả năng cho ~10% câu mơ hồ.
  final bool cloudFallbackEnabled;

  /// Đã hỏi Tony ít nhất một lần chưa (qua sheet đồng ý tự bật lần đầu gặp
  /// câu mơ hồ, HOẶC qua bật/tắt tay ở Cài đặt) — `true` ngăn sheet bật lại
  /// đè lên một lựa chọn đã tường minh, kể cả khi lựa chọn đó là "không".
  final bool cloudFallbackConsentAsked;

  /// Địa chỉ proxy AI trên tailnet — cấu hình được để đổi sang Cloudflare
  /// Worker sau này là cắm-vào-là-chạy (D8), không cần build lại app.
  final String aiFallbackBaseUrl;

  static const defaultAiFallbackBaseUrl =
      'https://tony.tailfcdcfc.ts.net/tonyfino-ai/';

  static final initial = AppSettings(
    themeMode: ThemeMode.system,
    amoled: false,
    biometricLockEnabled: false,
    budgetAnchorDay: 1,
    dynamicColorEnabled: false,
    hasSeenOnboarding: false,
    cloudFallbackEnabled: false,
    cloudFallbackConsentAsked: false,
    aiFallbackBaseUrl: defaultAiFallbackBaseUrl,
    homeSections: {...HomeSection.values},
    hideAmounts: true,
  );

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? amoled,
    bool? biometricLockEnabled,
    int? budgetAnchorDay,
    bool? dynamicColorEnabled,
    bool? hasSeenOnboarding,
    bool? cloudFallbackEnabled,
    bool? cloudFallbackConsentAsked,
    String? aiFallbackBaseUrl,
    Set<HomeSection>? homeSections,
    bool? hideAmounts,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      amoled: amoled ?? this.amoled,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      budgetAnchorDay: budgetAnchorDay ?? this.budgetAnchorDay,
      dynamicColorEnabled: dynamicColorEnabled ?? this.dynamicColorEnabled,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      cloudFallbackEnabled: cloudFallbackEnabled ?? this.cloudFallbackEnabled,
      cloudFallbackConsentAsked:
          cloudFallbackConsentAsked ?? this.cloudFallbackConsentAsked,
      aiFallbackBaseUrl: aiFallbackBaseUrl ?? this.aiFallbackBaseUrl,
      homeSections: homeSections ?? this.homeSections,
      hideAmounts: hideAmounts ?? this.hideAmounts,
    );
  }
}

/// Lưu bằng `shared_preferences` — không phải bí mật (khác khoá mã hoá DB ở
/// `flutter_secure_storage`, Phase 4), chỉ là tuỳ chọn hiển thị.
class AppSettingsController extends Notifier<AppSettings> {
  static const _themeModeKey = 'tonyfino_theme_mode';
  static const _amoledKey = 'tonyfino_amoled';
  static const _biometricLockKey = 'tonyfino_biometric_lock_enabled';
  static const _budgetAnchorDayKey = 'tonyfino_budget_anchor_day';
  static const _dynamicColorKey = 'tonyfino_dynamic_color_enabled';
  static const _hasSeenOnboardingKey = 'tonyfino_has_seen_onboarding';
  static const _cloudFallbackEnabledKey = 'tonyfino_cloud_fallback_enabled';
  static const _cloudFallbackConsentAskedKey =
      'tonyfino_cloud_fallback_consent_asked';
  static const _aiFallbackBaseUrlKey = 'tonyfino_ai_fallback_base_url';
  static const _homeSectionsKey = 'tonyfino_home_sections';
  static const _hideAmountsKey = 'tonyfino_hide_amounts';

  /// 🚨 KHỞI TẠO LƯỜI, có bọc try/catch — KHÔNG khởi tạo ở field.
  ///
  /// `SharedPreferencesAsync()` ném ngay trong CONSTRUCTOR khi chưa có
  /// platform binding ("The SharedPreferencesAsyncPlatform instance must be
  /// set") — tức là trong mọi widget test. Khởi tạo ở field nghĩa là cả
  /// `AppSettingsController` rơi vào trạng thái lỗi, và MỌI provider
  /// `ref.watch` nó cũng lỗi theo: `homePeriodProvider` lỗi →
  /// `filteredTransactionsProvider` lỗi → màn Giao dịch không dựng được gì
  /// cả, kể cả thẻ hero lẫn EmptyState. Đúng cái đã xảy ra khi tab Giao
  /// dịch bắt đầu lọc theo kỳ.
  ///
  /// `null` = không có nơi lưu (chỉ xảy ra trong test): app vẫn chạy bằng
  /// [AppSettings.initial], chỉ là không nhớ được giữa các lần mở.
  SharedPreferencesAsync? _prefsOrNull;
  bool _prefsTried = false;

  SharedPreferencesAsync? get _prefs {
    if (_prefsTried) return _prefsOrNull;
    _prefsTried = true;
    try {
      _prefsOrNull = SharedPreferencesAsync();
    } on Object {
      _prefsOrNull = null;
    }
    return _prefsOrNull;
  }

  @override
  AppSettings build() {
    // build() phải đồng bộ — đọc prefs bất đồng bộ rồi cập nhật state khi
    // xong. Một khung hình dùng giá trị mặc định trước khi prefs tải xong
    // là đánh đổi chấp nhận được, không đáng để chặn khởi động app vì nó.
    unawaited(_load());
    return AppSettings.initial;
  }

  Future<void> _load() async {
    final themeModeName = await _prefs?.getString(_themeModeKey);
    final amoled = await _prefs?.getBool(_amoledKey) ?? false;
    final biometricLockEnabled =
        await _prefs?.getBool(_biometricLockKey) ?? false;
    final budgetAnchorDay = await _prefs?.getInt(_budgetAnchorDayKey) ?? 1;
    final dynamicColorEnabled =
        await _prefs?.getBool(_dynamicColorKey) ?? false;
    final hasSeenOnboarding =
        await _prefs?.getBool(_hasSeenOnboardingKey) ?? false;
    final cloudFallbackEnabled =
        await _prefs?.getBool(_cloudFallbackEnabledKey) ?? false;
    final cloudFallbackConsentAsked =
        await _prefs?.getBool(_cloudFallbackConsentAskedKey) ?? false;
    final aiFallbackBaseUrl =
        await _prefs?.getString(_aiFallbackBaseUrlKey) ??
        AppSettings.defaultAiFallbackBaseUrl;
    // Mặc định BẬT che (Tony: "để default là mắt ẩn"). Số dư là thứ đầu
    // tiên đập vào mắt khi mở app ở nơi công cộng — mặc định an toàn thì
    // phải là che, còn hiện ra là một chạm.
    final hideAmounts = await _prefs?.getBool(_hideAmountsKey) ?? true;
    // Chưa từng lưu (`null`) = BẬT HẾT, khác hẳn với đã lưu một danh sách
    // RỖNG (người dùng cố ý tắt hết). Dùng `?? tất cả` cho cả hai ca là ép
    // mọi khối hiện lại mỗi lần mở app dù Tony đã tắt.
    final savedSections = await _prefs?.getStringList(_homeSectionsKey);
    final homeSections = savedSections == null
        ? {...HomeSection.values}
        : {
            for (final name in savedSections)
              for (final section in HomeSection.values)
                if (section.name == name) section,
          };
    final themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == themeModeName,
      orElse: () => ThemeMode.system,
    );
    state = AppSettings(
      themeMode: themeMode,
      amoled: amoled,
      biometricLockEnabled: biometricLockEnabled,
      budgetAnchorDay: budgetAnchorDay,
      dynamicColorEnabled: dynamicColorEnabled,
      hasSeenOnboarding: hasSeenOnboarding,
      cloudFallbackEnabled: cloudFallbackEnabled,
      homeSections: homeSections,
      hideAmounts: hideAmounts,
      cloudFallbackConsentAsked: cloudFallbackConsentAsked,
      aiFallbackBaseUrl: aiFallbackBaseUrl,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs?.setString(_themeModeKey, mode.name);
  }

  Future<void> setAmoled(bool value) async {
    state = state.copyWith(amoled: value);
    await _prefs?.setBool(_amoledKey, value);
  }

  Future<void> setBiometricLockEnabled(bool value) async {
    state = state.copyWith(biometricLockEnabled: value);
    await _prefs?.setBool(_biometricLockKey, value);
  }

  Future<void> setHomeSectionEnabled(HomeSection section, bool enabled) async {
    final next = {...state.homeSections};
    if (enabled) {
      next.add(section);
    } else {
      next.remove(section);
    }
    state = state.copyWith(homeSections: next);
    await _prefs?.setStringList(
      _homeSectionsKey,
      // Ghi theo THỨ TỰ enum, không theo thứ tự bấm — để giá trị lưu xuống
      // ổn định, dễ đọc khi soi prefs lúc gỡ lỗi.
      [
        for (final s in HomeSection.values)
          if (next.contains(s)) s.name,
      ],
    );
  }

  Future<void> setHideAmounts(bool value) async {
    state = state.copyWith(hideAmounts: value);
    await _prefs?.setBool(_hideAmountsKey, value);
  }

  Future<void> setBudgetAnchorDay(int day) async {
    state = state.copyWith(budgetAnchorDay: day);
    await _prefs?.setInt(_budgetAnchorDayKey, day);
  }

  Future<void> setDynamicColorEnabled(bool value) async {
    state = state.copyWith(dynamicColorEnabled: value);
    await _prefs?.setBool(_dynamicColorKey, value);
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    state = state.copyWith(hasSeenOnboarding: value);
    await _prefs?.setBool(_hasSeenOnboardingKey, value);
  }

  /// Luôn đánh dấu ĐÃ HỎI cùng lúc — dù bật hay tắt, đây là một lựa chọn
  /// tường minh (qua sheet đồng ý HOẶC bật/tắt tay ở Cài đặt), sheet không
  /// bao giờ bật lại đè lên sau khi hàm này chạy.
  Future<void> setCloudFallbackEnabled(bool value) async {
    state = state.copyWith(
      cloudFallbackEnabled: value,
      cloudFallbackConsentAsked: true,
    );
    await _prefs?.setBool(_cloudFallbackEnabledKey, value);
    await _prefs?.setBool(_cloudFallbackConsentAskedKey, true);
  }

  /// Từ chối ở sheet đồng ý: giữ `cloudFallbackEnabled = false`, chỉ đánh
  /// dấu đã hỏi để sheet không bật lại ở câu mơ hồ tiếp theo.
  Future<void> markCloudFallbackConsentDeclined() async {
    state = state.copyWith(cloudFallbackConsentAsked: true);
    await _prefs?.setBool(_cloudFallbackConsentAskedKey, true);
  }

  Future<void> setAiFallbackBaseUrl(String value) async {
    state = state.copyWith(aiFallbackBaseUrl: value);
    await _prefs?.setString(_aiFallbackBaseUrlKey, value);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
