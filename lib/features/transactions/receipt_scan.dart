import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../../data/services/receipt_capture_service.dart';
import '../../data/services/receipt_ocr_service.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_bottom_sheet.dart';
import '../quick_add/domain/category_keyword_entries.dart';
import '../quick_add/domain/parser/category_matcher.dart';
import 'domain/receipt_ocr_parser.dart';
import 'transaction_form_sheet.dart';

/// Quét hoá đơn (Phase 18, làm lại 2026-09-28) — chụp/chọn ảnh → XOAY/CẮT
/// → OCR cục bộ (ML Kit, không mạng) → trích tổng, tên quán, ngày, TỪNG MÓN
/// → mở sheet Thêm với bảng món điền sẵn, CHỜ Tony duyệt (Luật #7 —
/// `TransactionFormPrefill.fromReceiptScan` không bao giờ tự ghi gì vào DB).
/// OCR lỗi/không trích được gì vẫn mở form (chỉ trống hơn), KHÔNG chặn Tony
/// tự gõ tay — một lần quét hỏng không đáng một thông báo lỗi.
///
/// Bước xoay/cắt là BẮT BUỘC, cho cả ảnh chụp lẫn ảnh có sẵn (Tony yêu cầu):
/// cắt sát hoá đơn bỏ được nền bàn/ngón tay/chữ của tờ khác lọt vào khung,
/// và xoay thẳng là điều kiện để `arrangeIntoRows` ghép đúng nhãn "Tổng" với
/// con số cùng hàng. Lối vào: dấu + cạnh ô nhập ở màn chat, và "Thêm nhanh" ở tab
/// Giao dịch.
///
/// (Bản đầu 2026-09-28 dùng máy quét tài liệu ML Kit — thay bằng luồng này
/// theo yêu cầu của Tony; xem docs/decisions.md § 2026-09-28 (3).)
Future<void> openReceiptScanFlow(BuildContext context, WidgetRef ref) async {
  final fromCamera = await showAppBottomSheet<bool>(
    context: context,
    isScrollControlled: false,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(sheetContext.space.md),
            child: Text('Quét hoá đơn', style: sheetContext.text.titleMedium),
          ),
          ListTile(
            leading: const Icon(kIconAddAPhoto),
            title: const Text('Chụp ảnh'),
            subtitle: const Text('Chụp hoá đơn giấy bằng camera'),
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
          ListTile(
            leading: const Icon(kIconImage),
            title: const Text('Chọn ảnh có sẵn'),
            subtitle: const Text(
              'Ảnh trong máy, hoá đơn điện tử, ảnh chuyển khoản',
            ),
            onTap: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    ),
  );
  if (fromCamera == null || !context.mounted) return;

  final capture = ref.read(receiptCaptureServiceProvider);
  final picked = await capture.pickImage(fromCamera: fromCamera);
  if (picked == null || !context.mounted) return;
  // Thoát màn cắt = bỏ lần quét này (Tony chủ động bấm quay lại) — không
  // tự OCR ảnh chưa cắt: ảnh đó chính là thứ Tony vừa từ chối.
  final cropped = await capture.cropImage(picked);
  if (cropped == null || !context.mounted) return;
  await _recognizeAndOpenForm(context, ref, cropped);
}

Future<void> _recognizeAndOpenForm(
  BuildContext context,
  WidgetRef ref,
  String imagePath,
) async {
  // `XFile` (cross_file, qua image_picker) — đọc file mà không `dart:io`
  // trong `lib/features/` (luật iOS-portable, `tool/check_arch.sh`).
  final bytes = await XFile(imagePath).readAsBytes();
  final imageExtension = _extensionFromPath(imagePath);
  if (!context.mounted) return;

  final ocr = ref.read(receiptOcrServiceProvider);
  final now = ref.read(clockProvider).now();
  final closeScanningDialog = _showScanningDialog(context);
  var extraction = const ReceiptOcrExtraction();
  try {
    final text = await ocr.recognizeText(imagePath);
    extraction = extractReceiptInfo(text, now: now);
  } catch (_) {
    // OCR hỏng (ảnh mờ, model chưa tải xong lần đầu...) — coi như không
    // trích được gì, KHÔNG chặn luồng, xem doc comment đầu file.
  } finally {
    closeScanningDialog();
  }
  final lines = extraction.items.isEmpty
      ? const <TransactionFormPrefillLine>[]
      : _buildReceiptLines(extraction, await _expenseCategoryMatcher(ref));
  if (!context.mounted) return;

  // Có bảng món thì tổng mặc định là số "phải trả" đọc được, không có thì
  // tổng các món — Tony sửa tay được, và form có nút "Đặt tổng = tổng các
  // dòng" khi hai số lệch nhau.
  final itemsSum = lines.fold<int>(0, (s, l) => s + (l.amountMinor ?? 0));
  await showTransactionFormSheet(
    context: context,
    prefill: TransactionFormPrefill.fromReceiptScan(
      amountMinor: extraction.amountMinor ?? (itemsSum > 0 ? itemsSum : null),
      merchantName: extraction.merchantName,
      occurredAt: extraction.occurredAt,
      lines: lines,
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

/// Bảng món điền sẵn: mỗi món một dòng, danh mục gợi ý theo tên món; món
/// không khớp từ khoá nào nhận DANH MỤC CHUNG của hoá đơn (xem
/// [receiptFallbackCategory], lùi tiếp về tên quán) — đúng phương án Tony
/// chọn 2026-09-28.
///
/// Tổng hoá đơn LỚN HƠN tổng các món (VAT, phí dịch vụ in riêng) và mọi món
/// đều đã có tiền → thêm một dòng "Thuế, phí, khác" bằng phần chênh, để các
/// dòng cộng khớp tổng ngay mà không ai phải tính nhẩm. NHỎ HƠN (voucher,
/// giảm giá) thì KHÔNG bịa ra dòng âm — dòng tổng trong form tô đỏ và có nút
/// "Đặt tổng = …", Tony tự quyết. Còn món chưa có tiền thì phần chênh chính
/// là tiền của các món đó, cũng không thêm.
List<TransactionFormPrefillLine> _buildReceiptLines(
  ReceiptOcrExtraction extraction,
  int? Function(String name) suggestCategory,
) {
  final suggested = [
    for (final item in extraction.items) suggestCategory(item.name),
  ];
  final billCategory =
      receiptFallbackCategory(suggested) ??
      switch (extraction.merchantName) {
        final merchant? => suggestCategory(merchant),
        null => null,
      };
  final lines = [
    for (final (i, item) in extraction.items.indexed)
      TransactionFormPrefillLine(
        label: item.name,
        amountMinor: item.amountMinor,
        categoryId: suggested[i] ?? billCategory,
      ),
  ];
  final total = extraction.amountMinor;
  final allPriced = lines.every((l) => l.amountMinor != null);
  final sum = lines.fold<int>(0, (s, l) => s + (l.amountMinor ?? 0));
  if (total != null && allPriced && total > sum) {
    lines.add(
      TransactionFormPrefillLine(
        label: 'Thuế, phí, khác',
        amountMinor: total - sum,
      ),
    );
  }
  return lines;
}

/// Bộ gợi ý danh mục cho tên món — CÙNG bộ khớp từ khoá của màn chat
/// (`matchCategory`, cái đang hiểu "cà phê 35k"), giới hạn trong danh mục
/// CHI (hoá đơn mua hàng không bao giờ là khoản thu).
///
/// Đọc thẳng qua repository (`.first` của stream drift), KHÔNG qua
/// `categoryKeywordEntriesProvider`: StreamProvider của Riverpod 3 tạm dừng
/// khi không ai `watch` — đọc nó từ một luồng rời như thế này từng trả về
/// danh sách rỗng im lặng (docs/decisions.md § Phase 8).
Future<int? Function(String name)> _expenseCategoryMatcher(
  WidgetRef ref,
) async {
  final repo = ref.read(categoryRepositoryProvider);
  final categories = await repo.watchActive().first;
  final keywordRows = await repo.watchAllKeywords().first;
  final expenseKeys = {
    for (final c in categories)
      if (c.kind == 'expense') c.id.toString(),
  };
  final entries = [
    for (final e in buildCategoryKeywordEntries(
      categories: categories,
      keywordRows: keywordRows,
    ))
      if (expenseKeys.contains(e.categoryKey)) e,
  ];
  return (String name) => switch (matchCategory(name, entries)) {
    final match? => int.tryParse(match.categoryKey),
    null => null,
  };
}

/// Danh mục chung của một hoá đơn: danh mục được khớp NHIỀU món nhất (hoà
/// thì danh mục gặp trước). Một bữa nhà hàng khớp được "Cải bó xôi" và
/// "Buffet đồ uống" vào Ăn uống thì "Khoai môn", "Mực nút" cũng là Ăn uống,
/// không phải để trống bắt Tony chọn tay từng dòng. `null` khi không món
/// nào khớp.
@visibleForTesting
int? receiptFallbackCategory(List<int?> suggested) {
  final counts = <int, int>{};
  int? best;
  for (final id in suggested) {
    if (id == null) continue;
    final count = counts.update(id, (c) => c + 1, ifAbsent: () => 1);
    if (best == null || count > counts[best]!) best = id;
  }
  return best;
}
