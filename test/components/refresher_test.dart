import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return UiApp(
    mode: UiThemeMode.light,
    locale: locale,
    localizationsDelegates: const [UiLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('ar')],
    home: MediaQuery(
      data: MediaQueryData(padding: padding),
      child: UiPageScaffold(scrollFade: false, body: child),
    ),
  );
}

Widget _list({double height = 1000}) {
  return ListView(
    children: [SizedBox(height: height, child: const Text('content'))],
  );
}

Future<void> _pull(
  WidgetTester tester, {
  Finder? scrollable,
  double distance = 240,
}) async {
  await tester.pumpAndSettle();
  final target = scrollable ?? find.byType(ListView);
  await tester.timedDrag(
    target,
    Offset(0, distance),
    const Duration(milliseconds: 400),
  );
  await tester.pump();
}

void main() {
  group('UiRefresher', () {
    testWidgets('disposes safely without prior pull interaction',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiRefresher(
            onRefresh: () async {},
            child: _list(height: 20),
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
    });

    testWidgets('runs refresh and renders rich lifecycle feedback',
        (tester) async {
      final completer = Completer<void>();
      final statuses = <UiRefreshStatus>[];
      var refreshCount = 0;

      await tester.pumpWidget(
        _host(
          UiRefresher(
            onRefresh: () {
              refreshCount++;
              return completer.future;
            },
            onStatusChanged: statuses.add,
            child: _list(),
          ),
        ),
      );

      await _pull(tester);

      expect(refreshCount, 1);
      expect(
          statuses,
          containsAllInOrder([
            UiRefreshStatus.dragging,
            UiRefreshStatus.armed,
            UiRefreshStatus.refreshing,
          ]));
      expect(find.byType(UiRefreshIndicator), findsOneWidget);
      expect(find.text('Refreshing…'), findsNothing);

      completer.complete();
      await tester.pump();

      expect(statuses, contains(UiRefreshStatus.completed));
      expect(find.byType(UiRefreshIndicator), findsOneWidget);
      expect(find.text('Refresh complete'), findsNothing);

      await tester.pumpAndSettle();
      expect(statuses.last, UiRefreshStatus.idle);
    });

    testWidgets('always-scrollable composition refreshes short content',
        (tester) async {
      var refreshCount = 0;
      await tester.pumpWidget(
        _host(
          UiRefresher(
            onRefresh: () async => refreshCount++,
            child: _list(height: 20),
          ),
        ),
      );

      await _pull(tester);
      await tester.pumpAndSettle();

      expect(refreshCount, 1);
    });

    testWidgets('dismisses without refreshing below the trigger distance',
        (tester) async {
      var refreshCount = 0;
      final statuses = <UiRefreshStatus>[];
      await tester.pumpWidget(
        _host(
          UiRefresher(
            onRefresh: () async => refreshCount++,
            onStatusChanged: statuses.add,
            child: _list(),
          ),
        ),
      );

      await _pull(tester, distance: 48);
      await tester.pumpAndSettle();

      expect(refreshCount, 0);
      expect(statuses, isNot(contains(UiRefreshStatus.armed)));
      expect(statuses.last, UiRefreshStatus.idle);
    });

    testWidgets('controller coalesces concurrent refresh requests',
        (tester) async {
      final controller = UiRefresherController();
      final completer = Completer<void>();
      var refreshCount = 0;

      await tester.pumpWidget(
        _host(
          UiRefresher(
            controller: controller,
            onRefresh: () {
              refreshCount++;
              return completer.future;
            },
            child: _list(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final first = controller.refresh();
      final second = controller.refresh();
      await tester.pump();

      expect(controller.attached, isTrue);
      expect(controller.isRefreshing, isTrue);
      expect(identical(first, second), isTrue);
      expect(refreshCount, 1);

      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pumpAndSettle();
      await first;
      await second;
      expect(controller.status, UiRefreshStatus.idle);
    });

    testWidgets('surfaces failures and rethrows them to controller callers',
        (tester) async {
      final controller = UiRefresherController();
      Object? reportedError;

      await tester.pumpWidget(
        _host(
          UiRefresher(
            controller: controller,
            onRefresh: () async => throw StateError('offline'),
            onError: (error, _) => reportedError = error,
            child: _list(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final refresh = controller.refresh();
      final expectation = expectLater(refresh, throwsStateError);
      await tester.pump();

      expect(reportedError, isA<StateError>());
      expect(controller.status, UiRefreshStatus.failed);
      expect(find.byType(UiRefreshIndicator), findsOneWidget);
      expect(find.text('Refresh failed'), findsNothing);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pumpAndSettle();
      await expectation;
      expect(controller.status, UiRefreshStatus.idle);
    });

    testWidgets('provides live progress to a custom indicator builder',
        (tester) async {
      final completer = Completer<void>();
      final seen = <UiRefreshStatus>[];

      await tester.pumpWidget(
        _host(
          UiRefresher(
            onRefresh: () => completer.future,
            indicatorBuilder: (context, details) {
              seen.add(details.status);
              return Text(
                'custom-${details.status.name}-${details.progress.toStringAsFixed(1)}',
              );
            },
            child: _list(),
          ),
        ),
      );

      await _pull(tester);

      expect(seen, contains(UiRefreshStatus.armed));
      expect(find.text('custom-refreshing-1.0'), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('positions the overlay indicator below the top safe inset',
        (tester) async {
      final controller = UiRefresherController();
      final completer = Completer<void>();
      final triggerDistances = <double>[];
      const indicatorKey = ValueKey('safe-refresher-indicator');

      await tester.pumpWidget(
        _host(
          UiRefresher(
            controller: controller,
            onRefresh: () => completer.future,
            indicatorBuilder: (_, details) {
              triggerDistances.add(details.triggerDistance);
              return const SizedBox(
                key: indicatorKey,
                width: 24,
                height: 24,
              );
            },
            child: _list(),
          ),
          padding: const EdgeInsets.only(top: 40),
        ),
      );
      await tester.pumpAndSettle();

      final refresh = controller.refresh();
      await tester.pump();

      expect(tester.getTopLeft(find.byKey(indicatorKey)).dy, greaterThan(40));
      expect(triggerDistances, everyElement(72));
      completer.complete();
      await refresh;
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pumpAndSettle();
    });

    testWidgets('keeps RTL refresh feedback glyph-only', (tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(
        _host(
          UiRefresher(
            onRefresh: () => completer.future,
            child: _list(),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
      expect(find.byType(UiRefreshIndicator), findsWidgets);
      expect(find.text('اسحب للتحديث'), findsNothing);

      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();
      expect(find.byType(UiRefreshIndicator), findsOneWidget);
      expect(find.text('حرّر للتحديث'), findsNothing);

      await gesture.up();
      await tester.pump();
      expect(find.byType(UiRefreshIndicator), findsOneWidget);
      expect(find.text('جارٍ التحديث…'), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();
    });
  });

  group('UiSliverRefresher', () {
    testWidgets('refreshes inside a custom scroll view', (tester) async {
      final completer = Completer<void>();
      final statuses = <UiRefreshStatus>[];
      var refreshCount = 0;

      await tester.pumpWidget(
        _host(
          CustomScrollView(
            physics: UiRefresher.sliverPhysics,
            slivers: [
              UiSliverRefresher(
                onStatusChanged: statuses.add,
                onRefresh: () {
                  refreshCount++;
                  return completer.future;
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1000)),
            ],
          ),
        ),
      );

      await _pull(tester, scrollable: find.byType(CustomScrollView));
      for (var frame = 0;
          frame < 90 && !statuses.contains(UiRefreshStatus.refreshing);
          frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(refreshCount, 1);
      expect(statuses, contains(UiRefreshStatus.refreshing));
      expect(find.byType(UiRefreshIndicator), findsOneWidget);
      expect(find.text('Refreshing…'), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('maps callback errors to failed indicator feedback',
        (tester) async {
      Object? reportedError;
      await tester.pumpWidget(
        _host(
          CustomScrollView(
            physics: UiRefresher.sliverPhysics,
            slivers: [
              UiSliverRefresher(
                onRefresh: () async => throw StateError('offline'),
                onError: (error, _) => reportedError = error,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1000)),
            ],
          ),
        ),
      );

      await _pull(tester, scrollable: find.byType(CustomScrollView));
      await tester.pump();

      expect(reportedError, isA<StateError>());
      expect(find.byType(UiRefreshIndicator), findsOneWidget);
      expect(find.text('Refresh failed'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('positions the sliver indicator below the top safe inset',
        (tester) async {
      final completer = Completer<void>();
      final triggerDistances = <double>[];
      const indicatorKey = ValueKey('safe-sliver-refresher-indicator');

      await tester.pumpWidget(
        _host(
          CustomScrollView(
            physics: UiRefresher.sliverPhysics,
            slivers: [
              UiSliverRefresher(
                onRefresh: () => completer.future,
                indicatorBuilder: (_, details) {
                  triggerDistances.add(details.triggerDistance);
                  return const SizedBox(
                    key: indicatorKey,
                    width: 24,
                    height: 24,
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1000)),
            ],
          ),
          padding: const EdgeInsets.only(top: 40),
        ),
      );

      await _pull(tester, scrollable: find.byType(CustomScrollView));
      for (var frame = 0;
          frame < 90 && find.byKey(indicatorKey).evaluate().isEmpty;
          frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(find.byKey(indicatorKey), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(indicatorKey)).dy, greaterThan(40));
      expect(triggerDistances, everyElement(96));

      completer.complete();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('UiCollectionPage opts into refresher with one callback',
      (tester) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      _host(
        UiCollectionPage<String>(
          items: const ['one'],
          onRefresh: () async => refreshCount++,
          itemBuilder: (_, item, __) => SizedBox(
            height: 24,
            child: Text(item),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UiRefresher), findsOneWidget);
    await _pull(tester);
    await tester.pumpAndSettle();

    expect(refreshCount, 1);
  });

  test('controller explains unattached usage', () {
    final controller = UiRefresherController();
    expect(controller.refresh, throwsStateError);
  });
}
