import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('motion spec resolves theme timing and reduced motion', (
    tester,
  ) async {
    late UiMotionSpec standard;
    late UiMotionSpec reduced;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            standard = UiMotionSpec.resolve(context);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  reduced = UiMotionSpec.resolve(context);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(standard.duration, UiMotionTokens.defaults.standard);
    expect(standard.reverseDuration, UiMotionTokens.defaults.fast);
    expect(standard.curve, UiMotionTokens.defaults.standardCurve);
    expect(standard.isReduced, isFalse);
    expect(reduced.duration, Duration.zero);
    expect(reduced.reverseDuration, Duration.zero);
    expect(reduced.curve, Curves.linear);
    expect(reduced.isReduced, isTrue);
  });

  testWidgets('token-or-custom durations share reduced-motion behavior', (
    tester,
  ) async {
    late Duration tokenDuration;
    late Duration customDuration;
    late Duration reducedCustomDuration;
    late UiMotionSpec customSpec;
    late UiMotionSpec reducedCustomSpec;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            tokenDuration = UiMotionDuration.slow.resolve(context);
            customDuration = const UiMotionDuration.custom(
              Duration(milliseconds: 415),
            ).resolve(context);
            customSpec = UiMotionSpec.resolveCustom(
              context,
              duration: const Duration(milliseconds: 415),
            );
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  reducedCustomDuration = const UiMotionDuration.custom(
                    Duration(milliseconds: 415),
                  ).resolve(context);
                  reducedCustomSpec = UiMotionSpec.resolveCustom(
                    context,
                    duration: const Duration(milliseconds: 415),
                  );
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(tokenDuration, UiMotionTokens.defaults.slow);
    expect(customDuration, const Duration(milliseconds: 415));
    expect(customSpec.duration, const Duration(milliseconds: 415));
    expect(reducedCustomDuration, Duration.zero);
    expect(reducedCustomSpec.isReduced, isTrue);
  });

  testWidgets('measured morph interpolates geometry from a shared anchor', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: UiMeasuredMorph(
            progress: 0.5,
            alignment: Alignment.topRight,
            collapsed: SizedBox(key: Key('collapsed'), width: 40, height: 20),
            expanded: SizedBox(key: Key('expanded'), width: 80, height: 60),
          ),
        ),
      ),
    );

    final morphRect = tester.getRect(find.byType(UiMeasuredMorph));
    final collapsedRect = tester.getRect(find.byKey(const Key('collapsed')));
    final expandedRect = tester.getRect(find.byKey(const Key('expanded')));

    expect(morphRect.size, const Size(60, 40));
    expect(collapsedRect.top, morphRect.top);
    expect(expandedRect.top, morphRect.top);
    expect(collapsedRect.right, morphRect.right);
    expect(expandedRect.right, morphRect.right);
  });
}
