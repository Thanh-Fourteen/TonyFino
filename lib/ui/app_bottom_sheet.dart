import 'package:flutter/material.dart';

import '../theme/context_ext.dart';

/// Mở bottom sheet đúng chuẩn design system: bo góc `xxl` ở 2 góc trên,
/// `elevation: 0` (tự vẽ `BoxShadow` bậc 2 qua `bottomSheetTheme`), thời
/// lượng trồi lên 320ms (`AppDurations.sheet`, animation #4 trong ngân sách
/// 5 animation cứng). **Bottom-sheet-first**: chọn danh mục, chọn ngày, chi
/// tiết giao dịch, bộ lọc — mọi hành động chính nằm ở 1/3 dưới màn hình.
///
/// `useRootNavigator: true` là BẮT BUỘC, không phải tuỳ chọn — `go_router`'s
/// `StatefulShellRoute` dựng một `Navigator` RIÊNG cho mỗi nhánh (tab), sống
/// bên trong `body:` của `AppShell`'s `Scaffold` ngoài. Nếu push sheet vào
/// Navigator nhánh (mặc định `Navigator.of(context)` sẽ tìm cái GẦN NHẤT),
/// sheet chỉ vẽ trong layer `body` — cùng layer với nội dung cuộn — nên
/// `AppShell`'s `bottomNavigationBar` nổi (`GlassSurface`, vốn được Scaffold
/// NGOÀI cố ý vẽ ĐÈ LÊN body để cho phép cuộn xuyên qua, xem `extendBody`)
/// đè luôn lên PHẦN DƯỚI của sheet — kể cả khi sheet còn thừa chỗ. Nút
/// Lưu/Xoá lúc đó "biến mất" dù cây widget vẫn đúng và
/// `flutter analyze`/widget test sạch — chỉ ảnh chụp thiết bị thật (hoặc
/// emulator) mới lộ ra layer nào thực sự đè lên layer nào. `rootNavigator:
/// true` đẩy sheet lên `Overlay` gốc, phía TRÊN toàn bộ `AppShell`, đúng chỗ
/// một bottom sheet modal phải đứng.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final controller = AnimationController(
    duration: context.durations.sheet,
    reverseDuration: context.durations.sheet,
    vsync: rootNavigator,
  );
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    transitionAnimationController: controller,
    builder: (sheetContext) {
      final shadows = sheetContext.shadows;
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: shadows.level2TopHighlight, width: 1),
          ),
        ),
        // Chiều cao tối đa tường minh — không bắt buộc để sửa bug layer ở
        // trên, nhưng vẫn giữ để form dài (12 chip danh mục) cuộn được thay
        // vì tràn ra ngoài trên máy màn hình thấp.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.92,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: builder(sheetContext),
          ),
        ),
      );
    },
  );
}
