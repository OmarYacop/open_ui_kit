import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(UiPlatformCapabilities.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final client = UiPlatformCapabilities(channel: channel);

  setUp(client.invalidateCache);

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    client.invalidateCache();
  });

  test('parses the platform snapshot envelope', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getPlatformSnapshot');
      return <String, Object?>{
        'os': 'ios',
        'window': <String, Object?>{
          'mode': 'windowed',
          'supportsWindowing': true,
          'windowSize': <String, Object?>{'width': 820, 'height': 1080},
          'screenSize': <String, Object?>{'width': 1024, 'height': 1366},
        },
      };
    });

    final snapshot = await client.snapshot();

    expect(snapshot.os, 'ios');
    expect(snapshot.windowMode, UiWindowMode.windowed);
    expect(snapshot.isWindowed, isTrue);
    expect(snapshot.window.supportsWindowing, isTrue);
    expect(snapshot.window.windowSize?.width, 820);
    expect(snapshot.window.screenSize?.height, 1366);
  });

  test('parses currentWindowMode from both wire shapes', () async {
    var returnMap = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getWindowMode');
      if (returnMap) return <String, Object?>{'mode': 'fullscreen'};
      return 'windowed';
    });

    expect(await client.currentWindowMode(), UiWindowMode.windowed);

    returnMap = true;
    expect(
      await client.currentWindowMode(forceRefresh: true),
      UiWindowMode.fullscreen,
    );
  });

  test('coalesces snapshot calls and reuses fresh platform state', () async {
    var callCount = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getPlatformSnapshot');
      callCount += 1;
      await Future<void>.delayed(Duration.zero);
      return <String, Object?>{
        'os': 'android',
        'window': <String, Object?>{
          'mode': 'fullscreen',
          'supportsWindowing': true,
        },
      };
    });

    final snapshots = await Future.wait([
      client.snapshot(),
      client.snapshot(),
      client.snapshot(),
    ]);

    expect(callCount, 1);
    expect(
      snapshots.map((snapshot) => snapshot.windowMode),
      everyElement(UiWindowMode.fullscreen),
    );

    expect(await client.currentWindowMode(), UiWindowMode.fullscreen);
    expect(callCount, 1);

    client.invalidateCache();
    await client.snapshot();
    expect(callCount, 2);
  });

  test('invokes dynamic platform features', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'invokeFeature');
      expect(call.arguments, <String, Object?>{
        'feature': 'window.mode',
        'arguments': <String, Object?>{},
      });
      return <String, Object?>{'mode': 'notApplicable'};
    });

    final response = await client.invokeFeature<Map<Object?, Object?>>(
      'window.mode',
    );

    expect(response?['mode'], 'notApplicable');
  });

  test('publishes native window-mode transitions and refreshes the cache',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getPlatformSnapshot');
      return <String, Object?>{
        'os': 'ios',
        'window': <String, Object?>{
          'mode': 'fullscreen',
          'supportsWindowing': true,
        },
      };
    });
    expect((await client.snapshot()).windowMode, UiWindowMode.fullscreen);

    final modes = <UiWindowMode>[];
    final subscription = client.windowModeChanges.listen(modes.add);
    addTearDown(subscription.cancel);

    Future<void> pushMode(String mode) {
      return messenger.handlePlatformMessage(
        UiPlatformCapabilities.channelName,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('windowModeChanged', <String, Object?>{'mode': mode}),
        ),
        (_) {},
      );
    }

    await pushMode('windowed');
    await pushMode('windowed');

    expect(modes, <UiWindowMode>[UiWindowMode.windowed]);
    expect(await client.currentWindowMode(), UiWindowMode.windowed);

    await pushMode('fullscreen');
    expect(
      modes,
      <UiWindowMode>[UiWindowMode.windowed, UiWindowMode.fullscreen],
    );
  });
}
