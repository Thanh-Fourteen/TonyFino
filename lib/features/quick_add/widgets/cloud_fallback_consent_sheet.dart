import 'package:flutter/material.dart';

import '../../../theme/context_ext.dart';
import '../../../ui/app_bottom_sheet.dart';

/// Sheet đồng ý MỘT LẦN cho cloud AI fallback (Phase 23, D8) — tự bật lần
/// đầu một thẻ trong phiên hiện tại cần fallback (`amount == null` hoặc
/// `!confident`) VÀ Tony chưa từng được hỏi. Trả `true` = đồng ý bật,
/// `false`/`null` (đóng bằng vuốt xuống/nút back) = coi như từ chối — cả hai
/// đều đánh dấu "đã hỏi" ở tầng gọi, sheet không bật lại lần sau.
Future<bool?> showCloudFallbackConsentSheet(BuildContext context) {
  return showAppBottomSheet<bool>(
    context: context,
    builder: (context) => Padding(
      padding: EdgeInsets.all(context.space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Câu này hơi khó đoán', style: context.text.titleMedium),
          SizedBox(height: context.space.sm),
          Text(
            'TonyFino có thể gửi câu này (chỉ câu này, không kèm dữ liệu tài '
            'chính khác) cho một AI để đoán chính xác hơn — chạy qua máy chủ '
            'riêng của Tony, dùng khoá trả phí (không bị dùng để huấn luyện '
            'mô hình). Mặc định tắt, có thể bật/tắt lại bất cứ lúc nào ở Cài '
            'đặt.',
            style: context.text.bodyMedium,
          ),
          SizedBox(height: context.space.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Không dùng'),
                ),
              ),
              SizedBox(width: context.space.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Bật trợ lý AI'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
