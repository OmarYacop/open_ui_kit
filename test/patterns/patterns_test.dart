import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({required this.onInit, required this.onDispose});

  final VoidCallback onInit;
  final VoidCallback onDispose;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('lifecycle-probe');
}

void main() {
  group('UiMessageBubble', () {
    testWidgets('outgoing uses primary background; incoming uses muted',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              UiMessageBubble(
                text: 'hello',
                author: UiMessageAuthor.incoming,
              ),
              UiMessageBubble(
                text: 'hi back',
                author: UiMessageAuthor.outgoing,
              ),
            ],
          ),
        ),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();

      expect(
        decorations.any((d) => d.color == UiColorTokens.light.primary),
        isTrue,
        reason: 'Outgoing bubble should paint with primary color',
      );
      expect(
        decorations.any((d) => d.color == UiColorTokens.light.surfaceMuted),
        isTrue,
        reason: 'Incoming bubble should paint with muted surface',
      );
    });

    testWidgets('failed status shows error caption', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiMessageBubble(
            text: 'oops',
            author: UiMessageAuthor.outgoing,
            status: UiMessageStatus.failed,
          ),
        ),
      );
      expect(find.text('Failed to send'), findsOneWidget);
    });
  });

  group('UiChatComposer', () {
    testWidgets('send button is disabled until text is entered',
        (tester) async {
      final messages = <String>[];
      final controller = TextEditingController();
      await tester.pumpWidget(
        _host(
          UiChatComposer(
            controller: controller,
            onSend: messages.add,
          ),
        ),
      );

      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(messages, isEmpty);

      controller.text = 'hi';
      await tester.pump();

      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(messages, ['hi']);
      expect(controller.text, '');
    });

    testWidgets('composer grows input lines for long text', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          UiChatComposer(
            controller: controller,
            onSend: (_) {},
          ),
        ),
      );

      controller.text =
          'This is a long line intended to wrap in the composer input area '
          'so that the control grows beyond one line.';
      await tester.pumpAndSettle();

      final input = tester.widget<UiInput>(find.byType(UiInput));
      expect(input.minLines, greaterThan(1));
    });
  });

  group('UiAppShell', () {
    testWidgets('renders topBar, body, and bottomBar slots', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiAppShell(
            topBar: UiAppBar(title: 'Title'),
            bottomBar: Padding(padding: EdgeInsets.all(8), child: Text('bot')),
            body: Center(child: Text('body')),
          ),
        ),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
      expect(find.text('bot'), findsOneWidget);
    });

    testWidgets('UiAppBar resolves brand logo for light and dark themes',
        (tester) async {
      const brand = UiBrand(
        id: 'acme',
        displayName: 'Acme App',
        primary: Color(0xFF2451FF),
        onPrimary: Color(0xFFFFFFFF),
        logo: Text('acme-light-logo'),
        darkLogo: Text('acme-dark-logo'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: UiThemeData.light(),
          home: const Scaffold(
            body: UiAppBar(
              title: 'Courses',
              brand: brand,
            ),
          ),
        ),
      );
      expect(find.text('acme-light-logo'), findsOneWidget);
      expect(find.text('acme-dark-logo'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          theme: UiThemeData.dark(),
          darkTheme: UiThemeData.dark(),
          home: const Scaffold(
            body: UiAppBar(
              title: 'Courses',
              brand: brand,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('acme-light-logo'), findsNothing);
      expect(find.text('acme-dark-logo'), findsOneWidget);
    });

    testWidgets('UiAppBar layout remains stable when logo is absent',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiAppBar(
            title: 'Dashboard',
            leading: const Text('Back'),
            trailing: const Text('Actions'),
          ),
        ),
      );

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('UiPageLayout', () {
    testWidgets('renders semantic title, actions, and body', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 390,
            height: 640,
            child: UiPageLayout(
              title: 'Sessions',
              actions: [Text('Refresh')],
              body: Text('Session list'),
            ),
          ),
        ),
      );

      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Session list'), findsOneWidget);
    });

    testWidgets('places semantic parts responsively', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 1000,
            height: 640,
            child: UiPageLayout(
              filters: Text('Filters'),
              body: Text('Results'),
              secondary: Text('Inspector'),
            ),
          ),
        ),
      );

      final filters = tester.getTopLeft(find.text('Filters'));
      final results = tester.getTopLeft(find.text('Results'));
      final inspector = tester.getTopLeft(find.text('Inspector'));

      expect(filters.dx, lessThan(results.dx));
      expect(results.dx, lessThan(inspector.dx));
    });
  });

  group('UiFormPage', () {
    testWidgets('renders form chrome, fields, footer, and actions',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 390,
            height: 700,
            child: UiFormPage(
              title: 'Reset password',
              hero: Text('Illustration'),
              footer: Text('Code expires soon'),
              actions: [
                Text('Send code'),
              ],
              children: [
                Text('Phone field'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Reset password'), findsOneWidget);
      expect(find.text('Illustration'), findsOneWidget);
      expect(find.text('Phone field'), findsOneWidget);
      expect(find.text('Code expires soon'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
    });

    testWidgets('keeps the form column within the configured max width',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 900,
            height: 700,
            child: UiFormPage(
              maxWidth: 320,
              children: [
                SizedBox(width: double.infinity, child: Text('Field')),
              ],
            ),
          ),
        ),
      );

      final fieldWidth = tester.getSize(find.text('Field')).width;
      expect(fieldWidth, lessThanOrEqualTo(320));
    });
  });

  group('UiCollectionPage', () {
    testWidgets('renders title, actions, and list items', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 390,
            height: 700,
            child: UiCollectionPage<String>(
              title: 'Sessions',
              actions: const [Text('Refresh')],
              items: const ['Intro', 'Review'],
              itemBuilder: (context, item, index) => Text(item),
            ),
          ),
        ),
      );

      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Intro'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
    });

    testWidgets('renders empty state when the collection is empty',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 390,
            height: 700,
            child: UiCollectionPage<String>(
              items: const [],
              emptyTitle: 'No sessions yet',
              itemBuilder: (context, item, index) => Text(item),
            ),
          ),
        ),
      );

      expect(find.text('No sessions yet'), findsOneWidget);
    });

    testWidgets('adaptiveGrid uses grid placement on wide viewports',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 900,
            height: 700,
            child: UiCollectionPage<String>(
              layout: UiCollectionLayout.adaptiveGrid,
              gridMaxCrossAxisExtent: 300,
              items: const ['One', 'Two'],
              itemBuilder: (context, item, index) => Text(item),
            ),
          ),
        ),
      );

      final first = tester.getTopLeft(find.text('One'));
      final second = tester.getTopLeft(find.text('Two'));
      expect((first.dy - second.dy).abs(), lessThan(24));
      expect(first.dx, lessThan(second.dx));
    });
  });

  group('UiSettingsList', () {
    testWidgets('renders grouped settings items and footer', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 390,
            height: 700,
            child: UiSettingsList(
              groups: [
                UiSettingsGroup(
                  title: 'Account',
                  footer: 'Need help?',
                  items: [
                    UiSettingsItem(
                      label: 'Devices',
                      leading: Icon(Icons.devices_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Devices'), findsOneWidget);
      expect(find.text('Need help?'), findsOneWidget);
    });

    testWidgets('selects an item by id through the list callback',
        (tester) async {
      String? selected;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 390,
            height: 700,
            child: UiSettingsList(
              selectedItemId: selected,
              onItemSelected: (id) => selected = id,
              groups: const [
                UiSettingsGroup(
                  items: [
                    UiSettingsItem(id: 'devices', label: 'Devices'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Devices'));
      expect(selected, 'devices');
    });

    testWidgets('selected item uses the standard card variant on desktop',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 900,
            height: 700,
            child: UiSettingsList(
              selectedItemId: 'devices',
              groups: [
                UiSettingsGroup(
                  items: [
                    UiSettingsItem(id: 'devices', label: 'Devices'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      final card = tester.widget<UiCard>(
        find.ancestor(of: find.text('Devices'), matching: find.byType(UiCard)),
      );
      expect(card.variant, UiCardVariant.standard);
    });

    testWidgets('renders item descriptions, trailing controls, and actions',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 390,
            height: 700,
            child: UiSettingsList(
              groups: [
                UiSettingsGroup(
                  items: [
                    UiSettingsItem(
                      label: 'Notifications',
                      description: 'Allow in-app notification delivery.',
                      leading: Icon(Icons.notifications_active_rounded),
                      trailing: Text('Switch'),
                      actions: [
                        Text('System settings'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Allow in-app notification delivery.'), findsOneWidget);
      expect(find.text('Switch'), findsOneWidget);
      expect(find.text('System settings'), findsOneWidget);
    });
  });

  group('UiProfileSummary', () {
    testWidgets('renders initials avatar and name', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 390,
            height: 320,
            child: UiProfileSummary(name: 'Ada Lovelace'),
          ),
        ),
      );

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('AL'), findsOneWidget);
    });

    testWidgets('renders custom avatar, subtitle, and actions', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 390,
            height: 360,
            child: UiProfileSummary(
              name: 'Grace Hopper',
              subtitle: 'Teacher',
              avatar: Text('GH'),
              actions: [
                Text('Edit'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('GH'), findsOneWidget);
      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('Teacher'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });
  });

  group('UiAsyncState', () {
    testWidgets('section icons inherit muted color in dark mode',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          theme: UiThemeData.light(),
          darkTheme: UiThemeData.dark(),
          home: const Scaffold(
            body: UiEmptyState(
              mode: UiAsyncStateMode.section,
              icon: Icon(Icons.calendar_today, key: Key('section-icon')),
              title: 'No sessions',
            ),
          ),
        ),
      );

      final iconContext = tester.element(find.byKey(const Key('section-icon')));
      expect(IconTheme.of(iconContext).color, UiColorTokens.dark.textMuted);
    });
  });

  group('Environment widgets', () {
    testWidgets('UiPageScaffold applies system bars annotation',
        (tester) async {
      await tester.pumpWidget(
        _host(const UiPageScaffold(body: Text('body'))),
      );

      expect(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        findsWidgets,
      );
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets(
        'UiPageScaffold paints background full-bleed under the status bar',
        (tester) async {
      // Regression: if the scaffold painted its background *inside* the
      // SafeArea, the strip above the safe area would fall through to
      // whatever sits behind the scaffold (producing a black band on
      // top of a light page). The background must wrap the SafeArea.
      const bg = Color(0xFF123456);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: UiPageScaffold(
              backgroundColor: bg,
              body: SizedBox.expand(),
            ),
          ),
        ),
      );
      // The outermost decorated box in the scaffold uses the full screen.
      final decorations =
          tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).toList();
      final fullBleed = decorations.firstWhere(
        (d) {
          if (d.decoration is! BoxDecoration) return false;
          final dec = d.decoration as BoxDecoration;
          if (dec.color != bg) return false;
          final rect = tester.getRect(find.byWidget(d));
          return rect.top == 0;
        },
        orElse: () => throw StateError('No full-bleed background found'),
      );
      final rect = tester.getRect(find.byWidget(fullBleed));
      expect(rect.top, 0,
          reason: 'Background must extend above the safe-area inset.');
    });

    testWidgets('UiPageScaffold respects bottom padding from MediaQuery',
        (tester) async {
      const bottomInset = 34.0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: UiPageScaffold(
              safeViewportMode: UiSafeViewportMode.all,
              scrollFade: false,
              body: Container(
                  key: const Key('body'), color: const Color(0xFFFF0000)),
            ),
          ),
        ),
      );
      final bodyRect = tester.getRect(find.byKey(const Key('body')));
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(bodyRect.bottom, lessThanOrEqualTo(screen.height - bottomInset));
    });

    testWidgets('UiPageScaffold defaults to full-bleed body fade with insets',
        (tester) async {
      const topInset = 44.0;
      const bottomInset = 34.0;
      const leftInset = 24.0;
      const rightInset = 18.0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(
              top: topInset,
              bottom: bottomInset,
              left: leftInset,
              right: rightInset,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: UiPageScaffold(
              safeViewportMode: UiSafeViewportMode.all,
              body: Builder(
                builder: (context) {
                  final insets = UiPageBodyInsets.of(context);
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          key: const Key('scroll_fade_body'),
                          color: const Color(0xFFFF0000),
                        ),
                      ),
                      Text('insets:${insets.top}/${insets.bottom}'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      final bodyRect =
          tester.getRect(find.byKey(const Key('scroll_fade_body')));
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(bodyRect.top, 0);
      expect(bodyRect.bottom, screen.height);
      expect(find.text('insets:$topInset/$bottomInset'), findsOneWidget);
      expect(find.byType(SafeArea), findsNothing);
    });

    testWidgets('UiPageBodyInsets does not inject horizontal page padding',
        (tester) async {
      const topInset = 44.0;
      const bottomInset = 34.0;
      const leftInset = 24.0;
      const rightInset = 18.0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(
              top: topInset,
              bottom: bottomInset,
              left: leftInset,
              right: rightInset,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: UiPageScaffold(
              body: Builder(
                builder: (context) {
                  final insets = UiPageBodyInsets.of(context);
                  return Text(
                    'insets:${insets.left}/${insets.top}/'
                    '${insets.right}/${insets.bottom}',
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(
          find.text('insets:0.0/$topInset/0.0/$bottomInset'), findsOneWidget);
    });

    testWidgets('UiPageScaffold scroll fade uses transparent page background',
        (tester) async {
      const bg = Color(0xFFFFFFFF);
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: UiPageScaffold(
            backgroundColor: bg,
            body: SizedBox.expand(),
          ),
        ),
      );

      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.gradient)
          .whereType<LinearGradient>()
          .toList();

      expect(gradients, isNotEmpty);
      expect(
        gradients.any(
          (gradient) => gradient.colors.last == bg.withValues(alpha: 0),
        ),
        isTrue,
        reason:
            'Light mode fade must not interpolate toward transparent black.',
      );
    });

    testWidgets('UiSafeViewport none does not inject SafeArea', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiSafeViewport(
            mode: UiSafeViewportMode.none,
            child: Text('x'),
          ),
        ),
      );

      expect(find.byType(SafeArea), findsNothing);
      expect(find.text('x'), findsOneWidget);
    });

    testWidgets('UiSafeViewport all consumes MediaQuery top inset',
        (tester) async {
      const topInset = 44.0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: topInset),
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: UiSafeViewport(
              mode: UiSafeViewportMode.all,
              child: Text('x'),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.text('x'));
      expect(rect.top, greaterThanOrEqualTo(topInset));
    });

    testWidgets(
        'UiSafeViewport keyboardAware applies keyboard inset instead of bottom',
        (tester) async {
      const keyboard = 280.0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 44, bottom: 34),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: UiSafeViewport(
              mode: UiSafeViewportMode.keyboardAware,
              child: Container(
                key: const Key('kbd'),
                color: const Color(0xFF00FF00),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),
      );
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final bottom = tester.getRect(find.byKey(const Key('kbd'))).bottom;
      // Child should be lifted by the keyboard height, not the home
      // indicator inset — so bottom sits around (screen - keyboard).
      expect(
        bottom,
        closeTo(screen.height - keyboard, 1.0),
      );
    });

    testWidgets(
        'UiSafeViewport keyboardAware preserves child state as keyboard toggles',
        (tester) async {
      var initCount = 0;
      var disposeCount = 0;

      Widget host(double keyboard) {
        return MediaQuery(
          data: MediaQueryData(
            padding: const EdgeInsets.only(top: 44, bottom: 34),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: UiSafeViewport(
              mode: UiSafeViewportMode.keyboardAware,
              child: _LifecycleProbe(
                onInit: () => initCount++,
                onDispose: () => disposeCount++,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(host(0));
      expect(initCount, 1);
      expect(disposeCount, 0);

      await tester.pumpWidget(host(280));
      expect(initCount, 1);
      expect(disposeCount, 0);

      await tester.pumpWidget(host(0));
      expect(initCount, 1);
      expect(disposeCount, 0);
    });

    testWidgets(
        'UiSafeViewport keyboardAware preserves UiInput focus as keyboard opens',
        (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      Widget host(double keyboard) {
        return MaterialApp(
          theme: UiThemeData.light(),
          home: MediaQuery(
            data: MediaQueryData(
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: Scaffold(
              body: UiSafeViewport(
                mode: UiSafeViewportMode.keyboardAware,
                child: UiInput(
                  focusNode: focusNode,
                  hint: 'Focused input',
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(host(0));
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.pumpWidget(host(280));
      expect(focusNode.hasFocus, isTrue);

      await tester.pumpWidget(host(0));
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('UiSystemBars.inferFromBackground picks dark icons on light bg',
        (tester) async {
      final style =
          UiSystemBarsStyle.inferFromBackground(const Color(0xFFFAFAFA));
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    });

    testWidgets('UiSystemBars.inferFromBackground picks light icons on dark bg',
        (tester) async {
      final style =
          UiSystemBarsStyle.inferFromBackground(const Color(0xFF0A0A0A));
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
    });

    testWidgets('UiSystemBars infers from ambient theme when both args null',
        (tester) async {
      SystemUiOverlayStyle? observed;
      await tester.pumpWidget(
        MaterialApp(
          theme: UiThemeData.dark(),
          home: UiSystemBars(
            child: Builder(
              builder: (ctx) {
                observed = (ctx.findAncestorWidgetOfExactType<
                        AnnotatedRegion<SystemUiOverlayStyle>>())
                    ?.value;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(observed, isNotNull);
      // Dark theme background → icons flip to light.
      expect(observed!.statusBarIconBrightness, Brightness.light);
    });

    testWidgets('UiSurfaceRegion syncs system bars when requested',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiSurfaceRegion(
            background: Color(0xFF101010),
            syncSystemBars: true,
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );
      final regions = tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .map((r) => r.value)
          .toList();
      expect(
        regions.any((s) => s.statusBarIconBrightness == Brightness.light),
        isTrue,
      );
    });
  });

  group('Navigation scaffold', () {
    const spec = UiNavigationSpec(
      title: 'Inbox',
      subtitle: 'Recent conversations',
    );

    testWidgets('UiSliverNavigationBar builds inside CustomScrollView',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const CustomScrollView(
            slivers: [
              UiSliverNavigationBar(spec: spec),
              SliverToBoxAdapter(
                child: SizedBox(height: 600, child: Text('content')),
              ),
            ],
          ),
        ),
      );

      expect(find.byType(UiSliverNavigationBar), findsOneWidget);
      // At rest the large title is visible; compact may be present too
      // but hidden via Opacity(0) — we assert the text is rendered at
      // least once in the bar.
      expect(find.text('Inbox'), findsWidgets);
    });

    testWidgets('UiSliverNavigationBar default surface is frosted on iOS',
        (tester) async {
      const nav = CustomScrollView(
        slivers: [
          UiSliverNavigationBar(spec: spec),
          SliverToBoxAdapter(child: SizedBox(height: 300)),
        ],
      );

      final previous = debugDefaultTargetPlatformOverride;
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await tester.pumpWidget(
          _host(nav),
        );
        expect(
          find.byType(BackdropFilter),
          findsWidgets,
          reason: 'iOS default should resolve adaptive surface to blurred.',
        );
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    });

    testWidgets(
        'UiSliverNavigationBar default surface is solid on non-iOS platforms',
        (tester) async {
      const nav = CustomScrollView(
        slivers: [
          UiSliverNavigationBar(spec: spec),
          SliverToBoxAdapter(child: SizedBox(height: 300)),
        ],
      );

      final previous = debugDefaultTargetPlatformOverride;
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await tester.pumpWidget(
          _host(nav),
        );
        expect(
          find.byType(BackdropFilter),
          findsNothing,
          reason:
              'Non-iOS default should resolve adaptive surface to solid (no blur).',
        );
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    });

    testWidgets('collapse progress morphs title size in large-title mode',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          CustomScrollView(
            controller: controller,
            slivers: const [
              UiSliverNavigationBar(spec: spec),
              SliverToBoxAdapter(
                child: SizedBox(height: 2000, child: Text('content')),
              ),
            ],
          ),
        ),
      );

      double maxInboxFontSize() {
        final textWidgets =
            tester.widgetList<Text>(find.text('Inbox')).toList();
        return textWidgets
            .map((t) => t.style?.fontSize ?? 0)
            .fold<double>(0, (m, v) => v > m ? v : m);
      }

      final restSize = maxInboxFontSize();
      expect(restSize, greaterThan(20));

      // Scroll enough to collapse the bar fully.
      controller.jumpTo(80);
      await tester.pump();

      final collapsedSize = maxInboxFontSize();
      expect(
        collapsedSize,
        lessThan(restSize),
        reason: 'Large title should collapse down to compact title size.',
      );
    });

    testWidgets('subtitle renders for both large and compact configurations',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const CustomScrollView(
            slivers: [
              UiSliverNavigationBar(spec: spec),
              SliverToBoxAdapter(
                child: SizedBox(height: 400, child: Text('content')),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Recent conversations'), findsWidgets);

      const compactSpec = UiNavigationSpec(
        title: 'Inbox',
        subtitle: 'Recent conversations',
        largeTitle: false,
      );

      await tester.pumpWidget(
        _host(
          const CustomScrollView(
            slivers: [
              UiSliverNavigationBar(spec: compactSpec),
              SliverToBoxAdapter(
                child: SizedBox(height: 400, child: Text('content')),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Recent conversations'), findsOneWidget);
    });

    testWidgets(
        'UiSliverNavigationBar publishes an annotated region that '
        'picks icon brightness from the surface', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          theme: UiThemeData.dark(),
          darkTheme: UiThemeData.dark(),
          home: const Scaffold(
            body: CustomScrollView(
              slivers: [
                UiSliverNavigationBar(spec: spec),
                SliverToBoxAdapter(child: SizedBox(height: 400)),
              ],
            ),
          ),
        ),
      );
      final styles = tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .map((r) => r.value)
          .toList();
      // Dark theme → bar surface is dark → status-bar icons should be light.
      expect(
        styles.any((s) => s.statusBarIconBrightness == Brightness.light),
        isTrue,
      );
    });

    testWidgets('UiPageScaffold + paintTopInsetWithTopBar paints inset',
        (tester) async {
      const topInset = 44.0;
      const insetColor = Color(0xFFABCDEF);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: topInset)),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: UiPageScaffold(
              paintTopInsetWithTopBar: true,
              topInsetColor: insetColor,
              topBar: SizedBox(height: 48, child: Text('bar')),
              body: SizedBox.expand(),
            ),
          ),
        ),
      );
      // The dedicated inset strip paints with the given color.
      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(
        decorations.any((d) => d.color == insetColor),
        isTrue,
      );
    });

    testWidgets('UiNavigationStack swaps children with a keyed transition',
        (tester) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, setState) => Column(
              children: [
                SizedBox(
                  height: 120,
                  child: UiNavigationStack(
                    index: index,
                    children: const [
                      Center(child: Text('page-a')),
                      Center(child: Text('page-b')),
                    ],
                  ),
                ),
                UiButton(
                  label: 'next',
                  onPressed: () => setState(() => index = 1),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('page-a'), findsOneWidget);
      expect(find.text('page-b'), findsNothing);

      await tester.tap(find.text('next'));
      await tester.pump();
      // Both pages briefly coexist during the transition.
      expect(find.text('page-b'), findsWidgets);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('page-a'), findsNothing);
      expect(find.text('page-b'), findsOneWidget);
    });

    testWidgets('UiNavigationScope exposes the spec to descendants',
        (tester) async {
      UiNavigationSpec? observed;
      await tester.pumpWidget(
        _host(
          UiNavigationScope(
            spec: spec,
            child: Builder(
              builder: (ctx) {
                observed = UiNavigationScope.of(ctx);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(observed, equals(spec));
    });

    testWidgets('UiNavigationScope.maybeOf returns null when absent',
        (tester) async {
      UiNavigationSpec? observed = spec;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (ctx) {
              observed = UiNavigationScope.maybeOf(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(observed, isNull);
    });

    testWidgets(
      'spec with a back button forces inline title (no hero morph)',
      (tester) async {
        var backPresses = 0;
        final specWithBack = UiNavigationSpec(
          title: 'Detail',
          subtitle: 'Sample',
          largeTitle: true,
          back: UiNavigationBackConfig(
            label: 'Inbox',
            onPressed: () => backPresses++,
          ),
        );

        await tester.pumpWidget(
          _host(
            CustomScrollView(
              slivers: [
                UiSliverNavigationBar(spec: specWithBack),
                const SliverToBoxAdapter(child: SizedBox(height: 400)),
              ],
            ),
          ),
        );

        // Title appears exactly once (inline). No duplicate hero copy.
        expect(find.text('Detail'), findsOneWidget);
        // Back label is rendered and wired up.
        expect(find.text('Inbox'), findsOneWidget);
        await tester.tap(find.text('Inbox'));
        await tester.pump();
        expect(backPresses, 1);

        // With a back button, the bar pins at the collapsed height —
        // no expanded mode exists for it to grow into. We check the
        // AnnotatedRegion the bar wraps its paint box with; its size
        // reflects the sliver's laid-out extent.
        final barBox = tester.getRect(
          find
              .descendant(
                of: find.byType(UiSliverNavigationBar),
                matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
              )
              .first,
        );
        expect(
          barBox.height,
          lessThan(70),
          reason: 'Back-button bars should pin at the compact height.',
        );
      },
    );

    testWidgets('UiSliverNavigationBar resolves brand logo from spec',
        (tester) async {
      const brand = UiBrand(
        id: 'acme',
        displayName: 'Acme App',
        primary: Color(0xFF2451FF),
        onPrimary: Color(0xFFFFFFFF),
        logo: Text('sliver-light-logo'),
        darkLogo: Text('sliver-dark-logo'),
      );

      const lightSpec = UiNavigationSpec(
        title: 'Library',
        largeTitle: false,
        brand: brand,
      );

      await tester.pumpWidget(
        _host(
          const CustomScrollView(
            slivers: [
              UiSliverNavigationBar(spec: lightSpec),
              SliverToBoxAdapter(child: SizedBox(height: 500)),
            ],
          ),
        ),
      );
      expect(find.text('sliver-light-logo'), findsOneWidget);
      expect(find.text('sliver-dark-logo'), findsNothing);

      const darkSpec = UiNavigationSpec(
        title: 'Library',
        largeTitle: false,
        brand: brand,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: UiThemeData.dark(),
          home: const Scaffold(
            body: CustomScrollView(
              slivers: [
                UiSliverNavigationBar(spec: darkSpec),
                SliverToBoxAdapter(child: SizedBox(height: 500)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('sliver-light-logo'), findsNothing);
      expect(find.text('sliver-dark-logo'), findsOneWidget);
    });
  });
}
