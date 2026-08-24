import 'package:flutter/material.dart';

import '../theme/context_ext.dart';
import '../theme/tokens/palette.dart';

/// Nền có CHIỀU SÂU cho khung 4 tab — hai quầng sáng rất nhạt TRÔI CHẬM
/// trên nền canvas, thay cho một mảng màu phẳng tuyệt đối.
///
/// Vì sao làm ở NỀN chứ không ở từng thẻ: nghiên cứu (Copilot Money,
/// Mercury) và Apple HIG 2026 đều đặt độ sâu ở tầng NỔI TRÊN nội dung, không
/// bao giờ lên chính chỗ đọc số. Mọi thẻ vẫn đục 100% nên tương phản chữ/số
/// không đổi một chút nào; quầng sáng chỉ lộ ra ở khoảng trống giữa các thẻ.
///
/// Chuyển động cố tình RẤT chậm (một vòng ~24 giây) và biên độ nhỏ: mục
/// tiêu là nền "sống", không phải nền gây chú ý — mắt chỉ nhận ra khi nhìn
/// lâu, đúng như ánh sáng đổi trong phòng.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // 🚨 KHÔNG BAO GIỜ `repeat()` mà không kiểm cờ này trước:
    // `pumpAndSettle()` (dùng ở hầu hết widget test) đợi mọi animation dừng
    // hẳn, một controller lặp vô hạn treo nó tới timeout. Nền này bọc TOÀN
    // BỘ 4 tab nên bỏ quên sẽ làm hỏng test của cả app, không riêng một màn.
    if (MediaQuery.disableAnimationsOf(context)) return;
    _drift.repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Quầng nền dùng tông BỘT GẠCH dịu (#C86B4A) chứ không phải primary:
    // primary là màu để đọc chữ trên đó nên nó đậm và "kêu", trải rộng ra cả
    // nền thì nặng. Bột gạch không bao giờ có chữ đặt lên nên được phép dịu
    // và ấm hơn — đúng thứ hợp cho một mảng nền lớn.
    // Quầng nền dùng PETROL, không dùng cam.
    //
    // Cam ở 10% phủ lên canvas gần trắng ra một vệt be nhạt loang khắp đầu
    // màn hình — mảng ấm-nhạt lớn nhất còn lại sau khi đã dọn thang lịch và
    // nền icon, và mắt đọc nó là nâu chứ không phải "cam nhạt". Cam ở lại
    // nơi nó mạnh: những mảng NHỎ và ĐẬM (FAB, viên nav), chứ không phải
    // những mảng lớn và nhạt.
    final accent = colors.brandText;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.canvas),
      child: AnimatedBuilder(
        animation: _drift,
        builder: (context, child) {
          // −1 → 1 rồi ngược lại; nhân với biên độ nhỏ tính bằng pixel.
          final t = Curves.easeInOut.transform(_drift.value) * 2 - 1;
          return Stack(
            children: [
              // Quầng chính — góc trên-trái, đúng nơi mắt vào màn hình trước
              // tiên và cũng là nơi thẻ tổng quan ngồi lên trên.
              Positioned(
                top: -160 + t * 26,
                left: -120 + t * 18,
                child: _Glow(
                  size: 420,
                  color: accent.withValues(alpha: isDark ? 0.22 : 0.10),
                ),
              ),
              // Quầng phụ — góc dưới-phải, trôi NGƯỢC pha để hai quầng không
              // dịch chuyển như một khối, thứ trông giống lỗi cuộn hơn là
              // ánh sáng.
              Positioned(
                bottom: -200 - t * 22,
                right: -140 - t * 16,
                child: _Glow(
                  size: 380,
                  // Quầng phụ giữ CAM (đậm, alpha thấp) để app không mất
                  // hẳn hơi ấm — hai quầng lệch tông tạo chiều sâu tốt hơn
                  // hai quầng cùng màu.
                  color: paletteBrickDust.withValues(
                    alpha: isDark ? 0.10 : 0.05,
                  ),
                ),
              ),
              Positioned.fill(child: child!),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
