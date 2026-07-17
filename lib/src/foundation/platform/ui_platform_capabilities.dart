import 'dart:async';

import 'package:flutter/services.dart';

enum UiWindowMode {
  fullscreen,
  windowed,
  unknown,
  notApplicable;

  static UiWindowMode fromWire(String? value) {
    return switch (value) {
      'fullscreen' => UiWindowMode.fullscreen,
      'windowed' => UiWindowMode.windowed,
      'notApplicable' => UiWindowMode.notApplicable,
      _ => UiWindowMode.unknown,
    };
  }

  bool get isWindowed => this == UiWindowMode.windowed;
}

class UiPlatformWindowMetrics {
  const UiPlatformWindowMetrics({
    required this.windowSize,
    required this.screenSize,
    required this.supportsWindowing,
  });

  final Size? windowSize;
  final Size? screenSize;
  final bool supportsWindowing;

  factory UiPlatformWindowMetrics.fromJson(Object? value) {
    final json = _asMap(value);
    return UiPlatformWindowMetrics(
      windowSize: _sizeFromJson(json['windowSize']),
      screenSize: _sizeFromJson(json['screenSize']),
      supportsWindowing: json['supportsWindowing'] == true,
    );
  }
}

class UiPlatformSnapshot {
  const UiPlatformSnapshot({
    required this.os,
    required this.windowMode,
    required this.window,
    this.raw = const <String, Object?>{},
  });

  final String os;
  final UiWindowMode windowMode;
  final UiPlatformWindowMetrics window;
  final Map<String, Object?> raw;

  bool get isWindowed => windowMode.isWindowed;

  factory UiPlatformSnapshot.fromJson(Object? value) {
    final json = _asMap(value);
    final window = _asMap(json['window']);
    return UiPlatformSnapshot(
      os: json['os']?.toString() ?? 'unknown',
      windowMode: UiWindowMode.fromWire(window['mode']?.toString()),
      window: UiPlatformWindowMetrics.fromJson(window),
      raw: Map<String, Object?>.from(json),
    );
  }
}

class UiPlatformCapabilities {
  UiPlatformCapabilities({
    MethodChannel? channel,
    Duration cacheDuration = const Duration(milliseconds: 250),
  })  : _channel = channel ?? const MethodChannel(channelName),
        _cacheDuration = cacheDuration;

  static const channelName = 'dev.open_ui_kit/platform_capabilities';
  static final shared = UiPlatformCapabilities();

  final MethodChannel _channel;
  final Duration _cacheDuration;

  UiPlatformSnapshot? _cachedSnapshot;
  DateTime? _cachedSnapshotAt;
  Future<UiPlatformSnapshot>? _snapshotInFlight;

  UiWindowMode? _cachedWindowMode;
  DateTime? _cachedWindowModeAt;
  Future<UiWindowMode>? _windowModeInFlight;
  bool _handlesPlatformCalls = false;
  final StreamController<UiWindowMode> _windowModeChanges =
      StreamController<UiWindowMode>.broadcast(sync: true);

  /// Native window-mode transitions, including position-only scene moves that
  /// do not change Flutter's viewport metrics.
  Stream<UiWindowMode> get windowModeChanges {
    if (!_handlesPlatformCalls) {
      _channel.setMethodCallHandler(_handlePlatformCall);
      _handlesPlatformCalls = true;
    }
    return _windowModeChanges.stream;
  }

  void invalidateCache() {
    _cachedSnapshot = null;
    _cachedSnapshotAt = null;
    _cachedWindowMode = null;
    _cachedWindowModeAt = null;
  }

  Future<UiPlatformSnapshot> snapshot({bool forceRefresh = false}) {
    if (!forceRefresh && _isFresh(_cachedSnapshotAt)) {
      final cached = _cachedSnapshot;
      if (cached != null) return Future.value(cached);
    }

    final inFlight = _snapshotInFlight;
    if (!forceRefresh && inFlight != null) return inFlight;

    final request = _loadSnapshot();
    _snapshotInFlight = request;
    return request.whenComplete(() {
      if (identical(_snapshotInFlight, request)) {
        _snapshotInFlight = null;
      }
    });
  }

  Future<UiPlatformSnapshot> _loadSnapshot() async {
    final response = await _channel.invokeMethod<Object?>(
      'getPlatformSnapshot',
    );
    final snapshot = UiPlatformSnapshot.fromJson(response);
    final now = DateTime.now();
    _cachedSnapshot = snapshot;
    _cachedSnapshotAt = now;
    _cachedWindowMode = snapshot.windowMode;
    _cachedWindowModeAt = now;
    return snapshot;
  }

  Future<UiWindowMode> currentWindowMode({bool forceRefresh = false}) {
    if (!forceRefresh) {
      final snapshot = _cachedSnapshot;
      if (snapshot != null && _isFresh(_cachedSnapshotAt)) {
        return Future.value(snapshot.windowMode);
      }

      final cached = _cachedWindowMode;
      if (cached != null && _isFresh(_cachedWindowModeAt)) {
        return Future.value(cached);
      }

      final inFlight = _windowModeInFlight;
      if (inFlight != null) return inFlight;
    }

    final request = _loadWindowMode();
    _windowModeInFlight = request;
    return request.whenComplete(() {
      if (identical(_windowModeInFlight, request)) {
        _windowModeInFlight = null;
      }
    });
  }

  Future<UiWindowMode> _loadWindowMode() async {
    final response = await _channel.invokeMethod<Object?>('getWindowMode');
    final mode = response is String
        ? UiWindowMode.fromWire(response)
        : UiWindowMode.fromWire(_asMap(response)['mode']?.toString());
    _cacheWindowMode(mode);
    return mode;
  }

  Future<Object?> _handlePlatformCall(MethodCall call) async {
    if (call.method != 'windowModeChanged') {
      throw MissingPluginException(
          'Unsupported platform callback: ${call.method}');
    }

    final mode = call.arguments is String
        ? UiWindowMode.fromWire(call.arguments as String)
        : UiWindowMode.fromWire(
            _asMap(call.arguments)['mode']?.toString(),
          );
    final previousMode = _cachedWindowMode;
    _cacheWindowMode(mode);

    if (mode != previousMode) {
      _windowModeChanges.add(mode);
    }
    return null;
  }

  void _cacheWindowMode(UiWindowMode mode) {
    if (_cachedSnapshot?.windowMode != mode) {
      _cachedSnapshot = null;
      _cachedSnapshotAt = null;
    }
    _cachedWindowMode = mode;
    _cachedWindowModeAt = DateTime.now();
  }

  Future<T?> invokeFeature<T>(
    String feature, {
    Map<String, Object?> arguments = const <String, Object?>{},
  }) {
    return _channel.invokeMethod<T>('invokeFeature', <String, Object?>{
      'feature': feature,
      'arguments': arguments,
    });
  }

  bool _isFresh(DateTime? timestamp) {
    if (timestamp == null || _cacheDuration <= Duration.zero) return false;
    return DateTime.now().difference(timestamp) <= _cacheDuration;
  }
}

Map<Object?, Object?> _asMap(Object? value) {
  if (value is Map<Object?, Object?>) return value;
  if (value is Map) return Map<Object?, Object?>.from(value);
  return const <Object?, Object?>{};
}

Size? _sizeFromJson(Object? value) {
  final json = _asMap(value);
  final width = _asDouble(json['width']);
  final height = _asDouble(json['height']);
  if (width == null || height == null) return null;
  return Size(width, height);
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
