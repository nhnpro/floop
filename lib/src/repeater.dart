typedef RepeaterCallback = void Function(Repeater);

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

  /// The periodicity of the function calls when method `start` is called.
  int periodicityMilliseconds;

  /// Maximum duration of the recurrent calls once this repeaters starts.
  int durationMilliseconds;

  Repeater(this.fn,
      {this.periodicityMilliseconds = 50, this.durationMilliseconds});

  /// Creates a repeater that transitions a number from 0 to 1 inclusive,
  /// passing it as parameter to the function `evaluate` as the transition
  /// progresses.
  ///
  /// The transition lasts `durationMillis` milliseconds and updates with a
  /// periodicity of `refreshPeriodicityMillis` milliseconds.
  ///
  /// The number starts transitioning after `delayMillis` milliseconds, but
  /// the recurrent calls to `evaluate` start immediately (passing 0 until
  /// `delayMillis` have elapsed).
  ///
  /// `onFinish` is a callback that gets invoked one time when the transition
  /// finishes, passing the created repeater instance as parameter.
  factory Repeater.transition(
      int durationMillis, evaluate(double elapsedToDurationRatio),
      {int refreshPeriodicityMillis = 20,
      int delayMillis = 0,
      RepeaterCallback onFinish}) {
    callback(Repeater repeater) {
      double ratio =
          ((repeater.elapsedMilliseconds - delayMillis) / durationMillis)
              .clamp(0, 1);
      evaluate(ratio);
      if (ratio == 1 && onFinish != null) {
        onFinish(repeater);
      }
    }

    return Repeater(callback,
        periodicityMilliseconds: refreshPeriodicityMillis,
        durationMilliseconds: durationMillis + delayMillis);
  }

  /// Stops this [Repeater].
  stop() {
    super.stop();
  }

  /// Whether the [Repeater] is currently running.
  bool get isRunning => super.isRunning;

  /// Resets this repeater's underlying stopwatch.
  ///
  /// If `callOnce` is true (default) a single call to `update` is made
  /// potentially reseting some values.
  reset([bool callOnce = true]) {
    super.reset();
    if (callOnce) {
      update();
    }
  }

  _stopAndReleaseLock() {
    stop();
    _executionLocked = false;
  }

  _startAndLock() {
    super.start();
    _executionLocked = true;
  }

  /// Whether an asynchronous periodic instance is executing.
  ///
  /// A lock is necessary to ensure at most once asynchronous instance
  /// is executing at any given time.
  bool get isLocked => _executionLocked;

  /// The function that gets recurrently invoked while the [Repeater] is
  /// running. It invokes `fn` with `this` as parameter.
  update() {
    fn(this);
  }

  /// Starts making recurrent invocations to [update] with
  /// `frequencyMilliseconds` for a duration of `durationMilliseconds` or
  /// indefinetely if null.
  start() {
    if (isLocked) {
      return;
    }
    assert(!isRunning);
    _startAndLock();
    assert(isRunning);
    _run();
  }

  _run() {
    Future.delayed(Duration(milliseconds: periodicityMilliseconds), () {
      assert(isLocked);
      if (super.isRunning) {
        if (durationMilliseconds != null &&
            elapsedMilliseconds >= durationMilliseconds) {
          _stopAndReleaseLock();
        } else {
          _run();
        }
        update();
      } else {
        _stopAndReleaseLock();
      }
    });
  }

  /// Integer version of [Repeater.periodicLinear].
  int periodicLinearInt(int periodMilliseconds, int maxNumber) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    var res = (maxNumber * current) ~/ periodMilliseconds;
    return res;
  }

  /// Returns the equivalent value of a linear periodic function (sawtooth
  /// wave) that goes from 0 (inclusive) to `maxNumber` (exclusive) with
  /// period `periodMilliseconds` running for this Repeater's elapsed time.
  ///
  /// For example if elapsed time is 18ms and period is 8ms, then the
  /// "current cycle time" is 2ms (25% of the cycle length). If `maxNumber`
  /// is 6, the return value would be 1.5 (0.25*6).
  double periodicLinear(int periodMilliseconds, [double maxNumber = 1]) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    return maxNumber * current / periodMilliseconds;
  }
}
