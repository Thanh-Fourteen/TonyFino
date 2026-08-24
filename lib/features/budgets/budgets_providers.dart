import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../settings/settings_controller.dart';
import 'domain/budget_period.dart';
import 'domain/budget_progress.dart';

/// Kỳ đang xem trên màn Ngân sách — Notifier THUẦN UI STATE: `build()` chỉ
/// đọc `Clock.now()` + `AppSettings.budgetAnchorDay` MỘT LẦN, KHÔNG
/// `ref.watch` bất kỳ `StreamProvider`/`Notifier` nào (an toàn trước bẫy
/// huỷ-và-tái-tạo notifier, xem [[project_tonyfino_gotchas]] § Phase 9 —
/// cùng cấu trúc `ReportFilterController` ở Phase 10). Hệ quả: đổi
/// `budgetAnchorDay` ở Settings KHÔNG tự động đẩy lại kỳ đang xem ở màn
/// Ngân sách nếu nó đã mở sẵn — `SettingsScreen` tự gọi `goToCurrent()`
/// ngay sau khi đổi để bù, xem `settings_screen.dart`.
class BudgetPeriodController extends Notifier<BudgetPeriod> {
  @override
  BudgetPeriod build() => BudgetPeriod.of(
    ref.read(clockProvider).now(),
    anchorDay: ref.read(appSettingsProvider).budgetAnchorDay,
  );

  void goToPrevious() => state = state.previous;
  void goToNext() => state = state.next;
  void goToCurrent() => state = BudgetPeriod.of(
    ref.read(clockProvider).now(),
    anchorDay: ref.read(appSettingsProvider).budgetAnchorDay,
  );
}

final budgetPeriodProvider =
    NotifierProvider<BudgetPeriodController, BudgetPeriod>(
      BudgetPeriodController.new,
    );

/// `ref.watch(budgetPeriodProvider)` bên trong một `StreamProvider` (không
/// phải trong `build()` của một `Notifier` giữ state tích luỹ) — đúng chỗ an
/// toàn để watch, giống `categoryBreakdownProvider` ở Phase 10.
final budgetProgressProvider = StreamProvider<List<BudgetProgress>>((ref) {
  final period = ref.watch(budgetPeriodProvider);
  return ref.watch(budgetRepositoryProvider).watchBudgetsForPeriod(period);
});

/// Số "An toàn để tiêu hôm nay" (Phase 15) — LUÔN tính cho kỳ HIỆN TẠI thật
/// (qua `Clock.now()`), KHÔNG phụ thuộc `budgetPeriodProvider` (Tony có thể
/// đang lướt xem một kỳ quá khứ/tương lai ở màn Ngân sách bằng nút
/// trước/sau — số này vẫn phải luôn nói về "hôm nay").
final safeToSpendTodayProvider = StreamProvider((ref) {
  final now = ref.watch(clockProvider).now();
  final anchorDay = ref.watch(appSettingsProvider).budgetAnchorDay;
  return ref
      .watch(safeToSpendRepositoryProvider)
      .watchSafeToSpendToday(now, anchorDay: anchorDay);
});
