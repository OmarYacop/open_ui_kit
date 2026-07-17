import 'package:flutter/widgets.dart';

/// UI-kit string catalogue.
///
/// Every user-facing string hard-coded inside a component flows
/// through this contract so host apps can override per locale without
/// reaching into the kit's source. Add new entries here (with a
/// default English value on [UiLocalizationsEn]) rather than inlining
/// a new `"Retry"` or `"Back"` somewhere in the components layer.
///
/// ### Integration — recommended
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: const [
///     ...GlobalMaterialLocalizations.delegates, // if you use material
///     UiLocalizations.delegate,                 // <-- add this
///   ],
///   supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
///   // ...
/// )
/// ```
///
/// ### Reading inside a component
///
/// ```dart
/// final strings = UiLocalizations.of(context);
/// return UiButton(label: strings.back);
/// ```
///
/// `UiLocalizations.of(context)` never returns null — if the delegate
/// is not installed, the English defaults are used. That keeps
/// components working in minimal test harnesses and during app
/// bring-up, at the cost of not being able to catch a missing
/// delegate wiring at the call site. Host apps are still encouraged
/// to register the delegate explicitly.
///
/// ### Directionality
///
/// Text direction is NOT owned by this class. Flutter resolves it
/// from the ambient `Locale`, `Directionality` ancestor, or
/// `MaterialApp.localizationsDelegates`. Components should use
/// `EdgeInsetsDirectional`, `AlignmentDirectional`, and
/// `Directionality.of(context)` rather than branching on a locale
/// tag to get RTL right.
abstract class UiLocalizations {
  const UiLocalizations();

  /// Default label for the navigation back button.
  String get back;

  /// Default label for a confirm action.
  String get confirm;

  /// Default label for a cancel action.
  String get cancel;

  /// Default label for a retry affordance (empty / error states).
  String get retry;

  /// Default label for a close affordance.
  String get close;

  /// Default label for a "loading" caption.
  String get loading;

  /// Default spoken-state suffix: "selected".
  String get selected;

  /// Default spoken-state suffix: "disabled".
  String get disabled;

  /// Default spoken-state suffix: "today".
  String get today;

  /// Default spoken-state suffix for a range's start endpoint.
  String get rangeStart;

  /// Default spoken-state suffix for a range's end endpoint.
  String get rangeEnd;

  /// Default hint appended to the date picker header trigger's
  /// semantics label when tapping would open the month grid.
  String get opensMonthPicker;

  /// Default hint appended when tapping would open the year grid.
  String get opensYearPicker;

  /// Default hint appended when tapping would return to the month
  /// grid from the year grid.
  String get backToMonthGrid;

  /// Default label for a "previous page" pagination chip.
  String get previous;

  /// Default label for a "next page" pagination chip.
  String get next;

  /// Spoken label for a pagination chip pointing to [page]. The
  /// English default renders `"Page 3"`. Override for locales where
  /// the unit word takes a different position relative to the
  /// number.
  String pageSemanticsLabel(int page);

  /// Spoken label for a drawer surface. Screen readers announce this
  /// when focus enters the drawer so users understand they've moved
  /// into a side panel.
  String get drawer;

  /// Default label for expanding a collapsed navigation rail.
  String get expandNavigationRail;

  /// Default label for collapsing an expanded navigation rail.
  String get collapseNavigationRail;

  /// Spoken label for a sheet surface.
  String get sheet;

  /// Spoken label for a menu trigger.
  String get menu;

  /// Default label for an overflow navigation item.
  String get more;

  /// Resolve the active localization for [context]. When no delegate
  /// is installed, [UiLocalizationsEn] is returned so components keep
  /// working during test and bring-up.
  static UiLocalizations of(BuildContext context) {
    final fromWidget =
        Localizations.of<UiLocalizations>(context, UiLocalizations);
    return fromWidget ?? const UiLocalizationsEn();
  }

  /// The delegate to register in `MaterialApp.localizationsDelegates`.
  static const LocalizationsDelegate<UiLocalizations> delegate =
      _UiLocalizationsDelegate();
}

/// English (US) defaults. Also the implicit fallback when no delegate
/// is installed — see [UiLocalizations.of].
class UiLocalizationsEn extends UiLocalizations {
  const UiLocalizationsEn();

  @override
  String get back => 'Back';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get loading => 'Loading…';

  @override
  String get selected => 'selected';

  @override
  String get disabled => 'disabled';

  @override
  String get today => 'today';

  @override
  String get rangeStart => 'range start';

  @override
  String get rangeEnd => 'range end';

  @override
  String get opensMonthPicker => 'opens month picker';

  @override
  String get opensYearPicker => 'opens year picker';

  @override
  String get backToMonthGrid => 'back to month grid';

  @override
  String get previous => 'Prev';

  @override
  String get next => 'Next';

  @override
  String pageSemanticsLabel(int page) => 'Page $page';

  @override
  String get drawer => 'Drawer';

  @override
  String get expandNavigationRail => 'Expand navigation rail';

  @override
  String get collapseNavigationRail => 'Collapse navigation rail';

  @override
  String get sheet => 'Sheet';

  @override
  String get menu => 'Menu';

  @override
  String get more => 'More';
}

/// Minimal Arabic resource (RTL) demonstrating delegate wiring.
///
/// Host apps typically ship their own exhaustive translations —
/// this class is provided so the kit's own widget tests can exercise
/// the non-English path and so README examples can show a ready-made
/// RTL locale.
class UiLocalizationsAr extends UiLocalizations {
  const UiLocalizationsAr();

  @override
  String get back => 'رجوع';

  @override
  String get confirm => 'تأكيد';

  @override
  String get cancel => 'إلغاء';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get close => 'إغلاق';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get selected => 'محدد';

  @override
  String get disabled => 'معطل';

  @override
  String get today => 'اليوم';

  @override
  String get rangeStart => 'بداية النطاق';

  @override
  String get rangeEnd => 'نهاية النطاق';

  @override
  String get opensMonthPicker => 'فتح منتقي الشهر';

  @override
  String get opensYearPicker => 'فتح منتقي السنة';

  @override
  String get backToMonthGrid => 'العودة إلى شبكة الأشهر';

  @override
  String get previous => 'السابق';

  @override
  String get next => 'التالي';

  @override
  String pageSemanticsLabel(int page) => 'صفحة $page';

  @override
  String get drawer => 'لوحة جانبية';

  @override
  String get expandNavigationRail => 'توسيع شريط التنقل';

  @override
  String get collapseNavigationRail => 'طي شريط التنقل';

  @override
  String get sheet => 'لوحة';

  @override
  String get menu => 'قائمة';

  @override
  String get more => 'المزيد';
}

class _UiLocalizationsDelegate extends LocalizationsDelegate<UiLocalizations> {
  const _UiLocalizationsDelegate();

  // Built-in supported locales. The kit's delegate ships two (en, ar)
  // so the RTL story is testable out of the box. Host apps that need
  // additional locales should write their own delegate extending
  // [UiLocalizations] and register it AFTER this one in the app's
  // delegates list; Flutter will resolve to the most specific match.
  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'en' || locale.languageCode == 'ar';
  }

  @override
  Future<UiLocalizations> load(Locale locale) async {
    if (locale.languageCode == 'ar') {
      return const UiLocalizationsAr();
    }
    return const UiLocalizationsEn();
  }

  @override
  bool shouldReload(_UiLocalizationsDelegate old) => false;

  @override
  String toString() => 'UiLocalizations.delegate';
}

// ─────────────────────────────────────────────────────────────────────────────
// Directionality helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Small convenience around [Directionality.of] for call sites that
/// only care about a boolean RTL flag. Avoids each component having
/// to spell `Directionality.of(context) == TextDirection.rtl`.
bool uiIsRtl(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl;

/// Collection of directional glyphs used by the kit.
///
/// `‹`, `›`, `<`, `>`, `◀`, `▶` render the same in LTR and RTL
/// contexts, which means a "next month" chevron pointing right in
/// English also points right (toward the past) in Arabic. Components
/// should consult these constants — or their own
/// [Directionality]-aware pickers — instead of hard-coding an arrow
/// glyph.
class UiDirectionalGlyphs {
  UiDirectionalGlyphs._();

  /// Glyph for "navigate to the previous item in reading order".
  /// In LTR this points **left**; in RTL it points **right**.
  static String backwards(BuildContext context) => uiIsRtl(context) ? '›' : '‹';

  /// Glyph for "navigate to the next item in reading order".
  /// In LTR this points **right**; in RTL it points **left**.
  static String forwards(BuildContext context) => uiIsRtl(context) ? '‹' : '›';

  @visibleForTesting
  static const lightLeft = '‹';
  @visibleForTesting
  static const lightRight = '›';
}
