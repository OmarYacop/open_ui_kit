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

Widget _reducedMotionHost(Widget child) {
  return MaterialApp(
    theme: UiThemeData.light(),
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: appChild ?? const SizedBox.shrink(),
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void _noop() {}

void main() {
  group('UiAvatar', () {
    testWidgets('renders initials from a display name', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiAvatar(name: 'Ada Lovelace'),
        ),
      );

      expect(find.text('AL'), findsOneWidget);
    });

    testWidgets('renders fallback icon when no name or image is provided',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiAvatar(),
        ),
      );

      expect(find.byIcon(Icons.account_circle_rounded), findsOneWidget);
    });

    testWidgets('can render without a border', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiAvatar(name: 'Ada Lovelace', showBorder: false),
        ),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(decorations.any((d) => d.border == null), isTrue);
    });

    testWidgets('renders a custom image widget before fallback content',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiAvatar(
            name: 'Ada Lovelace',
            image: Text('custom-avatar'),
          ),
        ),
      );

      expect(find.text('custom-avatar'), findsOneWidget);
      expect(find.text('AL'), findsNothing);
    });

    testWidgets('avatar group renders visible avatars and overflow',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiAvatarGroup(
            items: [
              UiAvatarEntry(name: 'Ada Lovelace'),
              UiAvatarEntry(name: 'Grace Hopper'),
              UiAvatarEntry(name: 'Katherine Johnson'),
            ],
            maxVisible: 2,
          ),
        ),
      );

      expect(find.text('AL'), findsOneWidget);
      expect(find.text('GH'), findsOneWidget);
      expect(find.text('KJ'), findsNothing);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('avatar group preserves directional overlap', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiAvatarGroup(
            items: [
              UiAvatarEntry(name: 'Ada Lovelace'),
              UiAvatarEntry(name: 'Grace Hopper'),
            ],
            size: 40,
            overlap: 12,
          ),
        ),
      );

      final first = tester.getTopLeft(find.text('AL'));
      final second = tester.getTopLeft(find.text('GH'));
      expect(second.dx, greaterThan(first.dx));
      expect(second.dx - first.dx, lessThan(40));
    });
  });

  group('UiMediaPreview', () {
    testWidgets('renders fallback when no image is provided', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiMediaPreview(
            width: 120,
            height: 80,
            fallback: Icon(Icons.insert_drive_file_rounded),
          ),
        ),
      );

      expect(find.byIcon(Icons.insert_drive_file_rounded), findsOneWidget);
    });

    testWidgets('renders custom image widget before fallback content',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiMediaPreview(
            image: Text('custom-media'),
            fallback: Text('fallback-media'),
          ),
        ),
      );

      expect(find.text('custom-media'), findsOneWidget);
      expect(find.text('fallback-media'), findsNothing);
    });

    testWidgets('applies fallback background color', (tester) async {
      const fallbackBg = Color(0x33112233);
      await tester.pumpWidget(
        _host(
          const UiMediaPreview(
            fallbackBackgroundColor: fallbackBg,
            fallback: Icon(Icons.image_rounded),
          ),
        ),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();

      expect(decorations.any((d) => d.color == fallbackBg), isTrue);
    });
  });

  group('UiButton', () {
    testWidgets('renders label and fires onPressed', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _host(
          UiButton(
            label: 'Click me',
            intent: UiIntent.primary,
            onPressed: () => tapped++,
          ),
        ),
      );
      expect(find.text('Click me'), findsOneWidget);
      await tester.tap(find.text('Click me'));
      expect(tapped, 1);
    });

    testWidgets('primary variant uses theme primary background',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiButton(
            label: 'Go',
            intent: UiIntent.primary,
            onPressed: () {},
          ),
        ),
      );
      final deco = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(
        deco.any((d) => d.color == UiColorTokens.light.primary),
        isTrue,
      );
    });

    testWidgets(
        'defaultIntent renders as primary (alias, PR-A semantic change)',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiButton(
            label: 'Default',
            // Explicit to document the intent — omitting it yields
            // the same result since defaultIntent is the enum default.
            intent: UiIntent.defaultIntent,
            onPressed: () {},
          ),
        ),
      );
      final deco = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(
        deco.any((d) => d.color == UiColorTokens.light.primary),
        isTrue,
        reason: 'UiIntent.defaultIntent must resolve to the primary palette '
            'on UiButton.',
      );
    });

    testWidgets('neutral variant preserves the calm outlined surface look',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiButton(
            label: 'Neutral',
            intent: UiIntent.neutral,
            onPressed: () {},
          ),
        ),
      );
      final deco = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();
      // Neutral must NOT paint primary, and must render a surface fill.
      expect(
        deco.any((d) => d.color == UiColorTokens.light.primary),
        isFalse,
      );
      expect(
        deco.any((d) => d.color == UiColorTokens.light.surface),
        isTrue,
      );
      expect(
        deco
            .where((d) => d.color == UiColorTokens.light.surface)
            .any((d) => d.border != null),
        isTrue,
      );
    });

    testWidgets('applies optional button shadow to the button surface',
        (tester) async {
      const shadow = [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ];
      await tester.pumpWidget(
        _host(
          UiButton(
            label: 'Shadow',
            boxShadow: shadow,
            onPressed: () {},
          ),
        ),
      );

      final deco = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();

      expect(deco.any((d) => d.boxShadow == shadow), isTrue);
    });

    testWidgets('secondary pressed state keeps a single outlined surface',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiButton(
            label: 'Secondary',
            intent: UiIntent.secondary,
            onPressed: () {},
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Secondary')),
      );
      await tester.pump();

      final pressedSecondary = HSLColor.fromColor(UiColorTokens.light.secondary)
          .withLightness(
            (HSLColor.fromColor(UiColorTokens.light.secondary).lightness - 0.08)
                .clamp(0.0, 1.0),
          )
          .toColor();
      final matchingSurfaces = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == pressedSecondary)
          .toList();

      expect(matchingSurfaces.length, 1);
      expect(
        matchingSurfaces.single.border,
        isNotNull,
      );
      expect(
        matchingSurfaces.single.boxShadow,
        isNull,
      );

      await gesture.up();
    });

    testWidgets('showBorder=false suppresses secondary button outline',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiButton(
            label: 'Floating secondary',
            intent: UiIntent.secondary,
            showBorder: false,
            onPressed: () {},
          ),
        ),
      );

      final deco = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();

      expect(
        deco.any((d) => d.color == UiColorTokens.light.secondary),
        isTrue,
      );
      expect(deco.any((d) => d.border != null), isFalse);
    });

    testWidgets('disabled button rejects taps', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _host(
          UiButton(
            label: 'Off',
            onPressed: null,
          ),
        ),
      );
      await tester.tap(find.text('Off'));
      expect(tapped, 0);
    });

    testWidgets('loading state shows a spinner in place of label',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiButton(
            label: 'Save',
            loading: true,
            onPressed: () {},
          ),
        ),
      );
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('lg is visibly larger than sm along the size scale',
        (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              UiButton(label: 'SM', size: UiSize.sm, onPressed: () {}),
              UiButton(label: 'LG', size: UiSize.lg, onPressed: () {}),
            ],
          ),
        ),
      );
      // Compare the outer button tap rects. The small button bottoms out at
      // the 44pt tap-target floor, while the large button grows beyond it.
      final smRect = tester.getRect(find.text('SM'));
      final lgRect = tester.getRect(find.text('LG'));
      // Large uses bodyLg typography which has a bigger font size than
      // small (caption), so the rendered text height differs.
      expect(lgRect.height, greaterThan(smRect.height));
    });

    testWidgets('ghost button shows pressed feedback via backdrop shift',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiButton(label: 'Ghost', intent: UiIntent.ghost, onPressed: () {}),
        ),
      );

      BoxDecoration? ghostDecoration() {
        final boxes = tester.widgetList<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        for (final box in boxes) {
          final decoration = box.decoration;
          if (decoration is BoxDecoration &&
              decoration.color != null &&
              decoration.borderRadius != null) {
            return decoration;
          }
        }
        return null;
      }

      // Idle ghost = fully transparent background.
      expect(ghostDecoration()?.color?.a ?? 1, 0);

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Ghost')));
      await tester.pump(const Duration(milliseconds: 240));
      // Once pressed the ghost paints a muted surface backdrop so the
      // tap is visible even though the idle background is transparent.
      expect((ghostDecoration()?.color?.a ?? 0), greaterThan(0));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 240));
    });

    testWidgets('keyboard enter activates button through shortcuts/actions',
        (tester) async {
      var tapped = 0;
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        _host(
          UiButton(
            label: 'Keyboard',
            focusNode: node,
            onPressed: () => tapped++,
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(tapped, 1);
    });
  });

  group('UiIconButton', () {
    testWidgets('renders icon and fires onPressed', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _host(
          UiIconButton(
            icon: const Icon(Icons.more_vert_rounded),
            semanticsLabel: 'More actions',
            onPressed: () => tapped++,
          ),
        ),
      );

      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('More actions'));
      expect(tapped, 1);
    });

    testWidgets('custom colors render the configured surface', (tester) async {
      const bg = Color(0x33222222);
      const fg = Color(0xFFFFFFFF);
      await tester.pumpWidget(
        _host(
          const UiIconButton(
            icon: Icon(Icons.more_vert_rounded),
            semanticsLabel: 'More actions',
            backgroundColor: bg,
            foregroundColor: fg,
          ),
        ),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(decorations.any((d) => d.color == bg), isTrue);
    });

    testWidgets('accepts a custom border radius', (tester) async {
      const radius = BorderRadius.all(Radius.circular(999));

      await tester.pumpWidget(
        _host(
          const UiIconButton(
            icon: Icon(Icons.close_rounded),
            semanticsLabel: 'Close',
            borderRadius: radius,
          ),
        ),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();

      expect(decorations.any((d) => d.borderRadius == radius), isTrue);
    });

    testWidgets('ghost icon button paints pressed feedback', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiIconButton(
            icon: Icon(Icons.close_rounded),
            semanticsLabel: 'Close',
            onPressed: _noop,
          ),
        ),
      );

      BoxDecoration? iconDecoration() {
        for (final decoration in tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()) {
          if (decoration.borderRadius == UiRadiusTokens.standard.mdAll) {
            return decoration;
          }
        }
        return null;
      }

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.close_rounded)),
      );
      await tester.pump(const Duration(milliseconds: 240));

      expect((iconDecoration()?.color?.a ?? 0), greaterThan(0));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 240));
    });
  });

  group('UiInput', () {
    testWidgets('shows error text from prop', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiInput(
            label: 'Email',
            hint: 'you@example.com',
            errorText: 'Invalid email',
          ),
        ),
      );
      expect(find.text('Invalid email'), findsOneWidget);
    });

    testWidgets('disabled input uses muted surface', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiInput(
            label: 'Name',
            enabled: false,
          ),
        ),
      );
      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(
        decorations.any((d) => d.color == UiColorTokens.light.surfaceMuted),
        isTrue,
      );
    });

    testWidgets('validator sets internal error on validate()', (tester) async {
      final key = GlobalKey<UiInputState>();
      await tester.pumpWidget(
        _host(
          UiInput(
            key: key,
            initialValue: '',
            validator: (v) => v.isEmpty ? 'Required' : null,
          ),
        ),
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
    });
  });

  group('UiFilterChip', () {
    testWidgets('renders selected state with primary colors', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiFilterChip(label: 'Completed', selected: true),
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
      );
    });

    testWidgets('calls onSelected with the next value', (tester) async {
      bool? next;
      await tester.pumpWidget(
        _host(
          UiFilterChip(
            label: 'Completed',
            selected: false,
            onSelected: (value) => next = value,
          ),
        ),
      );

      await tester.tap(find.text('Completed'));
      expect(next, isTrue);
    });

    testWidgets('can render leading and trailing icons', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiFilterChip(
            label: 'Synced',
            selected: false,
            leading: Icon(Icons.filter_list_rounded),
            trailing: Icon(Icons.check_rounded),
          ),
        ),
      );

      expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('UiBadge', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(
        _host(const UiBadge(label: 'New', intent: UiIntent.primary)),
      );
      expect(find.text('New'), findsOneWidget);
    });

    testWidgets('renders leading and trailing icons', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiBadge(
            label: 'Group',
            leading: Icon(Icons.groups_rounded),
            trailing: Icon(Icons.check_rounded),
          ),
        ),
      );

      expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('custom color renders a tinted status badge', (tester) async {
      const status = Color(0xFF118844);
      await tester.pumpWidget(
        _host(
          const UiBadge(label: 'Active', color: status),
        ),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();

      expect(decorations.any((d) => d.color == status.withAlpha(30)), isTrue);
      expect(
        decorations.any((d) {
          final border = d.border;
          return border is Border && border.top.color == status.withAlpha(100);
        }),
        isTrue,
      );
    });

    testWidgets('explicit background color overrides badge recipes',
        (tester) async {
      const bg = Color(0x33FFFFFF);
      await tester.pumpWidget(
        _host(
          const UiBadge(
            label: '42.00',
            backgroundColor: bg,
            foregroundColor: Color(0xFFFFFFFF),
          ),
        ),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(decorations.any((d) => d.color == bg), isTrue);
    });

    testWidgets('accepts a custom border radius', (tester) async {
      const radius = BorderRadius.all(Radius.circular(6));

      await tester.pumpWidget(
        _host(
          const UiBadge(label: 'File', borderRadius: radius),
        ),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();

      expect(decorations.any((d) => d.borderRadius == radius), isTrue);
    });
  });

  group('UiTabs', () {
    testWidgets('fires onChanged with tapped index', (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, setState) => UiTabs(
              tabs: const [
                UiTab(label: 'One'),
                UiTab(label: 'Two'),
                UiTab(label: 'Three'),
              ],
              value: selected,
              onChanged: (i) => setState(() => selected = i),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Two'));
      await tester.pump();
      expect(selected, 1);
    });

    testWidgets('selected pill can be dragged to another tab', (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiTabs(
                tabs: const [
                  UiTab(label: 'One'),
                  UiTab(label: 'Two'),
                  UiTab(label: 'Three'),
                ],
                value: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.text('One'), const Offset(210, 0));
      await tester.pumpAndSettle();

      expect(selected, 2);
    });

    testWidgets(
        'drag leaving the pill zone cancels and does not change selection',
        (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiTabs(
                tabs: const [
                  UiTab(label: 'One'),
                  UiTab(label: 'Two'),
                  UiTab(label: 'Three'),
                ],
                value: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );

      final start = tester.getCenter(find.text('One'));
      final gesture = await tester.startGesture(start);
      // Jump far past the pill — pointer leaves the proposed pill zone and
      // the drag must cancel. Further moves must be ignored.
      await gesture.moveBy(const Offset(600, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-400, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(selected, 0);
    });

    testWidgets(
        'drag leaving the pill and re-entering tab bar away from pill does '
        'not change selection', (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiTabs(
                tabs: const [
                  UiTab(label: 'One'),
                  UiTab(label: 'Two'),
                  UiTab(label: 'Three'),
                ],
                value: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );

      final start = tester.getCenter(find.text('One'));
      final gesture = await tester.startGesture(start);
      // Escape horizontally far past the pill — tracking pauses.
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();
      // Return only partway — pointer is still clear of the frozen pill so
      // tracking stays paused. Vertical drift must not affect the state.
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(selected, 0);
    });

    testWidgets('in-pill drag that tracks the pill still changes selection',
        (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiTabs(
                tabs: const [
                  UiTab(label: 'One'),
                  UiTab(label: 'Two'),
                  UiTab(label: 'Three'),
                ],
                value: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );

      final start = tester.getCenter(find.text('One'));
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(selected, greaterThan(0));
    });

    testWidgets(
        'horizontal escape freezes pill and confirms nearest on release',
        (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiTabs(
                tabs: const [
                  UiTab(label: 'One'),
                  UiTab(label: 'Two'),
                  UiTab(label: 'Three'),
                ],
                value: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      double indicatorLeft() => (tester
                  .widget<AnimatedPositioned>(
                      find.byType(AnimatedPositioned).first)
                  .left ??
              0)
          .toDouble();

      final start = tester.getCenter(find.text('One'));
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      final trackedLeft = indicatorLeft();
      expect(trackedLeft, greaterThan(0));

      // Jump far past the pill — pointer escapes horizontally, pill freezes.
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();
      final frozenLeft = indicatorLeft();
      expect(frozenLeft, closeTo(trackedLeft, 0.5));

      // More horizontal motion while paused must not move the pill.
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      expect(indicatorLeft(), closeTo(frozenLeft, 0.5));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, greaterThan(0));
    });

    testWidgets('horizontal escape then catch-up resumes tracking',
        (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiTabs(
                tabs: const [
                  UiTab(label: 'One'),
                  UiTab(label: 'Two'),
                  UiTab(label: 'Three'),
                ],
                value: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final start = tester.getCenter(find.text('One'));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      // Escape horizontally — pill pauses.
      await gesture.moveBy(const Offset(400, 0));
      await tester.pump();
      // Catch up back to where the pill is frozen.
      await gesture.moveBy(const Offset(-430, 0));
      await tester.pump();
      // Resume tracking forward into a neighbour tab.
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(selected, greaterThan(0));
    });

    testWidgets('vertical drift while dragging does not pause tracking',
        (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiTabs(
                tabs: const [
                  UiTab(label: 'One'),
                  UiTab(label: 'Two'),
                  UiTab(label: 'Three'),
                ],
                value: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final start = tester.getCenter(find.text('One'));
      final gesture = await tester.startGesture(start);
      // Establish horizontal drag.
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      // Drift vertically — must not pause.
      await gesture.moveBy(const Offset(0, -120));
      await tester.pump();
      // Continue horizontal tracking.
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(selected, greaterThan(0));
    });

    testWidgets('selected slot expands while inactive slots stay compact',
        (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiTabs(
                tabs: const [
                  UiTab(label: 'Overview'),
                  UiTab(label: 'Notes'),
                  UiTab(label: 'Calendar'),
                ],
                value: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      List<double> slotWidths() => [
            for (var i = 0; i < 3; i++)
              tester.getSize(find.byKey(Key('ui_tabs_slot_$i'))).width,
          ];

      var widths = slotWidths();
      expect(widths[0], greaterThan(widths[1]));
      expect(widths[0], greaterThan(widths[2]));

      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      widths = slotWidths();
      expect(widths[2], greaterThan(widths[0]));
      expect(widths[2], greaterThan(widths[1]));
    });

    testWidgets('selected tab is capped at max width with long labels',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 900,
            child: UiTabs(
              tabs: const [
                UiTab(label: 'A'),
                UiTab(label: 'B'),
                UiTab(label: 'C'),
              ],
              value: 1,
              onChanged: (_) {},
              layout: UiTabsLayout.fill,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final widths = [
        for (var i = 0; i < 3; i++)
          tester.getSize(find.byKey(Key('ui_tabs_slot_$i'))).width,
      ];
      expect(widths[1], lessThanOrEqualTo(220.0 + 0.5));
      expect(widths[1], greaterThan(widths[0]));
      expect(widths[1], greaterThan(widths[2]));
    });

    testWidgets('inactive tabs keep their natural width when space permits',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 900,
            child: UiTabs(
              tabs: const [
                UiTab(label: 'Overview'),
                UiTab(label: 'Students'),
                UiTab(label: 'Assignments'),
              ],
              value: 0,
              onChanged: (_) {},
              layout: UiTabsLayout.fill,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final widths = [
        for (var i = 0; i < 3; i++)
          tester.getSize(find.byKey(Key('ui_tabs_slot_$i'))).width,
      ];
      // Inactive tabs exceed the legacy 72px cap — they now use natural
      // measured width instead of being squeezed.
      expect(widths[1], greaterThan(72.0));
      expect(widths[2], greaterThan(72.0));
    });

    testWidgets('very narrow host does not overflow and remains tappable',
        (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 180,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiTabs(
                tabs: const [
                  UiTab(label: 'One'),
                  UiTab(label: 'Two'),
                  UiTab(label: 'Three'),
                ],
                value: selected,
                onChanged: (i) => setState(() => selected = i),
                layout: UiTabsLayout.fill,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Two'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(selected, 1);
    });

    testWidgets('adaptive layout uses intrinsic width on tablet-sized host',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 900,
            child: UiTabs(
              tabs: const [
                UiTab(label: 'Overview'),
                UiTab(label: 'Students'),
                UiTab(label: 'Assignments'),
              ],
              value: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final intrinsicRect =
          tester.getRect(find.byKey(const Key('ui_tabs_intrinsic_container')));
      expect(intrinsicRect.width, lessThan(900));
    });
  });

  group('UiCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        _host(const UiCard(child: Text('content'))),
      );
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('uses roomier large-surface padding by default',
        (tester) async {
      await tester.pumpWidget(
        _host(const UiCard(child: Text('content'))),
      );

      final paddings = tester
          .widgetList<Padding>(
            find.descendant(
              of: find.byType(UiCard),
              matching: find.byType(Padding),
            ),
          )
          .map((padding) => padding.padding)
          .toList();

      expect(
        paddings,
        contains(const EdgeInsets.all(24)),
      );
    });

    testWidgets('uses the extra-large theme radius by default', (tester) async {
      await tester.pumpWidget(
        _host(const UiCard(child: Text('content'))),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(UiCard),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>();

      expect(
        decorations.any(
          (decoration) =>
              decoration.borderRadius == UiRadiusTokens.standard.xlAll,
        ),
        isTrue,
      );
    });
  });

  group('UiAlert', () {
    testWidgets('uses padding that matches the large radius scale',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiAlert(
            title: 'Warning',
            description: 'Proceed carefully.',
          ),
        ),
      );

      final paddings = tester
          .widgetList<Padding>(
            find.descendant(
              of: find.byType(UiAlert),
              matching: find.byType(Padding),
            ),
          )
          .map((padding) => padding.padding)
          .toList();

      expect(
        paddings,
        contains(const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
      );
    });
  });

  group('UiToast', () {
    testWidgets('uses padding that matches the large radius scale',
        (tester) async {
      await tester.pumpWidget(
        _host(const UiToast(message: 'Saved')),
      );

      final paddings = tester
          .widgetList<Padding>(
            find.descendant(
              of: find.byType(UiToast),
              matching: find.byType(Padding),
            ),
          )
          .map((padding) => padding.padding)
          .toList();

      expect(
        paddings,
        contains(const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
      );
    });

    testWidgets('wraps long body text inside narrow viewports', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 260,
            child: UiToast(
              title: 'Cancel unavailable',
              message:
                  'This action is not available yet. It needs a longer body '
                  'that should wrap instead of overflowing the toast surface.',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
          tester.getRect(find.byType(UiToast)).width, lessThanOrEqualTo(260));
    });
  });

  group('UiSelect', () {
    testWidgets('dropdown stays inside bottom and right viewport boundaries',
        (tester) async {
      tester.view.physicalSize = const Size(320, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: UiThemeData.light(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(
                width: 80,
                child: UiSelect<int>(
                  hint: 'Pick one',
                  shrinkWrap: true,
                  options: List.generate(
                    20,
                    (i) => UiSelectOption(value: i, label: 'Option $i'),
                  ),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      final triggerRect = tester.getRect(find.text('Pick one'));
      await tester.tap(find.text('Pick one'));
      await tester.pumpAndSettle();

      final menuRect = tester.getRect(
        find.byKey(const ValueKey<String>('ui-select-menu')),
      );

      expect(menuRect.top, greaterThanOrEqualTo(4));
      expect(menuRect.left, greaterThanOrEqualTo(4));
      expect(menuRect.right, lessThanOrEqualTo(316));
      expect(menuRect.bottom, lessThanOrEqualTo(316));
      expect(menuRect.bottom, lessThan(triggerRect.top));
    });

    testWidgets('open dropdown does not block parent scroll gestures',
        (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: UiThemeData.light(),
          home: Scaffold(
            body: SizedBox(
              height: 320,
              child: SingleChildScrollView(
                key: const Key('select-scroll-view'),
                controller: scrollController,
                child: Column(
                  children: [
                    UiSelect<int>(
                      hint: 'Pick one',
                      options: const [
                        UiSelectOption(value: 1, label: 'One'),
                        UiSelectOption(value: 2, label: 'Two'),
                      ],
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 900),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick one'));
      await tester.pump();
      expect(find.text('One'), findsOneWidget);

      await tester.dragFrom(const Offset(20, 280), const Offset(0, -180));
      await tester.pump();

      expect(scrollController.offset, greaterThan(0));
      expect(find.text('One'), findsNothing);
    });

    testWidgets('open dropdown closes when the trigger is tapped again',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: UiThemeData.light(),
          home: Scaffold(
            body: Center(
              child: UiSelect<int>(
                hint: 'Pick one',
                shrinkWrap: true,
                options: const [
                  UiSelectOption(value: 1, label: 'One'),
                  UiSelectOption(value: 2, label: 'Two'),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final triggerRectBefore = tester.getRect(find.text('Pick one'));

      await tester.tap(find.text('Pick one'));
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);

      final triggerRectOpen = tester.getRect(find.text('Pick one'));
      expect(triggerRectOpen.width, triggerRectBefore.width);

      await tester.tapAt(tester.getCenter(find.text('Pick one')));
      await tester.pumpAndSettle();
      expect(find.text('One'), findsNothing);
    });

    testWidgets('disposing while open does not throw', (tester) async {
      Widget host({required bool shown}) {
        return MaterialApp(
          theme: UiThemeData.light(),
          home: Scaffold(
            body: Column(
              children: [
                if (shown)
                  UiSelect<int>(
                    hint: 'Pick one',
                    options: const [
                      UiSelectOption(value: 1, label: 'One'),
                      UiSelectOption(value: 2, label: 'Two'),
                    ],
                    onChanged: (_) {},
                  ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(
        host(shown: true),
      );

      await tester.tap(find.text('Pick one'));
      await tester.pump();
      expect(find.text('One'), findsOneWidget);

      await tester.pumpWidget(host(shown: false));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('selection closes the dropdown before notifying onChanged',
        (tester) async {
      var menuVisibleDuringChange = true;

      await tester.pumpWidget(
        _host(
          UiSelect<int>(
            hint: 'Pick one',
            options: const [
              UiSelectOption(value: 1, label: 'One'),
              UiSelectOption(value: 2, label: 'Two'),
            ],
            onChanged: (_) {
              menuVisibleDuringChange = find
                  .byKey(const ValueKey<String>('ui-select-menu'))
                  .evaluate()
                  .isNotEmpty;
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick one'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('ui-select-menu')),
        findsOneWidget,
      );

      await tester.tap(find.text('One'));
      await tester.pump();

      expect(menuVisibleDuringChange, isFalse);
      expect(
        find.byKey(const ValueKey<String>('ui-select-menu')),
        findsNothing,
      );
    });

    testWidgets('dropdown highlights the selected row with a check',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiSelect<int>(
            value: 2,
            options: const [
              UiSelectOption(value: 1, label: 'One'),
              UiSelectOption(value: 2, label: 'Two'),
              UiSelectOption(value: 3, label: 'Three'),
            ],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Two'));
      await tester.pump();
      // Row for 'Two' should exist; it's visually distinguished by a bold
      // style + check glyph. We assert the options render.
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsWidgets);
      expect(find.text('Three'), findsOneWidget);

      // Find the 'Two' row inside the overlay and check that its text
      // weight is bold.
      final twoRows = tester.widgetList<Text>(find.text('Two')).toList();
      expect(
        twoRows.any((t) => t.style?.fontWeight == FontWeight.w600),
        isTrue,
      );
    });

    testWidgets('large dropdown lazily builds visible option rows',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiSelect<int>(
            hint: 'Pick one',
            options: List.generate(
              500,
              (i) => UiSelectOption(value: i, label: 'Option $i'),
            ),
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('Pick one'));
      await tester.pump();

      expect(find.text('Option 0'), findsOneWidget);
      expect(find.text('Option 499'), findsNothing);
    });

    testWidgets('combobox filters options and lazy-builds the menu',
        (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        _host(
          UiCombobox<int>(
            hint: 'Search learner',
            options: List.generate(
              500,
              (i) => UiSelectOption(value: i, label: 'Option $i'),
            ),
            onChanged: (value) => selected = value,
          ),
        ),
      );

      await tester.tap(find.text('Search learner'));
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('ui-combobox-menu')),
          findsOneWidget);
      expect(find.text('Option 0'), findsOneWidget);
      expect(find.text('Option 499'), findsNothing);

      await tester.enterText(find.byType(EditableText), '499');
      await tester.pump();

      expect(find.text('Option 499'), findsOneWidget);
      await tester.tap(find.text('Option 499'));
      await tester.pump();

      expect(selected, 499);
      expect(
          find.byKey(const ValueKey<String>('ui-combobox-menu')), findsNothing);
    });

    testWidgets('anchorSelected placement is honoured', (tester) async {
      await tester.pumpWidget(
        _host(
          UiSelect<int>(
            value: 1,
            placement: UiSelectPlacement.anchorSelected,
            options: const [
              UiSelectOption(value: 0, label: 'Alpha'),
              UiSelectOption(value: 1, label: 'Beta'),
              UiSelectOption(value: 2, label: 'Gamma'),
            ],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Beta'));
      await tester.pump();
      // Both labels (trigger + option row) are present.
      expect(find.text('Beta'), findsWidgets);
      expect(find.text('Alpha'), findsOneWidget);
    });

    testWidgets('custom option + value builders render', (tester) async {
      await tester.pumpWidget(
        _host(
          UiSelect<int>(
            value: 1,
            options: const [
              UiSelectOption(value: 0, label: 'Zero'),
              UiSelectOption(value: 1, label: 'One'),
            ],
            onChanged: (_) {},
            valueBuilder: (context, selected) =>
                Text('value:${selected?.value ?? -1}'),
            optionBuilder: (context, option, selected) =>
                Text('opt:${option.value}:${selected ? '!' : '.'}'),
          ),
        ),
      );

      // Closed trigger uses the custom value builder.
      expect(find.text('value:1'), findsOneWidget);

      await tester.tap(find.text('value:1'));
      await tester.pump();

      // Opened list uses the custom option builder.
      expect(find.text('opt:0:.'), findsOneWidget);
      expect(find.text('opt:1:!'), findsOneWidget);
    });

    testWidgets(
      'UiSelectOption composes leading + labelBuilder + subtitle inside the '
      'default row chrome',
      (tester) async {
        await tester.pumpWidget(
          _host(
            UiSelect<int>(
              value: 1,
              options: [
                UiSelectOption(
                  value: 0,
                  label: 'Acme',
                  subtitle: 'acme.example',
                  leading: const Text('🏷'),
                ),
                UiSelectOption(
                  value: 1,
                  label: 'Globex',
                  leading: const Text('🔷'),
                  labelBuilder: (ctx, option, selected) => Text(
                    'custom-${option.label}-${selected ? 'yes' : 'no'}',
                  ),
                ),
              ],
              onChanged: (_) {},
            ),
          ),
        );

        // Trigger renders the raw label string for the selected option.
        expect(find.text('Globex'), findsOneWidget);

        await tester.tap(find.text('Globex'));
        await tester.pump();

        // Option 0: default label Text + subtitle + leading all render
        // through the default row chrome.
        expect(find.text('Acme'), findsOneWidget);
        expect(find.text('acme.example'), findsOneWidget);
        expect(find.text('🏷'), findsOneWidget);

        // Option 1: labelBuilder replaces the label slot; the default
        // check (selected state) + leading are still painted by the
        // default chrome.
        expect(find.text('custom-Globex-yes'), findsOneWidget);
        expect(find.text('🔷'), findsOneWidget);
      },
    );
  });

  group('UiTabs animation', () {
    testWidgets('animated pill indicator shifts when selection changes',
        (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiTabs(
                tabs: const [
                  UiTab(label: 'A'),
                  UiTab(label: 'B'),
                  UiTab(label: 'C'),
                ],
                value: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );

      double indicatorLeft() {
        final ap = tester
            .widget<AnimatedPositioned>(find.byType(AnimatedPositioned).first);
        return ap.left ?? 0;
      }

      final initial = indicatorLeft();
      await tester.tap(find.text('C'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(indicatorLeft(), greaterThan(initial));
    });
  });

  group('UiToaster', () {
    tearDown(() {
      UiToaster.dismissAll();
      UiToaster.maxVisible = 3;
    });

    testWidgets('keeps maxVisible and replaces oldest when full',
        (tester) async {
      await tester.pumpWidget(_host(const SizedBox()));

      final ctx = tester.element(find.byType(Scaffold));
      UiToaster.maxVisible = 3;
      for (var i = 0; i < 5; i++) {
        UiToaster.show(
          ctx,
          message: 'msg $i',
          duration: const Duration(seconds: 10),
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Only 3 are visible; when full, older ones are replaced.
      expect(find.byType(UiToast), findsNWidgets(3));
      expect(find.text('msg 0'), findsNothing);
      expect(find.text('msg 1'), findsNothing);
      expect(find.text('msg 2'), findsOneWidget);
      expect(find.text('msg 3'), findsOneWidget);
      expect(find.text('msg 4'), findsOneWidget);
      UiToaster.dismissAll();
      await tester.pump();
    });

    testWidgets('manual dismiss leaves remaining visible toasts untouched',
        (tester) async {
      await tester.pumpWidget(_host(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));

      UiToaster.maxVisible = 2;
      UiToaster.show(ctx, message: 'a', duration: const Duration(seconds: 10));
      UiToaster.show(ctx, message: 'b', duration: const Duration(seconds: 10));
      final dismissC = UiToaster.show(
        ctx,
        message: 'c',
        duration: const Duration(seconds: 10),
      );
      await tester.pump();
      expect(find.text('a'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.text('a'), findsNothing);
      expect(find.text('b'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);

      // Remove one currently-visible toast and ensure no hidden queue
      // is promoted.
      dismissC();
      await tester.pump();
      expect(find.text('c'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.text('b'), findsOneWidget);
      expect(find.byType(UiToast), findsNWidgets(1));
      UiToaster.dismissAll();
      await tester.pump();
    });

    testWidgets('toast host grows vertically for wrapped body text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      UiToaster.show(
        ctx,
        title: 'Cancel unavailable',
        message: 'This action is not available yet. The message can wrap into '
            'multiple lines without being squeezed by the toast lane.',
        duration: const Duration(days: 1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(UiToast)).height, greaterThan(80));

      UiToaster.dismissAll();
      await tester.pump();
    });

    testWidgets('toast text compacts under tight vertical constraints',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 390,
            height: 80,
            child: UiToast(
              title: 'A title that can wrap into more than one line',
              message: 'A body message that would normally need more room.',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(UiToast), findsOneWidget);
    });

    testWidgets('outside interaction does not dismiss toast', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          TextButton(
            onPressed: () => taps++,
            child: const Text('Interact'),
          ),
        ),
      );
      final ctx = tester.element(find.byType(Scaffold));
      UiToaster.show(ctx,
          message: 'dismiss me', duration: const Duration(days: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Interact'));
      await tester.pump();

      expect(taps, 1);
      expect(find.text('dismiss me'), findsOneWidget);

      UiToaster.dismissAll();
      await tester.pump();
    });

    testWidgets('default toast position is top on mobile', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      UiToaster.show(ctx, message: 'mobile', duration: const Duration(days: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final toastRect = tester.getRect(find.byType(UiToast));
      expect(toastRect.top, lessThan(80));

      UiToaster.dismissAll();
      await tester.pump();
    });

    testWidgets('default toast position is bottom start on large screens',
        (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      UiToaster.show(ctx, message: 'wide', duration: const Duration(days: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final toastRect = tester.getRect(find.byType(UiToast));
      expect(toastRect.left, lessThan(32));
      expect(toastRect.bottom, greaterThan(620));

      UiToaster.dismissAll();
      await tester.pump();
    });

    testWidgets('pressing the stack reveals older toasts', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      UiToaster.show(ctx, message: 'first', duration: const Duration(days: 1));
      UiToaster.show(ctx, message: 'second', duration: const Duration(days: 1));
      UiToaster.show(ctx, message: 'third', duration: const Duration(days: 1));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      List<double> scales() => tester
          .widgetList<AnimatedScale>(find.byType(AnimatedScale))
          .map((scale) => scale.scale)
          .toList(growable: false);

      List<double> yOffsets() => tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .where((container) => container.transform != null)
          .map((container) => container.transform!.storage[13])
          .toList(growable: false);

      expect(scales(), containsAll(<double>[1, 0.95, 0.9]));
      expect(yOffsets(), containsAll(<double>[0, 14, 28]));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(UiToast).last),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(scales(), everyElement(1));
      expect(yOffsets().where((offset) => offset > 40).length, 2);

      await gesture.up();
      await tester.pump();
      expect(scales(), containsAll(<double>[1, 0.95, 0.9]));
      expect(yOffsets(), containsAll(<double>[0, 14, 28]));

      UiToaster.dismissAll();
      await tester.pump();
    });

    testWidgets('pointer callbacks after host removal do not set state',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      UiToaster.show(ctx,
          message: 'leaving', duration: const Duration(days: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(UiToast)),
      );
      await tester.pumpWidget(_host(const SizedBox()));
      UiToaster.dismissAll();
      await tester.pump();

      await gesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('vertical swipe dismisses a top toast', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      UiToaster.show(ctx,
          message: 'swipe me', duration: const Duration(days: 1));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      await tester.drag(find.byType(UiToast), const Offset(0, -60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      expect(find.text('swipe me'), findsNothing);
    });

    testWidgets('rapid stacked titled toasts do not overflow while entering',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));

      UiToaster.show(
        ctx,
        title: 'First update',
        message: 'A multi-line notification that needs its natural height.',
        duration: const Duration(days: 1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      UiToaster.show(
        ctx,
        title: 'Second update',
        message: 'Another notification fired while the first is entering.',
        duration: const Duration(days: 1),
      );
      UiToaster.show(
        ctx,
        title: 'Third update',
        message: 'This one should stack without forcing older content smaller.',
        duration: const Duration(days: 1),
      );

      for (final elapsed in <Duration>[
        Duration.zero,
        const Duration(milliseconds: 80),
        const Duration(milliseconds: 160),
        const Duration(milliseconds: 260),
        const Duration(milliseconds: 450),
      ]) {
        await tester.pump(elapsed);
        expect(tester.takeException(), isNull);
      }

      expect(find.byType(UiToast), findsNWidgets(3));
      UiToaster.dismissAll();
      await tester.pump();
    });

    testWidgets(
        'toast stack transition resolves immediately with reduced motion',
        (tester) async {
      await tester.pumpWidget(_reducedMotionHost(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));

      UiToaster.show(ctx,
          message: 'reduced', duration: const Duration(seconds: 10));
      await tester.pump();

      expect(find.text('reduced'), findsOneWidget);
      final transformedContainer = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .firstWhere((container) => container.transform != null);
      expect(transformedContainer.duration, Duration.zero);
      UiToaster.dismissAll();
      await tester.pump();
    });
  });

  group('UiInput focus ring', () {
    testWidgets('disabled input never shows the focus ring', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        _host(UiInput(enabled: false, focusNode: node)),
      );
      node.requestFocus();
      await tester.pump();
      // No focus halo should appear around disabled inputs.
      expect(find.byType(UiFocusRing), findsWidgets);
      // The only visible ring is the one wrapping the field, and it
      // must be in its "invisible" state (child equals its input).
      for (final w
          in tester.widgetList<UiFocusRing>(find.byType(UiFocusRing))) {
        expect(w.visible, isFalse);
      }
    });

    testWidgets('readOnly input keeps the ring suppressed when focused',
        (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        _host(UiInput(readOnly: true, focusNode: node)),
      );
      node.requestFocus();
      await tester.pump();
      for (final w
          in tester.widgetList<UiFocusRing>(find.byType(UiFocusRing))) {
        expect(w.visible, isFalse);
      }
    });
  });
}
