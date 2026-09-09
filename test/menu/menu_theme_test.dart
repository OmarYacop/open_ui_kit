import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';
import 'package:open_ui_kit/src/components/menu/ui_fluid_menu_button.dart'
    as legacy;
import 'package:open_ui_kit/src/components/menu/ui_fluid_menu_stack.dart'
    as legacy;
import 'package:open_ui_kit/src/components/menu/ui_fluid_menu_transition.dart'
    as legacy;

void main() {
  testWidgets('an open menu updates its local theme and items safely', (
    tester,
  ) async {
    late StateSetter update;
    var dark = false;
    var label = 'Before';
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return UiTheme(
              tokens: dark ? UiThemeData.dark() : UiThemeData.light(),
              child: Center(
                child: UiDropdownMenu(
                  trigger: const Text('Open'),
                  items: [UiMenuItem(label: label)],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tapAt(tester.getCenter(find.text('Open')));
    await tester.pumpAndSettle();
    update(() {
      dark = true;
      label = 'After';
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Before'), findsNothing);
    expect(find.text('After').hitTestable(), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('After')).style!.color,
      UiThemeData.dark().colors.textPrimary,
    );
  });
  for (final dark in [false, true]) {
    testWidgets(
      'menu icons match normal, destructive and disabled labels ($dark)',
      (tester) async {
        final tokens = dark ? UiThemeData.dark() : UiThemeData.light();
        await tester.pumpWidget(
          MaterialApp(
            home: UiTheme(
              tokens: tokens,
              child: Center(
                child: UiDropdownMenu(
                  trigger: const Text('Open'),
                  items: [
                    UiMenuItem(
                      label: 'Normal',
                      leading: const Icon(Icons.edit, key: ValueKey('normal')),
                      onPressed: () {},
                    ),
                    UiMenuItem(
                      label: 'Delete',
                      destructive: true,
                      leading: const Icon(
                        Icons.delete,
                        key: ValueKey('danger'),
                      ),
                      onPressed: () {},
                    ),
                    const UiMenuItem(
                      label: 'Disabled',
                      enabled: false,
                      leading: Icon(Icons.archive, key: ValueKey('disabled')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tapAt(tester.getCenter(find.text('Open')));
        await tester.pumpAndSettle();
        for (final entry in {
          'normal': ('Normal', tokens.colors.textPrimary),
          'danger': ('Delete', tokens.colors.danger),
          'disabled': ('Disabled', tokens.colors.textMuted),
        }.entries) {
          expect(
            IconTheme.of(tester.element(find.byKey(ValueKey(entry.key)))).color,
            entry.value.$2,
          );
          expect(
            tester.widget<Text>(find.text(entry.value.$1)).style!.color,
            entry.value.$2,
          );
        }
      },
    );
  }

  testWidgets('anchor captures local menu tokens and effects budget', (
    tester,
  ) async {
    const menu = UiMenuTokens(
      surfaceOpacity: .7,
      borderWidth: 2,
      borderOpacity: .3,
      backdropBlurSigma: 22,
      maxHeight: 310,
    );
    final theme = UiThemeData.dark(menu: menu)
        .copyWith(effects: UiEffectsTokens.reduced);
    await tester.pumpWidget(
      MaterialApp(
        home: UiTheme(
          tokens: theme,
          child: const Center(
            child: UiDropdownMenu(
              trigger: Text('Open'),
              items: [UiMenuItem(label: 'Action')],
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(tester.getCenter(find.text('Open')));
    await tester.pumpAndSettle();
    final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
    expect(morph.border.width, 2);
    expect(morph.border.color.a, closeTo(.3, .001));
    expect(morph.color.a, closeTo(.7, .001));
    expect(morph.backdropBlurSigma, 22);
    expect(
      tester
          .widgetList<BackdropFilter>(find.byType(BackdropFilter))
          .every((filter) => !filter.enabled),
      isTrue,
    );
  });

  test('menu tokens participate in theme copying and interpolation', () {
    final a = UiThemeData.light();
    final b = a.copyWith(
      menu: a.menu.copyWith(
        surfaceOpacity: .4,
        closeDuration: const Duration(milliseconds: 400),
      ),
    );
    final middle = a.lerp(b, .5);
    expect(
      middle.menu.surfaceOpacity,
      closeTo((a.menu.surfaceOpacity + .4) / 2, .001),
    );
    expect(middle.menu.closeDuration, const Duration(milliseconds: 340));
    expect(a == b, isFalse);
    expect(a.copyWith(), a);
  });

  testWidgets('legacy import paths delegate to canonical menu types', (
    tester,
  ) async {
    const button = legacy.UiFluidMenuButton(
      title: 'Actions',
      trigger: Text('Open'),
      items: [UiMenuItem(label: 'Action')],
    );
    const legacy.UiFluidMenuStack stack = UiMenuStack(
      title: 'Actions',
      items: [],
    );
    expect(stack, isA<UiMenuStack>());
    final legacy.UiFluidMenuGestureController controller =
        UiMenuGestureController();
    expect(controller, isA<UiMenuGestureController>());
    expect(legacy.UiFluidMenuTransition, UiMenuTransition);
    expect(button.title, 'Actions');
    expect(button.backLabel, 'Back');
    expect(button.minWidth, button.width);
    await tester.pumpWidget(MaterialApp(home: Center(child: button)));
    await tester.tapAt(tester.getCenter(find.text('Open')));
    await tester.pumpAndSettle();
    expect(find.byType(UiMenuStack), findsOneWidget);
    expect(find.text('Action').hitTestable(), findsOneWidget);
  });
}
