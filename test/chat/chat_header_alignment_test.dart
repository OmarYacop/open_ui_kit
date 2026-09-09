import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final inset in [0.0, 24.0, 59.0]) {
        for (final direction in TextDirection.values) {
          testWidgets(
            'chat/detail centers $platform $scale $inset $direction',
            (tester) async {
              tester.view.physicalSize = const Size(390, 844);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              Widget host(Widget child) => UiApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(390, 844),
                    padding: EdgeInsets.only(top: inset),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Directionality(textDirection: direction, child: child),
                ),
              );
              const leading = SizedBox(key: Key('back'), width: 44, height: 44);
              const action = SizedBox(
                key: Key('action'),
                width: 36,
                height: 36,
              );
              await tester.pumpWidget(
                host(
                  const Align(
                    alignment: Alignment.topCenter,
                    child: UiChatHeader(
                      title: 'Conversation',
                      leading: leading,
                      trailing: action,
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final titleY = tester.getCenter(find.text('Conversation')).dy;
              final backY = tester.getCenter(find.byKey(const Key('back'))).dy;
              final actionY = tester
                  .getCenter(find.byKey(const Key('action')))
                  .dy;
              await tester.pumpWidget(
                host(
                  UiPageScaffold(
                    body: CustomScrollView(
                      slivers: [
                        UiSliverNavigationBar(
                          spec: const UiNavigationSpec(
                            title: 'Conversation',
                            largeTitle: false,
                            leading: leading,
                            actions: [action],
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 1000)),
                      ],
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(
                tester.getCenter(find.text('Conversation')).dy,
                closeTo(titleY, .1),
              );
              expect(
                tester.getCenter(find.byKey(const Key('back'))).dy,
                closeTo(backY, .1),
              );
              expect(
                tester.getCenter(find.byKey(const Key('action'))).dy,
                closeTo(actionY, .1),
              );
            },
            variant: TargetPlatformVariant({platform}),
          );
        }
      }
    }
  }
}
