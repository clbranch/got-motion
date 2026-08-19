import 'dart:async';

/// Signals when startup work behind the splash screen has finished, so the
/// splash can hand off to the app instead of guessing at a duration.
class AppBoot {
  const AppBoot._();

  /// Startup should never strand the user on the splash, so callers pair this
  /// with a timeout.
  static const Duration timeout = Duration(seconds: 6);

  static Completer<void> _completer = Completer<void>();

  static Future<void> whenReady() =>
      _completer.future.timeout(timeout, onTimeout: () {});

  static void markReady() {
    if (!_completer.isCompleted) _completer.complete();
  }

  static bool get isReady => _completer.isCompleted;

  /// Test hook: lets a fresh boot be simulated.
  static void reset() => _completer = Completer<void>();
}
