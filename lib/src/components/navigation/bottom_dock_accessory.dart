part of 'bottom_tab_bar.dart';

const _kBottomDockAccessorySize = 48.0;

/// Shared accessory contour state; neither navigation mode owns the other.
mixin _BottomDockAccessoryState<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  UiBottomTabAccessory? get _accessory;
  double get _availableWidth;
  late final _content = UiContourCrossfadeController<UiBottomTabAccessory>(
    vsync: this,
  )..addListener(_tick);
  late final _search = UiFluidController(vsync: this)..addListener(_tick);
  late final _expansion = UiFluidController(vsync: this)..addListener(_tick);
  final _searchMotion = UiFluidSplitMotion(springStrength: .2);
  final _expansionMotion = UiFluidSplitMotion(springStrength: .2);
  late final _accessoryPress = AnimationController(vsync: this)
    ..addListener(_tick);
  bool _accessoryInTree = true;

  @override
  void deactivate() {
    _accessoryInTree = false;
    _accessoryPress.stop();
    _accessoryPress.value = 0;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _accessoryInTree = true;
  }

  void _setAccessoryPressed(bool pressed) {
    if (!mounted || !_accessoryInTree) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    _accessoryPress.animateTo(
      pressed && !reduced ? 1 : 0,
      duration: reduced
          ? Duration.zero
          : pressed
          ? UiThemeTokens.motionOf(context).fast
          : UiThemeTokens.motionOf(context).standard,
      curve: Curves.easeOutCubic,
    );
  }

  double _pressScale(UiFluidSplitFrame expansion) =>
      1 +
      (kUiPressGrowScale - 1) *
          _accessoryPress.value *
          (1 - expansion.geometryProgress.clamp(0.0, 1.0));
  UiBottomTabAccessory? _retainedAccessory;
  Widget _compactChild = const SizedBox.shrink();
  Widget _expandedChild = const SizedBox.shrink();
  int _expansionRevision = -1;
  double _expandedOpacity = 0;
  double _compactOpacity = 1;
  double _expandedOpacityOrigin = 0;
  double _compactOpacityOrigin = 1;
  void _drive(UiFluidController controller, bool open, {bool initial = false}) {
    final target = open ? 1.0 : 0.0;
    if (initial) controller.value = target;
    if (controller.target == target) return;
    if (open) {
      controller.open(context, direct: true);
    } else {
      controller.close(context);
    }
  }

  void _syncAccessory({bool initial = false}) {
    if (_accessory != null) {
      _retainedAccessory = _accessory;
      if (_accessory!.expanded) {
        _expandedChild = _accessory!.child;
      } else {
        _compactChild = _accessory!.child;
      }
    }
    _content.update(
      context,
      _accessory,
      identity: bottomTabAccessoryIdentity(_accessory),
      duration: UiMotionDuration.slow,
    );
    if (_accessory != null) {
      _drive(_search, true, initial: initial);
      // Presence always releases a compact surface vertically. Expansion is
      // a subsequent motion, never a diagonal shortcut to a wide field.
      _drive(
        _expansion,
        _search.value == 1 && _accessory!.expanded,
        initial: initial,
      );
    } else {
      _drive(_expansion, false, initial: initial);
      if (_expansion.value == 0) _drive(_search, false, initial: initial);
    }
  }

  void _tick() {
    if (!mounted || !_accessoryInTree) return;
    if (_accessory == null && _expansion.value == 0) {
      _drive(_search, false);
      if (_search.value == 0) _retainedAccessory = null;
    } else if (_search.value == 1 && _accessory != null) {
      _drive(_expansion, _accessory!.expanded);
    }
    setState(() {});
  }

  UiFluidGeometry _searchTarget(
    UiBottomTabAccessory accessory,
    UiFluidSplitFrame expansion,
    Rect Function(Rect) physical,
  ) {
    final compactWidth = math.min(
      accessory.collapsedWidth,
      _kBottomDockAccessorySize,
    );
    final compactHeight = accessory.collapsedHeight ?? accessory.height;
    final width = math.max(
      1.0,
      lerpDouble(compactWidth, _availableWidth, expansion.geometryProgress)!,
    );
    final height = lerpDouble(
      compactHeight,
      accessory.height,
      expansion.geometryProgress,
    )!;
    final rect = physical(
      Rect.fromLTWH(_availableWidth - width, 0, width, height),
    );
    final scale = _pressScale(expansion);
    return UiFluidGeometry(
      Rect.fromCenter(
        center: rect.center,
        width: width * scale,
        height: height * scale,
      ),
      height * scale / 2,
    );
  }

  Widget _buildSearch(
    BuildContext context,
    UiBottomTabAccessory accessory,
    UiFluidSplitFrame presence,
    UiFluidSplitFrame expansion,
    Rect source,
    Rect Function(Rect) physical,
    Color color,
  ) {
    final compactWidth = math.min(
      accessory.collapsedWidth,
      _kBottomDockAccessorySize,
    );
    // Fixed end alignment makes a compact search release strictly vertical
    // from either the next chevron or the trailing end of a full-width dock.
    final compactHeight = accessory.collapsedHeight ?? accessory.height;
    final target = _searchTarget(accessory, expansion, physical);
    final previous = _content.previous;
    final current = _content.current;
    final compact =
        previous != null &&
            current != null &&
            !previous.expanded &&
            !current.expanded
        ? buildUiContourCrossfade(
            context,
            progress: _content.progress,
            previous: previous.child,
            current: current.child,
          )
        : _compactChild;
    final expanding = _accessory?.expanded ?? false;
    if (_expansionRevision != _expansion.revision) {
      _expansionRevision = _expansion.revision;
      _expandedOpacityOrigin = _expandedOpacity;
      _compactOpacityOrigin = _compactOpacity;
    }
    final t = _expansion.transitionProgress;
    if (!_expansion.isAnimating) {
      _expandedOpacity = _expansion.value == 1 ? 1 : 0;
      _compactOpacity = 1 - _expandedOpacity;
    } else if (_expansion.target == 1) {
      _compactOpacity = lerpDouble(
        _compactOpacityOrigin,
        0,
        (t / .15).clamp(0.0, 1.0),
      )!;
      _expandedOpacity = lerpDouble(
        _expandedOpacityOrigin,
        1,
        ((t - .15) / .45).clamp(0.0, 1.0),
      )!;
    } else {
      // Retire the field before the fluid outline contracts around the icon.
      _expandedOpacity = lerpDouble(
        _expandedOpacityOrigin,
        0,
        (t / .22).clamp(0.0, 1.0),
      )!;
      _compactOpacity = lerpDouble(
        _compactOpacityOrigin,
        1,
        ((t - .25) / .25).clamp(0.0, 1.0),
      )!;
    }
    final child = Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: expanding,
          child: ExcludeFocus(
            excluding: expanding,
            child: ExcludeSemantics(
              excluding: expanding,
              child: Opacity(
                opacity: _compactOpacity,
                child: Align(
                  alignment: Directionality.of(context) == TextDirection.rtl
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: SizedBox(
                    width: compactWidth,
                    height: compactHeight,
                    child: UiActionSurfaceOwner(
                      onPressChanged: _setAccessoryPressed,
                      child: compact,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          ignoring: !expanding,
          child: ExcludeFocus(
            excluding: !expanding,
            child: ExcludeSemantics(
              excluding: !expanding,
              child: Opacity(opacity: _expandedOpacity, child: _expandedChild),
            ),
          ),
        ),
      ],
    );
    final active = _accessory != null;
    return Positioned.fill(
      child: UiFluidSplit(
        key: const Key('ui_paged_search_split'),
        controller: _search,
        frame: presence,
        sourceGeometry: UiFluidGeometry(
          physical(source),
          source.shortestSide / 2,
        ),
        source: const SizedBox.shrink(),
        color: color,
        branches: [
          UiFluidBranch(
            clipBehavior:
                !expanding && _search.value == 1 && _expansion.value == 0
                ? Clip.none
                : Clip.antiAlias,
            geometry: target,
            shadows: UiThemeTokens.of(context).shadows.md,
            // Keep the input and close target at their natural size while the
            // surface clips them; never relayout a field at compact icon width.
            contentSize: Size(
              _availableWidth,
              math.max(compactHeight, accessory.height),
            ),
            fit: BoxFit.none,
            alignment: Directionality.of(context) == TextDirection.rtl
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: IgnorePointer(
              ignoring: !active,
              child: ExcludeFocus(
                excluding: !active,
                child: ExcludeSemantics(
                  excluding: !active,
                  child: Transform.translate(
                    // The contour grows about its center. Counter the branch's
                    // end alignment so the icon and its hit target stay put.
                    offset: Offset(
                      (Directionality.of(context) == TextDirection.rtl
                              ? 1
                              : -1) *
                          target.rect.width *
                          (1 - 1 / _pressScale(expansion)) /
                          2,
                      0,
                    ),
                    child: child,
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
    _content.dispose();
    _search.dispose();
    _expansion.dispose();
    _accessoryPress.dispose();
    super.dispose();
  }
}

/// One outside contour prevents internal seams where a branch joins the dock.
/// Only paint changes with geometry; opacity-only indicator ticks reuse it.
class _BottomDockOutlinePainter extends CustomPainter {
  const _BottomDockOutlinePainter({
    required this.surfaces,
    required this.connections,
    required this.continuous,
    required this.color,
  });
  final List<UiFluidGeometry> surfaces;
  final List<(UiFluidGeometry, UiFluidGeometry, double)> connections;
  final bool continuous;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = fluidUnionOutline(
      surfaces: surfaces,
      connections: connections,
      continuous: continuous,
    );
    canvas.save();
    canvas.clipPath(outline);
    canvas.drawPath(
      outline,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  static Object geometryKey(UiFluidGeometry value) =>
      (value.rect, value.borderRadius);
  @override
  bool shouldRepaint(_BottomDockOutlinePainter old) =>
      color != old.color ||
      continuous != old.continuous ||
      !listEquals(
        surfaces.map(geometryKey).toList(),
        old.surfaces.map(geometryKey).toList(),
      ) ||
      !listEquals(
        connections
            .map((c) => (geometryKey(c.$1), geometryKey(c.$2), c.$3))
            .toList(),
        old.connections
            .map((c) => (geometryKey(c.$1), geometryKey(c.$2), c.$3))
            .toList(),
      );
}
