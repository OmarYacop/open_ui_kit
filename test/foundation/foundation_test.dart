import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  group('tokens', () {
    test('light/dark color tokens are distinct', () {
      expect(
        UiColorTokens.light.background,
        isNot(equals(UiColorTokens.dark.background)),
      );
      expect(
        UiColorTokens.light.textPrimary,
        isNot(equals(UiColorTokens.dark.textPrimary)),
      );
    });

    test('spacing scale is monotonic', () {
      const s = UiSpacingTokens.standard;
      expect(s.x0, lessThan(s.x1));
      expect(s.x1, lessThan(s.x2));
      expect(s.x4, lessThan(s.x8));
      expect(s.x8, lessThan(s.x16));
    });

    test('radius tokens expose BorderRadius helpers', () {
      const r = UiRadiusTokens.standard;
      expect(r.sm, const Radius.circular(10));
      expect(r.md, const Radius.circular(12));
      expect(r.lg, const Radius.circular(16));
      expect(r.xl, const Radius.circular(24));
      expect(r.mdAll, isA<BorderRadius>());
      expect(r.mdAll.topLeft, r.md);
    });

    test('typography scale: caption is smaller than body', () {
      final t = UiTypographyTokens.standard;
      expect(t.caption.fontSize, isNotNull);
      expect(t.body.fontSize, isNotNull);
      expect(t.caption.fontSize!, lessThan(t.body.fontSize!));
    });
  });

  group('theme', () {
    testWidgets('UiThemeTokens.of falls back to light when absent',
        (tester) async {
      late UiThemeTokens resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              resolved = UiThemeTokens.of(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.brightness, Brightness.light);
    });

    testWidgets('UiThemeData.light attaches UiThemeTokens extension',
        (tester) async {
      late UiThemeTokens resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: UiThemeData.light(),
          home: Builder(
            builder: (ctx) {
              resolved = UiThemeTokens.of(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.colors.background, UiColorTokens.light.background);
    });

    testWidgets('UiThemeData.dark yields dark tokens', (tester) async {
      late UiThemeTokens resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: UiThemeData.dark(),
          home: Builder(
            builder: (ctx) {
              resolved = UiThemeTokens.of(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.brightness, Brightness.dark);
      expect(resolved.colors.background, UiColorTokens.dark.background);
    });
  });

  group('primitives', () {
    testWidgets('UiBox renders a DecoratedBox when styled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: UiThemeData.light(),
          home: const UiBox(
            background: Color(0xFFAABBCC),
            padding: EdgeInsets.all(8),
            child: SizedBox(width: 10, height: 10),
          ),
        ),
      );
      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets('UiText applies heading font size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: UiThemeData.light(),
          home: const UiText('hi', variant: UiTextVariant.heading),
        ),
      );
      final rendered = tester.widget<Text>(find.text('hi'));
      expect(
        rendered.style?.fontSize,
        UiTypographyTokens.standard.heading.fontSize,
      );
    });
  });
}
