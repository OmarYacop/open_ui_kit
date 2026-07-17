import 'package:flutter/material.dart';

import '../../foundation/layout/ui_form_factor.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_brand.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_page_scaffold.dart';
import 'ui_safe_viewport.dart';

/// Semantic page pattern built on [UiPageScaffold].
///
/// Use this when a screen has common page parts (title, actions, filters,
/// primary content, and optional secondary content) and the kit should own
/// their responsive placement. Lower-level screens can still use
/// [UiPageScaffold] directly when they need full manual control.
class UiPageLayout extends StatelessWidget {
  const UiPageLayout({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.brand,
    this.leading,
    this.actions = const <Widget>[],
    this.filters,
    this.secondary,
    this.bottomBar,
    this.backgroundColor,
    this.safeViewportMode = UiSafeViewportMode.none,
    this.safeAreaMinimum = EdgeInsets.zero,
    this.syncSystemBars = true,
    this.leftSafeInset = true,
    this.rightSafeInset = true,
    this.showTopDivider = true,
    this.showBottomDivider = true,
    this.breakpoints = UiBreakpoints.standard,
    this.filtersPaneWidth = 280,
    this.secondaryPaneWidth = 360,
  });

  /// Main page content. This is always the primary flexible region.
  final Widget body;

  /// Page title rendered in the generated top bar.
  final String? title;

  /// Optional supporting text rendered below [title].
  final String? subtitle;

  /// Brand configuration used by the generated top bar.
  final UiBrand? brand;

  /// Leading top-bar affordance, usually a back button or menu trigger.
  final Widget? leading;

  /// Trailing page actions. The wrapper keeps these in the page chrome.
  final List<Widget> actions;

  /// Filtering or navigation controls. On compact viewports this is placed
  /// above [body]; on larger viewports it becomes a left pane.
  final Widget? filters;

  /// Inspector/detail content. On compact viewports this is placed below the
  /// primary body region; on larger viewports it becomes a right pane.
  final Widget? secondary;

  /// Bottom chrome, passed through to [UiPageScaffold].
  final Widget? bottomBar;

  final Color? backgroundColor;
  final UiSafeViewportMode safeViewportMode;
  final EdgeInsets safeAreaMinimum;
  final bool syncSystemBars;
  final bool leftSafeInset;
  final bool rightSafeInset;
  final bool showTopDivider;
  final bool showBottomDivider;
  final UiBreakpoints breakpoints;
  final double filtersPaneWidth;
  final double secondaryPaneWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = breakpoints.resolve(constraints.maxWidth);
        return UiPageScaffold(
          topBar: _buildTopBar(context),
          bottomBar: bottomBar,
          backgroundColor: backgroundColor,
          safeViewportMode: safeViewportMode,
          safeAreaMinimum: safeAreaMinimum,
          syncSystemBars: syncSystemBars,
          leftSafeInset: leftSafeInset,
          rightSafeInset: rightSafeInset,
          showTopDivider: showTopDivider,
          showBottomDivider: showBottomDivider,
          body: _buildBody(formFactor),
        );
      },
    );
  }

  Widget? _buildTopBar(BuildContext context) {
    if (title == null &&
        subtitle == null &&
        brand == null &&
        leading == null &&
        actions.isEmpty) {
      return null;
    }

    final tokens = UiThemeTokens.of(context);
    final brightness = Theme.of(context).brightness;
    final logo = brand?.resolveLogo(brightness);

    return UiBox(
      background: tokens.colors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.x4,
        vertical: tokens.spacing.x3,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: tokens.spacing.x3),
          ],
          if (logo != null) ...[
            Flexible(
              child: Semantics(
                container: true,
                label: '${brand!.displayName} logo',
                child: ExcludeSemantics(child: logo),
              ),
            ),
            SizedBox(width: tokens.spacing.x3),
          ],
          Expanded(
            child: _PageTitle(title: title, subtitle: subtitle),
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(width: tokens.spacing.x3),
            _PageActions(actions: actions),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(UiFormFactor formFactor) {
    if (filters == null && secondary == null) return body;

    switch (formFactor) {
      case UiFormFactor.phone:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (filters != null) filters!,
            Expanded(child: body),
            if (secondary != null) secondary!,
          ],
        );
      case UiFormFactor.tablet:
      case UiFormFactor.desktop:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (filters != null)
              SizedBox(width: filtersPaneWidth, child: filters!),
            Expanded(child: body),
            if (secondary != null)
              SizedBox(width: secondaryPaneWidth, child: secondary!),
          ],
        );
    }
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.subtitle});

  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    if (title == null && subtitle == null) return const SizedBox.shrink();

    if (subtitle == null) {
      return UiText(
        title ?? '',
        variant: UiTextVariant.heading,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          UiText(
            title!,
            variant: UiTextVariant.heading,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        UiText(
          subtitle!,
          variant: UiTextVariant.bodySm,
          tone: UiTextTone.muted,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PageActions extends StatelessWidget {
  const _PageActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final gap = UiThemeTokens.of(context).spacing.x2;
    final children = <Widget>[];
    for (var i = 0; i < actions.length; i += 1) {
      if (i > 0) children.add(SizedBox(width: gap));
      children.add(actions[i]);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
