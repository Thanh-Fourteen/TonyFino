import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/transaction_repository.dart';
import '../../data/services/home_widget/spending_widget_service.dart';
import '../../features/transactions/transactions_providers.dart';
import '../time/clock_provider.dart';

/// Đẩy "Chi tiêu từ đầu tháng" sang widget màn hình chính (Phase 21) mỗi khi
/// [monthSummaryProvider] phát giá trị mới — TÁI DÙNG nguyên query đang chạy
/// hero card (Phase 6), không tính lại bằng logic riêng.
///
/// `ref.listenManual` trong `initState`, KHÔNG PHẢI `ref.watch` trong
/// `Notifier.build()` — đã đọc source `flutter_riverpod-3.4.2` trước khi
/// viết (luật nghiên cứu chung của dự án): `WidgetRef.listen` (dùng được
/// trong `build()`) ở bản 3.4.2 KHÔNG có tham số `fireImmediately`; chỉ
/// `listenManual` (dành riêng cho `initState`/`State` lifecycle) mới có, và
/// cần nó để đồng bộ widget ngay khi app mở, không chỉ khi có giao dịch mới.
class HomeWidgetSyncHook extends ConsumerStatefulWidget {
  const HomeWidgetSyncHook({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeWidgetSyncHook> createState() => _HomeWidgetSyncHookState();
}

class _HomeWidgetSyncHookState extends ConsumerState<HomeWidgetSyncHook> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<MonthSummary>>(monthSummaryProvider, (
      previous,
      next,
    ) {
      final summary = next.value;
      if (summary == null) return;
      unawaited(
        const SpendingWidgetService().sync(
          summary,
          updatedAt: ref.read(clockProvider).now(),
        ),
      );
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
