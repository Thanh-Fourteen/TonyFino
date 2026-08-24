import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/receipt_ocr_service.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_bottom_sheet.dart';
import 'domain/receipt_ocr_parser.dart';
import 'transaction_form_sheet.dart';

const _receiptOcr = ReceiptOcrService();

/// Quét hoá đơn (Phase 18) — chụp/chọn ảnh → OCR cục bộ (ML Kit, không mạng)
/// → trích số tiền/merchant → mở sheet Thêm điền sẵn, CHỜ Tony xác nhận
/// (Luật #7 — `TransactionFormPrefill.fromReceiptScan` không bao giờ tự ghi
/// gì vào DB). OCR lỗi/không trích được gì vẫn mở form (chỉ trống hơn),
/// KHÔNG chặn Tony tự gõ tay — một lần quét hỏng không đáng một thông báo
/// lỗi, chỉ đáng một form trống như mọi lần "Thêm" bình thường.
Future<void> openReceiptScanFlow(BuildContext context, WidgetRef ref) async {
  final source = await showAppBottomSheet<ImageSource>(
    context: context,
    isScrollControlled: false,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(kIconAddAPhoto),
            title: const Text('Chụp hoá đơn'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(kIconImage),
            title: const Text('Chọn ảnh có sẵn'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (picked == null || !context.mounted) return;

  final bytes = await picked.readAsBytes();
  final imageExtension = _extensionFromPath(picked.path);
  if (!context.mounted) return;

  final closeScanningDialog = _showScanningDialog(context);
  var extraction = const ReceiptOcrExtraction();
  try {
    final text = await _receiptOcr.recognizeText(picked.path);
    extraction = extractReceiptInfo(text);
  } catch (_) {
    // OCR hỏng (ảnh mờ, model chưa tải xong lần đầu...) — coi như không
    // trích được gì, KHÔNG chặn luồng, xem doc comment đầu hàm.
  } finally {
    closeScanningDialog();
  }
  if (!context.mounted) return;

  await showTransactionFormSheet(
    context: context,
    prefill: TransactionFormPrefill.fromReceiptScan(
      amountMinor: extraction.amountMinor,
      merchantName: extraction.merchantName,
      receiptImageBytes: bytes,
      receiptImageExtension: imageExtension,
    ),
  );
}

String _extensionFromPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot == -1 || dot == path.length - 1) return 'jpg';
  return path.substring(dot + 1).toLowerCase();
}

/// Hộp thoại "Đang đọc hoá đơn…" không tắt tay được (OCR cục bộ chỉ mất
/// ~1-2 giây trên thiết bị thật) — trả về hàm đóng nó lại.
VoidCallback _showScanningDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: dialogContext.space.md),
          const Text('Đang đọc hoá đơn…'),
        ],
      ),
    ),
  );
  var closed = false;
  return () {
    if (closed) return;
    closed = true;
    Navigator.of(context, rootNavigator: true).pop();
  };
}
