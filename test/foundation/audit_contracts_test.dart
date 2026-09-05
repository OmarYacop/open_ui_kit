import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  test('semantic text colors remain separate from accents and interpolate', () {
    final light = UiColorTokens.light;
    expect(light.successForeground, isNot(light.success));
    expect(light.warningForeground, isNot(light.warning));
    for (final colors in [light, UiColorTokens.dark]) {
      for (final pair in [
        (colors.success, colors.successForeground),
        (colors.warning, colors.warningForeground),
      ]) {
        final background = Color.alphaBlend(
          pair.$1.withValues(alpha: .1),
          colors.surface,
        );
        final x = background.computeLuminance();
        final y = pair.$2.computeLuminance();
        expect(
          ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
    final custom = light.copyWith(successForeground: const Color(0xff123456));
    expect(
      UiColorTokens.lerp(light, custom, 1).successForeground,
      custom.successForeground,
    );
    expect(custom.warningForeground, light.warningForeground);
  });

  test('new locale hooks have English defaults and Arabic resources', () {
    const en = UiLocalizationsEn();
    const ar = UiLocalizationsAr();
    expect(en.dateLabel(DateTime(2026, 9, 5)), 'Saturday, September 5, 2026');
    expect(ar.dateLabel(DateTime(2026, 9, 5)), 'السبت، 5 سبتمبر 2026');
    expect(ar.alertWarning, 'تحذير');
    expect(ar.loadingTable, isNot(en.loadingTable));
    expect(ar.ratingLabel('3.5', 5), contains('3.5'));
    expect(ar.monthNames, hasLength(12));
    expect(ar.shortWeekdayNames, hasLength(7));
  });
}
