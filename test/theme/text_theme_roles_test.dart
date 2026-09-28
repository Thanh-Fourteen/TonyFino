// Luật #12 (dấu tiếng Việt không bị cắt) phải phủ MỌI vai chữ, không chỉ
// những vai hay dùng: vai nào quên khai là `context.text.<vai>` rơi về chữ
// mặc định của Material — sai font, không `leadingDistribution.even`. Đã
// lọt 43 chỗ `labelSmall` trước khi test này có (2026-09-28).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/theme/app_theme.dart';

void main() {
  for (final (name, theme) in [('sáng', lightTheme), ('tối', darkTheme)]) {
    test('theme $name: đủ 15 vai chữ, đều Be Vietnam Pro + nhịp dòng đều', () {
      final t = theme.textTheme;
      final roles = {
        'displayLarge': t.displayLarge,
        'displayMedium': t.displayMedium,
        'displaySmall': t.displaySmall,
        'headlineLarge': t.headlineLarge,
        'headlineMedium': t.headlineMedium,
        'headlineSmall': t.headlineSmall,
        'titleLarge': t.titleLarge,
        'titleMedium': t.titleMedium,
        'titleSmall': t.titleSmall,
        'bodyLarge': t.bodyLarge,
        'bodyMedium': t.bodyMedium,
        'bodySmall': t.bodySmall,
        'labelLarge': t.labelLarge,
        'labelMedium': t.labelMedium,
        'labelSmall': t.labelSmall,
      };
      roles.forEach((role, style) {
        expect(style?.fontFamily, 'BeVietnamPro', reason: role);
        expect(style?.height, isNotNull, reason: role);
        expect(
          style?.leadingDistribution,
          TextLeadingDistribution.even,
          reason: role,
        );
      });
    });
  }
}
