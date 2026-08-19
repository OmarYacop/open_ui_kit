import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('pages media and exposes accessible application actions', (
    tester,
  ) async {
    var dismissed = false;
    var shared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: UiMediaGallery(
          dismissLabel: 'Back',
          onDismiss: () => dismissed = true,
          items: [
            UiMediaGalleryItem(
              title: 'First image',
              builder: (_) => const ColoredBox(color: Color(0xFFFF0000)),
            ),
            UiMediaGalleryItem(
              title: 'Second image',
              builder: (_) => const ColoredBox(color: Color(0xFF00FF00)),
            ),
          ],
          actionsBuilder: (context, index) => [
            UiMediaGalleryAction(
              icon: Icons.share,
              label: 'Share',
              onPressed: () => shared = true,
            ),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(find.bySemanticsLabel('Share'), findsOneWidget);
    expect(find.text('First image'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Share'));
    expect(shared, isTrue);

    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Second image'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    expect(dismissed, isTrue);
  });

  testWidgets('double tap zoom disables paging until reset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UiMediaGallery(
          dismissLabel: 'Back',
          items: [
            UiMediaGalleryItem(
              builder: (_) => const ColoredBox(color: Color(0xFFFF0000)),
            ),
            UiMediaGalleryItem(
              builder: (_) => const ColoredBox(color: Color(0xFF00FF00)),
            ),
          ],
        ),
      ),
    );

    final center = tester.getCenter(find.byType(InteractiveViewer).first);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 100));

    final page = tester.widget<PageView>(find.byType(PageView));
    expect(page.physics, isA<NeverScrollableScrollPhysics>());
  });
}
