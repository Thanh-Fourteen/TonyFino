import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/services/backup/android_saf_destination.dart';

@immutable
class BackupHealthState {
  const BackupHealthState({required this.healthy, required this.hasChecked});

  /// `null` = chưa từng chấm dứt một lần chấm dứt hoàn chỉnh (chưa cấp thư
  /// mục, hoặc app vừa mở lần đầu chưa kịp check) — KHÔNG hiện banner cho
  /// trường hợp này, banner chỉ hiện khi CHẮC CHẮN hỏng (`healthy == false`).
  final bool? healthy;
  final bool hasChecked;

  static const initial = BackupHealthState(healthy: null, hasChecked: false);
}

/// Tách riêng khỏi [AndroidSafDestination] thật để test giả lập "grant bị
/// thu hồi"/"ghi lại được" mà không cần platform channel SAF thật (xem
/// TODOS.md Phase 12 § Xác minh: "giả lập đích backup bị thu hồi quyền").
final backupHealthProbeProvider = Provider<Future<bool> Function()>(
  (ref) => AndroidSafDestination().probeHealth,
);

/// Health-check H6 (TODOS.md) — ghi/đọc file thăm dò mỗi lần app resume.
/// Banner CỐ ĐỊNH không tự tắt cho tới khi một lần check tiếp theo thành
/// công (Tony bấm "Kiểm tra lại" sau khi tự khắc phục, hoặc bấm "Sao lưu
/// ngay" thành công — cả hai đường đều gọi lại [check]).
class BackupHealthController extends Notifier<BackupHealthState> {
  static const _everGrantedKey = 'tonyfino_auto_backup_enabled';
  final _prefs = SharedPreferencesAsync();

  @override
  BackupHealthState build() => BackupHealthState.initial;

  Future<void> check() async {
    // Chưa từng bật sao lưu tự động/cấp thư mục thì không có gì để probe —
    // KHÔNG coi đây là "hỏng", vì chưa từng có gì để hỏng.
    final everEnabled = await _prefs.getBool(_everGrantedKey) ?? false;
    if (!everEnabled) {
      state = const BackupHealthState(healthy: null, hasChecked: true);
      return;
    }
    final ok = await ref.read(backupHealthProbeProvider)();
    state = BackupHealthState(healthy: ok, hasChecked: true);
  }
}

final backupHealthProvider =
    NotifierProvider<BackupHealthController, BackupHealthState>(
      BackupHealthController.new,
    );
