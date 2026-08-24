import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../../../core/result/result.dart';
import 'backup_destination.dart';

/// Xuất backup qua share sheet của hệ điều hành — người dùng tự chọn lưu vào
/// đâu (Drive, Files, gửi qua Zalo, …) mỗi lần. Không có khái niệm "đích cố
/// định" nên KHÔNG hỗ trợ đọc lại — chỉ dùng cho export thủ công/one-off,
/// không phải đích của auto-backup (đó là [AndroidSafDestination]).
///
/// `share_plus` 13 đã bỏ API tĩnh `Share.shareXFiles()` — gần như mọi ví dụ
/// còn trên mạng vẫn dùng bản cũ. API hiện tại: `SharePlus.instance.share(ShareParams(...))`.
class ShareSheetDestination implements BackupDestination {
  const ShareSheetDestination();

  @override
  String get displayName => 'Chia sẻ qua ứng dụng khác';

  @override
  Future<Result<String, AppError>> write(
    String fileName,
    Uint8List bytes,
  ) async {
    try {
      final file = XFile.fromData(
        bytes,
        mimeType: 'application/json',
        name: fileName,
      );
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [fileName],
          subject: 'Backup TonyFino',
        ),
      );
      if (result.status == ShareResultStatus.dismissed) {
        return const Err(AppError('Đã huỷ chia sẻ backup.'));
      }
      return Ok(displayName);
    } catch (e) {
      return Err(AppError('Không mở được share sheet.', cause: e));
    }
  }
}
