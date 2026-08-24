import 'dart:typed_data';

import '../../../core/result/result.dart';

/// Nơi backup thực sự được ghi. Tách khỏi [BackupService] có chủ đích: logic
/// export/import (JSON, wipe, insert) là thuần và test được trên host; CÁCH
/// bytes đi ra ngoài (SAF, share sheet, sau này là thư mục Documents trên
/// iOS) là chi tiết nền tảng, chỉ test được trên thiết bị thật.
///
/// `IosDocumentsDestination` CỐ Ý CHƯA implement ở Phase 4 — chỉ ghi thẳng
/// bytes bằng `dart:io` vào thư mục Documents (không cần SAF, không cần
/// platform channel), nên hình dạng interface này đã đủ cho nó sau này.
abstract interface class BackupDestination {
  /// Tên hiển thị cho người dùng chọn giữa các đích (vd. "Thư mục đã cấp
  /// quyền", "Chia sẻ qua ứng dụng khác").
  String get displayName;

  /// Ghi [bytes] với tên [fileName]. Trả về mô tả nơi đã ghi khi thành công
  /// (không phải path tuyệt đối — SAF/share sheet không luôn có path thật).
  Future<Result<String, AppError>> write(String fileName, Uint8List bytes);
}
