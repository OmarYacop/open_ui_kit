import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../intl/intl.dart';

/// Direction-aware icon choices for navigation and disclosure affordances.
///
/// Use these when the intent is semantic (`back`, `forward`, `start`, `end`)
/// rather than physical (`left`, `right`). This keeps arrows and chevrons
/// correct in RTL layouts without scattering direction checks through apps.
class UiDirectionalIcons {
  const UiDirectionalIcons._();

  /// Navigation back. LTR points left; RTL points right.
  static IconData back(BuildContext context) =>
      uiIsRtl(context) ? LucideIcons.arrowRight : LucideIcons.arrowLeft;

  /// Navigation forward. LTR points right; RTL points left.
  static IconData forward(BuildContext context) =>
      uiIsRtl(context) ? LucideIcons.arrowLeft : LucideIcons.arrowRight;

  /// Chevron for moving back in reading order.
  static IconData chevronBack(BuildContext context) =>
      uiIsRtl(context) ? LucideIcons.chevronRight : LucideIcons.chevronLeft;

  /// Chevron for moving forward in reading order.
  static IconData chevronForward(BuildContext context) =>
      uiIsRtl(context) ? LucideIcons.chevronLeft : LucideIcons.chevronRight;

  /// Alias for a chevron pointing toward the directional start edge.
  static IconData chevronStart(BuildContext context) => chevronBack(context);

  /// Alias for a chevron pointing toward the directional end edge.
  static IconData chevronEnd(BuildContext context) => chevronForward(context);
}
