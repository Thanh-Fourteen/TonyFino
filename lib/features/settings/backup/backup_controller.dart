import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/result/result.dart';
import '../../../core/time/clock_provider.dart';
import '../../../data/services/backup/android_saf_destination.dart';
import '../../../data/services/backup/auto_backup_worker.dart';
import '../../../data/services/backup/backup_service.dart';
import '../../../data/services/backup/share_sheet_destination.dart';

/// Kết quả một thao tác sao lưu/khôi phục vừa chạy — hiển thị TẠM THỜI trên
/// Settings (không phải trạng thái treo mãi mãi như health-check banner).
sealed class BackupActionResult {
  const BackupActionResult();
}

class BackupActionSuccess extends BackupActionResult {
  const BackupActionSuccess(this.message);
  final String message;
}

class BackupActionError extends BackupActionResult {
  const BackupActionError(this.message);
  final String message;
}

@immutable
class BackupUiState {
  const BackupUiState({
    required this.isWorking,
    required this.lastBackupAt,
    required this.autoBackupEnabled,
    this.lastResult,
  });

  static const initial = BackupUiState(
    isWorking: false,
    lastBackupAt: null,
    autoBackupEnabled: false,
  );

  final bool isWorking;
  final DateTime? lastBackupAt;
  final bool autoBackupEnabled;
  final BackupActionResult? lastResult;

  BackupUiState copyWith({
    bool? isWorking,
    DateTime? lastBackupAt,
    bool? autoBackupEnabled,
    BackupActionResult? lastResult,
    bool clearLastResult = false,
  }) {
    return BackupUiState(
      isWorking: isWorking ?? this.isWorking,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
    );
  }
}

/// Nút "Sao lưu ngay"/"Khôi phục" thủ công (Phase 12) — gọi thẳng
/// [BackupService] đã có từ Phase 4, đóng khoảng trống bị flag từ Phase
/// 9/10/11 (xem docs/decisions.md). Cũng là nơi bật/tắt cờ sao lưu tự động
/// (`AutoBackupScheduler`, đăng ký/huỷ task `workmanager` thật sự nằm ở đó —
/// controller này chỉ lưu cờ + gọi).
class BackupController extends Notifier<BackupUiState> {
  static const _lastBackupAtKey = 'tonyfino_last_backup_at';
  static const _autoBackupEnabledKey = 'tonyfino_auto_backup_enabled';

  final _prefs = SharedPreferencesAsync();

  @override
  BackupUiState build() {
    unawaited(_load());
    return BackupUiState.initial;
  }

  Future<void> _load() async {
    final iso = await _prefs.getString(_lastBackupAtKey);
    final autoEnabled = await _prefs.getBool(_autoBackupEnabledKey) ?? false;
    state = state.copyWith(
      lastBackupAt: iso == null ? null : DateTime.tryParse(iso),
      autoBackupEnabled: autoEnabled,
    );
  }

  BackupService get _backupService =>
      BackupService(ref.read(appDatabaseProvider));

  Future<void> backupNow() async {
    state = state.copyWith(isWorking: true, clearLastResult: true);
    try {
      final now = ref.read(clockProvider).now();
      final bytes = await _backupService.exportToJson(exportedAt: now);
      final destination = AndroidSafDestination();
      final result = await destination.write('tonyfino_backup.json', bytes);
      await result.when(
        ok: (_) async {
          await _prefs.setString(_lastBackupAtKey, now.toIso8601String());
          state = state.copyWith(
            isWorking: false,
            lastBackupAt: now,
            lastResult: const BackupActionSuccess('Đã sao lưu xong.'),
          );
        },
        err: (error) async {
          state = state.copyWith(
            isWorking: false,
            lastResult: BackupActionError(error.message),
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isWorking: false,
        lastResult: BackupActionError('Sao lưu thất bại: $e'),
      );
    }
  }

  /// Xuất qua share sheet — one-off, KHÔNG dùng cho auto-backup (xem
  /// `ShareSheetDestination`'s doc comment: không hỗ trợ đọc lại đích).
  Future<void> shareBackup() async {
    state = state.copyWith(isWorking: true, clearLastResult: true);
    try {
      final now = ref.read(clockProvider).now();
      final bytes = await _backupService.exportToJson(exportedAt: now);
      final result = await const ShareSheetDestination().write(
        'tonyfino_backup_${now.millisecondsSinceEpoch}.json',
        bytes,
      );
      state = state.copyWith(
        isWorking: false,
        lastResult: result.when(
          ok: (_) => const BackupActionSuccess('Đã chia sẻ file sao lưu.'),
          err: (error) => BackupActionError(error.message),
        ),
      );
    } catch (e) {
      state = state.copyWith(
        isWorking: false,
        lastResult: BackupActionError('Chia sẻ thất bại: $e'),
      );
    }
  }

  /// Chọn một file JSON backup bất kỳ (từ thư mục SAF hay từ share/CSV
  /// trước đó) rồi khôi phục — GHI ĐÈ toàn bộ 4 bảng (xem
  /// `BackupService.importFromJson`), không phải merge.
  Future<void> restoreFromFile() async {
    state = state.copyWith(isWorking: true, clearLastResult: true);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Chọn file backup TonyFino (.json)',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) {
        state = state.copyWith(isWorking: false);
        return;
      }
      final bytes = await file.readAsBytes();
      final result = await _backupService.importFromJson(bytes);
      state = state.copyWith(
        isWorking: false,
        lastResult: result.when(
          ok: (_) => const BackupActionSuccess('Đã khôi phục xong.'),
          err: (error) => BackupActionError(error.message),
        ),
      );
    } catch (e) {
      state = state.copyWith(
        isWorking: false,
        lastResult: BackupActionError('Không đọc được file: $e'),
      );
    }
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    if (enabled) {
      final destination = AndroidSafDestination();
      final granted = await destination.grantDirectory();
      if (granted.isErr) {
        state = state.copyWith(
          lastResult: BackupActionError(
            (granted as Err<String, AppError>).error.message,
          ),
        );
        return;
      }
      // Đăng ký NGAY khi bật, không đợi lần mở app sau: `bootstrap` có gọi
      // `initialize()` mỗi lần khởi động, nhưng nếu Tony bật rồi tắt máy
      // luôn thì suốt phiên đó chẳng có tác vụ nền nào tồn tại.
      await const AutoBackupScheduler().initialize();
    } else {
      await const AutoBackupScheduler().cancel();
    }
    await _prefs.setBool(_autoBackupEnabledKey, enabled);
    state = state.copyWith(autoBackupEnabled: enabled);
  }

  void dismissResult() => state = state.copyWith(clearLastResult: true);
}

final backupControllerProvider =
    NotifierProvider<BackupController, BackupUiState>(BackupController.new);
