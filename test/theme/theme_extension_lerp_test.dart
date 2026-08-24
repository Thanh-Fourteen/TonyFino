// Luật #3: mọi ThemeExtension.lerp() phải nội suy THẬT, không được `=> other`.
// Test này ép chứng minh bằng cách kiểm t=0.5 KHÔNG bằng cả hai đầu mút.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/theme/app_colors.dart';
import 'package:tonyfino/theme/app_shadows.dart';
import 'package:tonyfino/theme/app_typography.dart';

void main() {
  group('AppColors.lerp — nội suy thật', () {
    test('t=0.5 khác cả light lẫn dark trên field màu đơn', () {
      final mid = AppColors.light.lerp(AppColors.dark, 0.5);
      expect(mid.canvas, isNot(AppColors.light.canvas));
      expect(mid.canvas, isNot(AppColors.dark.canvas));
      expect(
        mid.canvas,
        Color.lerp(AppColors.light.canvas, AppColors.dark.canvas, 0.5),
      );
    });

    test('t=0 / t=1 trả đúng hai đầu mút', () {
      final at0 = AppColors.light.lerp(AppColors.dark, 0);
      final at1 = AppColors.light.lerp(AppColors.dark, 1);
      expect(at0.canvas, AppColors.light.canvas);
      expect(at1.canvas, AppColors.dark.canvas);
    });

    test(
      'categoryFills (List<Color>) nội suy từng phần tử, không nhảy cứng',
      () {
        final mid = AppColors.light.lerp(AppColors.dark, 0.5);
        for (var i = 0; i < mid.categoryFills.length; i++) {
          expect(
            mid.categoryFills[i],
            Color.lerp(
              AppColors.light.categoryFills[i],
              AppColors.dark.categoryFills[i],
              0.5,
            ),
          );
        }
      },
    );

    test('other khác type → trả về this (an toàn, không throw)', () {
      final result = AppColors.light.lerp(null, 0.5);
      expect(result, AppColors.light);
    });
  });

  group('AppTypography.lerp — nội suy thật', () {
    test(
      't=0.5 cho fontSize nằm giữa hai đầu (dùng style khác size để lộ khác biệt)',
      () {
        const a = AppTypography(
          moneyHero: TextStyle(fontSize: 40),
          moneyLarge: TextStyle(fontSize: 28),
          moneyMedium: TextStyle(fontSize: 17),
          moneySmall: TextStyle(fontSize: 13),
        );
        const b = AppTypography(
          moneyHero: TextStyle(fontSize: 20),
          moneyLarge: TextStyle(fontSize: 28),
          moneyMedium: TextStyle(fontSize: 17),
          moneySmall: TextStyle(fontSize: 13),
        );
        final mid = a.lerp(b, 0.5);
        expect(
          mid.moneyHero.fontSize,
          30,
        ); // (40+20)/2 — chứng minh nội suy thật
      },
    );
  });

  group('AppShadows.lerp — nội suy thật khi đổi theme', () {
    test('t=0.5 giữa light và dark không nhảy cứng', () {
      final mid = AppShadows.light.lerp(AppShadows.dark, 0.5);
      final from = AppShadows.light.level1Shadow.first;
      final to = AppShadows.dark.level1Shadow.first;
      final midShadow = mid.level1Shadow.first;
      expect(mid.level1Shadow, isNotEmpty);
      expect(
        midShadow.blurRadius,
        closeTo((from.blurRadius + to.blurRadius) / 2, 0.001),
      );
      expect(midShadow.blurRadius, isNot(from.blurRadius));
      expect(midShadow.blurRadius, isNot(to.blurRadius));
    });

    test('CẢ HAI theme đều có bóng bậc 1 — dark không còn rỗng', () {
      // Quy ước cũ "dark không bao giờ đổ bóng" đã bị bỏ (2026-08-22):
      // đó chính là thứ khiến màn tối phẳng lì. Bóng đen alpha cao trên
      // nền gần đen vẫn đọc rõ. Test này giữ cho không ai lặng lẽ trả
      // dark về danh sách rỗng.
      expect(AppShadows.light.level1Shadow, hasLength(2));
      expect(AppShadows.dark.level1Shadow, hasLength(2));
      expect(AppShadows.dark.level1TopHighlight.a, greaterThan(0));
    });

    test('mỗi bậc là bóng HAI LỚP: tiếp xúc ngắn + toả rộng', () {
      for (final shadows in [AppShadows.light, AppShadows.dark]) {
        final contact = shadows.level1Shadow[0];
        final ambient = shadows.level1Shadow[1];
        expect(
          contact.blurRadius,
          lessThan(ambient.blurRadius),
          reason: 'lớp tiếp xúc phải sắc hơn hẳn lớp toả',
        );
        expect(contact.offset.dy, lessThan(ambient.offset.dy));
      }
    });

    test('border màu nội suy thật', () {
      final mid = AppShadows.light.lerp(AppShadows.dark, 0.5);
      expect(
        mid.level1Border,
        Color.lerp(
          AppShadows.light.level1Border,
          AppShadows.dark.level1Border,
          0.5,
        ),
      );
    });
  });
}
