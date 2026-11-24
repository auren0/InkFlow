import 'dart:async';

/// Runs an action once after [delay] without activity.
///
/// Every new call to [schedule] restarts the countdown, which is exactly what
/// an auto-save triggered by continuous typing needs.
class Debouncer {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _timer;

  bool get isActive => _timer?.isActive ?? false;

  void schedule(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
