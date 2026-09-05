import 'package:flutter/widgets.dart';

/// The kind of identity represented by a [UiWavatar].
enum UiWavatarSubject { person, organization, team, bot }

/// Optional identity context used only to diversify abstract geometry.
///
/// Gender never selects anatomical features or gender-coded colors.
enum UiWavatarGender { female, male, nonBinary }

/// Broad age context used to tune the glyph's proportions.
enum UiWavatarAgeGroup { child, teenager, adult, olderAdult }

/// Controls whether generated colors respond to platform brightness.
enum UiWavatarThemeMode {
  /// Preserve the same generated palette in light and dark themes.
  fixed,

  /// Keep the identity's hues while adapting luminance and contrast.
  adaptive,
}

/// Optional context that gently directs [UiWavatar]'s generated geometry.
///
/// All fields are visual hints, not claims about appearance.
@immutable
class UiWavatarCharacteristics {
  const UiWavatarCharacteristics({
    this.subject = UiWavatarSubject.person,
    this.gender,
    this.ageGroup,
  });

  final UiWavatarSubject subject;
  final UiWavatarGender? gender;
  final UiWavatarAgeGroup? ageGroup;
}

/// One distinct identity within a multi-participant [UiWavatar].
@immutable
class UiWavatarParticipant {
  const UiWavatarParticipant({
    required this.seed,
    this.characteristics = const UiWavatarCharacteristics(),
  });

  /// Stable value used to generate this participant's visual identity.
  final String seed;

  /// Optional information that subtly biases this participant's geometry.
  final UiWavatarCharacteristics characteristics;
}

/// A deterministic, locally rendered abstract avatar.
///
/// [UiWavatar] turns [seed] into a stable geometric identity mark. Its layered
/// shapes loosely suggest a face without depicting a literal person, making it
/// suitable for contact lists, accounts, and privacy-conscious placeholders.
/// Supply [participants] to compose up to four independently generated
/// identities into one shared avatar.
///
/// The component performs no I/O, needs no bundled assets, and has no package
/// dependencies beyond Flutter.
class UiWavatar extends StatelessWidget {
  const UiWavatar({
    super.key,
    required this.seed,
    this.size = 40,
    this.backgroundColor,
    this.characteristics = const UiWavatarCharacteristics(),
    this.participants = const [],
    this.themeMode = UiWavatarThemeMode.adaptive,
    this.shape = BoxShape.circle,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.semanticLabel,
  }) : assert(size > 0, 'size must be greater than zero');

  /// Stable value used to derive every visual feature.
  final String seed;

  /// Logical width and height of the avatar.
  final double size;

  /// Optional background override. When omitted, the seed selects a color.
  final Color? backgroundColor;

  /// Optional information that subtly biases the generated identity mark.
  final UiWavatarCharacteristics characteristics;

  /// Distinct identities represented by this avatar.
  ///
  /// When non-empty, each participant supplies an independent seed and
  /// characteristics, and up to the first four participants are painted.
  /// The avatar's own [seed] continues to define the shared background.
  final List<UiWavatarParticipant> participants;

  /// Whether generated colors adapt to the current platform brightness.
  final UiWavatarThemeMode themeMode;

  /// Outer silhouette. Use [BoxShape.circle] or [BoxShape.rectangle].
  final BoxShape shape;

  /// Corner radius used when [shape] is [BoxShape.rectangle].
  final BorderRadius borderRadius;

  /// Accessibility label. Defaults to `Avatar for {seed}`.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final brightness =
        MediaQuery.maybePlatformBrightnessOf(context) ??
        View.of(context).platformDispatcher.platformBrightness;
    final isDark =
        themeMode == UiWavatarThemeMode.adaptive &&
        brightness == Brightness.dark;
    final recipe = _WavatarRecipe.fromSeed(
      seed,
      backgroundColor,
      characteristics,
      isDark: isDark,
    );
    final participantRecipes = participants
        .take(4)
        .map(
          (participant) => _WavatarRecipe.fromSeed(
            participant.seed,
            null,
            participant.characteristics,
            isDark: isDark,
          ),
        )
        .toList(growable: false);
    final avatar = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _WavatarPainter(recipe, participantRecipes),
        isComplex: false,
        willChange: false,
      ),
    );

    return Semantics(
      image: true,
      label: semanticLabel ?? 'Avatar for $seed',
      child: shape == BoxShape.circle
          ? ClipOval(clipBehavior: Clip.antiAlias, child: avatar)
          : ClipRRect(
              borderRadius: borderRadius,
              clipBehavior: Clip.antiAlias,
              child: avatar,
            ),
    );
  }

  /// DJB2-style 32-bit hash used by the painter's deterministic recipe.
  @visibleForTesting
  static int hashSeed(String value) {
    var hash = 5381;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash << 5) + hash) ^ codeUnit;
      hash &= 0x7fffffff;
    }
    return hash;
  }
}

@immutable
class _WavatarRecipe {
  // A broad, deliberately soft palette. Keeping the hues curated avoids the
  // muddy or neon combinations that fully random HSV generation can produce.
  // Raspberry anchors the warm end alongside coral, apricot, amber, mint,
  // teal, sky, periwinkle, violet, and plum.
  static const _softHues = <double>[
    344,
    8,
    24,
    42,
    94,
    146,
    174,
    202,
    226,
    252,
    278,
    316,
  ];

  const _WavatarRecipe({
    required this.hash,
    required this.background,
    required this.backgroundAccent,
    required this.glyph,
    required this.glyphAccent,
    required this.ink,
    required this.glyphShape,
    required this.eyeStyle,
    required this.expressionStyle,
    required this.orbitStyle,
    required this.eyeSpacing,
    required this.expressionWidth,
    required this.rotation,
    required this.glyphScale,
    required this.eyeScale,
    required this.characteristicsKey,
    required this.subject,
    required this.isDark,
  });

  factory _WavatarRecipe.fromSeed(
    String seed,
    Color? backgroundOverride,
    UiWavatarCharacteristics characteristics, {
    required bool isDark,
  }) {
    final hash = UiWavatar.hashSeed(seed);
    final random = _HashStream(hash);
    final baseHue = _softHues[random.nextInt(_softHues.length)];
    final background =
        backgroundOverride ??
        HSVColor.fromAHSV(
          1,
          baseHue,
          isDark ? 0.42 : 0.46,
          isDark ? 0.42 : 0.86,
        ).toColor();
    final backgroundHsv = HSVColor.fromColor(background);
    final glyphHue = (baseHue + 80 + random.nextInt(200)) % 360;
    final glyph = HSVColor.fromAHSV(
      1,
      glyphHue,
      (isDark ? 0.34 : 0.40) + random.nextDouble() * 0.28,
      (isDark ? 0.80 : 0.88) + random.nextDouble() * 0.10,
    ).toColor();
    final glyphHsv = HSVColor.fromColor(glyph);
    final genderNudge = switch (characteristics.gender) {
      UiWavatarGender.female => 1,
      UiWavatarGender.male => 2,
      UiWavatarGender.nonBinary => 3,
      null => 0,
    };
    final generatedShape = random.nextInt(4);
    final glyphShape = switch (characteristics.subject) {
      UiWavatarSubject.person => (generatedShape + genderNudge) % 4,
      UiWavatarSubject.organization => 3,
      UiWavatarSubject.team => 2,
      UiWavatarSubject.bot => 0,
    };
    final ageScale = switch (characteristics.ageGroup) {
      UiWavatarAgeGroup.child => (glyph: 0.88, eyes: 1.22),
      UiWavatarAgeGroup.teenager => (glyph: 0.94, eyes: 1.10),
      UiWavatarAgeGroup.adult || null => (glyph: 1.0, eyes: 1.0),
      UiWavatarAgeGroup.olderAdult => (glyph: 1.04, eyes: 0.92),
    };
    final characteristicsKey =
        characteristics.subject.index |
        ((characteristics.gender?.index ?? 7) << 3) |
        ((characteristics.ageGroup?.index ?? 7) << 6);

    return _WavatarRecipe(
      hash: hash,
      background: background,
      backgroundAccent: backgroundHsv
          .withHue((backgroundHsv.hue + 28) % 360)
          .withSaturation((backgroundHsv.saturation - 0.10).clamp(0.18, 0.75))
          .withValue(
            (backgroundHsv.value + (isDark ? 0.10 : 0.12)).clamp(0.0, 1.0),
          )
          .toColor(),
      glyph: glyph,
      glyphAccent: glyphHsv
          .withHue((glyphHsv.hue + 32) % 360)
          .withValue((glyphHsv.value - 0.20).clamp(0.0, 1.0))
          .toColor(),
      ink: glyphHsv.value > 0.65
          ? const Color(0xFF25272C)
          : const Color(0xFFF8F7F3),
      glyphShape: glyphShape,
      eyeStyle: characteristics.subject == UiWavatarSubject.bot
          ? 2
          : random.nextInt(4),
      expressionStyle: random.nextInt(4),
      orbitStyle: random.nextInt(3),
      eyeSpacing: 0.115 + random.nextDouble() * 0.045,
      expressionWidth: 0.12 + random.nextDouble() * 0.07,
      rotation: (random.nextDouble() - 0.5) * 0.14,
      glyphScale: ageScale.glyph,
      eyeScale: ageScale.eyes,
      characteristicsKey: characteristicsKey,
      subject: characteristics.subject,
      isDark: isDark,
    );
  }

  final int hash;
  final Color background;
  final Color backgroundAccent;
  final Color glyph;
  final Color glyphAccent;
  final Color ink;
  final int glyphShape;
  final int eyeStyle;
  final int expressionStyle;
  final int orbitStyle;
  final double eyeSpacing;
  final double expressionWidth;
  final double rotation;
  final double glyphScale;
  final double eyeScale;
  final int characteristicsKey;
  final UiWavatarSubject subject;
  final bool isDark;
}

/// Small xorshift stream that expands one stable hash into independent picks.
class _HashStream {
  _HashStream(int seed) : _state = seed == 0 ? 0x6d2b79f5 : seed;

  int _state;

  int next() {
    var value = _state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    _state = value & 0x7fffffff;
    return _state;
  }

  int nextInt(int upperBound) => next() % upperBound;

  double nextDouble() => next() / 0x7fffffff;
}

class _WavatarPainter extends CustomPainter {
  const _WavatarPainter(this.recipe, this.participantRecipes);

  final _WavatarRecipe recipe;
  final List<_WavatarRecipe> participantRecipes;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    _paintBackground(canvas);
    _paintOrbit(canvas);

    final identities = participantRecipes.isNotEmpty
        ? participantRecipes
        : recipe.subject == UiWavatarSubject.team
        ? [recipe, recipe, recipe]
        : [recipe];

    switch (identities.length) {
      case 1:
        _paintIdentity(
          canvas,
          identities[0],
          const Offset(50, 52),
          1,
          identities[0].rotation,
        );
      case 2:
        _paintIdentity(
          canvas,
          identities[0],
          const Offset(66, 43),
          0.62,
          -0.05,
        );
        _paintIdentity(canvas, identities[1], const Offset(38, 59), 0.74, 0.04);
      case 3:
        _paintIdentity(
          canvas,
          identities[0],
          const Offset(68, 39),
          0.48,
          -0.05,
        );
        _paintIdentity(canvas, identities[1], const Offset(34, 43), 0.55, 0.04);
        _paintIdentity(canvas, identities[2], const Offset(53, 65), 0.68, 0);
      case 4:
        _paintIdentity(
          canvas,
          identities[0],
          const Offset(69, 37),
          0.44,
          -0.05,
        );
        _paintIdentity(canvas, identities[1], const Offset(31, 39), 0.47, 0.05);
        _paintIdentity(canvas, identities[2], const Offset(65, 66), 0.55, 0.03);
        _paintIdentity(
          canvas,
          identities[3],
          const Offset(35, 67),
          0.58,
          -0.02,
        );
    }

    canvas.restore();
  }

  void _paintIdentity(
    Canvas canvas,
    _WavatarRecipe identity,
    Offset center,
    double scale,
    double rotation,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.scale(identity.glyphScale * scale);
    canvas.translate(-50, -52);
    _paintGlyph(canvas, identity);
    _paintEyes(canvas, identity);
    _paintExpression(canvas, identity);
    canvas.restore();
  }

  void _paintBackground(Canvas canvas) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [recipe.backgroundAccent, recipe.background],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), paint);
  }

  void _paintOrbit(Canvas canvas) {
    final light = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.16);
    final dark = Paint()..color = recipe.glyphAccent.withValues(alpha: 0.18);

    switch (recipe.orbitStyle) {
      case 0:
        canvas.drawCircle(const Offset(16, 12), 31, light);
        canvas.drawCircle(const Offset(91, 92), 27, dark);
      case 1:
        canvas.drawOval(const Rect.fromLTWH(-18, 64, 73, 42), light);
        canvas.drawOval(const Rect.fromLTWH(64, -12, 48, 64), dark);
      default:
        final ribbon = Path()
          ..moveTo(-8, 73)
          ..cubicTo(20, 49, 34, 96, 62, 69)
          ..cubicTo(78, 54, 91, 54, 108, 64)
          ..lineTo(108, 108)
          ..lineTo(-8, 108)
          ..close();
        canvas.drawPath(ribbon, light);
    }
  }

  void _paintGlyph(Canvas canvas, _WavatarRecipe identity) {
    final paint = Paint()..color = identity.glyph;
    final accent = Paint()..color = identity.glyphAccent;

    switch (identity.glyphShape) {
      case 0:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(23, 21, 54, 62),
            const Radius.circular(22),
          ),
          paint,
        );
        canvas.drawCircle(const Offset(31, 27), 10, accent);
      case 1:
        final pebble = Path()
          ..moveTo(50, 17)
          ..cubicTo(69, 15, 82, 29, 78, 51)
          ..cubicTo(83, 72, 66, 87, 47, 83)
          ..cubicTo(27, 87, 17, 68, 22, 48)
          ..cubicTo(18, 29, 32, 18, 50, 17)
          ..close();
        canvas.drawPath(pebble, paint);
        canvas.drawCircle(const Offset(70, 29), 11, accent);
      case 2:
        final arch = Path()
          ..moveTo(21, 82)
          ..lineTo(21, 49)
          ..cubicTo(21, 28, 33, 17, 50, 17)
          ..cubicTo(68, 17, 79, 29, 79, 49)
          ..lineTo(79, 82)
          ..quadraticBezierTo(67, 76, 58, 83)
          ..quadraticBezierTo(48, 89, 39, 81)
          ..quadraticBezierTo(30, 75, 21, 82)
          ..close();
        canvas.drawPath(arch, paint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(25, 22, 50, 15),
            const Radius.circular(8),
          ),
          accent,
        );
      default:
        final tile = Path()
          ..moveTo(29, 18)
          ..lineTo(68, 18)
          ..quadraticBezierTo(82, 24, 77, 40)
          ..lineTo(73, 70)
          ..quadraticBezierTo(69, 84, 51, 84)
          ..lineTo(36, 82)
          ..quadraticBezierTo(20, 78, 22, 61)
          ..lineTo(20, 35)
          ..quadraticBezierTo(20, 21, 29, 18)
          ..close();
        canvas.drawPath(tile, paint);
        canvas.drawCircle(const Offset(26, 69), 9, accent);
    }
  }

  void _paintEyes(Canvas canvas, _WavatarRecipe identity) {
    final y = 48.0;
    final spacing = identity.eyeSpacing * 100;
    final left = Offset(50 - spacing, y);
    final right = Offset(50 + spacing, y);
    final fill = Paint()..color = identity.ink;
    final stroke = Paint()
      ..color = identity.ink
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (identity.eyeStyle) {
      case 0:
        canvas.drawCircle(left, 2.8 * identity.eyeScale, fill);
        canvas.drawCircle(right, 2.8 * identity.eyeScale, fill);
      case 1:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: left,
              width: 8 * identity.eyeScale,
              height: 4 * identity.eyeScale,
            ),
            const Radius.circular(2),
          ),
          fill,
        );
        canvas.drawCircle(right, 2.7 * identity.eyeScale, fill);
      case 2:
        canvas.drawCircle(left, 5.5, stroke);
        canvas.drawCircle(right, 5.5, stroke);
        canvas.drawLine(
          Offset(left.dx + 5.5, y),
          Offset(right.dx - 5.5, y),
          stroke,
        );
      default:
        canvas.drawLine(Offset(left.dx - 3, y), Offset(left.dx + 3, y), stroke);
        canvas.drawLine(
          Offset(right.dx - 3, y),
          Offset(right.dx + 3, y),
          stroke,
        );
    }
  }

  void _paintExpression(Canvas canvas, _WavatarRecipe identity) {
    final width = identity.expressionWidth * 100;
    final stroke = Paint()
      ..color = identity.ink
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final bounds = Rect.fromCenter(
      center: const Offset(50, 65),
      width: width,
      height: 10,
    );

    final style = switch (identity.subject) {
      UiWavatarSubject.organization => 1,
      UiWavatarSubject.bot => 2,
      _ => identity.expressionStyle,
    };
    switch (style) {
      case 0:
        canvas.drawArc(bounds, 0.2, 2.74, false, stroke);
      case 1:
        canvas.drawLine(
          Offset(50 - width / 2, 66),
          Offset(50 + width / 2, 66),
          stroke,
        );
      case 2:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: const Offset(50, 65),
              width: width * 0.72,
              height: 7,
            ),
            const Radius.circular(4),
          ),
          Paint()..color = identity.ink,
        );
      default:
        final wave = Path()
          ..moveTo(50 - width / 2, 66)
          ..quadraticBezierTo(47, 61, 50, 65)
          ..quadraticBezierTo(54, 69, 50 + width / 2, 63);
        canvas.drawPath(wave, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _WavatarPainter oldDelegate) {
    if (_recipeChanged(oldDelegate.recipe, recipe) ||
        oldDelegate.participantRecipes.length != participantRecipes.length) {
      return true;
    }

    for (var index = 0; index < participantRecipes.length; index++) {
      if (_recipeChanged(
        oldDelegate.participantRecipes[index],
        participantRecipes[index],
      )) {
        return true;
      }
    }
    return false;
  }

  static bool _recipeChanged(_WavatarRecipe previous, _WavatarRecipe current) {
    return previous.hash != current.hash ||
        previous.background != current.background ||
        previous.characteristicsKey != current.characteristicsKey ||
        previous.isDark != current.isDark;
  }
}
