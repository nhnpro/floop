import 'dart:math';

import 'package:floop/src/controller.dart';
import 'package:flutter/material.dart';

import '../floop.dart';

int _lastId = 0;

Map<BuildContext, Map<int, int>> _contextIds = Map();
ObservedMap<int, double> _idToFraction = ObservedMap.of({-1: 1});
Map<int, Repeater> _idToRepeater = Map();

typedef TransitionValueCalculator<V> = V Function(
    double elapsedToDurationRatio);

typedef TransitionCallback = Function(double elapsedToDurationRatio);

double transition(int durationMillis,
    {int refreshRateMillis = 20, TransitionCallback callback}) {
  double result = 1;
  int id;
  bool shouldCreateTransition = true;
  Map<int, int> durationToId;

  BuildContext context = floopController.currentBuild;
  if (context != null) {
    bool firstBuild = true;
    // If the context has a child, it means it was built at least once.
    // If the context was built at least once, a new transition will not
    // be created.
    context.visitChildElements((_) => firstBuild = false);
    durationToId = _contextIds[context];
    if (firstBuild) {
      // Creates a duration to id map for context if it is the first build.
      durationToId = Map();
      _contextIds[context] = durationToId;
    } else if (durationToId != null) {
      id = _contextIds[context][durationMillis];
    }
    shouldCreateTransition = firstBuild;
  }

  _cleanMaps(id) {
    // Cleans maps when the transition finishes.
    _idToFraction.remove(id, false);
    if (durationToId != null) {
      durationToId.remove(durationMillis);
      if (durationToId.isEmpty) {
        _contextIds.remove(context);
      }
    }
  }

  if (shouldCreateTransition) {
    id = _startTransition(
        durationMillis,
        callback ??
            (double fraction) {
              // Default callback that sets the value of an ObservedMap.
              // This will cause a Elements to rebuild when the value
              // changes if a Floop Widget is currently building.
              _idToFraction[id] = fraction;
              if (fraction >= 1) {
                _cleanMaps(id);
              }
            },
        refreshRateMillis: refreshRateMillis);
    assert(id != null);
    _idToFraction.setValue(id, 0, false);
    if (durationToId != null) {
      durationToId[durationMillis] = id;
    }
  }
  if (id != null) {
    result = _idToFraction[id] ?? 1;
  }
  return result;
}

int _startTransition(int durationMillis, TransitionCallback callback,
    {int refreshRateMillis}) {
  int id = _lastId++;

  updater(Repeater repeater) {
    double fraction = min(1, repeater.elapsedMilliseconds / durationMillis);
    callback(fraction);
    if (fraction == 1) {
      // stops the Repeater and cleans any reference to it
      repeater.stop();
      _idToRepeater.remove(id);
    }
  }

  _idToRepeater[id] = Repeater(updater, refreshRateMillis)..start();
  return id;
}

num transitionNum(num start, num end, int durationMillis,
    [refreshRateMillis = 20]) {
  num elapsedRatio =
      transition(durationMillis, refreshRateMillis: refreshRateMillis);
  return start + (end - start) * elapsedRatio;
}

/// Transitions the `map[key]` value using `calculateValue` on each update.
///
/// `calculateValue` receives as parameter a number between 0 and 1 that
/// is the ratio between the transition's running time and the transition's
/// duration.
transitionKeyValue<V>(Map<dynamic, V> map, key,
    TransitionValueCalculator<V> calculateValue, int durationMillis,
    {int refreshRateMillis = 20}) {
  return _startTransition(durationMillis, (double fraction) {
    map[key] = calculateValue(fraction);
  }, refreshRateMillis: refreshRateMillis);
}

// Object _transitionHash(Object start, Object end, Object context) {
//   start.hashCode + end.hashCode + context.hashCode;
//   return MultiHash();
// }

// num _proportionalValue(num start, num end, num fraction) {
//   return start+(end-start)*fraction;
// }

// num transitionNum(num start, num end, Object context, {
//   int durationMillis, int refreshRateMillis=20
//   }) {
//   final hash = _transitionHash(start, end, context);
//   // var id = multiHashToId[hash];
//   // if (id!=null) {
//   //   return ongoingTransitions[id].currentValue;
//   // }
//   var transition = ongoingTransitions[hash];
//   if (transition!=null) {
//     return ongoingTransitions[hash].currentValue;
//   }

//   transition = _transition<num>(
//     observedMap, hash, startValue, endValue, durationMillis, refreshRateMillis);
//   return startValue;
// }

// Transition _createTransitionFunction<V>(V start, V end) {

//   return Transition();
// }

// V transition<V>(Map map, Object key, V startValue, V endValue, StatelessElementFloop context, {
//   int durationMillis, int refreshRateMillis=20
//   }) {
//   final hash = _transitionHash(startValue, endValue, context);
//   // var id = multiHashToId[hash];
//   // if (id!=null) {
//   //   return ongoingTransitions[id].currentValue;
//   // }
//   var transition = ongoingTransitions[hash];
//   if (transition!=null) {
//     return ongoingTransitions[hash].currentValue;
//   }
//   transition = createTransition<V>(startValue, endValue, durationMillis, refreshRateMillis);
//   return startValue;
//   // if(!context.firstBuild) return; TODO
// }

// void transitionOnMount<V>(Map map, Object key, V startValue, V endValue, StatelessElementFloop context, {
//   int durationMillis, int refreshRateMillis=20
//   }) {
//   var hash = _transitionHash(startValue, endValue, context);
//   if (ongoingTransitions.containsKey(hash)) {
//     return ongoingTransitions[hash].currentValue;
//   }

//   // if(!context.firstBuild) return; TODO
//   int id = transitionId++;
//   // transitions[id] =
//   _transition<V>(map, key, startValue, endValue, durationMillis: durationMillis, refreshRateMillis: refreshRateMillis);
// }

// class FloopCyclicBuildError extends Error {
// }

// void _transition<V>(Map map, Object key, V start, V end, {
//   int durationMillis, int refreshRateMillis=20
//   }) {
//   transitionFunction(Repeater r) {
//     map[key] = r.proportionDouble(start as double, durationMillis);
//   }

//   Repeater(transitionFunction, refreshRateMillis).start();
// }

// void transition<V>(Map map, Object key, V startValue, V endValue, {
//   int durationMillis, int refreshRateMillis=20
//   }) {
//   if(floopController.isListening) {
//     throw FloopCyclicBuildError();
//   }
//   _transition(map, key, startValue, endValue, durationMillis: refreshRateMillis);
// }

// abstract class StatelessWidgetDynamic<K, V> extends FloopStatelessWidget {
//   static StatelessElementDynamic currentContext;

//   Map<K, V> get values => StatelessWidgetDynamic.currentContext.values.cast<K, V>();

//   @override
//   Widget build(BuildContext context) {
//     StatelessWidgetDynamic.currentContext = context;
//     return super.build(context);
//   }

//   @override
//   StatelessElementDynamic<K, V> createElement() {
//     return StatelessElementDynamic<K, V>(this);
//   }
// }

// class StatelessElementDynamic<K, V> extends StatelessElementFloop {
//   final ObservedMap<K, V> values;

//   StatelessElementDynamic(StatelessWidget widget) :
//     values = ObservedMap(),
//     super(widget);

// }

// class ClickerStateful extends StatefulWidget {
//   @override
//   State<StatefulWidget> createState() => ClickerState();
// }

// typedef PeriodicFunction = Function(Repeater);
//
// class Repeater {
//   /// Stops the repeating execution.
//   bool _stop = true;

//   /// Used to ensure only one asynchrnous repeating call in ongoing on this repeater.
//   bool _executionLock = false;

//   /// The function that will be called when method `start` is called on this repeater.
//   /// The function gets called with this repeater as parameter.
//   PeriodicFunction f;

//   /// The frequency of the function calls when method `start` is called.
//   ///
//   /// A frequency can optionally be provided when calling the start method,
//   /// so it's not necessary to set this value.
//   int frequencyMilliseconds;

//   final _stopWatch = Stopwatch();

//   Repeater(this.f, [this.frequencyMilliseconds = 50]);

//   /// Stops this stopwatch and the recurrent executions to `this.f`.
//   stop() {
//     _stop = true;
//   }

//   /// Stops and resets all values of this repeater to it's starting values. It makes a
//   /// single call to `this.f` at the end if `callF` is true (defaults to true).
//   reset([bool callF = true]) {
//     stop();
//     _stopWatch.stop();
//     _stopWatch.reset();
//     !callF ?? f(this);
//   }

//   /// Starts making recurrent calls to `this.f` with the given `frequency`.
//   /// Uses `this.frequencyMilliseconds` if no `frequency` is provided.
//   start([int frequency]) {
//     if (!_stop) {
//       print('The repeater is already running');
//       return;
//     } else if (_executionLock) {
//       print('Another asynchronous instance is already running');
//       return;
//     }
//     _stop = false;
//     _executionLock = true;
//     frequency = frequency ?? frequencyMilliseconds;
//     _stopWatch.start();

//     run() {
//       Future.delayed(Duration(milliseconds: frequency), () {
//         if (_stop) {
//           _stopWatch.stop();
//           _executionLock = false;
//         } else {
//           f(this);
//           run();
//         }
//       });
//     }

//     run();
//   }

//   /// Utility function that returns an integer between 0 inclusive and `maxNumber` exclusive
//   /// corresponding to the proportional position in a cycle of `periodMilliseconds` in current
//   /// `elapsed` time.
//   ///
//   /// For example if elapsed time is 23ms and period is 10ms, then the current cycle time is
//   /// 3ms or 30% of the cycle run. If `number` is 100, the result would be 30 (30% of 100).
//   int proportionInt(int maxNumber, int periodMilliseconds) {
//     int current = _stopWatch.elapsed.inMilliseconds % periodMilliseconds;
//     var res = (maxNumber * current) ~/ periodMilliseconds;
//     return res;
//   }

//   /// Returns the proportion of a [double] `number` in a cycle of length `periodMilliseconds`
//   /// running for `this.elapsed.inMilliseconds`.
//   ///
//   /// Floating point precision version of method `[Repeater.proportionInt]`.
//   double proportionDouble(double number, int periodMilliseconds) {
//     int current = _stopWatch.elapsed.inMilliseconds % periodMilliseconds;
//     return number * current / periodMilliseconds;
//   }
// }

// class Transition<V> extends Repeater {
//   TransitionValueCalculator<V> calculateValue;
//   int durationMillis;

//   /// Returns (elapsed time) /  (total duration of transition) capped to 1
//   double get elapsedFraction => min(1, elapsedMilliseconds / durationMillis);

//   V get currentValue {
//     if (elapsedMilliseconds >= durationMillis) {
//       stop();
//     }
//     calculateValue(elapsedFraction);
//   }

//   updateValue() {}

//   // V calculateValue(Repeater repeater) {
//   //   double fraction = repeater.elapsedMilliseconds/durationMillis;
//   //   if(fraction>=1) {
//   //     repeater.stop();
//   //     fraction = 1;
//   //   }
//   //   return valueCalculator(fraction);
//   // }

//   Transition(this.calculateValue, this.durationMillis, {refreshRateMillis = 20})
//       : super(null, refreshRateMillis) {
//     // f = calculateValue;
//   }
// }

// class MultiHash {
//   MultiHash();
// }
