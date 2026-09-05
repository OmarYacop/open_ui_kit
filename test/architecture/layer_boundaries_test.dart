import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source dependencies respect the documented layer direction', () {
    final root = Directory.current.uri;
    const ranks = {'foundation': 0, 'components': 1, 'patterns': 2};
    const appExceptions = {
      'lib/src/patterns/navigation/ui_navigation_transition.dart',
      'lib/src/patterns/navigation/ui_navigator_history.dart',
      'lib/src/patterns/navigation/ui_page_route.dart',
    };
    final violations = <String>[];
    final directives = RegExp(
      r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    for (final file
        in Directory('lib/src')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final source = file.absolute.uri.path.substring(root.path.length);
      final layer = source.split('/')[2];
      final code = file.readAsStringSync().replaceAll(
        RegExp(r'/\*[\s\S]*?\*/'),
        '',
      );
      for (final match in directives.allMatches(code)) {
        final import = match[1]!;
        if (import == 'package:flutter/material.dart' ||
            import == 'package:flutter/cupertino.dart') {
          violations.add('$source imports $import');
        }
        if (import.startsWith('dart:') ||
            (import.startsWith('package:') &&
                !import.startsWith('package:open_ui_kit/'))) {
          continue;
        }
        final targetUri = import.startsWith('package:open_ui_kit/')
            ? root.resolve(
                'lib/${import.substring('package:open_ui_kit/'.length)}',
              )
            : file.absolute.uri.resolve(import);
        final target = targetUri.path.substring(root.path.length);
        if (source == 'lib/src/foundation/ui_app.dart' &&
            appExceptions.contains(target)) {
          continue;
        }
        final parts = target.split('/');
        if (parts.length < 4 || parts[1] != 'src') {
          violations.add('$source imports a public barrel: $target');
          continue;
        }
        if (ranks[parts[2]]! > ranks[layer]!) {
          violations.add('$source depends upward on $target');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'See ADR 0001. Keep exceptions narrow and explicit.',
    );
  });
}
