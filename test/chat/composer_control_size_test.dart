import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final extent in [48.0, 56.0]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          '$platform $extent $direction attachment matches composer',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(360, 640));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            var opened = 0;
            await tester.pumpWidget(
              UiApp(
                home: MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(1.15),
                  ),
                  child: Directionality(
                    textDirection: direction,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: UiChatComposer.conversation(
                        controlExtent: extent,
                        onSend: (_) {},
                        onAttachmentMenuOpened: () => opened++,
                        attachmentItems: [
                          UiMenuItem(label: 'Photo', onPressed: () {}),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final attachment = find.byKey(const ValueKey('open-attachments'));
            final surface = find.descendant(
              of: attachment,
              matching: find.byType(UiBox),
            );
            final composer = find.byKey(
              const ValueKey('chat-composer-surface'),
            );
            expect(tester.getSize(surface), Size.square(extent));
            expect(
              tester.getSize(surface).height,
              tester.getSize(composer).height,
            );
            expect(
              tester.getRect(surface).bottom,
              tester.getRect(composer).bottom,
            );
            await tester.tap(attachment);
            await tester.pumpAndSettle();
            expect(opened, 1);
            expect(find.text('Photo'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant({platform}),
        );
      }
    }
  }
}
