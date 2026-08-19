import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: UiTheme(
      tokens: UiThemeData.light(effects: UiEffectsTokens.full),
      child: Scaffold(body: Center(child: child)),
    ),
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

    testWidgets('compact composer supports context and an icon send action', (
      tester,
    ) async {
      final messages = <String>[];
      await tester.pumpWidget(
        _host(
          UiChatComposer(
            header: const Text('Replying to Alex'),
            compactSendAction: true,
            sendLabel: 'Send message',
            onSend: messages.add,
          ),
        ),
      );

      expect(find.text('Replying to Alex'), findsOneWidget);
      expect(find.bySemanticsLabel('Send message'), findsOneWidget);

      await tester.enterText(find.byType(UiInput), 'Hello');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send message'));
      await tester.pump();

      expect(messages, ['Hello']);
    });

    testWidgets('composer synchronizes when its controller is replaced', (
      tester,
    ) async {
      final empty = TextEditingController();
      final ready = TextEditingController(text: 'Ready');
      addTearDown(empty.dispose);
      addTearDown(ready.dispose);
      final messages = <String>[];

      await tester.pumpWidget(
        _host(UiChatComposer(controller: empty, onSend: messages.add)),
      );
      await tester.pumpWidget(
        _host(UiChatComposer(controller: ready, onSend: messages.add)),
      );
      await tester.tap(find.text('Send'));
      await tester.pump();

      expect(messages, ['Ready']);
      expect(ready.text, isEmpty);

      await tester.pumpWidget(
        _host(UiChatComposer(controller: empty, onSend: messages.add)),
      );
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(messages, ['Ready']);

      await tester.pumpWidget(const SizedBox.shrink());
      ready.text = 'Changed after composer disposal';
      await tester.pump();
      expect(tester.takeException(), isNull);
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
      expect(find.byKey(const Key('ui_page_top_bar_shadow')), findsOneWidget);
      expect(
        find.byKey(const Key('ui_page_bottom_bar_shadow')),
        findsOneWidget,
      );
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
          home: UiTheme(
            tokens: UiThemeData.dark(),
            child: const Scaffold(
              body: UiAppBar(
                title: 'Courses',
                brand: brand,
              ),
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

    testWidgets('keeps its generated title below the system top inset',
        (tester) async {
      const topInset = 59.0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: topInset),
            ),
            child: const UiPageLayout(
              title: 'Safe title',
              body: SizedBox.expand(),
            ),
          ),
        ),
      );

      expect(
        tester.getRect(find.text('Safe title')).top,
        greaterThanOrEqualTo(topInset),
      );
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

    testWidgets('grid accepts a fixed main-axis extent', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 900,
            height: 700,
            child: UiCollectionPage<String>(
              layout: UiCollectionLayout.grid,
              gridMaxCrossAxisExtent: 300,
              gridMainAxisExtent: 180,
              items: const ['One', 'Two'],
              itemBuilder: (context, item, index) => SizedBox.expand(
                key: ValueKey(item),
                child: Text(item),
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(const ValueKey('One'))).height, 180);
      expect(tester.getSize(find.byKey(const ValueKey('Two'))).height, 180);
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

      expect(find.text('Account'), findsOneWidget);
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

    testWidgets('settings group uses a standard surface on desktop',
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

      final cards = tester.widgetList<UiCard>(
        find.ancestor(of: find.text('Devices'), matching: find.byType(UiCard)),
      );
      expect(
        cards.map((card) => card.variant),
        contains(UiCardVariant.standard),
      );
    });

    testWidgets('selected rows absorb adjacent separators', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 390,
            height: 700,
            child: UiSettingsList(
              groups: [
                UiSettingsGroup(
                  items: [
                    UiSettingsItem(label: 'English'),
                    UiSettingsItem(
                      label: 'Español',
                      selected: true,
                      showSelectedOnPhone: true,
                    ),
                    UiSettingsItem(label: 'Français'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(UiDivider), findsNothing);
      expect(
        find.byKey(const ValueKey('ui-settings-selected-separator-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ui-settings-selected-separator-2')),
        findsOneWidget,
      );
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
    testWidgets('renders generated avatar and name', (tester) async {
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
      expect(find.byType(UiWavatar), findsOneWidget);
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
          home: UiTheme(
            tokens: UiThemeData.dark(),
            child: const Scaffold(
              body: UiEmptyState(
                mode: UiAsyncStateMode.section,
                icon: Icon(Icons.calendar_today, key: Key('section-icon')),
                title: 'No sessions',
              ),
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
        'UiPageScaffold uses opaque fade backing for transparent system bars',
        (tester) async {
      const darkBacking = Color(0xFF101214);
      await tester.pumpWidget(
        _host(
          const UiPageScaffold(
            backgroundColor: Color(0x00000000),
            scrollFadeBackgroundColor: darkBacking,
            body: Text('body'),
          ),
        ),
      );

      final annotation = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(UiPageScaffold),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );

      expect(annotation.value.statusBarIconBrightness, Brightness.light);
      expect(
        annotation.value.systemNavigationBarIconBrightness,
        Brightness.light,
      );
    });

    testWidgets(
        'UiPageScaffold bleeds vertically and stays horizontally safe by default',
        (tester) async {
      const topInset = 59.0;
      const bottomInset = 34.0;
      const leftInset = 47.0;
      const rightInset = 31.0;
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
                  return Stack(
                    children: [
                      const Positioned.fill(
                        child: SizedBox(key: Key('safe-body')),
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

      final bodyRect = tester.getRect(find.byKey(const Key('safe-body')));
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(bodyRect.top, 0);
      expect(bodyRect.bottom, screen.height);
      expect(bodyRect.left, leftInset);
      expect(bodyRect.right, screen.width - rightInset);
      expect(find.text('insets:$topInset/$bottomInset'), findsOneWidget);
    });

    testWidgets('UiPageScaffold keeps its default top bar below the top inset',
        (tester) async {
      const topInset = 59.0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: topInset),
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: UiPageScaffold(
              topBar: SizedBox(
                key: Key('safe-top-bar'),
                height: 48,
                child: Text('Safe top bar'),
              ),
              body: SizedBox.expand(),
            ),
          ),
        ),
      );

      expect(
        tester.getRect(find.byKey(const Key('safe-top-bar'))).top,
        greaterThanOrEqualTo(topInset),
      );
    });

    testWidgets('UiPageScaffold allows an explicit full-bleed opt-out',
        (tester) async {
      const topInset = 59.0;
      const leftInset = 47.0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: topInset, left: leftInset),
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: UiPageScaffold(
              safeViewportMode: UiSafeViewportMode.none,
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  key: Key('full-bleed-body'),
                  width: 10,
                  height: 10,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getRect(find.byKey(const Key('full-bleed-body'))).top,
        0,
      );
      expect(
        tester.getRect(find.byKey(const Key('full-bleed-body'))).left,
        0,
      );
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

    testWidgets('UiPageScaffold can move safe insets into a full-bleed fade',
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
              scrollFadeUsesSafeArea: true,
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
      expect(bodyRect.left, leftInset);
      expect(bodyRect.right, screen.width - rightInset);
      expect(find.text('insets:$topInset/$bottomInset'), findsOneWidget);
      expect(find.byType(SafeArea), findsOneWidget);
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
              scrollFadeUsesSafeArea: true,
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

    testWidgets('UiPageScaffold scroll fade is full-width by default',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: UiPageScaffold(body: SizedBox.expand()),
        ),
      );

      final scaffold = tester.widget<UiPageScaffold>(
        find.byType(UiPageScaffold),
      );
      expect(scaffold.scrollFadeHorizontalInset, 0);
      expect(scaffold.scrollFadeUsesSafeArea, isTrue);
      expect(
        scaffold.scrollFadeBottomExtent,
        lessThan(scaffold.scrollFadeExtent),
      );

      final fade = tester.widget<UiScrollEdgeFade>(
        find.byType(UiScrollEdgeFade),
      );
      expect(fade.topExtent ?? fade.extent, scaffold.scrollFadeWideExtent);
      expect(fade.bottomExtent, scaffold.scrollFadeBottomExtent);
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
          home: UiTheme(
            tokens: UiThemeData.dark(),
            child: UiSystemBars(
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

    testWidgets(
        'title-following actions stay end aligned and pin without fading',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          CustomScrollView(
            controller: controller,
            slivers: [
              UiSliverNavigationBar(
                spec: const UiNavigationSpec(
                  title: 'Chats',
                  actionsFollowTitleCollapse: true,
                  actions: [
                    SizedBox(
                      key: Key('tracked-title-action'),
                      width: 44,
                      height: 44,
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1000)),
            ],
          ),
        ),
      );

      expect(
        find.byKey(const Key('ui_navigation_large_title_shadow')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ui_navigation_tracking_actions_shadow')),
        findsOneWidget,
      );

      final resting = tester.getTopRight(
        find.byKey(const Key('tracked-title-action')),
      );
      controller.jumpTo(24);
      await tester.pump();
      final moving = tester.getTopRight(
        find.byKey(const Key('tracked-title-action')),
      );
      controller.jumpTo(200);
      await tester.pump();
      final pinned = tester.getTopRight(
        find.byKey(const Key('tracked-title-action')),
      );
      controller.jumpTo(260);
      await tester.pump();
      final stillPinned = tester.getTopRight(
        find.byKey(const Key('tracked-title-action')),
      );

      expect(moving.dx, resting.dx);
      expect(moving.dy, lessThan(resting.dy));
      expect(stillPinned, pinned);
    });

    testWidgets('UiSliverNavigationBar adaptive default is platform-neutral',
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
        expect(find.byType(UiScrollEdgeFade), findsNothing);
        expect(find.byType(BackdropFilter), findsNothing);
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

    testWidgets('collapse triggers a snappy time-based title crossfade',
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

      expect(
        find.byKey(const Key('ui_navigation_large_title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ui_navigation_compact_title')),
        findsNothing,
      );

      final restTop = tester
          .getRect(find.byKey(const Key('ui_navigation_large_title')))
          .top;
      controller.jumpTo(20);
      await tester.pump();
      final scrolledTop = tester
          .getRect(find.byKey(const Key('ui_navigation_large_title')))
          .top;
      expect(scrolledTop, lessThan(restTop));
      expect(
        find.byKey(const Key('ui_navigation_compact_title')),
        findsNothing,
      );

      // Crossing the handoff point starts one short, time-based crossfade.
      controller.jumpTo(22);
      await tester.pump();

      final largeFade = tester.widget<TweenAnimationBuilder<double>>(
        find.byKey(const Key('ui_navigation_large_title_fade')),
      );
      final compactFade = tester.widget<AnimatedSwitcher>(
        find.byKey(const Key('ui_navigation_compact_title_fade')),
      );
      expect(largeFade.tween.end, 0);
      expect(largeFade.duration, const Duration(milliseconds: 96));
      expect(compactFade.duration, const Duration(milliseconds: 96));
      expect(
        find.byKey(const Key('ui_navigation_large_title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ui_navigation_compact_title')),
        findsOneWidget,
      );

      // The scroll position stays fixed while the crossfade completes.
      await tester.pump(const Duration(milliseconds: 48));
      final compactOpacity = tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(const Key('ui_navigation_compact_title')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      final largeOpacity = tester
          .widget<Opacity>(
            find.descendant(
              of: find.byKey(const Key('ui_navigation_large_title_fade')),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      expect(compactOpacity, inExclusiveRange(0, 1));
      expect(largeOpacity, inExclusiveRange(0, 1));
      expect(
        find.descendant(
          of: find.byKey(const Key('ui_navigation_large_title_fade')),
          matching: find.byType(ImageFiltered),
        ),
        findsOneWidget,
      );
      expect(controller.offset, 22);

      await tester.pump(const Duration(milliseconds: 48));
      final compactShadow = tester.widget<UiLegibilityShadow>(
        find
            .ancestor(
              of: find.byKey(const Key('ui_navigation_compact_title')),
              matching: find.byType(UiLegibilityShadow),
            )
            .first,
      );
      expect(compactShadow.blurSigma, greaterThan(2));
      expect(compactShadow.spreadRadius, greaterThan(0.5));

      // Re-crossing the threshold reverses the same brief handoff.
      controller.jumpTo(20);
      await tester.pump();
      expect(
        tester
            .widget<TweenAnimationBuilder<double>>(
              find.byKey(const Key('ui_navigation_large_title_fade')),
            )
            .tween
            .end,
        1,
      );
      await tester.pump(const Duration(milliseconds: 48));
      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: find.byKey(const Key('ui_navigation_large_title_fade')),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ui_navigation_compact_title')),
        findsNothing,
      );
    });

    testWidgets('UiSliverNavigationBar stays pinned for the full scroll view',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          CustomScrollView(
            controller: controller,
            slivers: const [
              UiSliverNavigationBar(spec: spec),
              SliverToBoxAdapter(child: SizedBox(height: 2000)),
            ],
          ),
        ),
      );

      controller.jumpTo(600);
      await tester.pump();

      final titleRect = tester.getRect(
        find.byKey(const Key('ui_navigation_compact_title')),
      );
      expect(titleRect.bottom, greaterThan(0));
      expect(titleRect.top, lessThan(tester.view.physicalSize.height));
    });

    testWidgets(
        'UiSliverNavigationBar becomes a quiet page header beside a rail',
        (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Widget host() {
        return _host(
          const UiResponsiveNavigationScaffold(
            sidebar: SizedBox(width: 96, child: Text('rail')),
            body: CustomScrollView(
              slivers: [
                UiSliverNavigationBar(
                  spec: UiNavigationSpec(
                    title: 'Library',
                    subtitle: 'Browse resources',
                    surface: UiNavigationSurface.blurred,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 1200)),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(host());

      expect(find.text('Library'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(SliverPersistentHeader), findsNothing);

      tester.view.physicalSize = const Size(390, 700);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(UiScrollEdgeFade), findsOneWidget);
      expect(find.byType(SliverPersistentHeader), findsOneWidget);
    });

    testWidgets(
        'UiSliverNavigationBar becomes a quiet page header on large screens',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const CustomScrollView(
            slivers: [
              UiSliverNavigationBar(
                spec: UiNavigationSpec(
                  title: 'Library',
                  subtitle: 'Browse resources',
                  surface: UiNavigationSurface.blurred,
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 1200)),
            ],
          ),
        ),
      );

      expect(find.text('Library'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(SliverPersistentHeader), findsNothing);
    });

    testWidgets('UiSliverStickyRegion stacks below the collapsed phone bar',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          CustomScrollView(
            controller: controller,
            slivers: const [
              UiSliverNavigationBar(
                spec: UiNavigationSpec(
                  title: 'Library',
                  surface: UiNavigationSurface.solid,
                ),
              ),
              UiSliverStickyRegion(
                extent: 52,
                child: Text('Search'),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 1600)),
            ],
          ),
        ),
      );

      controller.jumpTo(600);
      await tester.pumpAndSettle();

      final stickyRect = tester.getRect(
        find.byKey(const Key('ui_sliver_sticky_region_surface')),
      );
      expect(stickyRect.top, closeTo(52, 0.1));
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(
        find.byKey(const Key('ui_sliver_navigation_bar_shadow')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ui_sliver_sticky_region_shadow')),
        findsOneWidget,
      );
      final fade = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byKey(const Key('ui_sliver_sticky_region_fade')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(fade.opacity, 1);
    });

    testWidgets('UiSliverStickyRegion pins solid at the top beside a rail',
        (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          UiResponsiveNavigationScaffold(
            sidebar: const SizedBox(width: 96, child: Text('rail')),
            body: CustomScrollView(
              controller: controller,
              slivers: const [
                UiSliverNavigationBar(
                  spec: UiNavigationSpec(
                    title: 'Library',
                    surface: UiNavigationSurface.blurred,
                  ),
                ),
                UiSliverStickyRegion(
                  extent: 52,
                  child: Text('Search'),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 1600)),
              ],
            ),
          ),
        ),
      );

      controller.jumpTo(600);
      await tester.pumpAndSettle();

      final stickyRect = tester.getRect(
        find.byKey(const Key('ui_sliver_sticky_region_surface')),
      );
      expect(stickyRect.top, closeTo(0, 0.1));
      expect(find.byType(BackdropFilter), findsNothing);

      final surface = tester.widget<AnimatedContainer>(
        find.byKey(const Key('ui_sliver_sticky_region_surface')),
      );
      final decoration = surface.decoration! as BoxDecoration;
      expect(decoration.border!.bottom.color.a, 0);
    });

    testWidgets('subtitle renders only with the expanded large title',
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
      expect(find.text('Recent conversations'), findsOneWidget);

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

      expect(find.text('Recent conversations'), findsNothing);
    });

    testWidgets('compact title can differ from or omit the large title',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          CustomScrollView(
            controller: controller,
            slivers: const [
              UiSliverNavigationBar(
                spec: UiNavigationSpec(
                  title: 'Welcome, Albaraa',
                  compactTitle: 'Albaraa',
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 1000)),
            ],
          ),
        ),
      );
      controller.jumpTo(80);
      await tester.pump();
      expect(find.text('Albaraa'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const CustomScrollView(
            slivers: [
              UiSliverNavigationBar(
                spec: UiNavigationSpec(
                  title: 'Welcome, Albaraa',
                  showCompactTitle: false,
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 1000)),
            ],
          ),
        ),
      );
      expect(
        find.byKey(const Key('ui_navigation_compact_title')),
        findsNothing,
      );
    });

    testWidgets(
        'UiSliverNavigationBar publishes an annotated region that '
        'picks icon brightness from the surface', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UiTheme(
            tokens: UiThemeData.dark(),
            child: const Scaffold(
              body: CustomScrollView(
                slivers: [
                  UiSliverNavigationBar(spec: spec),
                  SliverToBoxAdapter(child: SizedBox(height: 400)),
                ],
              ),
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
            showLabel: true,
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
          home: UiTheme(
            tokens: UiThemeData.dark(),
            child: const Scaffold(
              body: CustomScrollView(
                slivers: [
                  UiSliverNavigationBar(spec: darkSpec),
                  SliverToBoxAdapter(child: SizedBox(height: 500)),
                ],
              ),
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
