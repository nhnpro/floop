
typedef PeriodicFunction = Function(Repeater);

/// A class for asynchronously calling a function with give frquency.
class Repeater extends Stopwatch {
  bool _stop = true;
  
  /// The function that will be called when method `start` is called on this repeater.
  /// The function gets called with this repeater as parameter.
  PeriodicFunction f;

  /// The frequency of the function calls when method `start` is called. A frequency can
  /// optionally be provided when calling the start method, so it's not necessary to set
  /// this value.
  int frequencyMilliseconds;

  /// 
  Repeater(this.f, [this.frequencyMilliseconds=50]);

  /// Stops the recurrent execution of `this.f`.
  stop() {
    super.stop();
    _stop = true;
  } 

  /// Stops and resets all values of this repeater to it's starting values. It makes a
  /// single call to `this.f` at the end.
  reset([bool callF=true]) {
    stop();
    super.reset();
    !callF ?? f(this);
  }

  /// Starts recurrent calls to `this.f` with the given `frequency`.
  /// Uses `this.frequencyMilliseconds` if no `frequency` is provided.
  start([int frequency]) {
    if(!_stop) {
      print('The Periodic was already running');
      return;
    }
    frequency = frequency ?? frequencyMilliseconds;
    _stop = false;
    super.start();
    run() {
      Future.delayed(
        Duration(milliseconds: frequency),
        () {
          if(_stop) {
            stop();
            return;
          }
          f(this);
          run();
        }
      );
    }
    run();
  }

  /// Utility function that returns the integer proportion of an [int] `number` in a cycle
  /// of length `periodMilliseconds` compared to this repeater's `elapsed` time.
  /// 
  /// For example if elapsed time is 23ms and period is 10ms, then the current cycle time is
  /// 3ms or 30% of the cycle run. If `number` is 100, the result would be 30 (30% of 100).
  int proportionInt(int number, int periodMilliseconds) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    var res = (number*current)~/periodMilliseconds;
    return res;
  }

  /// Returns the proportion of a [double] `number` in a cycle of length `periodMilliseconds`.
  /// 
  /// Floating point precision version of method `proportionInt`. See `proportionInt`
  /// doc for .
  double proportionDouble(double number, int periodMilliseconds) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    return number*current/periodMilliseconds;
  }
}
