import 'package:flutter/widgets.dart';

import '../../foundation/layout/ui_navigation_chrome_scope.dart';

/// Breakpoint form factors surfaced by [UiResponsiveNavigationScaffold].
enum UiNavigationFormFactor { phone, tablet, desktop }

/// Builder signature for responsive navigation.
typedef UiResponsiveNavigationBuilder = Widget Function(
  BuildContext context,
  UiNavigationFormFactor formFactor,
);

/// Navigation shell that picks a different chrome strategy per
/// breakpoint.
///
/// - **phone** (`< phoneBreakpoint`, default 600dp): `body` + optional
///   bottom bar; drawer is presented via [sidebar] swipe/tap.
/// - **tablet** (`phoneBreakpoint <= width < desktopBreakpoint`,
///   default 900dp): persistent [sidebar] on the left + `body`.
/// - **desktop** (`>= desktopBreakpoint`): [sidebar] + `body` +
///   optional [secondary] panel on the right.
class UiResponsiveNavigationScaffold extends StatelessWidget {
  const UiResponsiveNavigationScaffold({
    super.key,
    required this.body,
    this.sidebar,
    this.secondary,
    this.tabletSecondary,
    this.bottomBar,
    this.phoneBreakpoint = 600,
    this.desktopBreakpoint = 900,
    this.showSidebarOnPhone = false,
    this.showSidebarOnTablet = true,
    this.showSidebarOnDesktop = true,
    this.showBottomBarOnTablet = false,
    this.showBottomBarOnDesktop = false,
    this.showSecondaryOnTablet = false,
    this.showSecondaryOnDesktop = true,
  });

  final Widget body;

  /// Sidebar shown persistently on tablet/desktop. On phone, host app
  /// is responsible for presenting it through `UiDrawerScope.show`.
  final Widget? sidebar;

  /// Optional right-side panel on desktop form factor.
  final Widget? secondary;

  /// Optional secondary panel specifically for tablet form factor.
  final Widget? tabletSecondary;

  /// Bar shown on phone form factor (typically a [UiBottomTabBar]).
  final Widget? bottomBar;

  final double phoneBreakpoint;
  final double desktopBreakpoint;
  final bool showSidebarOnPhone;
  final bool showSidebarOnTablet;
  final bool showSidebarOnDesktop;
  final bool showBottomBarOnTablet;
  final bool showBottomBarOnDesktop;
  final bool showSecondaryOnTablet;
  final bool showSecondaryOnDesktop;

  UiNavigationFormFactor resolveFormFactor(double width) {
    if (width >= desktopBreakpoint) return UiNavigationFormFactor.desktop;
    if (width >= phoneBreakpoint) return UiNavigationFormFactor.tablet;
    return UiNavigationFormFactor.phone;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final form = resolveFormFactor(constraints.maxWidth);
        switch (form) {
          case UiNavigationFormFactor.phone:
            if (showSidebarOnPhone && sidebar != null) {
              return _SideChromeLayout(
                sidebar: sidebar,
                body: _BodyWithFloatingChrome(
                  body: body,
                  bottomBar: bottomBar,
                  hasPersistentRail: true,
                ),
              );
            }
            return _BodyWithFloatingChrome(
              body: body,
              bottomBar: bottomBar,
              hasPersistentRail: false,
            );
          case UiNavigationFormFactor.tablet:
            final resolvedTabletSecondary = tabletSecondary ?? secondary;
            return _SideChromeLayout(
              sidebar: showSidebarOnTablet ? sidebar : null,
              body: _BodyWithFloatingChrome(
                body: body,
                bottomBar: showBottomBarOnTablet ? bottomBar : null,
                hasPersistentRail: showSidebarOnTablet && sidebar != null,
              ),
              secondary: showSecondaryOnTablet ? resolvedTabletSecondary : null,
            );
          case UiNavigationFormFactor.desktop:
            return _SideChromeLayout(
              sidebar: showSidebarOnDesktop ? sidebar : null,
              body: _BodyWithFloatingChrome(
                body: body,
                bottomBar: showBottomBarOnDesktop ? bottomBar : null,
                hasPersistentRail: showSidebarOnDesktop && sidebar != null,
              ),
              secondary: showSecondaryOnDesktop ? secondary : null,
            );
        }
      },
    );
  }
}

enum _SideChromeSlot { body, sidebar, secondary }

class _SideChromeLayout extends StatelessWidget {
  const _SideChromeLayout({
    required this.body,
    this.sidebar,
    this.secondary,
  });

  final Widget body;
  final Widget? sidebar;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    if (sidebar == null && secondary == null) return body;

    return CustomMultiChildLayout(
      delegate: _SideChromeLayoutDelegate(Directionality.of(context)),
      children: [
        LayoutId(id: _SideChromeSlot.body, child: body),
        if (secondary != null)
          LayoutId(id: _SideChromeSlot.secondary, child: secondary!),
        if (sidebar != null)
          LayoutId(id: _SideChromeSlot.sidebar, child: sidebar!),
      ],
    );
  }
}

class _SideChromeLayoutDelegate extends MultiChildLayoutDelegate {
  _SideChromeLayoutDelegate(this.textDirection);

  final TextDirection textDirection;

  @override
  void performLayout(Size size) {
    final sidebarSize = hasChild(_SideChromeSlot.sidebar)
        ? layoutChild(
            _SideChromeSlot.sidebar,
            BoxConstraints.loose(size).copyWith(maxHeight: size.height),
          )
        : Size.zero;
    final secondarySize = hasChild(_SideChromeSlot.secondary)
        ? layoutChild(
            _SideChromeSlot.secondary,
            BoxConstraints.loose(size).copyWith(maxHeight: size.height),
          )
        : Size.zero;

    final bodyWidth = (size.width - sidebarSize.width - secondarySize.width)
        .clamp(0.0, size.width);
    layoutChild(
      _SideChromeSlot.body,
      BoxConstraints.tight(Size(bodyWidth, size.height)),
    );

    final rtl = textDirection == TextDirection.rtl;
    final sidebarX = rtl ? size.width - sidebarSize.width : 0.0;
    final secondaryX = rtl ? 0.0 : size.width - secondarySize.width;
    final bodyX = rtl ? secondarySize.width : sidebarSize.width;

    positionChild(_SideChromeSlot.body, Offset(bodyX, 0));
    if (hasChild(_SideChromeSlot.secondary)) {
      positionChild(_SideChromeSlot.secondary, Offset(secondaryX, 0));
    }
    if (hasChild(_SideChromeSlot.sidebar)) {
      positionChild(_SideChromeSlot.sidebar, Offset(sidebarX, 0));
    }
  }

  @override
  bool shouldRelayout(covariant _SideChromeLayoutDelegate oldDelegate) {
    return oldDelegate.textDirection != textDirection;
  }
}

class _BodyWithFloatingChrome extends StatelessWidget {
  const _BodyWithFloatingChrome({
    required this.body,
    required this.bottomBar,
    required this.hasPersistentRail,
  });

  final Widget body;
  final Widget? bottomBar;
  final bool hasPersistentRail;

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    if (bottomBar != null) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: body),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: bottomBar!,
          ),
        ],
      );
    }

    return UiNavigationChromeScope(
      hasPersistentRail: hasPersistentRail,
      child: content,
    );
  }
}
