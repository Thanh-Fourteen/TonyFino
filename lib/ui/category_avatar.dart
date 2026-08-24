import 'package:flutter/material.dart';

import '../theme/context_ext.dart';
import '../theme/tokens/icons.dart';

/// Avatar tròn của danh mục — nhận `categoryColorId` (D10: chỉ số INTEGER,
/// TUYỆT ĐỐI không phải hex) + `iconCode`, resolve màu QUA THEME
/// (`context.colors.categoryFills`) nên đổi cả bảng màu là đổi một file,
/// và dark mode tự động đúng.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.categoryColorId,
    required this.iconCode,
    this.size = 40,
    this.emoji,
  });

  final int categoryColorId;
  final String iconCode;
  final double size;

  /// Emoji tuỳ chọn của danh mục (Phase 17, `categories.emoji`) — `null` ở
  /// mọi danh mục chưa đặt (kể cả 12 danh mục seed). KHÔNG thay icon: icon
  /// vẫn là nguồn nhận diện màu/hình chính (D10) và là thứ duy nhất mọi màn
  /// khác đã dựa vào từ trước — emoji chỉ đè thêm một dấu nhỏ ở góc, giữ
  /// avatar cũ nguyên vẹn khi vắng mặt (mọi call site không truyền tham số
  /// này không đổi hình ảnh dù chỉ một pixel).
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final fills = context.colors.categoryFills;
    final fill = fills[categoryColorId % fills.length];

    // 🚨 NỀN vòng tròn là MỘT tông xanh chung, KHÔNG phải màu của từng danh
    // mục.
    //
    // Trước đây nền là `fill` (màu danh mục) ở 16%. Ở giao diện TỐI, màu ấm
    // pha 16% trên nền gần đen ra đúng một sắc nâu/ô-liu đục — Tony chụp màn
    // hình chỉ thẳng vào những vòng tròn này. Không có cách chỉnh alpha nào
    // cứu được: cam/vàng/nâu tối đi thì luôn ra nâu.
    //
    // Bỏ màu ở nền KHÔNG làm mất danh tính danh mục: phần ruột là icon 3D
    // (burger, ô tô, nhà…) — thứ nhận ra ngay và nhanh hơn một sắc nền nhạt.
    // Màu danh mục vẫn giữ nguyên vai trò ở chỗ nó thực sự cần: chú giải và
    // lát bánh của biểu đồ tròn (`report_category_color.dart`), nơi 12 màu
    // phải phân biệt được với nhau.
    //
    // `errorBuilder` lùi về glyph đơn sắc TÔ MÀU DANH MỤC: khi asset thiếu
    // thì không còn hình để nhận ra nữa, lúc đó màu là manh mối duy nhất.
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.brandText.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Image.asset(
        resolveCategoryIcon3d(iconCode),
        width: size * 0.68,
        height: size * 0.68,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, _, _) => Icon(
          resolveCategoryIcon(iconCode),
          size: size * 0.5,
          color: fill,
          fill: 1,
        ),
      ),
    );

    if (emoji == null || emoji!.isEmpty) return avatar;

    final badgeSize = size * 0.42;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -badgeSize * 0.12,
            bottom: -badgeSize * 0.12,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: context.colors.card,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.card, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(emoji!, style: TextStyle(fontSize: badgeSize * 0.62)),
            ),
          ),
        ],
      ),
    );
  }
}
