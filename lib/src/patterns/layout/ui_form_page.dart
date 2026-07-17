import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_page_layout.dart';
import 'ui_page_scaffold.dart';
import 'ui_safe_viewport.dart';

/// Semantic form page pattern.
///
/// This wraps the common app form shape: generated page chrome, a centered
/// max-width form column, optional visual/header content, form fields, helper
/// or legal copy, and bottom actions. It is intentionally slot-based so screen
/// authors describe intent while the kit owns consistent placement.
class UiFormPage extends StatelessWidget {
  const UiFormPage({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.leading,
    this.pageActions = const <Widget>[],
    this.hero,
    this.footer,
    this.actions = const <Widget>[],
    this.maxWidth = 600,
    this.padding,
    this.fieldSpacing,
    this.actionSpacing,
    this.safeViewportMode = UiSafeViewportMode.keyboardAware,
  });

  /// Form fields or field groups.
  final List<Widget> children;

  /// Title rendered by the generated page chrome.
  final String? title;

  /// Subtitle rendered by the generated page chrome.
  final String? subtitle;

  /// Leading page-chrome affordance.
  final Widget? leading;

  /// Actions rendered in the page chrome.
  final List<Widget> pageActions;

  /// Optional visual or explanatory content above the fields.
  final Widget? hero;

  /// Supporting copy rendered above [actions].
  final Widget? footer;

  /// Form actions rendered at the bottom of the form column.
  final List<Widget> actions;

  /// Maximum form column width.
  final double maxWidth;

  /// Outer form padding. Defaults to `spacing.x5` on every side.
  final EdgeInsets? padding;

  /// Gap between [children]. Defaults to `spacing.x4`.
  final double? fieldSpacing;

  /// Gap between [actions]. Defaults to `spacing.x3`.
  final double? actionSpacing;

  final UiSafeViewportMode safeViewportMode;

  @override
  Widget build(BuildContext context) {
    return UiPageLayout(
      title: title,
      subtitle: subtitle,
      leading: leading,
      actions: pageActions,
      safeViewportMode: safeViewportMode,
      body: _FormBody(
        maxWidth: maxWidth,
        padding: padding,
        fieldSpacing: fieldSpacing,
        actionSpacing: actionSpacing,
        hero: hero,
        footer: footer,
        actions: actions,
        children: children,
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.maxWidth,
    required this.padding,
    required this.fieldSpacing,
    required this.actionSpacing,
    required this.hero,
    required this.footer,
    required this.actions,
    required this.children,
  });

  final double maxWidth;
  final EdgeInsets? padding;
  final double? fieldSpacing;
  final double? actionSpacing;
  final Widget? hero;
  final Widget? footer;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final resolvedPadding = _withBodyInsets(
      context,
      padding ?? EdgeInsets.all(tokens.spacing.x5),
    );
    final resolvedFieldSpacing = fieldSpacing ?? tokens.spacing.x4;
    final resolvedActionSpacing = actionSpacing ?? tokens.spacing.x3;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: resolvedPadding,
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hero != null) Flexible(child: hero!),
                    ..._spaced(children, resolvedFieldSpacing),
                    const Spacer(),
                    if (footer != null) ...[
                      footer!,
                      SizedBox(height: tokens.spacing.x5),
                    ],
                    ..._spaced(actions, resolvedActionSpacing),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _spaced(List<Widget> widgets, double gap) {
    final result = <Widget>[];
    for (var i = 0; i < widgets.length; i += 1) {
      if (i > 0) result.add(SizedBox(height: gap));
      result.add(widgets[i]);
    }
    return result;
  }
}

EdgeInsets _withBodyInsets(BuildContext context, EdgeInsets padding) {
  final insets = UiPageBodyInsets.of(context);
  return EdgeInsets.fromLTRB(
    padding.left + insets.left,
    padding.top + insets.top,
    padding.right + insets.right,
    padding.bottom + insets.bottom,
  );
}
