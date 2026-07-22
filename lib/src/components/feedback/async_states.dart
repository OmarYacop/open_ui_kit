import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Layout shape for async placeholder widgets.
///
/// - [UiAsyncStateMode.inline]: compact, left-aligned — use inside rows,
///   lists, or cards.
/// - [UiAsyncStateMode.section]: centred, unframed — use inside page
///   sections that already provide their own surrounding structure.
/// - [UiAsyncStateMode.page]: centred full-height block — use as the
///   root of a page when it cannot render any primary content yet.
enum UiAsyncStateMode { inline, section, page }

/// Visual mode for [UiLoadingState]'s indicator.
enum UiLoadingIndicatorMode {
  /// Animated spinner for production loading feedback.
  animated,

  /// Static spinner frame for deterministic snapshots (for example, goldens).
  staticFrame,
}

/// Shared chrome for [UiLoadingState], [UiEmptyState], [UiErrorState].
/// Not exported directly — use one of the public variants.
class _AsyncStateSurface extends StatelessWidget {
  const _AsyncStateSurface({
    required this.icon,
    required this.title,
    required this.description,
    required this.mode,
    required this.actions,
    this.semanticsLabel,
    this.liveRegion = false,
  });

  final Widget icon;
  final String? title;
  final String? description;
  final UiAsyncStateMode mode;
  final List<Widget> actions;
  final String? semanticsLabel;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final colors = tokens.colors;
    final isPage = mode == UiAsyncStateMode.page;
    final isCentered = mode != UiAsyncStateMode.inline;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        RepaintBoundary(
          child: UiBox(
            width: 52,
            height: 52,
            background: colors.surfaceMuted,
            border: Border.all(color: colors.border, width: 1),
            borderRadius: tokens.radius.pillAll,
            alignment: Alignment.center,
            child: IconTheme.merge(
              data: IconThemeData(color: colors.textMuted, size: 24),
              child: icon,
            ),
          ),
        ),
        if (title != null) ...[
          SizedBox(height: tokens.spacing.x3),
          UiText(
            title!,
            variant: UiTextVariant.subheading,
            textAlign: isCentered ? TextAlign.center : TextAlign.start,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (description != null) ...[
          SizedBox(height: tokens.spacing.x1),
          UiText(
            description!,
            variant: UiTextVariant.bodySm,
            tone: UiTextTone.muted,
            textAlign: isCentered ? TextAlign.center : TextAlign.start,
          ),
        ],
        if (actions.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.x4),
          Wrap(
            alignment: isCentered ? WrapAlignment.center : WrapAlignment.start,
            spacing: tokens.spacing.x2,
            runSpacing: tokens.spacing.x2,
            children: actions,
          ),
        ],
      ],
    );

    final surface = UiBox(
      background: isPage ? colors.card : null,
      border: isPage ? Border.all(color: colors.border, width: 1) : null,
      borderRadius: isPage ? tokens.radius.xlAll : null,
      padding: EdgeInsets.symmetric(
        horizontal: isPage ? tokens.spacing.x6 : tokens.spacing.x4,
        vertical: isPage
            ? tokens.spacing.x8
            : mode == UiAsyncStateMode.section
                ? tokens.spacing.x6
                : tokens.spacing.x4,
      ),
      child: body,
    );

    final content = isCentered
        ? Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: surface,
            ),
          )
        : surface;

    return Semantics(
      container: true,
      liveRegion: liveRegion,
      label: semanticsLabel,
      child: content,
    );
  }
}

/// Placeholder shown while data is loading.
///
/// Publishes a polite `liveRegion` semantics annotation so screen
/// readers announce when the loading state replaces previous content.
class UiLoadingState extends StatelessWidget {
  const UiLoadingState({
    super.key,
    this.title,
    this.description,
    this.icon,
    this.mode = UiAsyncStateMode.inline,
    this.indicatorMode = UiLoadingIndicatorMode.animated,
    this.semanticsLabel = 'Loading',
    this.actions = const [],
  });

  final String? title;
  final String? description;
  final Widget? icon;
  final UiAsyncStateMode mode;
  final UiLoadingIndicatorMode indicatorMode;
  final String semanticsLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final resolvedIcon = icon ??
        switch (indicatorMode) {
          UiLoadingIndicatorMode.animated => const _Spinner(),
          UiLoadingIndicatorMode.staticFrame => const _StaticSpinner(),
        };

    return _AsyncStateSurface(
      icon: resolvedIcon,
      title: title,
      description: description,
      mode: mode,
      actions: actions,
      semanticsLabel: semanticsLabel,
      liveRegion: true,
    );
  }
}

/// Placeholder shown when a view has no data.
class UiEmptyState extends StatelessWidget {
  const UiEmptyState({
    super.key,
    this.title,
    this.description,
    this.icon,
    this.mode = UiAsyncStateMode.inline,
    this.actions = const [],
  });

  final String? title;
  final String? description;

  /// Optional leading illustration/icon. A neutral placeholder is used
  /// when omitted so there's always an anchor glyph.
  final Widget? icon;
  final UiAsyncStateMode mode;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return _AsyncStateSurface(
      icon: icon ?? const _PlaceholderGlyph(variant: _GlyphVariant.empty),
      title: title,
      description: description,
      mode: mode,
      actions: actions,
      semanticsLabel: title ?? 'No data',
    );
  }
}

/// Placeholder shown when loading failed.
///
/// The glyph and default title announce the error as a live region so
/// the user notices the state change.
class UiErrorState extends StatelessWidget {
  const UiErrorState({
    super.key,
    this.title,
    this.description,
    this.icon,
    this.mode = UiAsyncStateMode.section,
    this.actions = const [],
  });

  final String? title;
  final String? description;
  final Widget? icon;
  final UiAsyncStateMode mode;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return _AsyncStateSurface(
      icon: icon ?? const _PlaceholderGlyph(variant: _GlyphVariant.error),
      title: title,
      description: description,
      mode: mode,
      actions: actions,
      semanticsLabel: title ?? 'Error',
      liveRegion: true,
    );
  }
}

// ---------------------------------------------------------------------------

class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = UiThemeTokens.of(context).colors.textPrimary;
    return SizedBox(
      width: 28,
      height: 28,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Transform.rotate(
          angle: _c.value * 6.2831853,
          child: CustomPaint(painter: _SpinnerPainter(color)),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(2), -1.2, 4.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter old) => old.color != color;
}

class _StaticSpinner extends StatelessWidget {
  const _StaticSpinner();

  @override
  Widget build(BuildContext context) {
    final color = UiThemeTokens.of(context).colors.textPrimary;
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(painter: _SpinnerPainter(color)),
    );
  }
}

enum _GlyphVariant { empty, error }

class _PlaceholderGlyph extends StatelessWidget {
  const _PlaceholderGlyph({required this.variant});
  final _GlyphVariant variant;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final color = variant == _GlyphVariant.error ? c.danger : c.textMuted;
    return CustomPaint(
      size: const Size.square(24),
      painter: _GlyphPainter(variant: variant, color: color),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.variant, required this.color});
  final _GlyphVariant variant;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (variant) {
      case _GlyphVariant.empty:
        // Horizontal line + small rectangle — a neutral placeholder.
        canvas.drawLine(
          Offset(size.width * 0.25, size.height * 0.7),
          Offset(size.width * 0.75, size.height * 0.7),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * 0.3,
            size.height * 0.3,
            size.width * 0.4,
            size.height * 0.3,
          ),
          paint,
        );
        break;
      case _GlyphVariant.error:
        // Triangle with exclamation bar.
        final path = Path()
          ..moveTo(size.width * 0.5, size.height * 0.15)
          ..lineTo(size.width * 0.9, size.height * 0.85)
          ..lineTo(size.width * 0.1, size.height * 0.85)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.42),
          Offset(size.width * 0.5, size.height * 0.62),
          paint..strokeWidth = 2.2,
        );
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.73),
          1.4,
          Paint()..color = color,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.variant != variant || old.color != color;
}
