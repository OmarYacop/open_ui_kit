import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../../foundation/layout/ui_keyboard_geometry.dart';
import '../../foundation/layout/ui_edge_aware_insets.dart';
import 'chat_header.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../layout/ui_page_scaffold.dart';
import '../layout/ui_safe_viewport.dart';
import 'conversation_layout.dart';

/// Conversation page that owns safe areas, chrome measurement and IME avoidance.
///
/// Pass the supplied history padding through to the timeline. Do not wrap the
/// composer in another keyboard dock or the page in another resizing scaffold.
/// Header widgets own their top safe area (as [UiChatHeader] does).
class UiChatScaffold extends StatefulWidget {
  const UiChatScaffold({
    super.key,
    required this.header,
    required this.composer,
    required this.historyBuilder,
    this.floatingControls,
    this.fadeHistory = true,
    this.composerBottomGap,
  });

  final Widget header;
  final Widget composer;
  final Widget? floatingControls;
  final Widget Function(BuildContext, EdgeInsets) historyBuilder;
  final bool fadeHistory;
  final double? composerBottomGap;

  @override
  State<UiChatScaffold> createState() => _UiChatScaffoldState();
}

class _UiChatScaffoldState extends State<UiChatScaffold> {
  final _headerKey = GlobalKey();
  final _composerKey = GlobalKey();
  double _headerHeight = 0;
  double _composerHeight = 0;
  bool _scheduled = false;

  void _scheduleMeasurement() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final header =
          _headerKey.currentContext?.findRenderObject() as RenderBox?;
      final composer =
          _composerKey.currentContext?.findRenderObject() as RenderBox?;
      final h = header?.hasSize == true ? header!.size.height : 0.0;
      final c = composer?.hasSize == true ? composer!.size.height : 0.0;
      if ((h - _headerHeight).abs() < .1 && (c - _composerHeight).abs() < .1) {
        return;
      }
      setState(() {
        _headerHeight = h;
        _composerHeight = c;
      });
    });
  }

  Widget _measure(GlobalKey key, Widget child) =>
      NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _scheduleMeasurement();
          return false;
        },
        child: SizeChangedLayoutNotifier(key: key, child: child),
      );

  @override
  Widget build(BuildContext context) {
    _scheduleMeasurement();
    final tokens = UiThemeTokens.of(context);
    final gap =
        widget.composerBottomGap ??
        (UiKeyboardGeometry.currentInsetOf(context) > 0
            ? 0
            : resolveUiEdgeAwareBottomOffset(
                context,
                minimum: tokens.spacing.x2,
              ));
    return UiPageScaffold(
      scrollFade: false,
      resizeBodyForKeyboard: false,
      safeViewportMode: UiSafeViewportMode.none,
      body: UiConversationLayout(
        header: _measure(_headerKey, widget.header),
        headerExtent: _headerHeight,
        composerExtent: _composerHeight,
        historyBottomGap: 0,
        composerBottomGap: gap,
        obscuredBottomInset: UiKeyboardGeometry.currentInsetOf(context),
        fadeHistory: widget.fadeHistory,
        historyBuilder: (context, padding) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
          },
          child: widget.historyBuilder(context, padding),
        ),
        composer: UiKeyboardDock(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.floatingControls != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.x3),
                  child: widget.floatingControls!,
                ),
              _measure(_composerKey, widget.composer),
            ],
          ),
        ),
      ),
    );
  }
}
