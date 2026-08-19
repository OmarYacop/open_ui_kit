import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../foundation/layout/ui_form_factor.dart';
import '../../foundation/motion/ui_motion_spec.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/primitives/ui_divider.dart';
import '../navigation/ui_navigation_transition.dart';
import '../navigation/ui_page_route.dart';

/// Selection controller for [UiDualPane].
///
/// The controller intentionally owns only selection state. [UiDualPane] owns
/// how that state is presented for each form factor.
class UiDualPaneController<T> extends ChangeNotifier {
  UiDualPaneController({T? selected}) : _selected = selected;

  T? _selected;

  T? get selected => _selected;

  bool get hasSelection => _selected != null;

  void select(T? value) {
    if (_selected == value) return;
    _selected = value;
    notifyListeners();
  }

  void clear() => select(null);
}

/// Inherited access to a [UiDualPaneController].
class UiDualPaneScope<T> extends InheritedNotifier<UiDualPaneController<T>> {
  const UiDualPaneScope({
    super.key,
    required UiDualPaneController<T> controller,
    required super.child,
  }) : super(notifier: controller);

  static UiDualPaneController<T>? maybeOf<T>(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<UiDualPaneScope<T>>()
        ?.notifier;
  }

  static UiDualPaneController<T> of<T>(BuildContext context) {
    final controller = maybeOf<T>(context);
    assert(
      controller != null,
      'UiDualPaneScope.of() called with no UiDualPaneScope in context.',
    );
    return controller!;
  }
}

typedef UiDualPaneBuilder<T> = Widget Function(
  BuildContext context,
  T? selected,
  void Function(T? value) select,
);

/// How a tablet-width master/detail surface should use constrained width.
enum UiDualPaneTabletMode {
  /// Keep both panes visible.
  split,

  /// Keep the primary pane mounted and slide the selected detail over it.
  ///
  /// This preserves useful working width in portrait while the detail's own
  /// back/close action returns focus to the primary pane.
  overlayDetail,
}

/// Adaptive master-detail layout.
///
/// - Phone: pushes the detail pane as a full-screen route so it covers shell
///   chrome, bottom navigation, and owns the mobile safe area.
/// - Tablet/desktop: renders both panes side-by-side.
class UiDualPane<T> extends StatefulWidget {
  const UiDualPane({
    super.key,
    required this.controller,
    required this.primaryBuilder,
    required this.detailBuilder,
    this.primaryFlex = 1,
    this.detailFlex = 2,
    this.gap = 12,
    this.showDivider = true,
    this.breakpoints = UiBreakpoints.standard,
    this.phoneTransitionStyle,
    this.transitionDuration = UiMotionDuration.standard,
    this.reverseTransitionDuration = UiMotionDuration.standard,
    this.phoneUsesRootNavigator = true,
    this.tabletMode = UiDualPaneTabletMode.split,
    this.collapseDetailWithoutSelection = false,
    this.phoneEdgeSwipePop,
  });

  final UiDualPaneController<T> controller;
  final UiDualPaneBuilder<T> primaryBuilder;
  final UiDualPaneBuilder<T> detailBuilder;
  final int primaryFlex;
  final int detailFlex;
  final double gap;
  final bool showDivider;
  final UiBreakpoints breakpoints;

  /// Style for the phone-pushed detail route. `null` (the default) falls
  /// back to [UiApp]'s `defaultPageTransitionStyle` ambiently ([UiPageRouteDefaults]),
  /// same as [BuildContext.pushUiPage] — so this stays in sync with the
  /// app-wide push/pop style unless explicitly overridden here.
  final UiNavigationTransitionStyle? phoneTransitionStyle;
  final UiMotionDuration transitionDuration;
  final UiMotionDuration reverseTransitionDuration;

  /// When true, phone details are pushed on the root navigator.
  ///
  /// This lets master-detail pages inside app shells cover bottom navigation
  /// bars and own their full safe area, which is the expected mobile behavior.
  final bool phoneUsesRootNavigator;
  final UiDualPaneTabletMode tabletMode;

  /// Lets overview-style primary panes use the full width until a detail is
  /// selected. Chat-style layouts generally leave this false so their empty
  /// detail state remains visible.
  final bool collapseDetailWithoutSelection;

  /// Whether the phone-pushed detail route supports an edge-drag-from-the-
  /// left gesture to pop, the way a native iOS push does.
  ///
  /// Backed by [UiCupertinoBackGestureMixin], which only ever attaches the
  /// gesture on iOS — Android's system back gesture already pops a real
  /// `Navigator` route like this one without any help, and this mixin
  /// specifically reimplements Apple's own edge-swipe convention rather
  /// than a cross-platform one, so there is no "force it on Android" to
  /// opt into. `null` (the default) and `true` both mean "enabled where
  /// it's a native convention"; pass `false` to opt a specific
  /// [UiDualPane] out of it entirely, including on iOS.
  ///
  /// The gesture drives the route's own transition directly, so it always
  /// plays exactly [phoneTransitionStyle] — there is no separate
  /// drag-preview visual to configure.
  final bool? phoneEdgeSwipePop;

  @override
  State<UiDualPane<T>> createState() => _UiDualPaneState<T>();
}

class _UiDualPaneState<T> extends State<UiDualPane<T>> {
  bool _phoneRouteOpen = false;

  @override
  Widget build(BuildContext context) {
    final formFactor = uiFormFactorOf(
      context,
      breakpoints: widget.breakpoints,
    );

    return UiDualPaneScope<T>(
      controller: widget.controller,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return switch (formFactor) {
            UiFormFactor.phone => _buildPhone(context),
            UiFormFactor.tablet =>
              widget.tabletMode == UiDualPaneTabletMode.overlayDetail
                  ? _buildTabletOverlay(context)
                  : _buildWide(context),
            UiFormFactor.desktop => _buildWide(context),
          };
        },
      ),
    );
  }

  Widget _buildPhone(BuildContext context) {
    return _Pane<T>(
      key: const ValueKey('ui-dual-pane-primary'),
      controller: widget.controller,
      builder: (context, selected, _) {
        return widget.primaryBuilder(context, selected, (value) {
          _selectPhoneDetail(context, value);
        });
      },
    );
  }

  Widget _buildWide(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final selected = widget.controller.selected;
    final animateCollapsedDetail = widget.collapseDetailWithoutSelection;
    final detailVisible = selected != null || !animateCollapsedDetail;
    final totalFlex = widget.primaryFlex + widget.detailFlex;
    final splitFraction = totalFlex <= 0 ? 0.5 : widget.primaryFlex / totalFlex;

    return LayoutBuilder(
      builder: (context, constraints) {
        return TweenAnimationBuilder<double>(
          duration: detailVisible
              ? widget.transitionDuration.resolve(context)
              : widget.reverseTransitionDuration.resolve(context),
          curve: tokens.motion.standardCurve,
          tween: Tween<double>(end: detailVisible ? splitFraction : 1),
          builder: (context, primaryFraction, _) {
            final dividerWidth = widget.showDivider ? 1.0 : 0.0;
            final separation = detailVisible || primaryFraction < 0.999
                ? widget.gap + dividerWidth
                : 0.0;
            final usableWidth =
                (constraints.maxWidth - separation).clamp(0.0, double.infinity);
            final primaryWidth = usableWidth * primaryFraction;
            final detailWidth =
                (usableWidth - primaryWidth).clamp(0.0, double.infinity);
            final settledDetailWidth = usableWidth * (1 - splitFraction);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  key: detailVisible
                      ? const ValueKey('ui-dual-pane-wide-primary')
                      : const ValueKey('ui-dual-pane-wide-primary-only'),
                  width: primaryWidth,
                  child: ClipRect(
                    child: _Pane<T>(
                      controller: widget.controller,
                      builder: widget.primaryBuilder,
                    ),
                  ),
                ),
                if (separation > 0) ...[
                  if (widget.showDivider)
                    const SizedBox(
                      width: 1,
                      child: UiDivider(axis: Axis.vertical),
                    ),
                  if (widget.gap > 0) SizedBox(width: widget.gap),
                ],
                if (detailWidth > 0)
                  SizedBox(
                    key: const ValueKey('ui-dual-pane-wide-detail'),
                    width: detailWidth,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: AlignmentDirectional.centerStart,
                        minWidth: settledDetailWidth,
                        maxWidth: settledDetailWidth,
                        child: AnimatedSwitcher(
                          duration: widget.transitionDuration.resolve(context),
                          reverseDuration:
                              widget.reverseTransitionDuration.resolve(context),
                          switchInCurve: tokens.motion.standardCurve,
                          switchOutCurve: tokens.motion.standardCurve,
                          child: selected == null
                              ? const SizedBox.shrink(
                                  key: ValueKey(
                                    'ui-dual-pane-wide-detail-empty',
                                  ),
                                )
                              : DecoratedBox(
                                  key: ValueKey<Object>(selected as Object),
                                  decoration: BoxDecoration(
                                    color: tokens.colors.background,
                                  ),
                                  child: _SelectedPane<T>(
                                    controller: widget.controller,
                                    selected: selected,
                                    builder: widget.detailBuilder,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTabletOverlay(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final selected = widget.controller.selected;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Stack(
      fit: StackFit.expand,
      children: [
        _Pane<T>(
          key: const ValueKey('ui-dual-pane-tablet-primary'),
          controller: widget.controller,
          builder: widget.primaryBuilder,
        ),
        AnimatedSwitcher(
          duration: widget.transitionDuration.resolve(context),
          reverseDuration: widget.reverseTransitionDuration.resolve(context),
          switchInCurve: tokens.motion.standardCurve,
          switchOutCurve: tokens.motion.standardCurve,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(isRtl ? -0.08 : 0.08, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: selected == null
              ? const SizedBox.shrink(
                  key: ValueKey('ui-dual-pane-tablet-detail-empty'),
                )
              : DecoratedBox(
                  key: ValueKey<Object>(selected as Object),
                  decoration: BoxDecoration(
                    color: tokens.colors.background,
                    boxShadow: tokens.shadows.lg,
                  ),
                  child: _SelectedPane<T>(
                    controller: widget.controller,
                    selected: selected,
                    builder: widget.detailBuilder,
                  ),
                ),
        ),
      ],
    );
  }

  void _selectPhoneDetail(BuildContext context, T? value) {
    if (value == null) {
      widget.controller.clear();
      return;
    }

    widget.controller.select(value);
    if (_phoneRouteOpen) return;

    _phoneRouteOpen = true;
    final navigator = Navigator.of(
      context,
      rootNavigator: widget.phoneUsesRootNavigator,
    );
    // iOS users expect an edge-drag from the left to pop a pushed page —
    // nothing in a bare PageRouteBuilder provides that gesture on its own
    // (unlike CupertinoPageRoute, which owns it internally).
    // UiCupertinoBackGestureMixin only ever attaches the gesture on iOS
    // regardless of this flag (Android's system back gesture already pops
    // a real Navigator route without any help, and this mixin
    // specifically reimplements Apple's own convention, not a
    // cross-platform one) — `false` disables it there too; `true`/`null`
    // both mean "enabled where it's a native convention". Both flags fall
    // back to UiApp's app-wide default (UiPageRouteDefaults) before the
    // kit's own hard-coded default, so this pane stays in sync with the
    // rest of the app's push/pop unless explicitly overridden.
    final pageDefaults = UiPageRouteDefaults.maybeOf(context);
    final swipeEnabled =
        widget.phoneEdgeSwipePop ?? pageDefaults?.swipeBackEnabled ?? true;
    final transitionStyle = widget.phoneTransitionStyle ??
        pageDefaults?.transitionStyle ??
        UiNavigationTransitionStyle.softShift;

    unawaited(
      navigator
          .push<void>(
        // UiPageRoute is Open UI Kit's standard push/pop (see its own
        // doc) — using it here, the same as UiApp uses for its default
        // routes, is what makes this phone-pushed detail read as the
        // same signature motion as every other push in the app rather
        // than a bespoke one. Its edge-swipe gesture drives this route's
        // own transition directly, so the interactive drag isn't a
        // separately hand-built preview: nothing here needs to snapshot
        // or composite the primary pane underneath, because Flutter's
        // own Navigator already paints both routes correctly for any
        // in-flight transition.
        UiPageRoute<void>(
          swipeBackEnabled: swipeEnabled,
          transitionStyle: transitionStyle,
          transitionDuration: widget.transitionDuration.resolve(context),
          reverseTransitionDuration:
              widget.reverseTransitionDuration.resolve(context),
          builder: (routeContext) {
            return UiDualPaneScope<T>(
              controller: widget.controller,
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  return SizedBox.expand(
                    child: widget.detailBuilder(
                      context,
                      widget.controller.selected,
                      (next) => _selectPhoneRouteDetail(context, next),
                    ),
                  );
                },
              ),
            );
          },
        ),
      )
          .whenComplete(() {
        if (!mounted) return;
        _phoneRouteOpen = false;
        widget.controller.clear();
      }),
    );
  }

  void _selectPhoneRouteDetail(BuildContext context, T? value) {
    if (value == null) {
      Navigator.of(context).maybePop();
      return;
    }

    widget.controller.select(value);
  }
}

class _Pane<T> extends StatelessWidget {
  const _Pane({
    super.key,
    required this.controller,
    required this.builder,
  });

  final UiDualPaneController<T> controller;
  final UiDualPaneBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    return builder(context, controller.selected, controller.select);
  }
}

/// Keeps an outgoing detail bound to the value it was built for while its
/// transition finishes. Without this snapshot, clearing the shared controller
/// can rebuild the fading pane with the empty-detail UI for a frame.
class _SelectedPane<T> extends StatelessWidget {
  const _SelectedPane({
    required this.controller,
    required this.selected,
    required this.builder,
  });

  final UiDualPaneController<T> controller;
  final T selected;
  final UiDualPaneBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    return builder(context, selected, controller.select);
  }
}
