import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_brand.dart';
import 'ui_navigation_back_button.dart';
import 'ui_navigation_transition.dart';

/// Visual treatment for the navigation surface.
enum UiNavigationSurface {
  /// Platform-adaptive default:
  /// - iOS: [blurred]
  /// - others: [solid]
  adaptive,

  /// Opaque surface color — no blur, sharp edge.
  solid,

  /// Translucent tint + `BackdropFilter` blur (iOS-style glass).
  blurred,

  /// Fully transparent; lets the page content paint through.
  transparent,
}

/// Declarative metadata for a page's navigation chrome.
///
/// Consumers build a [UiNavigationSpec] per-screen and hand it to a
/// [UiSliverNavigationBar] or expose it via [UiNavigationScope] so nested
/// widgets can adapt (e.g. a custom trailing widget that reads the spec).
///
/// The spec is pure data — it does not perform navigation itself. Routing
/// stays with the app's existing router.
@immutable
class UiNavigationSpec {
  const UiNavigationSpec({
    required this.title,
    this.subtitle,
    this.brand,
    this.leading,
    this.back,
    this.actions = const <Widget>[],
    this.heroTag,
    this.largeTitle = true,
    this.surface = UiNavigationSurface.adaptive,
    this.blurSigma = 14,
    this.showDivider = true,
    this.transitionStyle = UiNavigationTransitionStyle.sharedAxis,
    this.animationGroupId,
  });

  /// Primary title shown in both the large and compact forms.
  final String title;

  /// Secondary line under the large title. Fades out first as the user
  /// collapses the header.
  final String? subtitle;

  /// Optional brand runtime config. When provided, navigation bars can
  /// resolve `brand.logo`/`brand.darkLogo` for the active brightness.
  final UiBrand? brand;

  /// Widget rendered at the start of the bar (e.g. back chevron).
  final Widget? leading;

  /// Preferred Open UI Kit back affordance (chevron + title button with
  /// optional long-press history menu).
  ///
  /// If set, [leading] is ignored by [UiSliverNavigationBar].
  final UiNavigationBackConfig? back;

  /// Trailing action cluster. Rendered right-to-left.
  final List<Widget> actions;

  /// Shared-element tag when pushing between pages with matching content.
  final Object? heroTag;

  /// When `true`, the bar renders a large-title form that collapses into
  /// a compact form as the scrolling content overscrolls.
  final bool largeTitle;

  /// Visual treatment for the bar surface.
  final UiNavigationSurface surface;

  /// Maximum BackdropFilter blur radius when collapsed. `0` disables the
  /// blur layer even when [surface] resolves to
  /// [UiNavigationSurface.blurred].
  final double blurSigma;

  /// Whether to paint a bottom divider under the bar once content scrolls
  /// behind it. Set this to `false` when blur and tint provide enough
  /// separation from scrolling content.
  final bool showDivider;

  /// Default transition used when a [UiNavigationStack] swaps children
  /// under this spec. Individual pushes can still override the style.
  final UiNavigationTransitionStyle transitionStyle;

  /// Opaque identifier grouping transitions that should animate together
  /// (e.g. a master/detail pair sharing one motion group).
  final Object? animationGroupId;

  UiNavigationSpec copyWith({
    String? title,
    String? subtitle,
    UiBrand? brand,
    Widget? leading,
    UiNavigationBackConfig? back,
    List<Widget>? actions,
    Object? heroTag,
    bool? largeTitle,
    UiNavigationSurface? surface,
    double? blurSigma,
    bool? showDivider,
    UiNavigationTransitionStyle? transitionStyle,
    Object? animationGroupId,
  }) {
    return UiNavigationSpec(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      brand: brand ?? this.brand,
      leading: leading ?? this.leading,
      back: back ?? this.back,
      actions: actions ?? this.actions,
      heroTag: heroTag ?? this.heroTag,
      largeTitle: largeTitle ?? this.largeTitle,
      surface: surface ?? this.surface,
      blurSigma: blurSigma ?? this.blurSigma,
      showDivider: showDivider ?? this.showDivider,
      transitionStyle: transitionStyle ?? this.transitionStyle,
      animationGroupId: animationGroupId ?? this.animationGroupId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UiNavigationSpec &&
        other.title == title &&
        other.subtitle == subtitle &&
        other.brand == brand &&
        other.leading == leading &&
        other.back == back &&
        _listEq(other.actions, actions) &&
        other.heroTag == heroTag &&
        other.largeTitle == largeTitle &&
        other.surface == surface &&
        other.blurSigma == blurSigma &&
        other.showDivider == showDivider &&
        other.transitionStyle == transitionStyle &&
        other.animationGroupId == animationGroupId;
  }

  @override
  int get hashCode => Object.hash(
        title,
        subtitle,
        brand,
        leading,
        back,
        Object.hashAll(actions),
        heroTag,
        largeTitle,
        surface,
        blurSigma,
        showDivider,
        transitionStyle,
        animationGroupId,
      );

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

@immutable
class UiNavigationBackConfig {
  const UiNavigationBackConfig({
    required this.onPressed,
    this.label,
    this.history = const <UiNavigationBackHistoryItem>[],
    this.onHistorySelected,
  });

  /// Title shown in the back button; defaults to [UiNavigationSpec.title]
  /// when omitted.
  final String? label;
  final VoidCallback onPressed;
  final List<UiNavigationBackHistoryItem> history;
  final ValueChanged<UiNavigationBackHistoryItem>? onHistorySelected;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UiNavigationBackConfig &&
        other.label == label &&
        other.onPressed == onPressed &&
        UiNavigationSpec._listEq(other.history, history) &&
        other.onHistorySelected == onHistorySelected;
  }

  @override
  int get hashCode => Object.hash(
        label,
        onPressed,
        Object.hashAll(history),
        onHistorySelected,
      );
}
