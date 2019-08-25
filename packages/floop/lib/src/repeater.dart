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
  /// from [0, `maxNumber`) with period `periodMilliseconds` that has been
  /// running for `this.elapsed.inMilliseconds`.
  ///
  /// For example if elapsed time is 23ms and period is 10ms, then the
  /// "current cycle time" is 3ms or 30% of the cycle run. If `maxNumber` is
  /// 100, the return value would be 30 (30% of 100).
  int periodicInt(int periodMilliseconds, int maxNumber) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    var res = (maxNumber * current) ~/ periodMilliseconds;
    return res;
  }

  /// Returns the equivalent value of a linear periodic function that goes
  /// from [0, `maxNumber`) with period `periodMilliseconds` that has been
  /// running for `this.elapsed.inMilliseconds`.
  ///
  /// Floating point precision version of method `[Repeater.periodicInt]`.
  double periodic(int periodMilliseconds, [double scale = 1]) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    return scale * current / periodMilliseconds;
  }
}
