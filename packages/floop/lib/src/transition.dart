import 'dart:math';

import 'package:floop/src/controller.dart';
import 'package:floop/src/mixins.dart';
import 'package:flutter/material.dart';

import '../floop.dart';

int _lastId = 0;

Map<BuildContext, Map<int, int>> _contextIds = Map();
ObservedMap<int, double> _idToFraction = ObservedMap();
Map<int, Repeater> _idToRepeater = Map();

typedef ValueUpdater<V> = V Function(double elapsedToDurationRatio);
typedef TransitionCallback = Function(double elapsedToDurationRatio);
typedef TransitionGenericCallback<V> = Function(V currentValue);

void resetTransitions(FloopElement context) {
  _elementUnmountCallback(context);
}

void _stopAndforgetTransition(id) {
  _idToRepeater[id]?.stop();
  _idToRepeater.remove(id);
  _idToFraction.remove(id);
}

void _elementUnmountCallback(Element element) {
  _contextIds[element]?.values?.forEach((int id) {
    _stopAndforgetTransition(id);
  });
  _contextIds.remove(element);
}

Repeater createTransitionObject(int durationMillis, TransitionCallback callback,
    {int refreshRateMillis = 20}) {
  updater(Repeater repeater) {
    double ratio = min(1, repeater.elapsedMilliseconds / durationMillis);
    callback(ratio);
    if (ratio == 1) {
      repeater.stop();
    }
  }

  return Repeater(updater, refreshRateMillis);
}

Repeater startTransition(int durationMillis, TransitionCallback callback,
    {int refreshRateMillis = 20}) {
  return createTransitionObject(durationMillis, callback)..start();
}

/// Returns the the ratio between the transition's elapsed time and
/// transition's total duration (`durationMillis`). A new transition is
/// created if none existed for given `durationMillis` or
///
/// Starts a transition of duration  and
///
///
/// When called outside a widget's [buildWithFloop] a `callback` must be
/// provided. Will always create a new transition and return 0.
///
/// When called within a widget's [buildWithFloop] method this method will
/// return the transition's elapsed time to `durationMillis` ratio.
/// When the transition finished, it always returns 1.
double transition(
  int durationMillis, {
  TransitionCallback callback,
  int refreshRateMillis = 20,
}) {
  FloopElement context = floopController.currentBuild;
  assert(() {
    if (callback == null && context == null) {
      print('Error: should not call transition without a callback unless\n'
          'it\'s called within a widget\'s buildWithFloop method, otherwise\n'
          'the transition will have no effect outside of itself.');
      return false;
    } else if (callback != null && context != null) {
      print('Error: should not provide a callback when calling transition\n'
          'while a widget is building. In those cases transition creates\n'
          'it\'s own custom callback.');
      return false;
    }
    return true;
  }());
  if (context != null) {
    return _transitionOnBuild(context, durationMillis, refreshRateMillis);
  } else {
    _startTransition(durationMillis, callback, refreshRateMillis);
    return 0;
  }
}

double _transitionOnBuild(
    FloopElement context, int durationMillis, int refreshRateMillis) {
  assert(context != null);
  Map<int, int> durationToId = _contextIds.putIfAbsent(context, () => Map());
  int id = durationToId[durationMillis];

  // If id is null, it means the transition has not been created yet.
  if (id == null) {
    id = _startTransition(durationMillis, (double fraction) {
      // The callback sets the value of the ObservedMap _idToFraction, causing
      // the Element to rebuild as the transition progresses.
      // print('id $id to fraction $fraction');
      _idToFraction[id] = fraction;
    }, refreshRateMillis);

    durationToId[durationMillis] = id;
    _idToFraction.setValue(id, 0, false);
    context.addUnmountCallback(_elementUnmountCallback);
    print('First build $context: $id');
  }
  assert(id != null);
  assert(_idToFraction.containsKey(id));
  return _idToFraction[id];
}

int _startTransition(
    int durationMillis, TransitionCallback callback, int refreshRateMillis) {
  int id = _lastId++;

  updater(Repeater repeater) {
    double fraction = min(1, repeater.elapsedMilliseconds / durationMillis);
    callback(fraction);
    if (fraction == 1) {
      // stops the Repeater and cleans internal references to it
      repeater.stop();
      _idToRepeater.remove(id);
    }
  }

  _idToRepeater[id] = Repeater(updater, refreshRateMillis)..start();
  return id;
}

int transitionInt(int start, int end, int durationMillis,
    {refreshRateMillis = 20, TransitionGenericCallback<int> callback}) {
  return transitionNumber(start, end, durationMillis,
          refreshRateMillis: refreshRateMillis, callback: callback)
      .toInt();
}

num transitionNumber(num start, num end, int durationMillis,
    {refreshRateMillis = 20, TransitionGenericCallback<num> callback}) {
  num elapsedRatio =
      transition(durationMillis, refreshRateMillis: refreshRateMillis);
  return start + (end - start) * elapsedRatio;
}

/// Returns the input value.
_identity(v) => v;

/// Transitions the `map[key]` value using `update` on each update.
///
/// `update` receives as parameter a number between 0 and 1 that corresponds
/// to the ratio between the transition's elapsed time and the transition's
/// total duration.
transitionKeyValue(Map map, Object key, int durationMillis,
    {ValueUpdater update = _identity, int refreshRateMillis = 20}) {
  return transition(durationMillis, callback: (double fraction) {
    map[key] = update(fraction);
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

// WIP
// double transition(int durationMillis,
//     {TransitionCallback callback, int refreshRateMillis = 20,
//     int delayedMillis=0,
//     TransitionCallback onFinish,
//     Object key}) {
//   assert(() {
//     if (callback == null && floopController.currentBuild == null) {
//       print('Error: should not call transition without a callback unless\n'
//           'it\'s called within a widget\'s buildWithFloop method, otherwise\n'
//           'the transition will have no effect outside of itself.');
//       return false;
//     } else if (callback != null && floopController.currentBuild != null) {
//       print('Error: should not provide a callback when calling transition\n'
//           'while a widget is building, in those cases transition creates\n'
//           'it\'s own custom callback.');
//       return false;
//     }
//     return true;
//   }());
//   if (callback == null) {
//     double correctionFactor = durationMillis/(durationMillis+delayedMillis);
//     double ratio = _transitionOnBuild(durationMillis+delayedMillis, refreshRateMillis);
//     // Adjusts ratio according to delay
//     return max(0,(ratio+correctionFactor-1)/correctionFactor);
//   } else {
//     Future.delayed(Duration(milliseconds: delayedMillis),
//     () => _startTransition(durationMillis, callback, refreshRateMillis));
//     return 0;
//   }
// }

// double _transitionOnBuild(int durationMillis, int refreshRateMillis) {
//   assert(floopController.currentBuild != null);
//   FloopElement context = floopController.currentBuild;
//   double result = 1;
//   int id;
//   Map<int, int> durationToId = _contextIds[context];

//   _cleanMaps() {
//     // Cleans maps when the transition finishes.
//     _idToFraction.remove(id, false);
//     if (durationToId != null) {
//       durationToId.remove(durationMillis);
//       if (durationToId.isEmpty) {
//         _contextIds.remove(context);
//       }
//     }
//   }

//   // If the context has a child, it means it was built at least once.
//   // If the context was built at least once, a new transition will not
//   // be created.
//   bool firstBuild = !context.didRebuild;

//   if (firstBuild) {
//     if (durationToId == null) {
//       durationToId = Map();
//       _contextIds[context] = durationToId;
//     }

//     id = _startTransition(durationMillis, (double fraction) {
//       // The callback sets the value of an ObservedMap, causing the
//       // Element to rebuild as the transition progresses.]
//       print('id $id to fraction $fraction');
//       _idToFraction[id] = fraction;
//       if (fraction >= 1) {
//         _cleanMaps();
//       }
//     }, refreshRateMillis);
//     assert(id != null);
//     durationToId[durationMillis] = id;
//     _idToFraction.setValue(id, 0, false);
//     print('First build $context: $id');
//   } else if (durationToId != null) {
//     id = durationToId[durationMillis];
//   }
//   // If the id is null, it means the transition finished and the observedMap
//   // should not subscribe to the Widget.
//   if (id != null) {
//     assert(_idToFraction.containsKey(id));
//     result = _idToFraction[id];
//   }

//   return result;
// }
