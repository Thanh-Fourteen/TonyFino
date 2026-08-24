import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bootstrap.dart';
import 'core/lifecycle/app_lock_gate.dart';
import 'core/lifecycle/app_resume_hooks.dart';
import 'core/lifecycle/home_widget_sync_hook.dart';
import 'core/lifecycle/onboarding_gate.dart';
import 'core/router/app_router.dart';
import 'ui/amount_visibility.dart';
import 'features/settings/settings_controller.dart';
import 'theme/app_theme.dart';

void main() async {
  runApp(await bootstrap(const TonyFinoApp()));
}

class TonyFinoApp extends ConsumerWidget {
  const TonyFinoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    // `DynamicColorBuilder` (Phase 17) LUÔN bọc ngoài — hỏi hệ điều hành màu
    // động là rẻ (một platform channel call) và không đổi hình dạng cây
    // widget theo cờ bật/tắt (tránh mất state khi Tony bật/tắt tuỳ chọn ở
    // Settings). CHỈ truyền dynamicScheme vào `appTheme` khi
    // `settings.dynamicColorEnabled` — `null` giữ đúng hành vi cũ (bảng màu
    // tím cố định), đúng D9 "mặc định TẮT".
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = settings.dynamicColorEnabled ? lightDynamic : null;
        final darkScheme = settings.dynamicColorEnabled ? darkDynamic : null;
        return MaterialApp.router(
          title: 'TonyFino',
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light, dynamicScheme: lightScheme),
          darkTheme: appTheme(
            Brightness.dark,
            amoled: settings.amoled,
            dynamicScheme: darkScheme,
          ),
          themeMode: settings.themeMode,
          routerConfig: appRouter,
          builder: (context, child) => HomeWidgetSyncHook(
            child: AppResumeHooks(
              child: AppLockGate(
                // Bọc NGOÀI toàn bộ nội dung: mọi `MoneyText` ở bất kỳ màn
                // nào, kể cả trong bottom sheet/dialog (chúng dựng qua
                // `rootNavigator` nên vẫn nằm dưới lớp này), đều đọc được cờ
                // che số. Xem `AmountVisibility`.
                child: AmountVisibility(
                  hidden: settings.hideAmounts,
                  child: OnboardingGate(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          // l10n mặc định `vi` (D-bàn giao Phase 6) — không chỉ chữ CỦA app (đã
          // tiếng Việt cứng ở mọi màn), mà cả widget Material tích hợp sẵn
          // (DatePicker/TimePicker) đọc nhãn "Cancel"/"OK"/tên tháng qua
          // `MaterialLocalizations` — thiếu khai báo này thì chúng luôn ra
          // tiếng Anh bất kể `locale` hệ thống là gì.
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
