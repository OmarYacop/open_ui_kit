import 'package:flutter/widgets.dart';

/// Semantic paint layers managed by [UiLayeredOverlayHost].
///
/// Entries in later layers paint above entries in earlier layers. The page
/// itself is below every managed layer.
enum UiOverlayLayer {
  /// Menus, morphing controls, tooltips, and other non-modal floating UI.
  floating,

  /// Persistent page chrome such as blurred navigation bars.
  navigationChrome,

  /// Transient system feedback that must remain legible above page chrome.
  ///
  /// Pull-to-refresh indicators and similar non-modal status feedback belong
  /// here.
  systemFeedback,

  /// Modal surfaces that must remain above page chrome.
  modal,
}

/// Provides deterministic, semantic overlay ordering within a page.
///
/// This is Open UI's equivalent of a small, named z-index scale. Components
/// should request a semantic layer instead of relying on insertion timing.
class UiLayeredOverlayHost extends StatefulWidget {
  const UiLayeredOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  State<UiLayeredOverlayHost> createState() => _UiLayeredOverlayHostState();
}

class _UiLayeredOverlayHostState extends State<UiLayeredOverlayHost> {
  final _keys = <UiOverlayLayer, GlobalKey<OverlayState>>{
    for (final layer in UiOverlayLayer.values) layer: GlobalKey<OverlayState>(),
  };
  bool _layersReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _layersReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _UiLayeredOverlayScope(
      keys: _keys,
      layersReady: _layersReady,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          for (final layer in UiOverlayLayer.values)
            Positioned.fill(
              child: Overlay(
                key: _keys[layer],
                clipBehavior: Clip.none,
                initialEntries: const [],
              ),
            ),
        ],
      ),
    );
  }
}

class _UiLayeredOverlayScope extends InheritedWidget {
  const _UiLayeredOverlayScope({
    required this.keys,
    required this.layersReady,
    required super.child,
  });

  final Map<UiOverlayLayer, GlobalKey<OverlayState>> keys;
  final bool layersReady;

  @override
  bool updateShouldNotify(_UiLayeredOverlayScope oldWidget) =>
      oldWidget.keys != keys || oldWidget.layersReady != layersReady;
}

/// Access to the nearest page-level semantic overlay layers.
abstract final class UiLayeredOverlay {
  static OverlayState? maybeOf(BuildContext context, UiOverlayLayer layer) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_UiLayeredOverlayScope>();
    return scope?.keys[layer]?.currentState;
  }

  static OverlayState of(BuildContext context, UiOverlayLayer layer) {
    final overlay = maybeOf(context, layer);
    assert(overlay != null, 'No UiLayeredOverlayHost found in context.');
    return overlay!;
  }
}

/// Lifts [child] into a semantic overlay layer while preserving its layout
/// position with a composited transform.
///
/// The source renders normally until the layer entry is ready, avoiding a
/// blank first frame. Once lifted, a same-sized target remains in layout while
/// the real child paints and receives input in [layer].
class UiLayeredOverlayPortal extends StatefulWidget {
  const UiLayeredOverlayPortal({
    super.key,
    required this.layer,
    required this.child,
  });

  final UiOverlayLayer layer;
  final Widget child;

  @override
  State<UiLayeredOverlayPortal> createState() => _UiLayeredOverlayPortalState();
}

class _UiLayeredOverlayPortalState extends State<UiLayeredOverlayPortal> {
  final _link = LayerLink();
  OverlayState? _overlay;
  OverlayEntry? _entry;
  Size _size = Size.zero;
  bool _lifted = false;
  bool _syncScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final overlay = UiLayeredOverlay.maybeOf(context, widget.layer);
    if (overlay == _overlay) return;
    _detach();
    _overlay = overlay;
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant UiLayeredOverlayPortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer != widget.layer) {
      _detach();
      _overlay = UiLayeredOverlay.maybeOf(context, widget.layer);
    }
    _scheduleSync();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_overlay == null) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final nextSize = constraints.biggest;
        if (nextSize.isFinite && nextSize != _size) {
          _size = nextSize;
          _scheduleSync();
        } else if (_entry != null) {
          _scheduleSync();
        }

        return CompositedTransformTarget(
          link: _link,
          child: _lifted ? const SizedBox.expand() : widget.child,
        );
      },
    );
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted || _overlay == null || !_size.isFinite || _size.isEmpty) {
        return;
      }
      final entry = _entry;
      if (entry == null) {
        _entry = OverlayEntry(builder: _buildEntry);
        _overlay!.insert(_entry!);
        setState(() => _lifted = true);
      } else {
        entry.markNeedsBuild();
      }
    });
  }

  Widget _buildEntry(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            child: SizedBox.fromSize(size: _size, child: widget.child),
          ),
        ),
      ],
    );
  }

  void _detach() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _overlay = null;
    _lifted = false;
  }
}
