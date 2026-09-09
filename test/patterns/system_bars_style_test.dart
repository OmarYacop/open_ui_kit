import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  const transparent = Color(0x00000000);

  test('forBrightness maps a resolved appearance to transparent bars', () {
    final light = UiSystemBarsStyle.forBrightness(Brightness.light);
    expect(light, same(UiSystemBarsStyle.light));
    expect(light.statusBarColor, transparent);
    expect(light.statusBarBrightness, Brightness.light);
    expect(light.statusBarIconBrightness, Brightness.dark);
    expect(light.systemNavigationBarColor, transparent);
    expect(light.systemNavigationBarIconBrightness, Brightness.dark);

    final dark = UiSystemBarsStyle.forBrightness(Brightness.dark);
    expect(dark, same(UiSystemBarsStyle.dark));
    expect(dark.statusBarBrightness, Brightness.dark);
    expect(dark.statusBarIconBrightness, Brightness.light);
    expect(dark.systemNavigationBarIconBrightness, Brightness.light);
  });

  test('transparent bars never enforce Android contrast scrims', () {
    for (final style in [UiSystemBarsStyle.light, UiSystemBarsStyle.dark]) {
      expect(style.systemStatusBarContrastEnforced, isFalse);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
    }
  });
}
