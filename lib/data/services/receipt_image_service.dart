import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Ảnh hoá đơn đính kèm giao dịch (Phase 17) — CHỈ giữ file, không OCR/phân
/// tích (Phase 18 riêng). Lưu ở thư mục con `receipts/` bên trong thư mục
/// app riêng (`getApplicationDocumentsDirectory()`), cùng nguyên tắc
/// `PathService`: `transactions.receiptImageFilename` chỉ lưu TÊN FILE
/// (Luật #5), thư mục gốc luôn resolve lại mỗi lần gọi thay vì tin cache —
/// thư mục gốc CÓ THỂ đổi giữa các lần cài trên cùng máy.
class ReceiptImageService {
  const ReceiptImageService();

  Future<Directory> _receiptsDir() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(documentsDir.path, 'receipts'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Ghi [bytes] thành một file MỚI, trả về TÊN FILE (không phải đường dẫn)
  /// để lưu vào `transactions.receiptImageFilename`. [now] do tầng gọi
  /// truyền vào (từ `Clock` inject, Luật #3) — service không tự đọc giờ hệ
  /// thống; ghép thêm một số ngẫu nhiên để hai lần lưu trong CÙNG mili giây
  /// (về lý thuyết) vẫn không trùng tên file.
  Future<String> saveImage(
    Uint8List bytes, {
    required DateTime now,
    required String extension,
  }) async {
    final fileName =
        'receipt_${now.millisecondsSinceEpoch}_${Random().nextInt(1000000)}.$extension';
    final dir = await _receiptsDir();
    await File(p.join(dir.path, fileName)).writeAsBytes(bytes);
    return fileName;
  }

  /// Ghi [bytes] với ĐÚNG tên file đã cho (không tự sinh) — dùng riêng cho
  /// khôi phục backup (Phase 17): file khôi phục lại phải trùng khớp tên đã
  /// lưu trong `transactions.receiptImageFilename` của chính bản backup đó,
  /// không phải một tên mới. [saveImage] (tự sinh tên) là cho lúc người
  /// dùng đính kèm ảnh MỚI qua form, hai việc khác nhau nên tách hai hàm.
  Future<void> writeImageWithFilename(String fileName, Uint8List bytes) async {
    final dir = await _receiptsDir();
    await File(p.join(dir.path, fileName)).writeAsBytes(bytes);
  }

  Future<String> resolvePath(String fileName) async {
    final dir = await _receiptsDir();
    return p.join(dir.path, fileName);
  }

  /// `null` nếu file không còn tồn tại (vd đã bị xoá thủ công ngoài app) —
  /// call site tự quyết định hiển thị gì (không throw, ảnh thiếu không phải
  /// lỗi nghiêm trọng của một giao dịch tài chính).
  Future<Uint8List?> readImage(String fileName) async {
    final file = File(await resolvePath(fileName));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// Không lỗi nếu file đã không còn tồn tại — xoá là một thao tác "đảm bảo
  /// vắng mặt", không phải "phải có trước khi xoá".
  Future<void> deleteImage(String fileName) async {
    final file = File(await resolvePath(fileName));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
