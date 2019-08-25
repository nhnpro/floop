import 'dart:math';

import 'package:floop/src/controller.dart';
import 'package:floop/src/utils.dart';
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
typedef RatioEvaluator<V> = V Function(double elapsedToDurationRatio);
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
  if (key != null) {
    _stopAndforgetTransition(key);
  }
  return _startTransition(durationMillis, callback, refreshRateMillis,
      delayMillis: delayMillis, key: key);
}

/// Returns the ratio between the transition's elapsed time transition's total
/// duration `durationMillis`. The ratio will always start at 0 at finish at 1.
///
///
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
  RatioEvaluator<double> evaluate,
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
    [int delayMillis = 0, Object key, ValueCallback<double> evaluate]) {
  assert(context != null);
  key ??= _getTransitionKey(context, durationMillis, delayMillis);
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
      _keyToRatio[key] = ratio;
    }, refreshRateMillis, delayMillis: delayMillis, key: key);

    contextKeys.add(key);
    _keyToRatio.setValue(key, 0, false);
    currentRatio = 0;
    // print(
    //     'First build $context: $key  -  number of ids: ${_keyToRatio.length} ');
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
  if (key == null) {
    key = _getTransitionKey();
    onFinish = (repeater) {
      if (onFinish != null) {
        onFinish(repeater);
      }
      _stopAndforgetTransition(key);
    };
  }
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
    {refreshRateMillis = 20, ValueCallback<num> callback = identity}) {
  return transition(durationMillis,
      refreshRateMillis: refreshRateMillis,
      evaluate: (double fraction) =>
          callback(start + (end - start) * fraction));
}

/// Transitions the `map[key]` value using `evaluate` on the elapsed  on each update.
///
/// `evaluate` receives as parameter a number between 0 and 1 that corresponds
/// to the ratio between the transition's elapsed time and the transition's
/// total duration.
transitionKeyValue<V>(Map<dynamic, V> map, Object key, int durationMillis,
    {RatioEvaluator<V> update, int refreshRateMillis = 20}) {
  assert(update != null || V is double);
  update ??= identityCast; // for type check passing
  return startTransition(durationMillis, (double ratio) {
    var value = update(ratio);
    map[key] = value;
    return value;
  }, refreshRateMillis: refreshRateMillis);
}
