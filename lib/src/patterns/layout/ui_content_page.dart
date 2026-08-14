import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../components/feedback/refresher.dart';
import '../../foundation/platform/ui_floating_window_chrome.dart';
import '../../foundation/platform/ui_platform_capabilities.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../navigation/ui_navigation_spec.dart';
import '../navigation/ui_sliver_navigation_bar.dart';
import 'ui_page_scaffold.dart';
import 'ui_safe_viewport.dart';

/// A titled, vertically scrolling page composed from Open UI Kit navigation,
/// safe-area, spacing, and refresh primitives.
///
/// Use this for straightforward content pages whose body is a sequence of
/// sections. Screens that own custom slivers should compose
/// [UiPageScaffold] and [UiSliverNavigationBar] directly.
class UiContentPage extends StatefulWidget {
  const UiContentPage({
    super.key,
    required this.title,
    this.subtitle,
    this.compactTitle,
    this.showCompactTitle = true,
    this.actions = const <Widget>[],
    this.children = const <Widget>[],
    this.padding,
    this.childSpacing,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final String? compactTitle;
  final bool showCompactTitle;
  final List<Widget> actions;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double? childSpacing;
  final Future<void> Function()? onRefresh;

  @override
  State<UiContentPage> createState() => _UiContentPageState();
}

class _UiContentPageState extends State<UiContentPage>
    with WidgetsBindingObserver {
  static const _windowModeDebounce = Duration(milliseconds: 140);
  static const _compactBreakpoint = 600.0;

  final UiPlatformCapabilities _platformCapabilities =
      UiPlatformCapabilities.shared;

  Timer? _windowModeRefreshTimer;
  int _windowModeRefreshToken = 0;
  UiWindowMode? _windowMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleWindowModeRefresh(immediate: true);
  }

  @override
  void dispose() {
    _windowModeRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _scheduleWindowModeRefresh(forceRefresh: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleWindowModeRefresh(forceRefresh: true);
    }
  }

  void _scheduleWindowModeRefresh({
    bool immediate = false,
    bool forceRefresh = false,
  }) {
    _windowModeRefreshTimer?.cancel();

    if (immediate) {
      unawaited(_refreshWindowMode(forceRefresh: forceRefresh));
      return;
    }

    _windowModeRefreshTimer = Timer(_windowModeDebounce, () {
      unawaited(_refreshWindowMode(forceRefresh: forceRefresh));
    });
  }

  Future<void> _refreshWindowMode({bool forceRefresh = false}) async {
    final token = ++_windowModeRefreshToken;
    try {
      final mode = await _platformCapabilities.currentWindowMode(
        forceRefresh: forceRefresh,
      );
      if (!mounted || token != _windowModeRefreshToken || mode == _windowMode) {
        return;
      }
      setState(() => _windowMode = mode);
    } catch (_) {
      // Tests and unsupported embedders may not register the native channel.
      // MediaQuery remains the non-fatal fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final spacing = widget.childSpacing ?? tokens.spacing.x4;
    final floatingWindowChromeLeadingInset =
        resolveUiFloatingWindowChromeLeadingInset(context, _windowMode);

    return UiPageScaffold(
      safeViewportMode: UiSafeViewportMode.all,
      showTopDivider: false,
      showBottomDivider: false,
      onRefresh: widget.onRefresh,
      body: Builder(
        builder: (context) {
          final basePadding = (widget.padding ??
                  EdgeInsets.fromLTRB(
                    tokens.spacing.x4,
                    tokens.spacing.x4,
                    tokens.spacing.x4,
                    tokens.spacing.x16 + tokens.spacing.x8,
                  ))
              .resolve(Directionality.of(context));
          final bodyInsets = UiPageBodyInsets.of(context);

          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth.isFinite &&
                  constraints.maxWidth < _compactBreakpoint;
              final titleStartPadding =
                  compact ? floatingWindowChromeLeadingInset : 0.0;
              final contentPadding = EdgeInsets.fromLTRB(
                basePadding.left,
                basePadding.top,
                basePadding.right,
                basePadding.bottom + bodyInsets.bottom,
              );

              return CustomScrollView(
                physics:
                    widget.onRefresh == null ? null : UiRefresher.sliverPhysics,
                slivers: [
                  UiSliverNavigationBar(
                    spec: UiNavigationSpec(
                      title: widget.title,
                      subtitle: widget.subtitle,
                      compactTitle: widget.compactTitle,
                      showCompactTitle: widget.showCompactTitle,
                      actions: widget.actions,
                      surface: UiNavigationSurface.transparent,
                      showDivider: false,
                      leading: titleStartPadding > 0
                          ? SizedBox(width: titleStartPadding)
                          : null,
                    ),
                  ),
                  SliverPadding(
                    padding: contentPadding,
                    sliver: SliverList.list(
                      children: [
                        for (var i = 0; i < widget.children.length; i++) ...[
                          if (i > 0) SizedBox(height: spacing),
                          widget.children[i],
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
