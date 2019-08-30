import 'dart:math';

import 'package:floop/src/flutter_import.dart';

typedef RepeaterCallback = Function(Repeater);

/// A class for making asynchronous calls to a function with a certain frequency.
class Repeater extends Stopwatch {
  /// Used to ensure only one asynchronous instance is executing.
  bool _executionLocked = false;

  /// The function that gets recurrently called by the [Repeater].
  /// It gets called with `this` as parameter.
  final RepeaterCallback fn;

  /// A convenient variable that can be used for storing arbitrary values.
  /// Useful for transmitting information between callbacks.
  dynamic storage;

  /// The frequency of the function calls when method `start` is called.
  int frequencyMilliseconds;

  /// Maximum duration of the recurrent calls once this repeaters starts.
  int durationMilliseconds;

  Repeater(this.fn,
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
  /// `onFinish` is a callback that gets invoked one time when the transition
  /// finishes, passing the created repeater instance as parameter.
  factory Repeater.transition(
      int durationMillis, update(double elapsedToDurationRatio),
      {int refreshRateMillis = 20,
      int delayMillis = 0,
      RepeaterCallback onFinish}) {
    callback(Repeater repeater) {
      double ratio = min(1,
          max(0, repeater.elapsedMilliseconds - delayMillis) / durationMillis);
      update(ratio);
      if (ratio == 1 && onFinish != null) {
        onFinish(repeater);
      }
    }

    return Repeater(callback, refreshRateMillis, durationMillis + delayMillis);
  }

  /// Stops the [Repeater].
  stop() {
    super.stop();
  }

  /// Whether the [Repeater] is currently running.
  bool get isRunning => super.isRunning;

  /// Resets this repeater's underlying stopwatch.
  ///
  /// If `callOnce` is true (default) a single call to `callback` is made
  /// potentially reseting some values that the callback is setting.
  reset([bool callOnce = true]) {
    super.reset();
    if (callOnce) {
      fn(this);
    }
  }

  _releaseLock() => _executionLocked = false;

  _lock() => _executionLocked = true;

  /// Whether an asynchronous periodic instance is executing.
  ///
  /// A lock is necessary to ensure at most once asynchronous instance
  /// is executing at any given time.
  bool get isLocked => _executionLocked;

  /// The function that gets recurrently invoked while the [Repeater] is running.
  update() {
    fn(this);
  }

  /// Starts making recurrent calls to `this.fn` by invoking [update] with
  /// `frequencyMilliseconds` for a duration of `durationMilliseconds` or
  /// indefinetely if null.
  start() {
    if (isLocked) {
      print('The repeater asynchronous instance is already running');
      return;
    }
    assert(!isRunning);
    _lock();
    super.start();
    assert(isRunning);
    _run();
  }

  _run() {
    Future.delayed(Duration(milliseconds: frequencyMilliseconds), () {
      if (super.isRunning) {
        if (durationMilliseconds == null ||
            elapsedMilliseconds < durationMilliseconds) {
          update();
          _run();
        } else {
          stop();
          // Invoke callback for the last time once finished.
          update();
        }
      } else {
        _releaseLock();
      }
    });
  }

  /// Returns the equivalent value of a linear periodic function (sawtooth wave)
  /// that goes from 0 (inclusive) to `maxNumber` (exclusive) with period
  /// `periodMilliseconds` running for this [Repeater] elapsed time.
  ///
  /// Integer version of `[Repeater.periodicInt]`.
  int periodicLinearInt(int periodMilliseconds, int maxNumber) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    var res = (maxNumber * current) ~/ periodMilliseconds;
    return res;
  }

  /// Returns the equivalent value of a linear periodic function (sawtooth wave)
  /// that goes from 0 (inclusive) to `maxNumber` (exclusive) with period
  /// `periodMilliseconds` running for this [Repeater] elapsed time.
  ///
  /// For example if elapsed time is 23ms and period is 10ms, then the
  /// "current cycle time" is 3ms (30% of the cycle run). If `maxNumber`
  /// is 6, the return value would be 1.8 (30% of 6).
  double periodicLinear(int periodMilliseconds, [double maxNumber = 1]) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    return maxNumber * current / periodMilliseconds;
  }
}
