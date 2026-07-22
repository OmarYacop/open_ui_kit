import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../foundation/layout/ui_form_factor.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/primitives/ui_divider.dart';
import '../navigation/ui_navigation_transition.dart';

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
    this.phoneTransitionStyle = UiNavigationTransitionStyle.softShift,
    this.transitionDuration,
    this.phoneUsesRootNavigator = true,
  });

  final UiDualPaneController<T> controller;
  final UiDualPaneBuilder<T> primaryBuilder;
  final UiDualPaneBuilder<T> detailBuilder;
  final int primaryFlex;
  final int detailFlex;
  final double gap;
  final bool showDivider;
  final UiBreakpoints breakpoints;
  final UiNavigationTransitionStyle phoneTransitionStyle;
  final Duration? transitionDuration;

  /// When true, phone details are pushed on the root navigator.
  ///
  /// This lets master-detail pages inside app shells cover bottom navigation
  /// bars and own their full safe area, which is the expected mobile behavior.
  final bool phoneUsesRootNavigator;

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
            UiFormFactor.tablet || UiFormFactor.desktop => _buildWide(context),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: widget.primaryFlex,
          child: _Pane<T>(
            controller: widget.controller,
            builder: widget.primaryBuilder,
          ),
        ),
        if (widget.showDivider)
          const UiDivider(
            axis: Axis.vertical,
          ),
        if (widget.gap > 0) SizedBox(width: widget.gap),
        Expanded(
          flex: widget.detailFlex,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tokens.colors.background),
            child: _Pane<T>(
              controller: widget.controller,
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

    unawaited(
      navigator
          .push<void>(
        PageRouteBuilder<void>(
          opaque: true,
          pageBuilder: (routeContext, animation, secondaryAnimation) {
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
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return UiNavigationTransition(
              animation: animation,
              style: widget.phoneTransitionStyle,
              child: child,
            );
          },
          transitionDuration: widget.transitionDuration ??
              UiThemeTokens.of(context).motion.standard,
          reverseTransitionDuration: widget.transitionDuration ??
              UiThemeTokens.of(context).motion.fast,
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
