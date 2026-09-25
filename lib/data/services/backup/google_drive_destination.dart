import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;

import '../../../core/result/result.dart';
import '../google/google_sign_in_service.dart';
import 'backup_destination.dart';

/// Ghi/đọc backup vào `appDataFolder` của Drive — khu vực ẩn, riêng của
/// TỪNG app trên TÀI KHOẢN GOOGLE của người dùng, không hiện trong giao diện
/// Drive thường, app khác không đọc được. Chỉ giữ ĐÚNG MỘT file (ghi đè bản
/// cũ) — đây là "bản sao lưu mới nhất", không phải kho lưu nhiều phiên bản.
///
/// `bytes` truyền vào đây PHẢI đã được mã hoá từ trước (xem
/// `BackupEncryption`) — lớp này không biết và không cần biết nội dung là gì.
class GoogleDriveDestination implements BackupDestination {
  const GoogleDriveDestination(this._signIn);

  final GoogleSignInService _signIn;

  static const _fileName = 'tonyfino_backup.enc';

  @override
  String get displayName => 'Google Drive';

  @override
  Future<Result<String, AppError>> write(
    String fileName,
    Uint8List bytes,
  ) async {
    final clientResult = await _signIn.authorizedDriveClient();
    return clientResult.when(
      ok: (client) async {
        try {
          final api = drive.DriveApi(client);
          final existingId = await _findExistingFileId(api);
          final media = drive.Media(
            Stream.value(bytes),
            bytes.length,
          );
          if (existingId != null) {
            await api.files.update(
              drive.File(),
              existingId,
              uploadMedia: media,
            );
          } else {
            await api.files.create(
              drive.File(name: _fileName, parents: const ['appDataFolder']),
              uploadMedia: media,
            );
          }
          return const Result.ok('Google Drive (khu vực riêng của app)');
        } catch (e) {
          return Result.err(
            AppError('Sao lưu lên Google Drive thất bại: $e', cause: e),
          );
        } finally {
          client.close();
        }
      },
      err: (e) async => Result.err(e),
    );
  }

  /// `null` nghĩa là chưa có bản sao lưu nào trên Drive — KHÔNG phải lỗi,
  /// đây là trạng thái bình thường của người dùng lần đầu bật tính năng này.
  Future<Result<Uint8List?, AppError>> downloadLatest() async {
    final clientResult = await _signIn.authorizedDriveClient();
    return clientResult.when(
      ok: (client) async {
        try {
          final api = drive.DriveApi(client);
          final existingId = await _findExistingFileId(api);
          if (existingId == null) return const Result.ok(null);
          final media =
              await api.files.get(
                    existingId,
                    downloadOptions: drive.DownloadOptions.fullMedia,
                  )
                  as drive.Media;
          final builder = BytesBuilder();
          await for (final chunk in media.stream) {
            builder.add(chunk);
          }
          return Result.ok(builder.toBytes());
        } catch (e) {
          return Result.err(
            AppError('Tải bản sao lưu từ Google Drive thất bại: $e', cause: e),
          );
        } finally {
          client.close();
        }
      },
      err: (e) async => Result.err(e),
    );
  }

  Future<String?> _findExistingFileId(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_fileName'",
      $fields: 'files(id)',
    );
    final files = list.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }
}
