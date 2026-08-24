// XÁC MINH BẮT BUỘC (Phase 5): golden cho MỌI text style, ở CẢ light và
// dark, ở 1.0× và 1.3× text scale, với chuỗi chống-cắt-dấu chuẩn. Đây là
// thứ bắt lỗi cắt dấu tiếng Việt (ế ữ ỗ ặ ỡ...) trước khi ship — không phải
// optional, đây là lý do cả 10 text style (6 TextTheme + 4 money) phải có
// mặt trong MỖI ảnh.
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonyfino/theme/app_theme.dart';
import 'package:tonyfino/theme/context_ext.dart';

/// Chuỗi chuẩn từ TODOS.md § Font — dấu chồng (ế ữ ỗ ặ ỡ), gạch ngang em-dash,
/// dấu chấm phân cách nghìn, ký hiệu ₫. Nếu `height`/`leadingDistribution`
/// sai, dấu ở "ế ữ ỗ ặ ỡ" bị cắt trên/dưới đầu tiên.
const kDiacriticStressString = 'Đồng Nai — ế ữ ỗ ặ ỡ Ế Ữ Ỗ · 1.234.567 ₫';

Widget _specimenSheet(ThemeData theme) {
  return Theme(
    data: theme,
    child: Builder(
      builder: (context) {
        final colors = context.colors;
        final text = context.text;
        final money = context.money;
        Widget scenario(String name, TextStyle? style) {
          return GoldenTestScenario(
            name: name,
            child: ColoredBox(
              color: colors.canvas,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  kDiacriticStressString,
                  style: (style ?? const TextStyle()).copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
          );
        }

        return ColoredBox(
          color: colors.canvas,
          child: GoldenTestGroup(
            columns: 1,
            children: [
              scenario('displayLarge', text.displayLarge),
              scenario('titleLarge', text.titleLarge),
              scenario('titleMedium', text.titleMedium),
              scenario('bodyLarge', text.bodyLarge),
              scenario('bodyMedium', text.bodyMedium),
              scenario('labelMedium', text.labelMedium),
              scenario('moneyHero', money.moneyHero),
              scenario('moneyLarge', money.moneyLarge),
              scenario('moneyMedium', money.moneyMedium),
              scenario('moneySmall', money.moneySmall),
            ],
          ),
        );
      },
    ),
  );
}

void main() {
  group('Text styles — chống cắt dấu tiếng Việt', () {
    goldenTest(
      'light, 1.0x',
      fileName: 'text_styles_light_1_0x',
      constraints: const BoxConstraints(maxWidth: 420),
      builder: () => _specimenSheet(lightTheme),
    );

    goldenTest(
      'light, 1.3x',
      fileName: 'text_styles_light_1_3x',
      textScaleFactor: 1.3,
      constraints: const BoxConstraints(maxWidth: 420),
      builder: () => _specimenSheet(lightTheme),
    );

    goldenTest(
      'dark, 1.0x',
      fileName: 'text_styles_dark_1_0x',
      constraints: const BoxConstraints(maxWidth: 420),
      builder: () => _specimenSheet(darkTheme),
    );

    goldenTest(
      'dark, 1.3x',
      fileName: 'text_styles_dark_1_3x',
      textScaleFactor: 1.3,
      constraints: const BoxConstraints(maxWidth: 420),
      builder: () => _specimenSheet(darkTheme),
    );
  });
}
