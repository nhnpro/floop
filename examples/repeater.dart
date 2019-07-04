
typedef PeriodicFunction = Function(Repeater);

/// A class for asynchronously calling a function with give frquency.
class Repeater extends Stopwatch {
  /// Stops the repeating execution.
  bool _stop = true;
  
  /// Used to ensure only one asynchrnous repeating call in ongoing on this repeater.
  bool _executionLock = false;

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
    if(!_stop || _executionLock) {
      print('The Periodic was already running');
      return;
    }
    _stop = false;
    _executionLock = true;
    frequency = frequency ?? frequencyMilliseconds;
    super.start();
    run() {
      Future.delayed(
        Duration(milliseconds: frequency),
        () {
          if(_stop) {
            _executionLock = false;
            return;
          }
          f(this);
          run();
        }
      );
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
    var res = (maxNumber*current)~/periodMilliseconds;
    return res;
  }

  /// Returns the proportion of a [double] `number` in a cycle of length `periodMilliseconds`
  /// running for `this.elapsed.inMilliseconds`.
  /// 
  /// Floating point precision version of method `proportionInt`. See `proportionInt` for example.
  double proportionDouble(double number, int periodMilliseconds) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    return number*current/periodMilliseconds;
  }
}
