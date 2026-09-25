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
import '../../../data/services/backup/backup_encryption.dart';
import '../../../data/services/backup/backup_service.dart';
import '../../../data/services/backup/google_drive_destination.dart';
import '../../../data/services/backup/share_sheet_destination.dart';
import '../../../data/services/google/google_account.dart';
import '../../../data/services/google/google_providers.dart';

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
    this.googleAccount,
    this.lastDriveBackupAt,
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

  /// Tài khoản Google đang đăng nhập — `null` nghĩa là chưa đăng nhập.
  final GoogleAccount? googleAccount;
  final DateTime? lastDriveBackupAt;

  BackupUiState copyWith({
    bool? isWorking,
    DateTime? lastBackupAt,
    bool? autoBackupEnabled,
    BackupActionResult? lastResult,
    bool clearLastResult = false,
    GoogleAccount? googleAccount,
    bool clearGoogleAccount = false,
    DateTime? lastDriveBackupAt,
  }) {
    return BackupUiState(
      isWorking: isWorking ?? this.isWorking,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      googleAccount: clearGoogleAccount
          ? null
          : (googleAccount ?? this.googleAccount),
      lastDriveBackupAt: lastDriveBackupAt ?? this.lastDriveBackupAt,
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
  static const _lastDriveBackupAtKey = 'tonyfino_last_drive_backup_at';

  final _prefs = SharedPreferencesAsync();

  @override
  BackupUiState build() {
    unawaited(_load());
    unawaited(_initGoogle());
    return BackupUiState.initial;
  }

  Future<void> _load() async {
    final iso = await _prefs.getString(_lastBackupAtKey);
    final autoEnabled = await _prefs.getBool(_autoBackupEnabledKey) ?? false;
    final driveIso = await _prefs.getString(_lastDriveBackupAtKey);
    state = state.copyWith(
      lastBackupAt: iso == null ? null : DateTime.tryParse(iso),
      autoBackupEnabled: autoEnabled,
      lastDriveBackupAt: driveIso == null ? null : DateTime.tryParse(driveIso),
    );
  }

  /// Khôi phục phiên Google đã đăng nhập trước đó (nếu có) mà không hiện
  /// UI nào, rồi tiếp tục lắng nghe đăng nhập/đăng xuất suốt vòng đời app.
  ///
  /// Nuốt lỗi có chủ đích: máy không có Google Play Services (hoặc trong
  /// `flutter_test`, không có platform channel thật — `GoogleSignInPlatform`
  /// ném `UnimplementedError`) thì coi như CHƯA đăng nhập, không phá luôn cả
  /// màn Cài đặt vì một tính năng phụ. Bấm "Đăng nhập Google" sau đó vẫn thử
  /// lại được, lỗi thật sự hiện qua `lastResult` như mọi thao tác khác.
  Future<void> _initGoogle() async {
    try {
      final signIn = ref.read(googleSignInServiceProvider);
      await signIn.initialize();
      signIn.accountChanges.listen((account) {
        state = state.copyWith(
          googleAccount: account,
          clearGoogleAccount: account == null,
        );
      });
    } catch (_) {
      // Xem doc comment ở trên — im lặng là đúng ý ở đây.
    }
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

  Future<void> signInWithGoogle() async {
    final result = await ref.read(googleSignInServiceProvider).signIn();
    state = state.copyWith(
      googleAccount: result.valueOrNull,
      lastResult: result.when(
        ok: (account) => BackupActionSuccess('Đã đăng nhập ${account.email}.'),
        err: (error) => BackupActionError(error.message),
      ),
    );
  }

  Future<void> signOutGoogle() async {
    await ref.read(googleSignInServiceProvider).signOut();
    state = state.copyWith(clearGoogleAccount: true);
  }

  /// [passphrase] do người dùng tự đặt — KHÔNG lưu ở đâu cả, quên là mất
  /// vĩnh viễn bản backup này (xem `BackupEncryption`). Mã hoá xong mới gửi
  /// lên `appDataFolder`, Drive chỉ thấy bytes đã mã hoá.
  Future<void> backupToDrive(String passphrase) async {
    state = state.copyWith(isWorking: true, clearLastResult: true);
    try {
      final now = ref.read(clockProvider).now();
      final bytes = await _backupService.exportToJson(exportedAt: now);
      final encrypted = await const BackupEncryption().encrypt(
        bytes,
        passphrase,
      );
      final destination = GoogleDriveDestination(
        ref.read(googleSignInServiceProvider),
      );
      final result = await destination.write('tonyfino_backup.enc', encrypted);
      await result.when(
        ok: (_) async {
          await _prefs.setString(
            _lastDriveBackupAtKey,
            now.toIso8601String(),
          );
          state = state.copyWith(
            isWorking: false,
            lastDriveBackupAt: now,
            lastResult: const BackupActionSuccess(
              'Đã sao lưu lên Google Drive.',
            ),
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
        lastResult: BackupActionError('Sao lưu lên Drive thất bại: $e'),
      );
    }
  }

  /// [passphrase] phải khớp mật khẩu lúc [backupToDrive] — sai mật khẩu trả
  /// lỗi rõ ràng (`BackupEncryption.decrypt`), KHÔNG ghi đè dữ liệu hiện có
  /// bằng rác giải mã sai.
  Future<void> restoreFromDrive(String passphrase) async {
    state = state.copyWith(isWorking: true, clearLastResult: true);
    try {
      final destination = GoogleDriveDestination(
        ref.read(googleSignInServiceProvider),
      );
      final downloadResult = await destination.downloadLatest();
      await downloadResult.when(
        ok: (bytes) async {
          if (bytes == null) {
            state = state.copyWith(
              isWorking: false,
              lastResult: const BackupActionError(
                'Chưa có bản sao lưu nào trên Google Drive.',
              ),
            );
            return;
          }
          final decryptResult = await const BackupEncryption().decrypt(
            bytes,
            passphrase,
          );
          await decryptResult.when(
            ok: (plain) async {
              final importResult = await _backupService.importFromJson(plain);
              state = state.copyWith(
                isWorking: false,
                lastResult: importResult.when(
                  ok: (_) =>
                      const BackupActionSuccess('Đã khôi phục từ Google Drive.'),
                  err: (error) => BackupActionError(error.message),
                ),
              );
            },
            err: (error) async {
              state = state.copyWith(
                isWorking: false,
                lastResult: BackupActionError(error.message),
              );
            },
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
        lastResult: BackupActionError('Khôi phục từ Drive thất bại: $e'),
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
