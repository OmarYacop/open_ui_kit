import 'package:flutter/widgets.dart';

import '../theme/ui_theme_extensions.dart';
import 'ui_platform_capabilities.dart';

double resolveUiFloatingWindowChromeLeadingInset(
  BuildContext context,
  UiWindowMode? windowMode,
) {
  if (windowMode == UiWindowMode.windowed) {
    return _chromeLeadingInset(context);
  }
  return 0;
}

double _chromeLeadingInset(BuildContext context) {
  final tokens = UiThemeTokens.of(context);
  return tokens.spacing.x10 + tokens.spacing.x5;
}
