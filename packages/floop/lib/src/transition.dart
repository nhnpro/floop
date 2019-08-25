import 'dart:math';

import 'package:floop/src/controller.dart';
import 'package:flutter/material.dart';

import '../floop.dart';

ObservedMap<Key, double> _keyToRatio = ObservedMap();
Map<Element, Set<Key>> _contextToKeys = Map();
Map<Key, Repeater> _keyToRepeater = Map();

class _MultiKey extends LocalKey {
  final a, b, c;
  final _hash;

  _MultiKey([this.a, this.b, this.c]) : _hash = hashValues(a, b, c);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _MultiKey &&
        this.a == other.a &&
        this.b == other.b &&
        this.c == other.c;
  }

  @override
  int get hashCode => _hash;
}

typedef TransitionCallback = Function(double elapsedToDurationRatio);
typedef TransitionGenericCallback<V> = Function(V transitionValue);
typedef ValueCallback<V> = V Function(V transitionValue);

Key _getTransitionKey([context, durationMillis, delayMillis]) {
  if (context != null) {
    return _MultiKey(context, durationMillis, delayMillis);
  } else {
    return UniqueKey();
  }
}

Repeater getTransitionObject(Object key) {
  return _keyToRepeater[key];
}

clearTransitions({Key key, BuildContext context}) {
  _applyToTransitions(_stopAndforgetTransition, key: key, context: context);
}

void restartTransitions({Key key, BuildContext context}) {
  _applyToTransitions(_restartTransition, key: key, context: context);
}

_applyToTransitions(Function apply, {Key key, BuildContext context}) {
  if (key != null) {
    apply(key);
  } else if (context != null) {
    _contextToKeys[context]?.forEach(apply);
  } else {
    _keyToRepeater.keys.toList().forEach(apply);
  }
}

void _restartTransition(Key key) {
  if (_keyToRepeater.containsKey(key)) {
    _keyToRepeater[key]
      ..reset()
      ..start();
  }
}

void _stopAndforgetTransition(key) {
  _keyToRepeater.remove(key)?.stop();
  _keyToRatio.remove(key);
}

void _elementUnsubscribeCallback(Element element) {
  _contextToKeys.remove(element)?.forEach(_stopAndforgetTransition);
}

Repeater createTransitionObject(int durationMillis, TransitionCallback callback,
    {int refreshRateMillis = 20,
    int delayMillis = 0,
    RepeaterCallback onFinish}) {
  updater(Repeater repeater) {
    double ratio = min(
        1, max(0, repeater.elapsedMilliseconds - delayMillis) / durationMillis);
    callback(ratio);
    if (onFinish != null && ratio == 1) {
      onFinish(repeater);
    }
  }

  return Repeater(updater, refreshRateMillis, durationMillis + delayMillis);
}

Key startTransition(
  int durationMillis,
  TransitionCallback callback, {
  int refreshRateMillis = 20,
  int delayMillis = 0,
  Key key,
}) {
  key ??= _getTransitionKey();
  _startTransition(durationMillis, callback, refreshRateMillis,
      delayMillis: delayMillis, onFinish: (_) {
    _stopAndforgetTransition(key);
  }, key: key);
  // key ??= _getTransitionKey();
  // _keyToRepeater[key] =
  //     createTransitionObject(durationMillis, callback, onFinish: (_) {
  //   _stopAndforgetTransition(key);
  // })
  //       ..start();
  return key;
  // return key;
}

_noOperation(x) {}

V _identity<V>(V x) => x;

/// Returns the the ratio between the transition's elapsed time and
/// transition's total duration `durationMillis`. A new transition is
/// created if none existed for given `durationMillis`.
///
/// Starts a transition of duration  and
///
///
/// When called outside a widget's [buildWithFloop] a `callback` must be
/// provided. Will always create a new transition and return 0.
///
/// Use [startTransition] to start a transition outside a widget's
/// [buildWithFloop] method.
///
/// When called within a widget's [buildWithFloop] method this method will
/// return the transition's elapsed time to `durationMillis` ratio.
/// When the transition finished, it always returns 1.
double transition(
  int durationMillis, {
  int refreshRateMillis = 20,
  int delayMillis = 0,
  Object key,
  ValueCallback<double> evaluate,
}) {
  Element context = floopController.currentBuild;
  assert(() {
    if (evaluate == null && context == null) {
      print(
          'Error: should not call transition without evaluate callback unless\n'
          'it\'s called within a widget\'s buildWithFloop method, otherwise\n'
          'the transition will have no effect outside of itself.');
      return false;
    }
    // else if (evaluate != null && context != null) {
    //   print('Error: should not provide a callback when calling transition\n'
    //       'while a widget is building. In those cases transition creates\n'
    //       'it\'s own custom callback.');
    //   return false;
    // }
    return true;
  }());
  if (context != null) {
    return _transitionOnBuild(
        context, durationMillis, refreshRateMillis, delayMillis, key, evaluate);
  } else {
    startTransition(durationMillis, evaluate,
        refreshRateMillis: refreshRateMillis,
        delayMillis: delayMillis,
        key: key);
    return 0;
  }
}

double _transitionOnBuild(
    Element context, int durationMillis, int refreshRateMillis,
    [int delayMillis = 0,
    Object key,
    ValueCallback<double> evaluate = _identity]) {
  assert(context != null);
  key ??= _getTransitionKey(context, durationMillis, delayMillis);
  // int id = _getTransitionKey(context, durationMillis, delayMillis);
  Set<Key> contextKeys = _contextToKeys[context];

  if (contextKeys == null) {
    addUnsubscribeCallback(context, _elementUnsubscribeCallback);
    contextKeys = Set();
    _contextToKeys[context] = contextKeys;
  }

  double currentRatio = _keyToRatio[key];

  if (currentRatio == null) {
    _startTransition(durationMillis, (double ratio) {
      // The callback sets the value of the ObservedMap _idToRatio, causing
      // the Element to rebuild as the transition progresses.
      // print('id $id to fraction $fraction');
      _keyToRatio[key] = ratio;
    }, refreshRateMillis, delayMillis: delayMillis, key: key);

    contextKeys.add(key);
    _keyToRatio.setValue(key, 0, false);
    currentRatio = 0;
    print(
        'First build $context: $key  -  number of ids: ${_keyToRatio.length} ');
  }
  assert(currentRatio != null);
  assert(_keyToRatio.containsKey(key));
  if (evaluate != null) {
    return evaluate(currentRatio);
  }
  return currentRatio;
}

Key _startTransition(
    int durationMillis, TransitionCallback callback, int refreshRateMillis,
    {RepeaterCallback onFinish, int delayMillis = 0, Key key}) {
  key ??= _getTransitionKey();
  _keyToRepeater[key] = createTransitionObject(durationMillis, callback,
      delayMillis: delayMillis, onFinish: onFinish)
    ..start();
  return key;
}

int transitionInt(int start, int end, int durationMillis,
    {refreshRateMillis = 20, ValueCallback<int> callback}) {
  return transitionNumber(start, end, durationMillis,
      refreshRateMillis: refreshRateMillis,
      callback: (num ratio) => callback(ratio.toInt())).toInt();
}

num transitionNumber(num start, num end, int durationMillis,
    {refreshRateMillis = 20, ValueCallback<num> callback = _identity}) {
  // if(callback!=null) {
  //   callback = ;
  // }
  return transition(durationMillis,
      refreshRateMillis: refreshRateMillis,
      evaluate: (double fraction) =>
          callback(start + (end - start) * fraction));
  // return start + (end - start) * elapsedRatio;
}

// V _doubleAsAnyTypeIdentity<V>(double x) => x as V;

/// Transitions the `map[key]` value using `evaluate` on each update.
///
/// `evaluate` receives as parameter a number between 0 and 1 that corresponds
/// to the ratio between the transition's elapsed time and the transition's
/// total duration.
transitionKeyValue(Map map, Object key, int durationMillis,
    {ValueCallback evaluate = _identity, int refreshRateMillis = 20}) {
  return startTransition(durationMillis, (double ratio) {
    double value = evaluate(ratio);
    map[key] = value;
    return value;
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
//     int delayMillis=0,
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
//     double correctionFactor = durationMillis/(durationMillis+delayMillis);
//     double ratio = _transitionOnBuild(durationMillis+delayMillis, refreshRateMillis);
//     // Adjusts ratio according to delay
//     return max(0,(ratio+correctionFactor-1)/correctionFactor);
//   } else {
//     Future.delayed(Duration(milliseconds: delayMillis),
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

// Transition class with extra parameters for internal use.
// class _Transition extends Transition {
//   Repeater repeater;
//   final int id;
//   final FloopElement context;

//   _Transition(this.id, [this.context]): super(id, context);

//   _Transition.ofCallback(int durationMillis, TransitionCallback callback,
//     {int refreshRateMillis = 20, this.context}): id = _lastId++,
//     super(durationMillis, callback, refreshRateMillis:refreshRateMillis);
// }

// class Transition<V> extends Repeater {
//   // Repeater repeater;
//   // final int id;
//   // final FloopElement context;

//   int durationMillis;

//   static _createCallback(Transition t, TransitionCallback callback) {
//     return (Repeater repeater) {
//       double ratio = min(1, repeater.elapsedMilliseconds / durationMillis);
//       callback(ratio);
//       if (ratio == 1) {
//         // stops the Repeater and cleans internal references to it
//         repeater.stop();
//       }
//     };
//   }

//   Transition(int durationMillis, TransitionCallback callback,
//     {int refreshRateMillis = 20}): super(_createCallback(callback), refreshRateMillis);
//   // Transition(this.id, [this.context]);

//   start([freq]) {
//     repeater.start();
//   }
// }
