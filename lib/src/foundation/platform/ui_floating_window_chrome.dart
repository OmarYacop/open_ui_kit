import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/ui_theme_extensions.dart';
import 'ui_platform_capabilities.dart';

/// Whether the current embedder can show native window chrome inside the app
/// surface.
///
/// Browser windows provide their own chrome outside Flutter's surface, even
/// when [defaultTargetPlatform] reflects iOS or macOS.
bool supportsUiFloatingWindowChrome() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

double resolveUiFloatingWindowChromeLeadingInset(
  BuildContext context,
  UiWindowMode? windowMode,
) {
  if (!supportsUiFloatingWindowChrome()) return 0;

  if (windowMode == UiWindowMode.windowed) {
    return _chromeLeadingInset(context);
  }
  if (windowMode == UiWindowMode.fullscreen ||
      windowMode == UiWindowMode.notApplicable) {
    return 0;
  }

  final viewPadding = MediaQuery.viewPaddingOf(context);
  final appHasTopSystemInset = viewPadding.top > 8;
  if (appHasTopSystemInset) return 0;

  return _chromeLeadingInset(context);
}

double _chromeLeadingInset(BuildContext context) {
  final tokens = UiThemeTokens.of(context);
  return tokens.spacing.x10 + tokens.spacing.x5;
}
