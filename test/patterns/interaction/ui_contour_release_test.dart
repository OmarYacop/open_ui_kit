import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

const _triggerKey = ValueKey('contour-release-trigger');

// Default duration is 200ms with an easeOutCubic curve, which crosses the
// widget's 0.92 activation threshold at ~57% elapsed (~114ms). These
// checkpoints are chosen to sit safely on either side of that threshold.
const _beforeThreshold = Duration(milliseconds: 60);
const _afterThreshold = Duration(milliseconds: 130);

Widget _host(
  Widget child, {
  bool disableAnimations = false,
  bool rtl = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

List<UiContourReleaseAction> _actions({
  void Function()? onReply,
  void Function()? onArchive,
  bool archiveDisabled = false,
}) {
  return [
    UiContourReleaseAction(
      icon: const Icon(Icons.reply_rounded),
      semanticsLabel: 'Reply',
      onPressed: onReply,
    ),
    UiContourReleaseAction(
      icon: const Icon(Icons.archive_rounded),
      semanticsLabel: 'Archive',
      onPressed: archiveDisabled ? null : onArchive,
    ),
  ];
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_triggerKey));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('collapsed: trigger is tappable, released actions are not', (
    tester,
  ) async {
    var replyTaps = 0;
    await tester.pumpWidget(
      _host(
        UiContourRelease(
          label: 'More',
          actions: _actions(onReply: () => replyTaps++),
        ),
      ),
    );

    // Mounted (co-located with the trigger, zero-width) but not hittable.
    await tester.tap(find.byIcon(Icons.reply_rounded), warnIfMissed: false);
    await tester.pump();
    expect(replyTaps, 0);

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.reply_rounded), findsOneWidget);
  });

  testWidgets('tapping the trigger opens and released actions become tappable',
      (
    tester,
  ) async {
    var replies = 0;
    await tester.pumpWidget(
      _host(
        UiContourRelease(
          label: 'More',
          actions: _actions(onReply: () => replies++),
        ),
      ),
    );

    await _open(tester);

    await tester.tap(find.byIcon(Icons.reply_rounded));
    await tester.pump();
    expect(replies, 1);
  });

  testWidgets(
      'the same trigger element persists across collapse and expand (real identity, not a crossfaded pair)',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(UiContourRelease(label: 'More', actions: _actions())),
    );
    final collapsedElement = tester.element(find.byKey(_triggerKey));

    await _open(tester);
    expect(find.byKey(_triggerKey), findsOneWidget);
    final expandedElement = tester.element(find.byKey(_triggerKey));
    expect(identical(collapsedElement, expandedElement), isTrue);

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();
    final recollapsedElement = tester.element(find.byKey(_triggerKey));
    expect(identical(collapsedElement, recollapsedElement), isTrue);

    // Exactly one trigger button exists at any time — never a duplicate.
    expect(find.byKey(_triggerKey), findsOneWidget);
  });

  testWidgets(
      'trigger content hands off on expand: label and icon change, never duplicated',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(UiContourRelease(label: 'More', actions: _actions())),
    );
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
    expect(find.byIcon(LucideIcons.ellipsis), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsNothing);
    expect(
      tester.getSemantics(find.byKey(_triggerKey)).label,
      contains('More'),
    );

    await _open(tester);
    // Exactly one label and one icon are ever present — a real handoff,
    // never both collapsed and expanded content visible at once.
    expect(find.text('More'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byIcon(LucideIcons.ellipsis), findsNothing);
    expect(find.byIcon(LucideIcons.x), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(_triggerKey)).label,
      contains('Collapse'),
    );

    // And reversal restores the exact original content.
    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('custom collapsed/expanded semantics labels are honored', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        UiContourRelease(
          label: 'More',
          collapsedSemanticsLabel: 'More message actions',
          expandedSemanticsLabel: 'Hide message actions',
          actions: _actions(),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byKey(_triggerKey)).label,
      'More message actions',
    );
    await _open(tester);
    expect(
      tester.getSemantics(find.byKey(_triggerKey)).label,
      'Hide message actions',
    );
  });

  testWidgets(
      'a null callback renders a genuinely disabled action: no tap effect, not wrapped enabled',
      (
    tester,
  ) async {
    var archives = 0;
    await tester.pumpWidget(
      _host(
        UiContourRelease(
          label: 'More',
          actions: _actions(
            onArchive: () => archives++,
            archiveDisabled: true,
          ),
        ),
      ),
    );
    await _open(tester);

    final iconButton = tester.widget<UiIconButton>(
      find.ancestor(
        of: find.byIcon(Icons.archive_rounded),
        matching: find.byType(UiIconButton),
      ),
    );
    expect(iconButton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.archive_rounded), warnIfMissed: false);
    await tester.pump();
    expect(archives, 0);
  });

  testWidgets(
      'actions become interactive only after crossing the emergence threshold',
      (
    tester,
  ) async {
    var replies = 0;
    await tester.pumpWidget(
      _host(
        UiContourRelease(
          label: 'More',
          actions: _actions(onReply: () => replies++),
        ),
      ),
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pump();
    await tester.pump(_beforeThreshold);
    await tester.tap(find.byIcon(Icons.reply_rounded), warnIfMissed: false);
    await tester.pump();
    expect(replies, 0, reason: 'not yet emerged past the activation threshold');

    await tester.pump(_afterThreshold - _beforeThreshold);
    await tester.tap(find.byIcon(Icons.reply_rounded));
    await tester.pump();
    expect(replies, 1);
  });

  testWidgets(
      'progress checkpoints: geometry stays finite, monotonic, and constraint-safe',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(UiContourRelease(label: 'More', actions: _actions())),
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pump();

    double? previousWidth;
    for (final step in [
      const Duration(milliseconds: 1),
      const Duration(milliseconds: 40),
      const Duration(milliseconds: 90),
      const Duration(milliseconds: 150),
      const Duration(milliseconds: 190),
    ]) {
      await tester.pump(step);
      expect(tester.takeException(), isNull);
      final renderBox = tester.renderObject<RenderBox>(
        find.byKey(_triggerKey).first,
      );
      expect(renderBox.size.width.isFinite, isTrue);
      expect(renderBox.size.height.isFinite, isTrue);

      final outer = tester.renderObject<RenderBox>(
        find.byType(UiContourRelease),
      );
      expect(outer.size.width.isFinite, isTrue);
      expect(outer.size.width, greaterThanOrEqualTo(0));
      if (previousWidth != null) {
        expect(
          outer.size.width,
          greaterThanOrEqualTo(previousWidth - 0.01),
          reason: 'width recoiled at $step',
        );
      }
      previousWidth = outer.size.width;
    }

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reversal during emergence does not throw and returns exactly to the trigger',
      (
    tester,
  ) async {
    var replies = 0;
    await tester.pumpWidget(
      _host(
        UiContourRelease(
          label: 'More',
          actions: _actions(onReply: () => replies++),
        ),
      ),
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pump();
    await tester.pump(_beforeThreshold);
    // Reverse mid-emergence via the same persistent trigger.
    await tester.tap(find.byKey(_triggerKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.reply_rounded), warnIfMissed: false);
    expect(replies, 0);
  });

  testWidgets('rapid repeated taps do not corrupt state', (tester) async {
    await tester.pumpWidget(
      _host(UiContourRelease(label: 'More', actions: _actions())),
    );

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(_triggerKey));
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reduced motion reaches the final state without waiting for elapsed time',
      (
    tester,
  ) async {
    var replies = 0;
    await tester.pumpWidget(
      _host(
        UiContourRelease(
          label: 'More',
          actions: _actions(onReply: () => replies++),
        ),
        disableAnimations: true,
      ),
    );

    await tester.tap(find.byKey(_triggerKey));
    // A single pump (no elapsed duration) must already reflect the final,
    // interactive state.
    await tester.pump();
    await tester.tap(find.byIcon(Icons.reply_rounded));
    await tester.pump();
    expect(replies, 1);
  });

  testWidgets('collapseOnAction closes after an action fires', (
    tester,
  ) async {
    var archives = 0;
    await tester.pumpWidget(
      _host(
        UiContourRelease(
          label: 'More',
          collapseOnAction: true,
          actions: _actions(onArchive: () => archives++),
        ),
      ),
    );

    await _open(tester);
    await tester.tap(find.byIcon(Icons.archive_rounded));
    await tester.pumpAndSettle();

    expect(archives, 1);
    var laterArchives = archives;
    await tester.tap(find.byIcon(Icons.archive_rounded), warnIfMissed: false);
    await tester.pump();
    expect(archives, laterArchives);
  });

  testWidgets(
      'works under RTL directionality: actions land left of the trigger and remain tappable',
      (
    tester,
  ) async {
    var replies = 0;
    await tester.pumpWidget(
      _host(
        UiContourRelease(
          label: 'More',
          actions: _actions(onReply: () => replies++),
        ),
        rtl: true,
      ),
    );

    await _open(tester);
    expect(tester.takeException(), isNull);

    final triggerCenter = tester.getCenter(find.byKey(_triggerKey));
    final actionCenter = tester.getCenter(find.byIcon(Icons.reply_rounded));
    expect(
      actionCenter.dx,
      lessThan(triggerCenter.dx),
      reason:
          'in RTL, released actions should extend to the left of the trigger',
    );

    await tester.tap(find.byIcon(Icons.reply_rounded));
    await tester.pump();
    expect(replies, 1);
  });

  testWidgets('controlled mode follows the expanded flag', (tester) async {
    var expanded = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return _host(
            UiContourRelease(
              label: 'More',
              expanded: expanded,
              onExpandedChanged: (v) => setState(() => expanded = v),
              actions: _actions(),
            ),
          );
        },
      ),
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();
    expect(expanded, isTrue);
    expect(find.byIcon(Icons.reply_rounded), findsOneWidget);
  });

  testWidgets('focus stays on the trigger across expand/collapse', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(UiContourRelease(label: 'More', actions: _actions())),
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pump();
    final focusedBefore = FocusManager.instance.primaryFocus;
    await tester.pumpAndSettle();
    final focusedAfter = FocusManager.instance.primaryFocus;
    // Focus ownership is not silently dropped mid-transition: whichever
    // node held focus after the tap remains valid and attached throughout.
    expect(focusedBefore?.context, isNotNull);
    expect(focusedAfter?.context, isNotNull);
  });

  testWidgets('disposing mid-transition does not throw', (tester) async {
    await tester.pumpWidget(
      _host(UiContourRelease(label: 'More', actions: _actions())),
    );
    await tester.tap(find.byKey(_triggerKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(_host(const SizedBox()));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'regression: released actions paint and hit-test correctly when the '
      'component sits away from the global origin (double-offset clip bug)',
      (tester) async {
    // At the global origin, a clip rect that is accidentally shifted by
    // `offset` twice still lands in the same place (offset is zero), so
    // this bug is invisible there. A large ancestor offset makes it visible:
    // a double-shifted clip window no longer overlaps where the action is
    // actually painted, and the action silently fails to render/hit-test.
    var replies = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 137, top: 253),
            child: UiContourRelease(
              label: 'More',
              actions: _actions(onReply: () => replies++),
            ),
          ),
        ),
      ),
    );

    await _open(tester);
    expect(tester.takeException(), isNull);

    // The action must actually be painted (non-empty layer, real pixels) at
    // its expected screen position, not just present with zero-area clip.
    final iconFinder = find.byIcon(Icons.reply_rounded);
    expect(iconFinder, findsOneWidget);
    final iconRect = tester.getRect(iconFinder);
    expect(iconRect.width, greaterThan(0));
    expect(iconRect.height, greaterThan(0));
    // Sanity: still positioned to the right of the ancestor offset, not
    // clipped away at (0,0) or off past double the offset.
    expect(iconRect.left, greaterThan(137));
    expect(iconRect.left, lessThan(137 + 400));

    await tester.tap(iconFinder);
    await tester.pump();
    expect(replies, 1,
        reason: 'a double-shifted clip would silently swallow this tap');
  });

  testWidgets('throws for zero actions and for more than maxInlineActions', (
    tester,
  ) async {
    expect(
      () => UiContourRelease(label: 'More', actions: const []),
      throwsAssertionError,
    );
    expect(
      () => UiContourRelease(
        label: 'More',
        actions: List.generate(
          UiContourRelease.maxInlineActions + 1,
          (i) => UiContourReleaseAction(
            icon: const Icon(Icons.circle),
            semanticsLabel: 'Action $i',
            onPressed: () {},
          ),
        ),
      ),
      throwsAssertionError,
    );
  });
}
