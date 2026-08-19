import 'package:flutter/widgets.dart';

import '../../foundation/foundation.dart';
import '../forms/forms.dart';

/// Application-owned media content displayed by [UiMediaGallery].
class UiMediaGalleryItem {
  const UiMediaGalleryItem({
    required this.builder,
    this.title,
    this.subtitle,
    this.heroTag,
    this.zoomable = true,
  });

  final WidgetBuilder builder;
  final String? title;
  final String? subtitle;
  final Object? heroTag;
  final bool zoomable;
}

/// An accessible icon action in the gallery chrome.
class UiMediaGalleryAction {
  const UiMediaGalleryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
}

/// Full-screen gallery chrome for images, video, documents, or custom media.
///
/// Fetching stays with the application so authenticated caches and specialized
/// renderers remain reusable. The gallery owns paging, pinch/double-tap zoom,
/// tap-to-hide controls, swipe-down dismissal, and toolbar semantics.
class UiMediaGallery extends StatefulWidget {
  const UiMediaGallery({
    super.key,
    required this.items,
    required this.dismissLabel,
    this.initialIndex = 0,
    this.actionsBuilder,
    this.bottomActionsBuilder,
    this.onDismiss,
    this.backgroundColor = UiPalette.black,
    this.minScale = 1,
    this.maxScale = 5,
  })  : assert(items.length > 0),
        assert(initialIndex >= 0 && initialIndex < items.length);

  final List<UiMediaGalleryItem> items;
  final String dismissLabel;
  final int initialIndex;
  final List<UiMediaGalleryAction> Function(BuildContext, int)? actionsBuilder;
  final List<UiMediaGalleryAction> Function(BuildContext, int)?
      bottomActionsBuilder;
  final VoidCallback? onDismiss;
  final Color backgroundColor;
  final double minScale;
  final double maxScale;

  @override
  State<UiMediaGallery> createState() => _UiMediaGalleryState();
}

class _UiMediaGalleryState extends State<UiMediaGallery> {
  late final PageController _pages;
  late int _index;
  bool _chromeVisible = true;
  bool _zoomed = false;
  double _verticalDrag = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pages = PageController(initialPage: _index);
  }

  void _dismiss() {
    if (widget.onDismiss case final callback?) {
      callback();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];
    final topActions = widget.actionsBuilder?.call(context, _index) ?? const [];
    final bottomActions =
        widget.bottomActionsBuilder?.call(context, _index) ?? const [];
    final duration = UiThemeTokens.of(context).motion.fast;

    return ColoredBox(
      color: widget.backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _chromeVisible = !_chromeVisible),
            onVerticalDragStart: _zoomed ? null : (_) => _verticalDrag = 0,
            onVerticalDragUpdate:
                _zoomed ? null : (details) => _verticalDrag += details.delta.dy,
            onVerticalDragEnd: _zoomed
                ? null
                : (details) {
                    if (_verticalDrag.abs() > 96 ||
                        (details.primaryVelocity ?? 0).abs() > 850) {
                      _dismiss();
                    }
                    _verticalDrag = 0;
                  },
            child: PageView.builder(
              controller: _pages,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              itemCount: widget.items.length,
              onPageChanged: (index) => setState(() {
                _index = index;
                _zoomed = false;
              }),
              itemBuilder: (context, index) {
                final entry = widget.items[index];
                Widget content = entry.builder(context);
                if (entry.heroTag case final tag?) {
                  content = Hero(tag: tag, child: content);
                }
                if (!entry.zoomable) return Center(child: content);
                return _UiZoomableMedia(
                  minScale: widget.minScale,
                  maxScale: widget.maxScale,
                  onZoomChanged: index == _index
                      ? (value) {
                          if (_zoomed != value && mounted) {
                            setState(() => _zoomed = value);
                          }
                        }
                      : null,
                  child: content,
                );
              },
            ),
          ),
          _ChromeVisibility(
            visible: _chromeVisible,
            duration: duration,
            alignment: Alignment.topCenter,
            child: _UiMediaChrome(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 12, 20),
                  child: Row(
                    children: [
                      _UiMediaAction(
                        action: UiMediaGalleryAction(
                          icon: UiDirectionalIcons.back(context),
                          label: widget.dismissLabel,
                          onPressed: _dismiss,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.title case final title?)
                              UiText(
                                title,
                                variant: UiTextVariant.label,
                                style: const TextStyle(color: UiPalette.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (item.subtitle case final subtitle?) ...[
                              const SizedBox(height: 2),
                              UiText(
                                subtitle,
                                variant: UiTextVariant.caption,
                                style: const TextStyle(
                                  color: UiPalette.white70,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      for (final action in topActions)
                        _UiMediaAction(action: action),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (bottomActions.isNotEmpty || widget.items.length > 1)
            _ChromeVisibility(
              visible: _chromeVisible,
              duration: duration,
              alignment: Alignment.bottomCenter,
              child: _UiMediaChrome(
                topToBottom: false,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      24,
                      16,
                      12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final action in bottomActions)
                          _UiMediaAction(action: action),
                        if (widget.items.length > 1) ...[
                          const SizedBox(width: 12),
                          Semantics(
                            liveRegion: true,
                            label: '${_index + 1} / ${widget.items.length}',
                            child: UiText(
                              '${_index + 1} / ${widget.items.length}',
                              variant: UiTextVariant.caption,
                              style: const TextStyle(color: UiPalette.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }
}

class _UiZoomableMedia extends StatefulWidget {
  const _UiZoomableMedia({
    required this.child,
    required this.minScale,
    required this.maxScale,
    this.onZoomChanged,
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<_UiZoomableMedia> createState() => _UiZoomableMediaState();
}

class _UiZoomableMediaState extends State<_UiZoomableMedia> {
  final TransformationController _transform = TransformationController();
  TapDownDetails? _doubleTap;

  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1.01) {
      _transform.value = Matrix4.identity();
      widget.onZoomChanged?.call(false);
      return;
    }
    final point = _doubleTap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        -point.dx * (scale - 1),
        -point.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
    widget.onZoomChanged?.call(true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTap = details,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        onInteractionEnd: (_) => widget.onZoomChanged?.call(
          _transform.value.getMaxScaleOnAxis() > 1.01,
        ),
        child: SizedBox.expand(child: widget.child),
      ),
    );
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }
}

class _ChromeVisibility extends StatelessWidget {
  const _ChromeVisibility({
    required this.visible,
    required this.duration,
    required this.alignment,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        child: Align(alignment: alignment, child: child),
      ),
    );
  }
}

class _UiMediaChrome extends StatelessWidget {
  const _UiMediaChrome({required this.child, this.topToBottom = true});

  final Widget child;
  final bool topToBottom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: topToBottom ? Alignment.topCenter : Alignment.bottomCenter,
          end: topToBottom ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Color(0xD9000000), Color(0x00000000)],
        ),
      ),
      child: child,
    );
  }
}

class _UiMediaAction extends StatelessWidget {
  const _UiMediaAction({required this.action});

  final UiMediaGalleryAction action;

  @override
  Widget build(BuildContext context) {
    return UiIconButton(
      semanticsLabel: action.label,
      onPressed: action.loading ? null : action.onPressed,
      size: UiSize.lg,
      intent: UiIntent.ghost,
      backgroundColor: const Color(0x66000000),
      foregroundColor: UiPalette.white,
      borderRadius: UiThemeTokens.of(context).radius.pillAll,
      icon: action.loading
          ? const SizedBox.square(
              dimension: 19,
              child: UiSpinner(strokeWidth: 2, color: UiPalette.white),
            )
          : Icon(action.icon, size: 21),
    );
  }
}
