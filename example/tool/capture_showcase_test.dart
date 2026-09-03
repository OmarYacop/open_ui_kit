import 'dart:io';
import 'dart:ui' as ui;

import 'package:contour_example/showcase.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

const _captureSize = Size(1440, 1120);
const _fontFamily = 'OpenUiKitShowcaseSans';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final bytes = await File('/System/Library/Fonts/SFNS.ttf').readAsBytes();
    final loader = FontLoader(_fontFamily)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    final iconLoader = FontLoader('packages/lucide_flutter/LucideIcons')
      ..addFont(rootBundle.load('packages/lucide_flutter/assets/lucide.ttf'));
    await iconLoader.load();
  });

  testWidgets('capture README showcase images', (tester) async {
    await binding.setSurfaceSize(_captureSize);
    addTearDown(() => binding.setSurfaceSize(null));
    final output = Directory('../doc/assets/showcase')
      ..createSync(recursive: true);

    await _capture(
      tester,
      mode: UiThemeMode.light,
      path: '${output.path}/overview-light.png',
    );
    await _capture(
      tester,
      mode: UiThemeMode.dark,
      path: '${output.path}/overview-dark.png',
    );
  });
}

Future<void> _capture(
  WidgetTester tester, {
  required UiThemeMode mode,
  required String path,
}) async {
  final boundaryKey = GlobalKey();
  final typography = _showcaseTypography(UiTypographyTokens.standard);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: UiApp(
        mode: mode,
        lightTokens: UiThemeData.light(typography: typography),
        darkTokens: UiThemeData.dark(typography: typography),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [DefaultWidgetsLocalizations.delegate],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const OpenUiKitShowcase(),
      ),
    ),
  );
  // Some showcase components own ambient painters that keep scheduling frames.
  // A bounded pair of pumps is deterministic and avoids waiting for an idle
  // scheduler that those components intentionally never provide.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Could not encode showcase image.');
    await File(path).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  });
}

UiTypographyTokens _showcaseTypography(UiTypographyTokens source) {
  TextStyle family(TextStyle style) => style.copyWith(fontFamily: _fontFamily);
  return source.copyWith(
    displayXl: family(source.displayXl),
    displayLg: family(source.displayLg),
    displayMd: family(source.displayMd),
    title: family(source.title),
    heading: family(source.heading),
    subheading: family(source.subheading),
    bodyLg: family(source.bodyLg),
    body: family(source.body),
    bodySm: family(source.bodySm),
    label: family(source.label),
    labelSm: family(source.labelSm),
    caption: family(source.caption),
    micro: family(source.micro),
    mono: family(source.mono),
  );
}
