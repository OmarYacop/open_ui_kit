import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  test('UiNavigationRailGeometry keeps labels visible until late collapse', () {
    const geometry = UiNavigationRailGeometry.defaults;

    expect(
      geometry.labelProgressForRailProgress(0.5, collapsed: false),
      0,
    );
    expect(
      geometry.labelProgressForRailProgress(0.5, collapsed: true),
      1,
    );
  });

  testWidgets('UiNavigationRail uses UiApp title and toggles collapse', (
    tester,
  ) async {
    var collapsed = false;
    var selected = 0;

    await tester.pumpWidget(
      UiApp(
        title: 'Example App',
        home: StatefulBuilder(
          builder: (context, setState) => UiNavigationRail(
            collapsed: collapsed,
            onToggleCollapsed: () => setState(() => collapsed = !collapsed),
            destinations: [
              UiNavigationRailDestination(
                label: 'Home',
                icon: LucideIcons.house,
                activeIcon: LucideIcons.house,
                selected: selected == 0,
                onPressed: () => setState(() => selected = 0),
              ),
              UiNavigationRailDestination(
                label: 'Chat',
                icon: LucideIcons.messageCircle,
                activeIcon: LucideIcons.messageCircle,
                selected: selected == 1,
                onPressed: () => setState(() => selected = 1),
              ),
            ],
            footerActions: [
              UiNavigationRailAction(
                label: 'Notifications',
                icon: LucideIcons.bell,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Example App'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.bySemanticsLabel('Collapse navigation rail'), findsOneWidget);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(selected, 1);

    await tester.tap(find.bySemanticsLabel('Collapse navigation rail'));
    await tester.pumpAndSettle();
    expect(collapsed, isTrue);
    expect(find.bySemanticsLabel('Expand navigation rail'), findsOneWidget);
  });

  testWidgets('UiNavigationRail main surface adapts below max height', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        title: 'Example App',
        home: UiNavigationRail(
          collapsed: false,
          onToggleCollapsed: () {},
          destinations: [
            UiNavigationRailDestination(
              label: 'Home',
              icon: LucideIcons.house,
              selected: true,
              onPressed: () {},
            ),
            UiNavigationRailDestination(
              label: 'Chat',
              icon: LucideIcons.messageCircle,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surfaceHeight = tester
        .getSize(find.byKey(const Key('ui_navigation_rail_main_surface')))
        .height;

    expect(surfaceHeight, lessThan(UiNavigationRail.maxPanelHeight));
    expect(surfaceHeight, greaterThanOrEqualTo(120));
  });

  testWidgets('UiNavigationRail expanded header uses default top padding', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final platformCapabilities = _FakePlatformCapabilities(
      UiWindowMode.fullscreen,
    );
    try {
      await tester.pumpWidget(
        UiApp(
          title: 'Example App',
          home: UiNavigationRail(
            collapsed: false,
            onToggleCollapsed: () {},
            platformCapabilities: platformCapabilities,
            destinations: [
              UiNavigationRailDestination(
                label: 'Home',
                icon: LucideIcons.house,
                selected: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(const Key('ui_navigation_rail_header'))).top,
        closeTo(
          UiNavigationRailGeometry.defaults.expandedHeaderTopPadding,
          0.1,
        ),
      );
      expect(platformCapabilities.windowModeRequestCount, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'UiNavigationRail expanded header keeps default top padding with chrome',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final platformCapabilities = _FakePlatformCapabilities(
        UiWindowMode.windowed,
      );
      try {
        await tester.pumpWidget(
          UiApp(
            title: 'Example App',
            home: UiNavigationRail(
              collapsed: false,
              onToggleCollapsed: () {},
              platformCapabilities: platformCapabilities,
              destinations: [
                UiNavigationRailDestination(
                  label: 'Home',
                  icon: LucideIcons.house,
                  selected: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .getRect(find.byKey(const Key('ui_navigation_rail_header')))
              .top,
          closeTo(
            UiNavigationRailGeometry.defaults.expandedHeaderTopPadding,
            0.1,
          ),
        );
        expect(platformCapabilities.windowModeRequestCount, 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('UiNavigationRail keeps no-chrome height stable when collapsing',
      (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      var collapsed = false;
      await tester.pumpWidget(
        UiApp(
          title: 'Example App',
          home: StatefulBuilder(
            builder: (context, setState) => UiNavigationRail(
              collapsed: collapsed,
              onToggleCollapsed: () => setState(() => collapsed = !collapsed),
              platformCapabilities: _FakePlatformCapabilities(
                UiWindowMode.fullscreen,
              ),
              destinations: [
                UiNavigationRailDestination(
                  label: 'Home',
                  icon: LucideIcons.house,
                  selected: true,
                  onPressed: () {},
                ),
                UiNavigationRailDestination(
                  label: 'Chat',
                  icon: LucideIcons.messageCircle,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expandedHeight = tester
          .getSize(find.byKey(const Key('ui_navigation_rail_main_surface')))
          .height;

      await tester.tap(find.bySemanticsLabel('Collapse navigation rail'));
      await tester.pumpAndSettle();

      final collapsedHeight = tester
          .getSize(find.byKey(const Key('ui_navigation_rail_main_surface')))
          .height;

      expect(collapsedHeight, closeTo(expandedHeight, 0.1));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('UiNavigationRail reacts to pushed native window-mode changes',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final platformCapabilities = _FakePlatformCapabilities(
      UiWindowMode.fullscreen,
    );
    try {
      await tester.pumpWidget(
        UiApp(
          title: 'Example App',
          home: UiNavigationRail(
            collapsed: true,
            onToggleCollapsed: () {},
            platformCapabilities: platformCapabilities,
            destinations: [
              UiNavigationRailDestination(
                label: 'Home',
                icon: LucideIcons.house,
                selected: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(const Key('ui_navigation_rail_header'))).top,
        closeTo(
          UiNavigationRailGeometry.defaults.collapsedHeaderTopPadding,
          0.1,
        ),
      );

      platformCapabilities.emit(UiWindowMode.windowed);
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(const Key('ui_navigation_rail_header'))).top,
        closeTo(
          UiNavigationRailGeometry.defaults.collapsedChromeTopPadding,
          0.1,
        ),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      await platformCapabilities.close();
    }
  });

  testWidgets('UiNavigationRail surface width animates while collapsing', (
    tester,
  ) async {
    var collapsed = false;
    await tester.pumpWidget(
      UiApp(
        title: 'Example App',
        home: StatefulBuilder(
          builder: (context, setState) => UiNavigationRail(
            collapsed: collapsed,
            onToggleCollapsed: () => setState(() => collapsed = !collapsed),
            destinations: [
              UiNavigationRailDestination(
                label: 'Home',
                icon: LucideIcons.house,
                selected: true,
                onPressed: () {},
              ),
              UiNavigationRailDestination(
                label: 'Chat',
                icon: LucideIcons.messageCircle,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(find.byKey(const Key('ui_navigation_rail_main_surface')))
          .width,
      closeTo(UiNavigationRailGeometry.defaults.expandedPanelWidth, 0.1),
    );

    await tester.tap(find.bySemanticsLabel('Collapse navigation rail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    final midCollapseWidth = tester
        .getSize(find.byKey(const Key('ui_navigation_rail_main_surface')))
        .width;

    expect(
      midCollapseWidth,
      lessThan(UiNavigationRailGeometry.defaults.expandedPanelWidth),
    );
    expect(
      midCollapseWidth,
      greaterThan(UiNavigationRailGeometry.defaults.collapsedPanelWidth),
    );

    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const Key('ui_navigation_rail_main_surface')))
          .width,
      closeTo(UiNavigationRailGeometry.defaults.collapsedPanelWidth, 0.1),
    );
  });

  testWidgets('UiNavigationRail header toggle aligns with content end', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        title: 'Example App',
        home: UiNavigationRail(
          collapsed: false,
          onToggleCollapsed: () {},
          destinations: [
            UiNavigationRailDestination(
              label: 'Home',
              icon: LucideIcons.house,
              selected: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggleRect = tester.getRect(
      find.byKey(const Key('ui_navigation_rail_toggle_button')),
    );
    final expectedEnd = UiNavigationRailGeometry.defaults.outerMargin +
        UiNavigationRailGeometry.defaults.expandedPanelWidth -
        UiNavigationRailGeometry.defaults.headerEndPadding;

    expect(toggleRect.right, closeTo(expectedEnd, 0.1));
    expect(
        toggleRect.width, UiNavigationRailGeometry.defaults.headerToggleExtent);
    expect(toggleRect.height, toggleRect.width);
  });

  testWidgets('UiNavigationRail centers collapsed destination affordances', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        title: 'Example App',
        home: UiNavigationRail(
          collapsed: true,
          onToggleCollapsed: () {},
          destinations: [
            UiNavigationRailDestination(
              label: 'Home',
              icon: LucideIcons.house,
              selected: true,
              onPressed: () {},
            ),
          ],
          footerDestinations: [
            UiNavigationRailDestination(
              label: 'Account',
              leadingBuilder: (context, foreground) =>
                  const UiNavigationRailAvatar(name: 'Example User'),
              leadingSize: 26,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    const railCenter = UiNavigationRail.collapsedOuterWidth / 2;

    expect(
      tester.getCenter(find.byIcon(LucideIcons.house)).dx,
      closeTo(railCenter, 0.1),
    );
    expect(
      tester.getCenter(find.byType(UiAvatar)).dx,
      closeTo(railCenter, 0.1),
    );
  });
}

class _FakePlatformCapabilities extends UiPlatformCapabilities {
  _FakePlatformCapabilities(this.mode) : super(cacheDuration: Duration.zero);

  final UiWindowMode mode;
  final StreamController<UiWindowMode> _changes =
      StreamController<UiWindowMode>.broadcast(sync: true);
  int windowModeRequestCount = 0;

  @override
  Stream<UiWindowMode> get windowModeChanges => _changes.stream;

  void emit(UiWindowMode mode) => _changes.add(mode);

  Future<void> close() => _changes.close();

  @override
  Future<UiWindowMode> currentWindowMode({bool forceRefresh = false}) async {
    windowModeRequestCount += 1;
    return mode;
  }
}
