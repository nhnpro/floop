import 'package:floop/src/controller.dart';
import 'package:flutter/material.dart';

import '../floop.dart';
import './repeater.dart';

_doNothing([x]) {}
T _doubleAsType<T, V>(V x) => x as T;

ObservedMap<Key, double> _keyToRatio = ObservedMap();
Map<Element, Set<Key>> _contextToKeys = Map();
Map<Key, Repeater> _keyToRepeater = Map();

class _MultiKey extends LocalKey {
  final a, b, c, d;
  final _hash;

  _MultiKey([this.a, this.b, this.c, this.d]) : _hash = hashValues(a, b, c, d);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _MultiKey &&
        this.a == other.a &&
        this.b == other.b &&
        this.c == other.c &&
        this.d == other.d;
  }

  @override
  int get hashCode => _hash;
}

typedef TransitionCallback = Function(double elapsedToDurationRatio);
typedef ValueCallback<V> = V Function(V transitionValue);

Key _createKey([context, durationMillis, delayMillis, evaluate]) {
  if (context != null) {
    Key key = _MultiKey(context, durationMillis, delayMillis, evaluate);
    Set<Key> contextKeys = _contextToKeys[context];
    if (contextKeys == null) {
      contextKeys = Set();
      _contextToKeys[context] = contextKeys;
      addUnsubscribeCallback(context, _clearContextTransitions);
    }
    contextKeys.add(key);
    return key;
  } else {
    return UniqueKey();
  }
}

/// Transitions a number from 0 to 1 inclusive in `durationMillis` milliseconds.
///
/// Specially designed for being called from within [Floop.buildWithFloop], by
/// causing the widget to rebuild as the transition's progresses.
///
/// When called from within a [buildWithFloop] method, `evaluate` must be null,
/// otherwise `evaluate` is invoked with the transition value as parameter on
/// every transition update.
///
/// `refreshRateMillis` is the frequency in milliseconds at which the
/// transition should update it's value.
///
/// The transition can be delayed by `delayMillis` milliseconds.
///
/// If `key` is non null, the value of an ongoing transition registered with the
/// same `key` will be returned. Otherwise a new transition will be created.
/// The `key` parameter is useful for refering to the transition with the
/// methods [clearTransitions], [restartTransitions] or [getTransitionObject].
///
/// Note that created transitions references get cleared once they finish,
/// unless they are created from within a [buildWithFloop] method, where they
/// get cleared once the corresponding BuildContext gets unmounted.
///
/// See also [Repeater.transition], the base construct used by this function.
double transition(
  int durationMillis, {
  int refreshRateMillis = 20,
  int delayMillis = 0,
  TransitionCallback evaluate = _doNothing,
  Object key,
}) {
  Element context = floopController.currentBuild;
  assert(() {
    if (context == null && key == null && evaluate == _doNothing) {
      print(
          'Error: should not invoke transition without `evaluate` and without a\n'
          'key unless it\'s called within a widget\'s buildWithFloop method. The\n'
          'transition would have no effect outside of itself.');
      return false;
    } else if (evaluate != _doNothing && context != null) {
      print('Error: should not provide `evaluate` when calling transition\n'
          'while a widget is building as it won\'t be used');
      return false;
    }
    return true;
  }());
  key ??= _createKey(context, durationMillis, delayMillis);
  if (!_keyToRatio.containsKey(key)) {
    assert(!_keyToRepeater.containsKey(key));
    _keyToRatio.setValue(key, 0, false);

    // If within a BuildContext, the transitions will get cleared once the
    // element unmounts.
    var onFinish =
        context == null ? (_) => _stopAndforgetTransition(key) : null;
    _keyToRepeater[key] = Repeater.transition(durationMillis, (double ratio) {
      evaluate(ratio);
      // The callback sets the value of the ObservedMap _idToRatio, causing
      // the context (element) to rebuild as the transition progresses.
      _keyToRatio[key] = ratio;
    },
        refreshRateMillis: refreshRateMillis,
        delayMillis: delayMillis,
        onFinish: onFinish)
      ..start();
  }
  return _keyToRatio[key];
}

int transitionInt(int start, int end, int durationMillis,
    {refreshRateMillis = 20}) {
  return transitionNumber(start, end, durationMillis,
          refreshRateMillis: refreshRateMillis)
      .toInt();
}

num transitionNumber(num start, num end, int durationMillis,
    {refreshRateMillis = 20}) {
  return start +
      (end - start) *
          transition(durationMillis, refreshRateMillis: refreshRateMillis);
}

/// Transitions the value of `key` in the provided `map`.
///
/// The transition lasts for `durationMillis` and updates it's value
/// with a rate of `refreshRateMillis`.
///
/// Useful for easily transitiong an [ObservedMap] key
Repeater transitionKeyValue<V>(
    Map<dynamic, V> map, Object key, int durationMillis,
    {V update(double elapsedToDurationRatio), int refreshRateMillis = 20}) {
  assert(update != null);
  assert(() {
    if (update == null && V != dynamic && V != double && V != num) {
      print('Error: Must provide update function as parameter for type $V');
      return false;
    }
    return true;
  }());
  update ??= _doubleAsType;
  return Repeater.transition(durationMillis, (double ratio) {
    var value = update(ratio);
    map[key] = value;
  }, refreshRateMillis: refreshRateMillis);
}

Repeater getTransitionObject(Object key) {
  return _keyToRepeater[key];
}

/// Clears all transitions if no `key` or `context` is provided.
///
/// Can provide optional `key` or `context`, but not both. If so, only the
/// associated transitions will be cleared.
clearTransitions({Key key, BuildContext context}) {
  assert(key == null || context == null);
  if (key != null) {
    _stopAndforgetTransition(key);
  } else if (context != null) {
    _clearContextTransitions(context);
  } else {
    _keyToRepeater.keys.toList().forEach(_stopAndforgetTransition);
  }
}

/// Restarts all transitions if no `key` or `context` is provided.
///
/// Can provide optional `key` or `context`, but not both. If so, only the
/// associated transitions will get restarted.
void restartTransitions({Key key, BuildContext context}) {
  if (key != null) {
    _restartTransition(key);
  } else if (context != null) {
    _contextToKeys[context]?.forEach(_restartTransition);
  } else {
    _keyToRepeater.keys.forEach(_restartTransition);
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

void _clearContextTransitions(Element element) {
  _contextToKeys.remove(element)?.forEach(_stopAndforgetTransition);
}
