import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  UiRouteSpec<void, void> homeRoute(UiRouteSpec<dynamic, void> detail) {
    return UiRouteSpec<void, void>(
      id: 'home',
      title: 'Home',
      builder: (_, __) => Builder(
        builder: (context) {
          final controller = UiNavigationControllerScope.of(context).controller;
          return Column(
            children: [
              const Text('home-page'),
              UiButton(
                label: 'Go detail',
                onPressed: () => controller.push(detail, args: 7),
              ),
            ],
          );
        },
      ),
    );
  }

  final detail = UiRouteSpec<dynamic, void>(
    id: 'detail',
    title: 'Detail',
    builder: (context, args) => Builder(
      builder: (context) {
        final scope = UiNavigationControllerScope.of(context);
        return Column(
          children: [
            Text('detail-$args'),
            UiButton(
              label: 'Back',
              onPressed: () => scope.controller.pop(),
            ),
          ],
        );
      },
    ),
  );

  Widget host(UiNavigationController controller) {
    return MaterialApp(
      theme: UiThemeData.light(),
      home: Scaffold(body: UiNavigationHost(controller: controller)),
    );
  }

  testWidgets('host renders initial route then reacts to push/pop',
      (tester) async {
    final controller = UiNavigationController(
      routes: [homeRoute(detail), detail],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(controller));
    expect(find.text('home-page'), findsOneWidget);

    await tester.tap(find.text('Go detail'));
    await tester.pumpAndSettle();
    expect(find.text('detail-7'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('custom host builder receives route entries', (tester) async {
    final home = UiRouteSpec<void, void>(
      id: 'home',
      title: 'Home',
      builder: (_, __) => const SizedBox.shrink(),
    );
    final detail = UiRouteSpec<dynamic, void>(
      id: 'detail',
      title: 'Detail',
      builder: (_, __) => const SizedBox.shrink(),
    );
    final controller = UiNavigationController(routes: [home, detail]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: UiThemeData.light(),
        home: Scaffold(
          body: UiNavigationHost(
            controller: controller,
            builder: (context, entry) => Builder(
              builder: (context) {
                final current = UiNavigationControllerScope.of(context).entry;
                return Text('entry:${entry.id}|scope:${current.id}');
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('entry:home|scope:home'), findsOneWidget);

    controller.push(detail, args: 2);
    await tester.pumpAndSettle();

    expect(find.text('entry:detail|scope:detail'), findsOneWidget);
  });

  testWidgets('host uses softShift transition by default', (tester) async {
    final controller = UiNavigationController(
      routes: [homeRoute(detail), detail],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(controller));
    await tester.tap(find.text('Go detail'));
    await tester.pump();

    final transition = tester.widget<UiNavigationTransition>(
      find.byType(UiNavigationTransition).last,
    );
    expect(transition.style, UiNavigationTransitionStyle.softShift);
  });
}
