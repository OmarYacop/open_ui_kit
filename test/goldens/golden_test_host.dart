import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

const Size kGoldenSurfaceSize = Size(360, 360);
const double kGoldenDevicePixelRatio = 1.0;
const Locale kGoldenLocale = Locale('en', 'US');

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
  final tokens =
      brightness == Brightness.dark ? UiThemeData.dark() : UiThemeData.light();

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: kGoldenLocale,
      supportedLocales: const [kGoldenLocale],
      theme: _materialThemeFor(tokens),
      home: UiTheme(
        tokens: tokens,
        child: MediaQuery(
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
    ),
  );
}

ThemeData _materialThemeFor(UiThemeTokens tokens) {
  final colors = tokens.colors;
  return ThemeData(
    useMaterial3: true,
    brightness: tokens.brightness,
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.background,
    colorScheme: ColorScheme(
      brightness: tokens.brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      error: colors.danger,
      onError: colors.onDanger,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    ),
  );
}
