import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Global performance configuration that adapts to the device's native
/// refresh rate (60Hz, 90Hz, 120Hz, 144Hz, 165Hz+).
class PerformanceConfig {
  PerformanceConfig._();

  static int _targetFps = 60;
  static double _frameBudgetMs = 16.67;
  static bool _initialized = false;

  /// The device's detected maximum refresh rate in Hz.
  static int get targetFps => _targetFps;

  /// The ideal frame budget in milliseconds (1000 / targetFps).
  static double get frameBudgetMs => _frameBudgetMs;

  /// Whether initialization has completed.
  static bool get isInitialized => _initialized;

  /// Initialize by detecting the device refresh rate.
  /// Call this once during startup, before [runApp].
  static Future<void> initialize() async {
    try {
      // Flutter 3.x+: PlatformDispatcher exposes display refresh rate
      final displays = PlatformDispatcher.instance.displays;
      if (displays.isNotEmpty) {
        final maxHz = displays.map((d) => d.refreshRate).fold<double>(
          60.0,
          (prev, rate) => rate > prev ? rate : prev,
        );
        _targetFps = maxHz.round().clamp(30, 240);
        _frameBudgetMs = 1000.0 / _targetFps;
        debugPrint('[PerformanceConfig] Detected refresh rate: ${_targetFps}Hz'
            ' (budget: ${_frameBudgetMs.toStringAsFixed(2)}ms)');
      }
    } catch (e) {
      debugPrint('[PerformanceConfig] Refresh rate detection failed: $e — using 60Hz default');
      _targetFps = 60;
      _frameBudgetMs = 16.67;
    }

    _initialized = true;
  }

  /// Returns a duration suitable for one animation frame at the device's rate.
  static Duration get frameDuration =>
      Duration(microseconds: (1000000 / _targetFps).round());

  /// True if the device supports high refresh rate (>= 90Hz).
  static bool get isHighRefreshRate => _targetFps >= 90;

  /// True if the device supports 120Hz+.
  static bool get is120Hz => _targetFps >= 120;

  /// Clamps an animation duration to a minimum that stays within the
  /// frame budget while still looking smooth.
  static Duration clampAnimationDuration(Duration requested) {
    final minFrames = isHighRefreshRate ? 3 : 4;
    final minMs = minFrames * _frameBudgetMs;
    final requestedMs = requested.inMilliseconds.toDouble();
    return Duration(milliseconds: requestedMs.clamp(minMs, 3000).round());
  }
}
