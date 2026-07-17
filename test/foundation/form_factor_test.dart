import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child, {required Size size}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: child,
    ),
  );
}

void main() {
  group('UiBreakpoints.resolve', () {
    test('below phone breakpoint → phone', () {
      expect(UiBreakpoints.standard.resolve(320), UiFormFactor.phone);
      expect(UiBreakpoints.standard.resolve(599.99), UiFormFactor.phone);
    });
    test('between phone and desktop → tablet', () {
      expect(UiBreakpoints.standard.resolve(600), UiFormFactor.tablet);
      expect(UiBreakpoints.standard.resolve(800), UiFormFactor.tablet);
      expect(UiBreakpoints.standard.resolve(899.99), UiFormFactor.tablet);
    });
    test('at or above desktop → desktop', () {
      expect(UiBreakpoints.standard.resolve(900), UiFormFactor.desktop);
      expect(UiBreakpoints.standard.resolve(1400), UiFormFactor.desktop);
    });
    test('custom breakpoints are honoured', () {
      const b = UiBreakpoints(phone: 480, desktop: 1024);
      expect(b.resolve(479), UiFormFactor.phone);
      expect(b.resolve(480), UiFormFactor.tablet);
      expect(b.resolve(1023), UiFormFactor.tablet);
      expect(b.resolve(1024), UiFormFactor.desktop);
    });
  });

  group('uiFormFactorOf', () {
    testWidgets('reads width from MediaQuery', (tester) async {
      late UiFormFactor observed;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              observed = uiFormFactorOf(context);
              return const SizedBox();
            },
          ),
          size: const Size(700, 800),
        ),
      );
      expect(observed, UiFormFactor.tablet);
    });
  });

  group('UiAdaptive', () {
    testWidgets('mode: dispatches to the matching builder', (tester) async {
      Widget shell(Size size) => _host(
            UiAdaptive.mode(
              phone: (_) => const Text('phone-build'),
              tablet: (_) => const Text('tablet-build'),
              desktop: (_) => const Text('desktop-build'),
            ),
            size: size,
          );

      await tester.pumpWidget(shell(const Size(400, 800)));
      expect(find.text('phone-build'), findsOneWidget);

      await tester.pumpWidget(shell(const Size(720, 800)));
      expect(find.text('tablet-build'), findsOneWidget);

      await tester.pumpWidget(shell(const Size(1200, 800)));
      expect(find.text('desktop-build'), findsOneWidget);
    });

    testWidgets(
        'mode: missing builders fall back to the next smallest provided',
        (tester) async {
      // No tablet or desktop builders — desktop width should still
      // render the phone build.
      await tester.pumpWidget(
        _host(
          UiAdaptive.mode(
            phone: (_) => const Text('only-phone'),
          ),
          size: const Size(1200, 800),
        ),
      );
      expect(find.text('only-phone'), findsOneWidget);
    });

    testWidgets('variant: feeds the correct value into the builder',
        (tester) async {
      Widget shell(Size size) => _host(
            UiAdaptive.variant<double>(
              phone: 8,
              tablet: 16,
              desktop: 32,
              builder: (_, v) => Text('p:$v'),
            ),
            size: size,
          );
      await tester.pumpWidget(shell(const Size(400, 800)));
      expect(find.text('p:8.0'), findsOneWidget);
      await tester.pumpWidget(shell(const Size(720, 800)));
      expect(find.text('p:16.0'), findsOneWidget);
      await tester.pumpWidget(shell(const Size(1200, 800)));
      expect(find.text('p:32.0'), findsOneWidget);
    });

    testWidgets(
        'visible: drops the child from the tree when false for the '
        'current form factor', (tester) async {
      await tester.pumpWidget(
        _host(
          UiAdaptive.visible(
            phone: false,
            tablet: true,
            desktop: true,
            child: const Text('detail-panel'),
          ),
          size: const Size(400, 800),
        ),
      );
      expect(find.text('detail-panel'), findsNothing);

      await tester.pumpWidget(
        _host(
          UiAdaptive.visible(
            phone: false,
            tablet: true,
            desktop: true,
            child: const Text('detail-panel'),
          ),
          size: const Size(720, 800),
        ),
      );
      expect(find.text('detail-panel'), findsOneWidget);
    });
  });
}
