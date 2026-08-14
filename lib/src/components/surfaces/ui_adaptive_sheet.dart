import 'package:flutter/widgets.dart';

import '../../foundation/layout/ui_form_factor.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../overlay/dialog.dart';
import 'ui_sheet.dart';

/// Presents focused content as a bottom sheet on phones and a constrained
/// floating surface on tablet/desktop.
///
/// This is the canonical adaptive modal entry point. Callers provide content;
/// Open UI Kit owns form-factor selection, safe modal chrome, and motion.
abstract final class UiAdaptiveSheetScope {
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    UiSheetSnap snap = const UiSheetSnap.fit(),
    UiBreakpoints breakpoints = UiBreakpoints.standard,
    double maxWidth = 460,
    double maxHeightFactor = 0.8,
    bool barrierDismissible = true,
    bool isDismissible = true,
    bool showPhoneHandle = true,
  }) {
    assert(maxWidth > 0, 'maxWidth must be positive');
    assert(
      maxHeightFactor > 0 && maxHeightFactor <= 1,
      'maxHeightFactor must be in the range (0, 1]',
    );

    final formFactor = uiFormFactorOf(context, breakpoints: breakpoints);
    if (formFactor == UiFormFactor.phone) {
      return UiSheetScope.show<T>(
        context,
        snap: snap,
        barrierDismissible: barrierDismissible,
        isDismissible: isDismissible,
        builder: (sheetContext, _) => UiSheet(
          padding: EdgeInsets.zero,
          showHandle: showPhoneHandle,
          child: builder(sheetContext),
        ),
      );
    }

    return UiDialogScope.show<T>(
      context,
      barrierDismissible: barrierDismissible && isDismissible,
      builder: (dialogContext) => PopScope(
        canPop: isDismissible,
        child: _UiAdaptiveFloatingSurface(
          maxWidth: maxWidth,
          maxHeightFactor: maxHeightFactor,
          child: builder(dialogContext),
        ),
      ),
    );
  }
}

class _UiAdaptiveFloatingSurface extends StatelessWidget {
  const _UiAdaptiveFloatingSurface({
    required this.maxWidth,
    required this.maxHeightFactor,
    required this.child,
  });

  final double maxWidth;
  final double maxHeightFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final viewport = MediaQuery.sizeOf(context);

    return Center(
      child: ConstrainedBox(
        key: const ValueKey('ui_adaptive_floating_surface'),
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: viewport.height * maxHeightFactor,
        ),
        child: ClipRRect(
          borderRadius: tokens.radius.xlAll,
          child: ColoredBox(color: tokens.colors.card, child: child),
        ),
      ),
    );
  }
}
