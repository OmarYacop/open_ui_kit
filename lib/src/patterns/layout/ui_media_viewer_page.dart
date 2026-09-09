import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/foundation.dart';
import '../navigation/ui_navigation_spec.dart';
import '../navigation/ui_sliver_navigation_bar.dart';
import 'ui_page_scaffold.dart';
import 'ui_safe_viewport.dart';

/// An edge-to-edge media page with canonical navigation over the content.
///
/// Supply application-owned images, players or document renderers in [child].
/// The page owns safe insets and system bars; do not wrap it in another scaffold
/// or SafeArea. Playback overlays belong inside [child], persistent actions in
/// [footer]. Tap media to hide/reveal chrome without resizing the content.
/// Interactive children keep their own gestures. Screen-reader navigation keeps
/// chrome visible; Escape dismisses the page.
class UiMediaViewerPage extends StatefulWidget {
  const UiMediaViewerPage({
    super.key,
    required this.title,
    required this.dismissLabel,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.footer,
    this.caption,
    this.chromeVisible,
    this.onChromeVisibilityChanged,
    this.onDismiss,
    this.mediaBackgroundColor = UiPalette.black,
  });

  final String title;
  final String dismissLabel;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Widget? footer;

  /// Optional caption above the footer, scrollable within a quarter viewport.
  /// Omit for media without captions. The page supplies a legibility scrim.
  final Widget? caption;

  /// Controlled visibility for players that coordinate their own controls.
  /// Null lets the page own tap-to-toggle visibility.
  final bool? chromeVisible;
  final ValueChanged<bool>? onChromeVisibilityChanged;
  final VoidCallback? onDismiss;
  final Color mediaBackgroundColor;

  @override
  State<UiMediaViewerPage> createState() => _UiMediaViewerPageState();
}

class _UiMediaViewerPageState extends State<UiMediaViewerPage> {
  bool _chromeVisible = true;

  void _dismiss() {
    if (widget.onDismiss case final callback?) {
      callback();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final accessible = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    final visible = accessible || (widget.chromeVisible ?? _chromeVisible);
    // Only chrome adopts the dark media palette. Renderers retain app tokens.
    final chromeTokens = tokens.copyWith(
      colors: UiThemeTokens.dark.colors,
      brightness: Brightness.dark,
    );
    Widget chrome(Widget child, {bool bottom = false}) => UiTheme(
      tokens: chromeTokens,
      child: ExcludeFocus(
        excluding: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: tokens.motion.fast,
              curve: tokens.motion.standardCurve,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: bottom
                        ? Alignment.bottomCenter
                        : Alignment.topCenter,
                    end: bottom ? Alignment.topCenter : Alignment.bottomCenter,
                    colors: bottom
                        ? const [
                            Color(0xE6000000),
                            Color(0xB3000000),
                            Color(0x00000000),
                          ]
                        : const [Color(0xE6000000), Color(0x00000000)],
                    stops: bottom ? const [0, .8, 1] : null,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _dismiss},
      child: Focus(
        autofocus: true,
        child: UiPageScaffold(
          backgroundColor: widget.mediaBackgroundColor,
          safeViewportMode: UiSafeViewportMode.none,
          leftSafeInset: false,
          rightSafeInset: false,
          scrollFade: false,
          scrollFadeUsesSafeArea: false,
          body: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: accessible
                    ? null
                    : () {
                        final next = !visible;
                        if (widget.chromeVisible == null) {
                          setState(() => _chromeVisible = next);
                        }
                        widget.onChromeVisibilityChanged?.call(next);
                      },
                child: widget.child,
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: chrome(
                  SafeArea(
                    top: false, // The canonical navigation owns the top inset.
                    bottom: false,
                    child: CustomScrollView(
                      shrinkWrap: true,
                      primary: false,
                      physics: const NeverScrollableScrollPhysics(),
                      slivers: [
                        UiSliverNavigationBar(
                          useOverlay: false,
                          adaptToPersistentRail: false,
                          spec: UiNavigationSpec(
                            title: widget.title,
                            largeTitle: false,
                            surface: UiNavigationSurface.transparent,
                            showDivider: false,
                            back: UiNavigationBackConfig(
                              label: widget.dismissLabel,
                              onPressed: _dismiss,
                            ),
                            actions: widget.actions,
                          ),
                        ),
                        if (widget.subtitle case final text?)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                tokens.spacing.x4,
                                0,
                                tokens.spacing.x4,
                                tokens.spacing.x3,
                              ),
                              child: UiText(
                                text,
                                variant: UiTextVariant.caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.footer != null || widget.caption != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: chrome(
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          tokens.spacing.x4,
                          widget.caption == null
                              ? tokens.spacing.x3
                              : tokens.spacing.x8,
                          tokens.spacing.x4,
                          tokens.spacing.x3,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.caption case final caption?)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.sizeOf(context).height * .25,
                                ),
                                child: SingleChildScrollView(
                                  primary: false,
                                  child: caption,
                                ),
                              ),
                            if (widget.caption != null && widget.footer != null)
                              SizedBox(height: tokens.spacing.x3),
                            if (widget.footer case final footer?) footer,
                          ],
                        ),
                      ),
                    ),
                    bottom: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
