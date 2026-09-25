import 'package:flutter/material.dart';

import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/glass_surface.dart';

/// Chiều cao xấp xỉ của thanh nav nổi (không kể `viewPadding.bottom`) — mỗi
/// scroll view trong các tab dùng số này để chừa đệm đáy, tự xử lý inset
/// theo TỪNG scroll view thay vì một `SafeArea` bao trùm (TODOS.md § Bố cục,
/// edge-to-edge Android 15+).
const kBottomNavReservedHeight = 88.0;

/// Chỗ trống THÊM một scroll view phải chừa phía trên
/// [kBottomNavReservedHeight] khi màn đó còn có một FAB nổi riêng (56dp nút
/// + ~16dp lề mặc định của `Scaffold`). Trước đây các màn dùng đúng
/// [kBottomNavReservedHeight] cho CẢ đệm danh sách LẪN vị trí neo của FAB —
/// đệm dừng đúng chỗ FAB bắt đầu nên nút luôn đè lên ~72dp cuối cùng của nội
/// dung đã cuộn (bắt bằng ảnh chụp thật, xem project_tonyfino_gotchas).
const kFabClearance = 72.0;

class NavTabSpec {
  const NavTabSpec({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

const kNavTabs = [
  NavTabSpec(icon: kIconHome, label: 'Trang chủ'),
  NavTabSpec(icon: kIconReceiptLong, label: 'Giao dịch'),
  NavTabSpec(icon: kIconBarChart, label: 'Báo cáo'),
  NavTabSpec(icon: kIconAccountBalanceWallet, label: 'Túi tiền'),
];

/// Bottom nav 4 tab đúng đặc tả — trên `GlassSurface` (một trong hai chỗ
/// DUY NHẤT dùng `BackdropFilter`), **pill biến hình + icon FILL 0→1** khi
/// đổi tab: mục đang chọn tự phình rộng ra để chứa nhãn (animate chiều rộng
/// + bo góc), KHÔNG cross-fade — đúng ý tưởng M3 Expressive mượn riêng
/// (TODOS.md § Package UI), tách khỏi ngân sách 5 animation nội dung.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: context.space.lg,
        right: context.space.lg,
        bottom: context.space.sm + MediaQuery.viewPaddingOf(context).bottom,
        top: context.space.sm,
      ),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(context.radii.full),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.xs,
            vertical: context.space.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < kNavTabs.length; i++)
                _NavItem(
                  spec: kNavTabs[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final NavTabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    // Viên tab đang chọn: CAM ĐẬM + chữ tối, không phải cam 10% + chữ đậm.
    // Cùng lý do FAB (xem `app_theme.dart`) — cam ở liều nhỏ mà đậm, không
    // phải mảng be nhạt.
    final fg = selected ? scheme.onPrimary : colors.onSurfaceVariant;

    // Nhãn hiện thành chữ chỉ khi ĐANG chọn (xem `AnimatedSize` bên dưới) —
    // tab chưa chọn chỉ còn icon trần, nên TalkBack/VoiceOver cần `Semantics`
    // bù lại, không thì `content-desc` rỗng (bắt bằng `uiautomator dump`
    // thật, xem project_tonyfino_gotchas).
    return Semantics(
      label: spec.label,
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.radii.full),
          child: AnimatedContainer(
            duration: context.durations.navMorph,
            curve: context.curves.navMorph,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: EdgeInsets.symmetric(
              horizontal: selected ? context.space.md : context.space.sm,
              vertical: context.space.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(context.radii.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: selected ? 1.0 : 0.0),
                  duration: context.durations.navMorph,
                  curve: context.curves.navMorph,
                  builder: (context, fill, _) =>
                      Icon(spec.icon, fill: fill, color: fg, size: 24),
                ),
                AnimatedSize(
                  duration: context.durations.navMorph,
                  curve: context.curves.navMorph,
                  child: selected
                      ? Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: context.space.xs,
                          ),
                          child: Text(
                            spec.label,
                            style: context.text.labelMedium?.copyWith(
                              color: fg,
                            ),
                          ),
                        )
                      : const SizedBox(height: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
