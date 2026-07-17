import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

// Locale-aware test harness. The `inject` callback lets a test inject
// a [UiLocalizations] via `Localizations.override` without pulling in
// a full Arabic Material stack (which would need GlobalMaterialLocalizations).
Widget _host(
  Widget child, {
  TextDirection dir = TextDirection.ltr,
  UiLocalizations? strings,
}) {
  final tree = Directionality(
    textDirection: dir,
    child: Builder(
      builder: (ctx) {
        if (strings == null) return child;
        return Localizations.override(
          context: ctx,
          delegates: [
            _InlineUiLocalizationsDelegate(strings),
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: child,
        );
      },
    ),
  );
  return MaterialApp(theme: UiThemeData.light(), home: Scaffold(body: tree));
}

class _InlineUiLocalizationsDelegate
    extends LocalizationsDelegate<UiLocalizations> {
  _InlineUiLocalizationsDelegate(this.value);
  final UiLocalizations value;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<UiLocalizations> load(Locale locale) async => value;

  @override
  bool shouldReload(_InlineUiLocalizationsDelegate old) => old.value != value;
}

void main() {
  group('UiPagination localization (PR-1)', () {
    testWidgets('uses English defaults without a delegate installed',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiPagination(
            currentPage: 2,
            totalPages: 3,
            onPageChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Prev'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('flips to Arabic strings when the delegate returns ar',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiPagination(
            currentPage: 1,
            totalPages: 3,
            onPageChanged: (_) {},
          ),
          dir: TextDirection.rtl,
          strings: const UiLocalizationsAr(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('السابق'), findsOneWidget); // Prev
      expect(find.text('التالي'), findsOneWidget); // Next
      expect(find.text('Prev'), findsNothing);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('loading caption uses the localized "loading" string',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiPagination(
            currentPage: 1,
            totalPages: 3,
            loading: true,
            onPageChanged: (_) {},
          ),
          strings: const UiLocalizationsAr(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('جارٍ التحميل…'), findsOneWidget);
    });

    testWidgets(
        'page semantics label uses pageSemanticsLabel(n) from the '
        'installed delegate', (tester) async {
      await tester.pumpWidget(
        _host(
          UiPagination(
            currentPage: 2,
            totalPages: 3,
            onPageChanged: (_) {},
          ),
          strings: const UiLocalizationsAr(),
        ),
      );
      await tester.pumpAndSettle();
      // Arabic: "صفحة 2"
      final matches = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'صفحة 2',
      );
      expect(matches, findsWidgets);
    });
  });

  group('UiSliverNavigationBar back label (PR-1)', () {
    testWidgets('falls back to localized `back` when no history / label',
        (tester) async {
      final spec = UiNavigationSpec(
        title: 'Detail',
        back: UiNavigationBackConfig(onPressed: () {}),
      );
      await tester.pumpWidget(
        _host(
          CustomScrollView(
            slivers: [
              UiSliverNavigationBar(spec: spec),
              const SliverToBoxAdapter(child: SizedBox(height: 400)),
            ],
          ),
          strings: const UiLocalizationsAr(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('رجوع'), findsOneWidget); // Back in Arabic
      expect(find.text('Back'), findsNothing);
    });

    testWidgets('explicit spec.back.label takes precedence over the locale',
        (tester) async {
      final spec = UiNavigationSpec(
        title: 'Detail',
        back: UiNavigationBackConfig(
          label: 'Courses',
          onPressed: () {},
        ),
      );
      await tester.pumpWidget(
        _host(
          CustomScrollView(
            slivers: [
              UiSliverNavigationBar(spec: spec),
              const SliverToBoxAdapter(child: SizedBox(height: 400)),
            ],
          ),
          strings: const UiLocalizationsAr(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Courses'), findsOneWidget);
    });
  });

  group('UiDrawer semantics (PR-1)', () {
    testWidgets('announces the localized drawer label by default',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiDrawer(child: Text('nav')),
          strings: const UiLocalizationsAr(),
        ),
      );
      await tester.pumpAndSettle();
      final matches = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'لوحة جانبية',
      );
      expect(matches, findsWidgets);
    });

    testWidgets('empty semanticsLabel suppresses the announcement',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiDrawer(
            semanticsLabel: '',
            child: Text('nav'),
          ),
          strings: const UiLocalizationsAr(),
        ),
      );
      await tester.pumpAndSettle();
      // No semantics node with the default Arabic label should exist.
      final matches = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'لوحة جانبية',
      );
      expect(matches, findsNothing);
    });

    testWidgets(
        'explicit semanticsLabel overrides both the locale and the default',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiDrawer(
            semanticsLabel: 'Main nav',
            child: Text('nav'),
          ),
          strings: const UiLocalizationsAr(),
        ),
      );
      await tester.pumpAndSettle();
      final matches = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Main nav',
      );
      expect(matches, findsWidgets);
    });
  });
}
