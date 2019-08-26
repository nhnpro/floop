import 'dart:math';

typedef RepeaterCallback = Function(Repeater);

/// A class for making asynchronous calls to a function with a certain frequency.
class Repeater extends Stopwatch {
  /// Stops the repeating execution.
  bool _stop = true;

  /// Used to ensure only one asynchrnous instance is executing.
  bool _executionLocked = false;

  /// The callback that gets recurrently called by this repeater.
  /// It gets called with this repeater as parameter.
  final RepeaterCallback callback;

  /// A convenient variable that can be used for storing arbitrary values.
  /// Useful for transmitting information between callbacks.
  dynamic storage;

  /// The frequency of the function calls when method `start` is called.
  int frequencyMilliseconds;

  /// Maximum duration of the recurrent calls once this repeaters starts.
  int durationMilliseconds;

  Repeater(this.callback,
      [this.frequencyMilliseconds = 50, this.durationMilliseconds]);

  /// Creates a repeater that transitions a number from 0 to 1 inclusive,
  /// passing it as parameter to the function `update` as the transition
  /// progresses.
  ///
  /// The transition lasts `durationMillis` milliseconds and updates with a
  /// frequency of `refreshRateMillis` milliseconds.
  ///
  /// The number starts transitioning after `delayMillis` milliseconds, but
  /// the recurrent calls to `update` start immediately (passing 0 until
  /// `delayMillis` have elapsed).
  ///
  /// `onFinish` is a convenient callback that gets invoked one time when the
  /// transition finishes with the created repeater instance as parameter.
  factory Repeater.transition(
      int durationMillis, update(double elapsedToDurationRatio),
      {int refreshRateMillis = 20,
      int delayMillis = 0,
      RepeaterCallback onFinish}) {
    callback(Repeater repeater) {
      double ratio = min(1,
          max(0, repeater.elapsedMilliseconds - delayMillis) / durationMillis);
      update(ratio);
      if (onFinish != null && ratio == 1) {
        onFinish(repeater);
      }
    }

    return Repeater(callback, refreshRateMillis, durationMillis + delayMillis);
  }

  /// Stops the repeater.
  stop() {
    super.stop();
    _stop = true;
  }

  /// Resets this repeater's underlying stopwatch.
  ///
  /// If `callOnce` is true (default) a single call to `callback` is made
  /// potentially reseting some values that the callback is setting.
  reset([bool callOnce = true]) {
    super.reset();
    print(
        'elapsed: $elapsedMilliseconds duration: $durationMilliseconds - stop=$_stop');
    if (callOnce) {
      callback(this);
    }
  }

  _releaseLock() => _executionLocked = false;

  _lock() => _executionLocked = true;

  bool get isLocked => _executionLocked;

  /// Starts making recurrent calls to `this.callback` with
  /// `frequencyMilliseconds` for a duration of `durationMilliseconds`
  /// or indefinetely if `durationMilliseconds` is null.
  start() {
    if (!_stop) {
      print('The repeater is already running');
      return;
    } else if (isLocked) {
      print('Another asynchronous instance is already running');
      return;
    }
    _stop = false;
    _lock();
    super.start();
    run() {
      Future.delayed(Duration(milliseconds: frequencyMilliseconds), () {
        if (!_stop) {
          if (durationMilliseconds == null ||
              elapsedMilliseconds < durationMilliseconds) {
            callback(this);
            run();
          } else {
            stop();
            // Make one last call
            callback(this);
          }
        }
        if (_stop) {
          _releaseLock();
        }
      });
    }

    run();
  }

  /// Returns the equivalent value of a linear periodic function that goes
  /// from 0 (inclusive) to `maxNumber` (exclusive) with period
  /// `periodMilliseconds` running for `this.elapsed.inMilliseconds`.
  ///
  /// Integer version of `[Repeater.periodicInt]`.
  int periodicLinearInt(int periodMilliseconds, int maxNumber) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    var res = (maxNumber * current) ~/ periodMilliseconds;
    return res;
  }

  /// Returns the equivalent value of a linear periodic function that goes
  /// from 0 (inclusive) to `maxNumber` (exclusive) with period
  /// `periodMilliseconds` running for `this.elapsed.inMilliseconds`.
  ///
  /// For example if elapsed time is 23ms and period is 10ms, then the
  /// "current cycle time" is 3ms (30% of the cycle run). If `maxNumber`
  /// is 6, the return value would be 1.8 (30% of 6).
  double periodicLinear(int periodMilliseconds, [double maxNumber = 1]) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    return maxNumber * current / periodMilliseconds;
  }
}
