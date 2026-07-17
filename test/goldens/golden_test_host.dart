import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

const Size kGoldenSurfaceSize = Size(360, 360);
const double kGoldenDevicePixelRatio = 1.0;
const Locale kGoldenLocale = Locale('en', 'US');
const TargetPlatform kGoldenTargetPlatform = TargetPlatform.macOS;

bool get isSupportedGoldenHost => Platform.isMacOS;

Future<void> pumpGoldenFrame(
  WidgetTester tester, {
  required Brightness brightness,
  required Widget child,
  Size size = kGoldenSurfaceSize,
}) async {
  final view = tester.view;
  view
    ..physicalSize = Size(
      size.width * kGoldenDevicePixelRatio,
      size.height * kGoldenDevicePixelRatio,
    )
    ..devicePixelRatio = kGoldenDevicePixelRatio;
  addTearDown(view.reset);
  final theme = (brightness == Brightness.dark
          ? UiThemeData.dark()
          : UiThemeData.light())
      .copyWith(platform: kGoldenTargetPlatform);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: kGoldenLocale,
      supportedLocales: const [kGoldenLocale],
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          devicePixelRatio: kGoldenDevicePixelRatio,
          textScaler: TextScaler.noScaling,
          platformBrightness: brightness,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox.fromSize(
              size: size,
              child: Scaffold(body: child),
            ),
          ),
        ),
      ),
    ),
  );
}
