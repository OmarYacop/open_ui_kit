import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  group('UiLocalizations', () {
    testWidgets(
        'of(context) returns English defaults when no delegate '
        'is installed', (tester) async {
      late UiLocalizations strings;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              strings = UiLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(strings, isA<UiLocalizationsEn>());
      expect(strings.back, 'Back');
      expect(strings.cancel, 'Cancel');
      expect(strings.opensMonthPicker, 'opens month picker');
    });

    test('delegate.load returns Arabic strings for an Arabic Locale', () async {
      const delegate = UiLocalizations.delegate;
      final strings = await delegate.load(const Locale('ar'));
      expect(strings, isA<UiLocalizationsAr>());
      expect(strings.back, 'رجوع');
      expect(strings.confirm, 'تأكيد');
      expect(strings.opensMonthPicker, 'فتح منتقي الشهر');
    });

    test('delegate.load returns English for an English Locale', () async {
      const delegate = UiLocalizations.delegate;
      final strings = await delegate.load(const Locale('en'));
      expect(strings, isA<UiLocalizationsEn>());
      expect(strings.back, 'Back');
    });

    testWidgets('isSupported honours the declared locale set', (tester) async {
      const delegate = UiLocalizations.delegate;
      expect(delegate.isSupported(const Locale('en')), isTrue);
      expect(delegate.isSupported(const Locale('ar')), isTrue);
      expect(delegate.isSupported(const Locale('fr')), isFalse);
      expect(delegate.isSupported(const Locale('de')), isFalse);
    });
  });

  group('uiIsRtl', () {
    testWidgets('true under TextDirection.rtl', (tester) async {
      late bool observed;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) {
              observed = uiIsRtl(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(observed, isTrue);
    });

    testWidgets('false under TextDirection.ltr', (tester) async {
      late bool observed;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              observed = uiIsRtl(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(observed, isFalse);
    });
  });

  group('UiDirectionalGlyphs', () {
    testWidgets('flips chevrons by text direction', (tester) async {
      late String rtlForwards;
      late String ltrForwards;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) {
              rtlForwards = UiDirectionalGlyphs.forwards(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              ltrForwards = UiDirectionalGlyphs.forwards(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(ltrForwards, UiDirectionalGlyphs.lightRight);
      expect(rtlForwards, UiDirectionalGlyphs.lightLeft);
    });
  });
}
