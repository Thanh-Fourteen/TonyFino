import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/context_ext.dart';

/// `BackdropFilter` — CHỈ dùng ở HAI chỗ theo đặc tả design system: thanh
/// bottom nav và thanh nhập chat nổi, cả hai đè lên nội dung cuộn. Không
/// chỗ nào khác — blur nặng trên Android đọc ra là bắt chước Apple, và
/// `BackdropFilter` là một lượt render offscreen thật sự tốn GPU trên máy
/// tầm trung vốn thống trị thị trường Việt Nam (E5: emulator dev máy này
/// còn không có GPU dùng được, chạy SwiftShader).
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.blurSigma = 20,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(context.radii.full);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: context
                .colors
                .glassTint, // nền 70–80% — xem AppColors.glassTint
            borderRadius: radius,
            // hairline 1px trên, hiện ở cả hai theme (khác `level2TopHighlight`
            // vốn cố ý trong suốt ở light — sheet dựa vào bóng, glass thì không).
            border: Border(
              top: BorderSide(color: context.colors.hairline, width: 1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
