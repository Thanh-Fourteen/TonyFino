import 'dart:convert';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:clock/clock.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/result/result.dart';
import 'backup_destination.dart';

/// Ghi backup vào một thư mục do người dùng cấp quyền một lần qua Storage
/// Access Framework, rồi ghi lặp lại KHÔNG cần hỏi lại — sống sót qua reboot.
///
/// H6 (đã xác minh bằng cách đọc thẳng source `android_file_picker` 1.0.1):
/// `file_picker.getDirectoryPath()` mặc định KHÔNG gọi
/// `takePersistableUriPermission()` — chỉ gọi khi truyền
/// `AndroidSAFOptions(grant: lifetime, persistGrant: true)`. Không truyền là
/// grant chết âm thầm sau reboot, người dùng tưởng có backup mà không có.
///
/// Persistable grant không tự cho phép ghi file mới vào cây thư mục đó —
/// `dart:io File` không hiểu URI `content://`. Cần MethodChannel nhỏ gọi
/// `DocumentFile`/`ContentResolver` phía Kotlin (`android/.../SafBackupChannel.kt`,
/// ~50 dòng) — đây là nửa "platform channel Kotlin" của quyết định nghiên cứu
/// trước, thay vì kéo thêm một package `saf` ngoài không rõ độ bảo trì.
class AndroidSafDestination implements BackupDestination {
  AndroidSafDestination({FlutterSecureStorage? storage, Clock? clock})
    : _storage = storage ?? const FlutterSecureStorage(),
      _clock = clock ?? const Clock();

  static const _channel = MethodChannel('dev.tony.tonyfino/saf');
  static const _treeUriKey = 'tonyfino_saf_backup_tree_uri';

  final FlutterSecureStorage _storage;
  final Clock _clock;

  @override
  String get displayName => 'Thư mục đã cấp quyền';

  /// Mở hộp thoại chọn thư mục, xin grant lifetime + đọc-ghi, lưu URI cây đã
  /// cấp. Gọi một lần lúc setup (hoặc lại khi health-check thấy grant chết).
  Future<Result<String, AppError>> grantDirectory() async {
    try {
      final uri = await FilePicker.getDirectoryPath(
        dialogTitle: 'Chọn thư mục lưu backup TonyFino',
        androidOptions: FilePickerAndroidOptions(
          safOptions: AndroidSAFOptions(
            grant: AndroidSAFGrant.lifetime,
            accessMode: AndroidSAFAccessMode.readWrite,
            persistGrant: true,
          ),
        ),
      );
      if (uri == null) {
        // 🚨 Nói RÕ vì sao, đừng chỉ nói "chưa chọn".
        //
        // Bộ chọn thư mục của Android mở ở nơi truy cập gần nhất — máy mới
        // thì đó là GỐC bộ nhớ, và Android TỪ CHỐI cho cấp quyền cả gốc
        // ("Can't use this folder. To protect your privacy, choose another
        // folder"). Nút "USE THIS FOLDER" xám ngoét, người dùng bấm mãi
        // không được rồi bỏ cuộc — đúng thứ Tony gặp khi bật sao lưu tự
        // động. Không ép được vị trí mở từ Dart: gói `android_file_picker`
        // 1.0.1 KHÔNG đặt `EXTRA_INITIAL_URI` cho nhánh chọn-thư-mục (đã
        // đọc `FileUtils.startFileExplorer`), nên thứ duy nhất làm được là
        // nói cho người dùng biết phải làm gì.
        return const Err(
          AppError(
            'Chưa chọn được thư mục. Android không cho chọn thư mục GỐC — '
            'hãy mở vào một thư mục con (vd Documents hoặc Download), hoặc '
            'bấm "Tạo thư mục mới", rồi mới bấm "Dùng thư mục này".',
          ),
        );
      }
      // GIỮ quyền lâu dài NGAY, khi grant còn sống trong tiến trình này.
      // Không giữ thì mọi thứ vẫn chạy cho tới khi đóng app, rồi im lặng
      // chết — xem `SafBackupChannel."takePersistable"`.
      final persisted = await _channel.invokeMethod<bool>('takePersistable', {
        'treeUri': uri,
      });
      if (persisted != true) {
        return const Err(
          AppError(
            'Android không giữ được quyền vào thư mục này. Hãy chọn lại một '
            'thư mục con trong bộ nhớ máy (vd Documents).',
          ),
        );
      }
      await _storage.write(key: _treeUriKey, value: uri);
      return Ok(uri);
    } catch (e) {
      return Err(AppError('Không cấp được quyền thư mục.', cause: e));
    }
  }

  /// H6: xác nhận grant vẫn còn hiệu lực — gọi mỗi lần app resume (Phase 12).
  Future<bool> isGrantValid() async {
    final treeUri = await _storage.read(key: _treeUriKey);
    if (treeUri == null) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isGrantValid', {
        'treeUri': treeUri,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Có thư mục đã cấp quyền chưa — dùng để QUYẾT ĐỊNH TRƯỚC khi gọi [write]
  /// từ ngữ cảnh KHÔNG có UI (tác vụ nền `workmanager`): `write()` tự mở hộp
  /// thoại chọn thư mục nếu chưa có, điều không thể làm khi không có
  /// Activity foreground nào đang hiển thị.
  Future<bool> hasGrantedDirectory() async {
    return await _storage.read(key: _treeUriKey) != null;
  }

  /// 🚨 KHÔNG mở đầu bằng dấu chấm, và PHẢI có đuôi khớp `mimeType`.
  ///
  /// Tên cũ là `.tonyfino_health_probe` (ẩn, không đuôi). SAF tự chuẩn hoá
  /// tên hiển thị theo mimeType khi tạo document — `text/plain` không đuôi
  /// thì provider gắn thêm `.txt`, nên đọc lại theo ĐÚNG tên cũ luôn trượt
  /// và health-check báo hỏng vĩnh viễn. Banner đỏ "Sao lưu tự động đang
  /// hỏng" hiện ngay cả khi vừa sao lưu thành công — đúng thứ Tony thấy.
  static const _healthProbeFileName = 'tonyfino_health_probe.txt';

  /// H6 đầy đủ: `isGrantValid()` chỉ xác nhận quyền URI còn persisted, KHÔNG
  /// xác nhận thư mục đích còn ghi/đọc được thật (Tony có thể đã xoá tay thư
  /// mục đó trong Files app mà quyền URI vẫn còn "hợp lệ" theo hệ thống).
  /// Ghi một file thăm dò nhỏ với payload ngẫu nhiên theo thời điểm gọi, đọc
  /// lại NGAY, so khớp byte — round-trip thật, không suy luận từ trạng thái
  /// quyền. Trả `false` cho MỌI kiểu hỏng (chưa cấp quyền, grant chết, ghi
  /// lỗi, đọc lỗi, hoặc đọc ra khác payload vừa ghi).
  Future<bool> probeHealth() async {
    final treeUri = await _storage.read(key: _treeUriKey);
    if (treeUri == null) return false;
    if (!await isGrantValid()) return false;

    final payload = Uint8List.fromList(
      utf8.encode('tonyfino-health-${_clock.now().microsecondsSinceEpoch}'),
    );
    try {
      await _channel.invokeMethod<String>('writeFile', {
        'treeUri': treeUri,
        'fileName': _healthProbeFileName,
        'mimeType': 'text/plain',
        'bytes': payload,
      });
      final readBack = await _channel.invokeMethod<Uint8List>('readFile', {
        'treeUri': treeUri,
        'fileName': _healthProbeFileName,
      });
      final ok = readBack != null && _bytesEqual(readBack, payload);
      if (!ok) {
        debugPrint(
          'TONYFINO probeHealth: đọc lại KHÔNG khớp '
          '(readBack=${readBack?.length} bytes, payload=${payload.length})',
        );
      }
      return ok;
    } on PlatformException catch (e) {
      // 🚨 KHÔNG nuốt lặng.
      //
      // `return false` trần biến mọi hỏng hóc thành một banner đỏ vô nghĩa
      // ("Sao lưu tự động đang hỏng") mà không ai biết hỏng ở đâu — Tony
      // báo lỗi này ba lần và mỗi lần tôi phải mò lại từ đầu.
      debugPrint(
        'TONYFINO probeHealth PlatformException: ${e.code} ${e.message}',
      );
      return false;
    }
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<Result<String, AppError>> write(
    String fileName,
    Uint8List bytes,
  ) async {
    var treeUri = await _storage.read(key: _treeUriKey);
    if (treeUri == null) {
      final granted = await grantDirectory();
      if (granted.isErr) {
        return Err((granted as Err<String, AppError>).error);
      }
      treeUri = (granted as Ok<String, AppError>).value;
    }

    try {
      final documentUri = await _channel.invokeMethod<String>('writeFile', {
        'treeUri': treeUri,
        'fileName': fileName,
        'mimeType': 'application/json',
        'bytes': bytes,
      });
      return Ok(documentUri ?? treeUri);
    } on PlatformException catch (e) {
      return Err(
        AppError(
          'Không ghi được file backup vào thư mục đã cấp quyền.',
          cause: e,
        ),
      );
    }
  }
}
