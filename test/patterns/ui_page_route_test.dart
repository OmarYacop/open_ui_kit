import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

// The framework runs `debugAssertAllFoundationVarsUnset` before a regular
// `addTearDown` callback fires, so the override must be cleared inside the
// test body itself — wrap it in this helper rather than tearing down late.
Future<T> _runWithPlatform<T>(
  TargetPlatform platform,
  Future<T> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    return await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

// A single large moveBy() only ever produces the drag recognizer's *start*
// event and never a distinct onUpdate — small incremental steps are
// required for the route's controller.value to actually advance.
Future<void> _dragFromEdge(
  WidgetTester tester, {
  required double fraction,
}) async {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final gesture = await tester.startGesture(const Offset(6, 400));
  const steps = 10;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveBy(Offset(width * fraction / steps, 0));
    await tester.pump(const Duration(milliseconds: 4));
  }
  await gesture.up();
}

void main() {
  group('UiPageRoute / pushUiPage', () {
    testWidgets('pushes a UiPageRoute that plays UiNavigationTransition', (
      tester,
    ) async {
      await tester.pumpWidget(
        UiApp(
          lightTokens: UiThemeTokens.light,
          localizationsDelegates: const [DefaultWidgetsLocalizations.delegate],
          home: Builder(
            builder: (context) => Center(
              child: UiButton(
                label: 'Open',
                onPressed: () =>
                    context.pushUiPage<void>((_) => const Text('Detail')),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(find.byType(UiNavigationTransition), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.text('Detail'))),
        isA<UiPageRoute>(),
      );
    });

    testWidgets(
      'dragging past halfway from the left edge on iOS pops the route',
      (tester) async {
        await _runWithPlatform(TargetPlatform.iOS, () async {
          await tester.pumpWidget(
            UiApp(
              lightTokens: UiThemeTokens.light,
              localizationsDelegates: const [
                DefaultWidgetsLocalizations.delegate,
              ],
              home: Builder(
                builder: (context) => Center(
                  child: UiButton(
                    label: 'Open',
                    onPressed: () =>
                        context.pushUiPage<void>((_) => const Text('Detail')),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.text('Detail'), findsOneWidget);

          await _dragFromEdge(tester, fraction: 0.6);
          await tester.pumpAndSettle();

          expect(find.text('Open'), findsOneWidget);
          expect(find.text('Detail'), findsNothing);
        });
      },
    );

    testWidgets('no edge-swipe gesture is installed on Android', (
      tester,
    ) async {
      await _runWithPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          UiApp(
            lightTokens: UiThemeTokens.light,
            localizationsDelegates: const [
              DefaultWidgetsLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) => Center(
                child: UiButton(
                  label: 'Open',
                  onPressed: () =>
                      context.pushUiPage<void>((_) => const Text('Detail')),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await _dragFromEdge(tester, fraction: 0.6);
        await tester.pumpAndSettle();

        expect(find.text('Detail'), findsOneWidget);
      });
    });

    testWidgets('swipeBackEnabled: false disables the gesture on iOS', (
      tester,
    ) async {
      await _runWithPlatform(TargetPlatform.iOS, () async {
        await tester.pumpWidget(
          UiApp(
            lightTokens: UiThemeTokens.light,
            localizationsDelegates: const [
              DefaultWidgetsLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) => Center(
                child: UiButton(
                  label: 'Open',
                  onPressed: () => context.pushUiPage<void>(
                    (_) => const Text('Detail'),
                    swipeBackEnabled: false,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await _dragFromEdge(tester, fraction: 0.6);
        await tester.pumpAndSettle();

        expect(find.text('Detail'), findsOneWidget);
      });
    });
  });

  group('UiApp default navigation', () {
    // UiApp passes WidgetsApp.pageRouteBuilder — the factory it falls back
    // to for any route it generates (e.g. a plain Navigator.pushNamed with
    // no explicit route table). Confirming *that* factory's output is a
    // swipe-enabled UiPageRoute is what proves a default push, not just an
    // explicit pushUiPage call, gets the same signature motion.
    testWidgets('pageRouteBuilder produces a swipe-enabled UiPageRoute', (
      tester,
    ) async {
      await _runWithPlatform(TargetPlatform.iOS, () async {
        late Route<void> Function<T>(RouteSettings, WidgetBuilder) builder;
        await tester.pumpWidget(
          UiApp(
            lightTokens: UiThemeTokens.light,
            localizationsDelegates: const [
              DefaultWidgetsLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) {
                final widgetsApp = context
                    .findAncestorWidgetOfExactType<WidgetsApp>();
                builder = widgetsApp!.pageRouteBuilder!;
                return const SizedBox();
              },
            ),
          ),
        );

        final route = builder<void>(
          const RouteSettings(name: '/detail'),
          (_) => const Text('Detail'),
        );
        expect(route, isA<UiPageRoute<void>>());
        expect((route as UiPageRoute<void>).swipeBackEnabled, isTrue);
      });
    });
  });
}
