import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/notifications/recurring_reminder_service.dart';
import '../../features/settings/backup/backup_health_provider.dart';
import '../providers/database_providers.dart';

/// Chạy health-check backup (H6) + lên lịch lại nhắc giao dịch định kỳ mỗi
/// lần app resume — KHÔNG chỉ lúc khởi động lạnh. Đặt ở gốc cây widget (qua
/// `MaterialApp.router`'s `builder:`) để chạy độc lập với route hiện tại,
/// không cần nhét vào từng màn hình.
class AppResumeHooks extends ConsumerStatefulWidget {
  const AppResumeHooks({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppResumeHooks> createState() => _AppResumeHooksState();
}

class _AppResumeHooksState extends ConsumerState<AppResumeHooks>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runChecks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _runChecks();
  }

  void _runChecks() {
    unawaited(ref.read(backupHealthProvider.notifier).check());
    unawaited(_rescheduleReminders());
  }

  Future<void> _rescheduleReminders() async {
    final repo = ref.read(recurringTransactionRepositoryProvider);
    final active = await repo.watchActive().first;
    await RecurringReminderService().rescheduleAll(active);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
