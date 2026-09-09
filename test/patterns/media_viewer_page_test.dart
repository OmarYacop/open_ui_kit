import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('media page safe layout $size dark=$dark', (tester) async {
        tester.view.resetPhysicalSize();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var dismissed = false;
        var saved = false;
        await tester.pumpWidget(
          UiApp(
            mode: dark ? UiThemeMode.dark : UiThemeMode.light,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: const EdgeInsets.fromLTRB(24, 44, 24, 34),
                textScaler: const TextScaler.linear(2),
              ),
              child: Directionality(
                textDirection: dark ? TextDirection.rtl : TextDirection.ltr,
                child: UiMediaViewerPage(
                  title: 'A long localized media title with sender details',
                  subtitle: 'Tuesday, September 8 · 16:00',
                  dismissLabel: 'Back',
                  onDismiss: () => dismissed = true,
                  footer: UiButton(
                    label: 'Save',
                    onPressed: () => saved = true,
                  ),
                  child: const SizedBox.expand(key: Key('media')),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(UiPageScaffold), findsOneWidget);
        expect(find.byType(UiSliverNavigationBar), findsOneWidget);
        final media = tester.getRect(find.byKey(const Key('media')));
        expect(media, Offset.zero & size);
        expect(find.text('Tuesday, September 8 · 16:00'), findsOneWidget);
        expect(
          tester.getRect(find.text('Save')).bottom,
          lessThanOrEqualTo(size.height - 34),
        );
        await tester.tap(find.text('Save'));
        expect(saved, isTrue);
        await tester.tap(find.bySemanticsLabel('Back'));
        expect(dismissed, isTrue);
      });
    }
  }

  testWidgets('embedded gallery retains zoom without duplicate navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        home: UiMediaViewerPage(
          title: 'Image',
          dismissLabel: 'Back',
          child: UiMediaGallery(
            showChrome: false,
            dismissLabel: 'Gallery back',
            items: [
              UiMediaGalleryItem(
                builder: (_) => const ColoredBox(color: Color(0xff123456)),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Gallery back'), findsNothing);
    final point = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
  });

  testWidgets('chrome hides without resizing media and Escape dismisses', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var dismissed = false;
    final footerFocus = FocusNode();
    addTearDown(footerFocus.dispose);
    await tester.pumpWidget(
      UiApp(
        home: UiMediaViewerPage(
          title: 'Photo',
          dismissLabel: 'Back',
          onDismiss: () => dismissed = true,
          footer: Focus(focusNode: footerFocus, child: const UiText('Details')),
          child: const SizedBox.expand(key: Key('media')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byKey(const Key('media')));
    await tester.tapAt(before.center);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('media'))), before);
    expect(find.bySemanticsLabel('Back').hitTestable(), findsNothing);
    expect(footerFocus.canRequestFocus, isFalse);
    expect(
      tester.getSemantics(find.byType(UiMediaViewerPage)).toStringDeep(),
      isNot(contains('label: "Back"')),
    );
    await tester.tapAt(before.center);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(footerFocus.canRequestFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(dismissed, isTrue);
    semantics.dispose();
  });

  testWidgets('embedded gallery single tap toggles page chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        home: UiMediaViewerPage(
          title: 'Photo',
          dismissLabel: 'Back',
          child: UiMediaGallery(
            showChrome: false,
            dismissLabel: 'Gallery back',
            items: [
              UiMediaGalleryItem(builder: (_) => const SizedBox.expand()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final point = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Back').hitTestable(), findsNothing);
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
  });

  testWidgets('screen reader keeps chrome and child actions keep taps', (
    tester,
  ) async {
    var played = false;
    await tester.pumpWidget(
      UiApp(
        home: MediaQuery(
          data: const MediaQueryData(
            accessibleNavigation: true,
            disableAnimations: true,
          ),
          child: UiMediaViewerPage(
            title: 'Video',
            dismissLabel: 'Back',
            child: Center(
              child: UiButton(label: 'Play', onPressed: () => played = true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    expect(played, isTrue);
    await tester.tapAt(const Offset(20, 250));
    await tester.pump();
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('long caption and playback share overlay at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UiApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: const EdgeInsets.fromLTRB(24, 44, 24, 34),
              textScaler: const TextScaler.linear(2),
            ),
            child: UiMediaViewerPage(
              title: 'Video',
              dismissLabel: 'Back',
              caption: UiText(
                List.filled(30, 'A long caption').join(' '),
                key: const Key('caption'),
              ),
              footer: UiButton(label: 'Playback', onPressed: () {}),
              child: const SizedBox.expand(key: Key('media')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('media'))),
        Offset.zero & size,
      );
      expect(
        tester.getRect(find.text('Playback')).bottom,
        lessThan(size.height - 34),
      );
      final scrollable = find.ancestor(
        of: find.byKey(const Key('caption')),
        matching: find.byType(SingleChildScrollView),
      );
      final captionRect = tester.getRect(scrollable);
      expect(captionRect.height, lessThanOrEqualTo(size.height * .25));
      expect(
        captionRect.bottom,
        lessThan(tester.getRect(find.text('Playback')).top),
      );
      await tester.drag(scrollable, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Back').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('controlled player chrome hides caption and header together', (
    tester,
  ) async {
    bool visible = true;
    await tester.pumpWidget(
      UiApp(
        home: StatefulBuilder(
          builder: (context, setState) => UiMediaViewerPage(
            title: 'Video',
            dismissLabel: 'Back',
            chromeVisible: visible,
            onChromeVisibilityChanged: (value) =>
                setState(() => visible = value),
            caption: const UiText('Caption'),
            footer: UiButton(label: 'Playback', onPressed: () {}),
            child: const SizedBox.expand(key: Key('media')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byKey(const Key('media'))));
    await tester.pumpAndSettle();
    expect(visible, isFalse);
    expect(find.text('Playback').hitTestable(), findsNothing);
    expect(find.bySemanticsLabel('Back').hitTestable(), findsNothing);
    await tester.tapAt(tester.getCenter(find.byKey(const Key('media'))));
    await tester.pumpAndSettle();
    expect(visible, isTrue);
    expect(find.text('Playback').hitTestable(), findsOneWidget);
  });
}
