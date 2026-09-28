import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';

/// Kết quả một lần mở máy quét tài liệu.
sealed class DocumentScanOutcome {
  const DocumentScanOutcome();
}

/// Quét xong — [imagePath] là JPEG đã cắt mép, nắn thẳng (file tạm trong
/// cache của app, do Play Services ghi ra).
final class DocumentScanned extends DocumentScanOutcome {
  const DocumentScanned(this.imagePath);
  final String imagePath;
}

/// Tony tự thoát máy quét — không làm gì cả, không báo lỗi.
final class DocumentScanCancelled extends DocumentScanOutcome {
  const DocumentScanCancelled();
}

/// Máy không mở được máy quét (Play Services thiếu/cũ, RAM < 1,7 GB, module
/// chưa tải được...) — lùi về camera thường.
final class DocumentScannerUnavailable extends DocumentScanOutcome {
  const DocumentScannerUnavailable();
}

/// Lấy ảnh hoá đơn: máy quét tài liệu ML Kit (đường chính) hoặc
/// `image_picker` (ảnh chụp màn hình, và dự phòng khi máy quét không chạy).
///
/// Interface để widget test lái được cả ba nhánh của luồng quét mà không
/// cần Play Services — cùng lý do các `*Platform` fake ở `test/support/`.
abstract interface class ReceiptCaptureService {
  Future<DocumentScanOutcome> scanDocument();

  /// Đường dẫn ảnh, hoặc `null` nếu Tony huỷ.
  Future<String?> pickImage({required bool fromCamera});
}

final receiptCaptureServiceProvider = Provider<ReceiptCaptureService>(
  (ref) => const MlKitReceiptCaptureService(),
);

class MlKitReceiptCaptureService implements ReceiptCaptureService {
  const MlKitReceiptCaptureService();

  /// Máy quét ML Kit (`google_mlkit_document_scanner` 0.6.1, CHỈ Android) —
  /// tự bắt khung khi thấy hoá đơn, dò mép, nắn thẳng, xoá bóng. Chạy qua
  /// Play Services nên app KHÔNG cần quyền camera, và không mạng.
  ///
  /// - `ScannerMode.full`: có cả lọc ảnh lẫn xoá bóng/vết bẩn — đúng thứ
  ///   giấy in nhiệt nhàu cần.
  /// - `pageLimit: 1`: một hoá đơn một giao dịch.
  /// - `isGalleryImport: true`: ảnh hoá đơn chụp sẵn vẫn được cắt/nắn.
  ///
  /// 🚨 Plugin báo HUỶ và báo LỖI bằng CÙNG một `PlatformException` (code
  /// `DocumentScanner`), chỉ khác message — đọc thẳng từ
  /// `DocumentScanner.kt` của plugin: `RESULT_CANCELED` → "Operation
  /// cancelled"; không mở được intent → "Failed to start document
  /// scanner". Phải phân biệt, nếu không Tony bấm thoát máy quét lại bị đẩy
  /// sang camera thường.
  @override
  Future<DocumentScanOutcome> scanDocument() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        mode: ScannerMode.full,
        pageLimit: 1,
        isGalleryImport: true,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      final path = result.images?.firstOrNull;
      return path == null
          ? const DocumentScanCancelled()
          : DocumentScanned(path);
    } on PlatformException catch (e) {
      return (e.message ?? '').toLowerCase().contains('cancel')
          ? const DocumentScanCancelled()
          : const DocumentScannerUnavailable();
    } on MissingPluginException {
      // Nền tảng không có plugin (iOS — máy quét ML Kit chưa có bản iOS).
      return const DocumentScannerUnavailable();
    } finally {
      // `close()` đi qua CÙNG kênh — ném ở đây (vd iOS không có plugin) sẽ
      // đè mất kết quả vừa trả ở trên. Dọn dẹp hỏng thì bỏ qua.
      try {
        await scanner.close();
      } on Object catch (_) {}
    }
  }

  @override
  Future<String?> pickImage({required bool fromCamera}) async {
    final picked = await ImagePicker().pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    return picked?.path;
  }
}
