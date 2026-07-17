import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  const acme = UiBrand(
    id: 'acme',
    displayName: 'Acme',
    primary: Color(0xFFFF5722),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF1976D2),
    danger: Color(0xFFB00020),
  );

  test('colorTokens layers brand values onto the neutral baseline', () {
    final light = acme.colorTokens(Brightness.light);
    expect(light.primary, const Color(0xFFFF5722));
    expect(light.onPrimary, const Color(0xFFFFFFFF));
    // Overrides flow through…
    expect(light.danger, const Color(0xFFB00020));
    expect(light.focusRing, const Color(0xFF1976D2));
    // …while unspecified fields fall through to the neutral baseline.
    expect(light.surface, UiColorTokens.light.surface);
    expect(light.background, UiColorTokens.light.background);
  });

  test('colorTokens picks dark baseline under dark brightness', () {
    final dark = acme.colorTokens(Brightness.dark);
    expect(dark.background, UiColorTokens.dark.background);
    expect(dark.primary, const Color(0xFFFF5722));
  });

  testWidgets('UiThemeData.fromBrand exposes brand tokens to descendants',
      (tester) async {
    UiThemeTokens? tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: UiThemeData.fromBrand(acme),
        home: Builder(
          builder: (ctx) {
            tokens = UiThemeTokens.of(ctx);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(tokens, isNotNull);
    expect(tokens!.colors.primary, const Color(0xFFFF5722));
    expect(tokens!.colors.focusRing, const Color(0xFF1976D2));
  });

  test('copyWith preserves + overrides fields', () {
    final next = acme.copyWith(
      displayName: 'Acme Pro',
      primary: const Color(0xFF000000),
    );
    expect(next.id, acme.id);
    expect(next.displayName, 'Acme Pro');
    expect(next.primary, const Color(0xFF000000));
    // Non-overridden fields stay the same instance.
    expect(next.accent, acme.accent);
  });

  test('equality collapses identical brands + differs when changed', () {
    const b1 = UiBrand(
      id: 'a',
      displayName: 'A',
      primary: Color(0xFF111111),
      onPrimary: Color(0xFFFFFFFF),
    );
    const b2 = UiBrand(
      id: 'a',
      displayName: 'A',
      primary: Color(0xFF111111),
      onPrimary: Color(0xFFFFFFFF),
    );
    expect(b1, equals(b2));
    expect(
      b1,
      isNot(equals(b1.copyWith(primary: const Color(0xFF222222)))),
    );
  });
}
