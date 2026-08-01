import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  testWidgets('shows only the selection until expanded, then collapses on pick',
      (tester) async {
    var unreadOnly = false;

    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            return UiCompactChoiceFilter<bool>(
              value: unreadOnly,
              options: const [false, true],
              labelBuilder: (value) => value ? 'Unread' : 'All',
              iconBuilder: (value) =>
                  Icon(value ? Icons.mark_email_unread : Icons.all_inbox),
              expandedTitle: 'Show notifications',
              overlayViewportPadding: const EdgeInsets.only(top: 20),
              onChanged: (value) => setState(() => unreadOnly = value),
            );
          },
        ),
      ),
    );

    expect(find.text('All').hitTestable(), findsOneWidget);
    expect(find.text('Unread').hitTestable(), findsNothing);
    final restingRect = tester.getRect(
      find.byKey(const Key('compact_choice_trigger_surface')),
    );
    final restingLabelRect = tester.getRect(find.text('All').hitTestable());
    expect(restingRect.height, 36);
    expect(
      (restingLabelRect.center.dy - restingRect.center.dy).abs(),
      lessThan(1),
    );

    await tester.tap(find.text('All').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final midMorphSize = tester.getSize(
      find.byKey(const Key('compact_choice_expanded_surface')),
    );
    await tester.pumpAndSettle();

    final expandedSurface = find.byKey(
      const Key('compact_choice_expanded_surface'),
    );
    final expandedContent = find
        .descendant(
          of: expandedSurface,
          matching: find.byKey(const Key('compact_choice_expanded_content')),
        )
        .hitTestable();
    expect(
      find.descendant(of: expandedContent, matching: find.text('All')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: expandedContent, matching: find.text('Unread')),
      findsOneWidget,
    );
    final triggerRect = tester.getRect(
      find.byKey(const Key('compact_choice_trigger_surface')),
    );
    final expandedRect = tester.getRect(
      expandedSurface,
    );
    final expandedContentRect = tester.getRect(expandedContent);
    expect((expandedRect.top - triggerRect.top).abs(), lessThan(2));
    expect((expandedRect.right - triggerRect.right).abs(), lessThan(2));
    expect(expandedContentRect.top - expandedRect.top, 8);
    expect(expandedContentRect.left - expandedRect.left, 8);
    expect(expandedRect.right - expandedContentRect.right, 8);
    expect(expandedRect.bottom - expandedContentRect.bottom, 8);
    expect(midMorphSize.width, greaterThan(triggerRect.width));
    expect(midMorphSize.width, lessThan(expandedRect.width));
    expect(expandedRect.width, greaterThan(triggerRect.width));

    await tester.tap(
      find.descendant(of: expandedContent, matching: find.text('Unread')),
    );
    await tester.pumpAndSettle();

    expect(unreadOnly, isTrue);
    expect(find.text('All').hitTestable(), findsNothing);
    expect(find.text('Unread').hitTestable(), findsOneWidget);
  });

  testWidgets('resolves the expanded state immediately for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: UiCompactChoiceFilter<bool>(
                  value: false,
                  options: const [false, true],
                  labelBuilder: (value) => value ? 'Unread' : 'All',
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('All').hitTestable());
    await tester.pump();

    final expandedSurface = find.byKey(
      const Key('compact_choice_expanded_surface'),
    );
    expect(expandedSurface, findsOneWidget);
    expect(
      find.descendant(of: expandedSurface, matching: find.text('Unread')),
      findsOneWidget,
    );
  });

  testWidgets('expanded surface follows its anchor and clips progressively', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UiLayeredOverlayHost(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.only(top: 180),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: UiCompactChoiceFilter<bool>(
                    value: false,
                    options: const [false, true],
                    labelBuilder: (value) => value ? 'Unread' : 'All',
                    overlayViewportPadding: const EdgeInsets.all(12),
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('All').hitTestable());
    await tester.pumpAndSettle();

    controller.jumpTo(210);
    await tester.pump();

    final expanded = find.byKey(
      const Key('compact_choice_expanded_surface'),
    );
    expect(expanded, findsOneWidget);
    final rect = tester.getRect(expanded);
    expect(rect.top, lessThan(12));
    expect(rect.bottom, greaterThan(12));
  });
}
