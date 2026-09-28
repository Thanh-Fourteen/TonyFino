import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/tokens/palette.dart';

/// Lấy ảnh hoá đơn: chụp bằng camera hoặc chọn ảnh có sẵn (`image_picker`),
/// rồi XOAY/CẮT trên màn uCrop (`image_cropper`) trước khi OCR — luồng Tony
/// yêu cầu 2026-09-28: "cho chọn ảnh từ máy (chụp ảnh), cho phép xoay, crop
/// rồi mới vào OCR".
///
/// Interface để widget test lái được cả luồng mà không cần camera/thư viện
/// ảnh/màn cắt thật — cùng lý do các `*Platform` fake ở `test/support/`.
abstract interface class ReceiptCaptureService {
  /// Đường dẫn ảnh GỐC, hoặc `null` nếu Tony huỷ.
  Future<String?> pickImage({required bool fromCamera});

  /// Đường dẫn ảnh ĐÃ xoay/cắt, hoặc `null` nếu Tony thoát màn cắt.
  Future<String?> cropImage(String imagePath);
}

final receiptCaptureServiceProvider = Provider<ReceiptCaptureService>(
  (ref) => const DeviceReceiptCaptureService(),
);

class DeviceReceiptCaptureService implements ReceiptCaptureService {
  const DeviceReceiptCaptureService();

  /// Lấy ảnh ở độ phân giải GỐC (không `maxWidth`). Thu nhỏ trước khi cắt
  /// là phí chữ: hoá đơn thường chỉ chiếm một phần khung ảnh, thu cả khung
  /// về 1600px thì phần hoá đơn còn vài trăm px — dấu tiếng Việt vỡ trước
  /// tiên. Thu nhỏ để ở [cropImage], SAU khi đã cắt sát hoá đơn.
  @override
  Future<String?> pickImage({required bool fromCamera}) async {
    final picked = await ImagePicker().pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 95,
    );
    return picked?.path;
  }

  /// Màn cắt uCrop (`image_cropper` 12.2.1, uCrop 2.2.11 — đã hỗ trợ
  /// edge-to-edge của Android 15+): khung tự do (hoá đơn dài ngắn tuỳ quán),
  /// có lưới để căn thẳng dòng chữ, xoay tay từng độ ở thanh dưới.
  ///
  /// Đầu ra tối đa 1600×3200: đủ nét cho ML Kit trên hoá đơn đã cắt sát,
  /// và là ảnh đính kèm của giao dịch nên không để phình dung lượng sao lưu.
  @override
  Future<String?> cropImage(String imagePath) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: imagePath,
      maxWidth: 1600,
      maxHeight: 3200,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Xoay, cắt hoá đơn',
          // Petrol cho mảng lớn (thanh công cụ), cam chỉ ở điểm nhấn nhỏ
          // (nút xoay/tỉ lệ đang chọn) — đúng luật màu của app: cam giảm
          // sáng là NÂU, không dùng cam cho mảng lớn.
          toolbarColor: paletteBrickTextLight,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: paletteBrickLight,
          statusBarLight: false,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          showCropGrid: true,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.square,
          ],
        ),
      ],
    );
    return cropped?.path;
  }
}
