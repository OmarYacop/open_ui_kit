import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Widget;

import '../tokens/ui_color_tokens.dart';

/// Runtime brand configuration consumed by [UiThemeData.fromBrand].
///
/// Carries the *brand-specific* surface knobs that a host app wires at
/// bootstrap — colours, wordmarks, endpoints, display name. Pure tokens
/// (spacing, radius, typography, motion) stay under `UiThemeTokens` and
/// are not part of this contract.
///
/// The goal of the type is to be a single bootstrap seam: leaf widgets
/// should never branch on brand id. When a runtime value needs to
/// diverge per brand, plumb it through [UiBrand] instead.
@immutable
class UiBrand {
  const UiBrand({
    required this.id,
    required this.displayName,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.accent,
    this.danger,
    this.logo,
    this.darkLogo,
    this.apiBaseUrl,
    this.metadata = const <String, Object?>{},
  });

  /// Short machine identifier (e.g. `"acme"`). Used for analytics +
  /// switch statements at the *bootstrap* layer only.
  final String id;

  /// Human-readable brand label used in UI copy + app bar titles.
  final String displayName;

  /// Required foreground/background pair used for `UiIntent.primary`.
  final Color primary;
  final Color onPrimary;

  /// Optional secondary pair. Falls back to the neutral secondary
  /// token when omitted.
  final Color? secondary;
  final Color? onSecondary;

  /// Optional accent used for focus rings / selection highlights when
  /// the brand wants a non-neutral cursor tint.
  final Color? accent;

  /// Optional override for destructive (`UiIntent.destructive`) colour.
  final Color? danger;

  /// Optional logo — typical use is a `SvgPicture`/`Image` resolved at
  /// app bootstrap. Open UI Kit treats the widget as opaque.
  final Widget? logo;

  /// Dark-theme variant of [logo]. When omitted, [logo] is reused.
  final Widget? darkLogo;

  /// API base URL metadata — not consumed by Open UI Kit itself, but useful
  /// to colocate with the brand config so one bootstrap produces both
  /// theme + network bindings.
  final Uri? apiBaseUrl;

  /// Escape hatch for free-form brand settings (feature flags, remote
  /// config seeds, etc.). Keyed data — avoid embedding widgets here.
  final Map<String, Object?> metadata;

  /// Build a colour-token snapshot for [brightness] using this brand's
  /// values layered on top of the neutral Open UI Kit defaults. Pure: call
  /// it every build cycle without cost.
  UiColorTokens colorTokens(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? UiColorTokens.dark
        : UiColorTokens.light;
    return base.copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary ?? base.secondary,
      onSecondary: onSecondary ?? base.onSecondary,
      danger: danger ?? base.danger,
      focusRing: accent ?? base.focusRing,
    );
  }

  /// Logo resolved for the current brightness; falls back gracefully
  /// when only the light asset is supplied.
  Widget? resolveLogo(Brightness brightness) {
    if (brightness == Brightness.dark) return darkLogo ?? logo;
    return logo;
  }

  UiBrand copyWith({
    String? id,
    String? displayName,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? accent,
    Color? danger,
    Widget? logo,
    Widget? darkLogo,
    Uri? apiBaseUrl,
    Map<String, Object?>? metadata,
  }) {
    return UiBrand(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      accent: accent ?? this.accent,
      danger: danger ?? this.danger,
      logo: logo ?? this.logo,
      darkLogo: darkLogo ?? this.darkLogo,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UiBrand &&
        other.id == id &&
        other.displayName == displayName &&
        other.primary == primary &&
        other.onPrimary == onPrimary &&
        other.secondary == secondary &&
        other.onSecondary == onSecondary &&
        other.accent == accent &&
        other.danger == danger &&
        other.apiBaseUrl == apiBaseUrl;
  }

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        primary,
        onPrimary,
        secondary,
        onSecondary,
        accent,
        danger,
        apiBaseUrl,
      );
}
