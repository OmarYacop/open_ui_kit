import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget host(
  Widget child, {
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
  EdgeInsets padding = EdgeInsets.zero,
  Size size = const Size(390, 844),
}) => UiApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: size,
      padding: padding,
      textScaler: TextScaler.linear(scale),
    ),
    child: Directionality(textDirection: direction, child: child),
  ),
);

void main() {
  for (final (safeTop, scale) in [
    (24.0, 1.0),
    (59.0, 1.0),
    (24.0, 1.15),
    (59.0, 1.15),
  ]) {
    testWidgets(
      'compact action header keeps a fixed content gap $safeTop/$scale',
      (tester) async {
        await tester.pumpWidget(
          host(
            UiPageScaffold(
              body: CustomScrollView(
                slivers: [
                  UiSliverNavigationBar(
                    spec: UiNavigationSpec(
                      title: 'Chats',
                      actionsFollowTitleCollapse: true,
                      actions: [
                        UiIconButton(
                          icon: const Icon(IconData(0xe001)),
                          semanticsLabel: 'Unread',
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      key: Key('following-content'),
                      height: 1000,
                    ),
                  ),
                ],
              ),
            ),
            padding: EdgeInsets.only(top: safeTop),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        final actions = tester.getRect(
          find.byKey(const Key('ui_navigation_tracking_actions')),
        );
        final title = tester.getRect(
          find.byKey(const Key('ui_navigation_large_title')),
        );
        final contentTop = tester
            .getTopLeft(find.byKey(const Key('following-content')))
            .dy;
        expect(actions.center.dy, closeTo(title.center.dy, 1));
        expect(
          contentTop - actions.bottom,
          closeTo(12, 1),
          reason: 'Safe-area height must not inflate title-to-content spacing.',
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }

  for (final scale in [1.0, 1.3, 2.0]) {
    for (final safeTop in [0.0, 59.0]) {
      testWidgets(
        'large titles share y anchor across subtitle/action combinations scale=$scale safe=$safeTop',
        (tester) async {
          double? titleY;
          double? actionY;
          double? headerHeight;
          for (final subtitle in [
            null,
            'Review upcoming and recent classes.',
          ]) {
            for (final hasAction in [false, true]) {
              await tester.pumpWidget(
                host(
                  CustomScrollView(
                    slivers: [
                      UiSliverNavigationBar(
                        spec: UiNavigationSpec(
                          title: 'Page title',
                          subtitle: subtitle,
                          actionsFollowTitleCollapse: true,
                          actions: hasAction
                              ? [
                                  UiIconButton(
                                    key: const Key('aligned-action'),
                                    size: UiSize.lg,
                                    icon: const Icon(IconData(0xe001)),
                                    semanticsLabel: 'Action',
                                    onPressed: () {},
                                  ),
                                ]
                              : const [],
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 1000)),
                    ],
                  ),
                  scale: scale,
                  padding: EdgeInsets.only(top: safeTop),
                ),
              );
              await tester.pumpAndSettle();
              final title = tester.getRect(
                find.byKey(const Key('ui_navigation_large_title')),
              );
              titleY ??= title.top;
              expect(title.top, closeTo(titleY, .01));
              final height = tester
                  .getSize(
                    find.byKey(const Key('ui_sliver_navigation_bar_shadow')),
                  )
                  .height;
              headerHeight ??= height;
              if (hasAction && subtitle == null) {
                expect(height, lessThan(headerHeight - 8));
              } else {
                expect(height, closeTo(headerHeight, .01));
              }
              if (hasAction) {
                final action = tester.getRect(
                  find.byKey(const Key('aligned-action')),
                );
                actionY ??= action.center.dy;
                expect(action.center.dy, closeTo(actionY, .01));
                expect(action.center.dy, closeTo(title.center.dy, 1));
              }
              expect(tester.takeException(), isNull);
            }
          }
        },
      );
    }
  }

  for (final subtitle in [null, 'Recent conversations']) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'sliver title action clears bottom with subtitle=$subtitle scale=$scale',
        (tester) async {
          final controller = ScrollController();
          addTearDown(controller.dispose);
          var presses = 0;
          await tester.pumpWidget(
            host(
              SizedBox(
                width: 390,
                child: CustomScrollView(
                  controller: controller,
                  slivers: [
                    UiSliverNavigationBar(
                      spec: UiNavigationSpec(
                        title: 'Chats',
                        subtitle: subtitle,
                        actionsFollowTitleCollapse: true,
                        actions: [
                          UiIconButton(
                            key: const Key('sized-action'),
                            size: UiSize.lg,
                            icon: const Icon(IconData(0xe001)),
                            semanticsLabel: 'New chat',
                            onPressed: () => presses++,
                          ),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 1200)),
                  ],
                ),
              ),
              scale: scale,
              padding: const EdgeInsets.only(top: 24),
            ),
          );
          await tester.pumpAndSettle();
          final action = find.byKey(const Key('sized-action'));
          final surface = find.byKey(
            const Key('ui_sliver_navigation_bar_shadow'),
          );
          final expanded = tester.getRect(surface);
          final actionRect = tester.getRect(action);
          expect(actionRect.height, closeTo(44, .01));
          expect(
            actionRect.bottom,
            lessThanOrEqualTo(expanded.bottom - 12 + .01),
          );
          expect(actionRect.top, greaterThanOrEqualTo(expanded.top + 24));
          if (subtitle != null) {
            expect(
              tester.getRect(find.text(subtitle)).bottom,
              lessThanOrEqualTo(expanded.bottom - 12 + .01),
            );
          }
          await tester.tapAt(
            Offset(actionRect.center.dx, actionRect.bottom - 2),
          );
          expect(presses, 1);
          controller.jumpTo(500);
          await tester.pumpAndSettle();
          final compact = tester.getRect(surface);
          final pinnedAction = tester.getRect(action);
          expect(
            pinnedAction.bottom,
            lessThanOrEqualTo(compact.bottom - 8 + .01),
          );
          expect(pinnedAction.top, greaterThanOrEqualTo(compact.top + 24));
          await tester.tapAt(
            Offset(pinnedAction.center.dx, pinnedAction.bottom - 2),
          );
          expect(presses, 2);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('chat header symmetry and title space $direction $scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 390,
                child: UiChatHeader(
                  title: 'A long conversation title that needs the available space',
                  leading: UiNavigationBackButton(
                    label: 'Back',
                    onPressed: () {},
                  ),
                  trailing: const UiAvatar(name: 'Study group', size: 32),
                ),
              ),
            ),
            scale: scale,
            direction: direction,
          ),
        );
        await tester.pumpAndSettle();
        final back = tester.getRect(find.byType(UiNavigationBackButton));
        final avatar = tester.getRect(find.byType(UiAvatar));
        expect(avatar.width, closeTo(back.width, .01));
        expect(avatar.height, closeTo(back.height, .01));
        expect(avatar.center.dy, closeTo(back.center.dy, .01));
        final title = tester.getRect(
          find.text('A long conversation title that needs the available space'),
        );
        expect(title.width, greaterThan(220));
        expect(title.overlaps(back), isFalse);
        expect(title.overlaps(avatar), isFalse);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('sliver title uses asymmetric free space $direction', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 390,
              child: CustomScrollView(
                slivers: [
                  UiSliverNavigationBar(
                    spec: UiNavigationSpec(
                      title: 'A long title needing the available header width',
                      largeTitle: false,
                      back: UiNavigationBackConfig(
                        label: 'Back',
                        onPressed: () {},
                      ),
                      actions: const [
                        SizedBox(key: Key('action'), width: 80, height: 44),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          direction: direction,
        ),
      );
      await tester.pumpAndSettle();
      final title = tester.getRect(
        find.byKey(const Key('ui_navigation_compact_title')),
      );
      expect(title.width, greaterThan(200));
      expect(
        title.overlaps(tester.getRect(find.byKey(const Key('action')))),
        isFalse,
      );
      expect(
        title.overlaps(tester.getRect(find.byType(UiNavigationBackButton))),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final safe in [
    EdgeInsets.zero,
    const EdgeInsets.only(top: 24, bottom: 16),
    const EdgeInsets.only(top: 59, bottom: 34),
  ]) {
    testWidgets('scroll endpoints clear fade with safe insets $safe', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          UiPageScaffold(
            body: Builder(
              builder: (context) => SingleChildScrollView(
                controller: controller,
                padding: UiPageBodyInsets.of(context),
                child: const Column(
                  children: [
                    SizedBox(key: Key('first'), height: 44),
                    SizedBox(height: 1200),
                    SizedBox(key: Key('last'), height: 44),
                  ],
                ),
              ),
            ),
          ),
          padding: safe,
        ),
      );
      final fade = tester.getRect(find.byType(UiScrollEdgeFade));
      expect(
        tester.getRect(find.byKey(const Key('first'))).top,
        greaterThanOrEqualTo(fade.top + 128),
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const Key('last'))).bottom,
        lessThanOrEqualTo(fade.bottom - 48),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'fade clearance overrides, disabled edges, safe minimum and wide defaults',
    (tester) async {
      EdgeInsets? observed;
      Future<void> check({
        bool fade = true,
        bool top = true,
        bool bottom = true,
        bool usesSafe = true,
        double? topClearance,
        double? bottomClearance,
        Size size = const Size(390, 844),
      }) async {
        await tester.pumpWidget(
          host(
            UiPageScaffold(
              scrollFade: fade,
              scrollFadeTop: top,
              scrollFadeBottom: bottom,
              scrollFadeUsesSafeArea: usesSafe,
              scrollFadeTopClearance: topClearance,
              scrollFadeBottomClearance: bottomClearance,
              body: Builder(
                builder: (context) {
                  observed = UiPageBodyInsets.of(context);
                  return const SizedBox();
                },
              ),
            ),
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            size: size,
          ),
        );
      }

      await check(topClearance: 80, bottomClearance: 64);
      expect(observed, const EdgeInsets.only(top: 80, bottom: 64));
      await check(topClearance: 0, bottomClearance: 0);
      expect(observed, const EdgeInsets.only(top: 24, bottom: 16));
      await check(top: false, bottom: false);
      expect(observed, const EdgeInsets.only(top: 24, bottom: 16));
      await check(fade: false);
      expect(observed, EdgeInsets.zero);
      await check(usesSafe: false);
      expect(observed, EdgeInsets.zero);
      await check(size: const Size(1024, 768));
      expect(observed, const EdgeInsets.only(top: 72, bottom: 48));
    },
  );
}
