import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/foundation.dart';

void main() {
  test('migration scales resolve familiar shade numbers', () {
    expect(UiTailwindPalette.blue[500], UiTailwindPalette.blue.s500);
    expect(UiShadcnPalette.zinc, same(UiTailwindPalette.zinc));
    expect(() => UiTailwindPalette.blue[42], throwsArgumentError);
  });

  test('well-known palette anchors remain available', () {
    expect(UiBootstrapPalette.blue.toARGB32(), 0xFF0D6EFD);
    expect(UiAntPalette.blue.toARGB32(), 0xFF1677FF);
    expect(UiRadixPalette.blue.toARGB32(), 0xFF0090FF);
  });
}
