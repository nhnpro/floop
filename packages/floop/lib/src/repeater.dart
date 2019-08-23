import 'dart:math';

typedef RepeaterCallback = Function(Repeater);

/// A class for making asynchronous calls to a function with a certain frequency.
class Repeater extends Stopwatch {
  /// Stops the repeating execution.
  bool _stop = true;

  /// Used to ensure only one asynchrnous repeating call in ongoing on this repeater.
  bool _executionLocked = false;

  /// The callback that gets recurrently called by this repeater.
  /// I gets called with this repeater as parameter.
  final RepeaterCallback callback;

  /// A convenient variable that can be used for storing arbitrary values.
  /// Useful for transmitting information between callbacks.
  dynamic storage;

  /// The frequency of the function calls when method `start` is called.
  ///
  /// If the optional `frequencyMillis` is provided when calling the start method
  /// this value is not used.
  int frequencyMilliseconds;

  Repeater(this.callback, [this.frequencyMilliseconds = 50]);

  /// Stops the recurrent executions to `callback`.
  stop() {
    super.stop();
    _stop = true;
  }

  /// Stops and resets all values of this repeater to it's starting values.
  /// It makes a single call to `callback` at the end if `callOnce` is true
  /// (defaults to true).
  reset([bool callOnce = true]) {
    stop();
    super.reset();
    if (callOnce) {
      callback(this);
    }
  }

  /// Starts making recurrent calls to `this.callback` with
  /// `this.frequencyMilliseconds` for a duration of `durationMilliseconds`
  /// or indefinetely if `durationMilliseconds` is not specified.
  start([int durationMilliseconds]) {
    if (!_stop) {
      print('The repeater is already running');
      return;
    } else if (_executionLocked) {
      print('Another asynchronous instance is already running');
      return;
    }
    _stop = false;
    _executionLocked = true;
    // frequencyMillis ??= frequencyMilliseconds;
    super.start();
    run() {
      Future.delayed(Duration(milliseconds: frequencyMilliseconds), () {
        if (_stop) {
          _executionLocked = false;
        } else {
          callback(this);
          if (durationMilliseconds == null ||
              elapsedMilliseconds < durationMilliseconds) {
            run();
          }
        }
      });
    }

    run();
  }

  /// Utility function that returns an integer between 0 inclusive and `maxNumber` exclusive
  /// corresponding to the proportional position in a cycle of `periodMilliseconds` in current
  /// `elapsed` time.
  ///
  /// For example if elapsed time is 23ms and period is 10ms, then the current cycle time is
  /// 3ms or 30% of the cycle run. If `number` is 100, the result would be 30 (30% of 100).
  int proportionInt(int maxNumber, int periodMilliseconds) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    var res = (maxNumber * current) ~/ periodMilliseconds;
    return res;
  }

  /// Returns the proportion of a [double] `number` in a cycle of length `periodMilliseconds`
  /// running for `this.elapsed.inMilliseconds`.
  ///
  /// Floating point precision version of method `[Repeater.proportionInt]`.
  double proportionDouble(double number, int periodMilliseconds) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    return number * current / periodMilliseconds;
  }
}
