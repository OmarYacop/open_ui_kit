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
  return MaterialApp(home: Scaffold(body: tree));
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
  testWidgets('date picker localizes visible and spoken labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final day = DateTime(2026, 9, 5);
    await tester.pumpWidget(
      _host(
        UiDatePicker(value: day, today: day, onChanged: (_) {}),
        strings: const UiLocalizationsAr(),
        dir: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('سبتمبر 2026'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('السبت.*سبتمبر.*اليوم')),
      findsOneWidget,
    );
    semantics.dispose();
  });
  testWidgets('alert and table defaults use the active locale', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const UiAlert(title: 'تم', intent: UiAlertIntent.success),
        strings: const UiLocalizationsAr(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('نجاح.*تم')), findsOneWidget);
    await tester.pumpWidget(
      _host(
        const UiDataTable(columns: [], rows: [], loading: true),
        strings: const UiLocalizationsAr(),
      ),
    );
    await tester.pump();
    expect(find.text(const UiLocalizationsAr().loadingTable), findsOneWidget);
    semantics.dispose();
  });
}
