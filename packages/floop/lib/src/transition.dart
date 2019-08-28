import 'package:floop/src/controller.dart';
import './flutter_import.dart';

import '../floop.dart';
import './repeater.dart';

T _doubleAsType<T, V>(V x) => x as T;

final ObservedMap<Key, double> _keyToRatio = ObservedMap();
final Map<Element, Set<Key>> _contextToKeys = Map();
final Map<Key, Repeater> _keyToRepeater = Map();

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

/// Transitions a number from 0 to 1 inclusive in `durationMillis` milliseconds
/// when invoked from inside a [Floop.buildWithFloop] method, automatically
/// rebuilding the widget as the transition progresses.
///
/// See [transitionEval] to create transitions from outside build methods.
///
/// `refreshRateMillis` is the frequency in milliseconds at which the
/// transition updates it's value.
///
/// The transition can be delayed by `delayMillis` milliseconds.
///
/// Returns null if `durationMillis` is null and there is no transition for
/// given `key`. If `key` is non null and a transition registered to `key`
/// exists, it's current value is returned.
///
/// When invoked from outside [buildWithFloop] methods, new transitions are
/// not created, therefore `key` parameter should always be provided in those
/// cases.
///
/// Keys are useful to reference transitions somewhere else or to manipulate
/// transitions with [clearTransitions] and [resetTransitions].
///
/// Note that this method does not work inside builders, like [StreamBuilder],
/// as builders build outside of the encompassing widget's build method.
/// One workaround is to define a transition with a `key` within the
/// encompassing [Floop] widget's build method: `transition(ms, key: myKey)`.
/// Reference it from inside the builder: `transition(null, key: myKey)`.
///
/// In the following example `x` transitions from 0 to 1 in one second and
/// `floop['y']` transitions from 0 to 1 in three seconds when there is a click
/// event somewhere in the widget. The `Text` widget will always display the
/// updated values.
///
/// ```dart
/// class MyWidget extends StatelessWidget with Floop {
///   ...
///
///   @override
///   Widget buildWithFloop(BuildContext context, MyButtonState state) {
///     double x = transition(1000);
///     return ...
///         Text('X is at $x and Y is at: ${floop['y']}'),
///         ...
///         ...onPressed: () => transitionEval(3000, evaluate: (x) => floop['y'] = x),
///         ...
///     ...
///   }
/// }
/// ```
///
/// Created transitions references get cleared when the corresponding
/// context gets unmounted.
double transition(
  int durationMillis, {
  int refreshRateMillis = 20,
  int delayMillis = 0,
  Object key,
}) {
  Element context = floopController.currentBuild;
  final bool _canCreate = durationMillis != null && context != null;
  assert(() {
    if (!(_canCreate || key != null)) {
      print(
          'Error: When invoking [transition] outside a widget\'s buildWithFloop\n'
          'method, the `key` parameter must be provided, as it can only be used\n'
          'to reference transitions. See [transitionEval] to create transitions\n'
          'outside build methods.'
          'If this is getting invoked from within a [Builder], check\n'
          '[transition]\'s docs to handle that case.');
      return false;
    }
    return true;
  }());
  final bool _exists = key != null && _keyToRatio.containsKey(key);
  if (!(_canCreate || _exists)) {
    return null;
  }
  assert(context != null || _keyToRatio.containsKey(key));
  key ??= _createKey(context, durationMillis, delayMillis);
  _contextToKeys.putIfAbsent(context, () => Set()..add(key));
  if (!_keyToRatio.containsKey(key)) {
    assert(!_keyToRepeater.containsKey(key));
    assert(_contextToKeys[context].contains(key));
    _keyToRatio.setValue(key, 0, false);
    _keyToRepeater[key] = Repeater.transition(durationMillis, (double ratio) {
      // The callback sets the value of the ObservedMap _idToRatio, causing
      // the context (element) to rebuild as the transition progresses.
      _keyToRatio[key] = ratio;
    }, refreshRateMillis: refreshRateMillis, delayMillis: delayMillis)
      ..start();
  }
  return _keyToRatio[key];
}

/// Transitions a number from 0 to 1 inclusive in `durationMillis` milliseconds,
/// invoking `evaluate` with the number as parameter on every update.
///
/// `durationMillis` and `evaluate` must not be null.
///
/// `refreshRateMillis` is the frequency in milliseconds at which the
/// transition updates it's value.
///
/// The transition can be delayed by `delayMillis` milliseconds.
///
/// If `key` is null or no transition is registered to `key`, a new transition
/// is created. Otherwise no operation is done. The key of the created or
/// existing transition is always returned. A new key is created in case `key`
/// is null.
/// Once the transition finishes, all references to it get cleared.
///
/// This function cannot be invoked from within a widget's [buildWithFloop].
/// Refer to [transition] for that use case.
///
/// See also [Repeater.transition], the base construct used by this function.
Key transitionEval(
  int durationMillis,
  TransitionCallback evaluate, {
  int refreshRateMillis = 20,
  int delayMillis = 0,
  Key key,
}) {
  assert(() {
    if (floopController.currentBuild != null) {
      print('Error: should not invoke [transitionEval] while a Floop Widget\n'
          'is building. Use [transition]` instead.');
      return false;
    }
    return true;
  }());
  key ?? _createKey();
  if (!_keyToRatio.containsKey(key)) {
    _keyToRepeater[key] = Repeater.transition(durationMillis, (double ratio) {
      evaluate(ratio);
      _keyToRatio[key] = ratio;
    },
        refreshRateMillis: refreshRateMillis,
        delayMillis: delayMillis,
        onFinish: (_) => _stopAndforgetTransition(key))
      ..start();
  }
  return key;
}

/// Transitions allow manipulating the transitions generated by this library.
///
/// For operations [pause], [resume], [reset] and [clear], parameters `key`
/// or `context` can be provided, but not both. If none of them is specified,
/// the operation is applied to all transitions.
///
/// If `key` is provided, the operation is applied to the corresponding
/// transition if it exists, otherwise nothing is done.
///
/// If `context` is provided, the operation is applied to all the transitions
/// created while the context was building.
abstract class Transitions {
  /// Pauses transitions.
  ///
  /// Be mindful that paused transitions that are not associated to any
  /// [BuildContext] will be saved until they are resumed with [resume]
  /// or get deleted with [clear].
  static pause({Key key, BuildContext context}) {
    _applyToTransitions(_resetTransition, key, context);
  }

  /// Resumes transitions.
  static resume({Key key, BuildContext context}) {
    _applyToTransitions(_startTransition, key, context);
  }

  /// Resets transitions to their starting state. If the transitions were
  /// paused, they remain paused.
  ///
  /// For resetting context transitions, [clear] might be more suitable, since
  /// the transitions will be created again once the context rebuilds, while
  /// resetting them would cause transitions that are created within
  /// conditional statements to replay before the condition triggers.
  static reset({Key key, BuildContext context}) {
    _applyToTransitions(_resetTransition, key, context);
  }

  /// Clear all transitions. Equivalent to invoking `Transitions.clear()`.
  static clearAll() => clear();

  /// Stops and removes references to transitions.
  ///
  /// Particularly useful for causing a context to rebuild as if it was being
  /// built for the first time.
  static clear({Key key, BuildContext context}) {
    clearTransitions(key: key, context: context);
  }
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
/// Useful for easily transitiong an [ObservedMap] key-value and use
Repeater transitionKeyValue<V>(
    Map<dynamic, V> map, Object key, int durationMillis,
    {V update(double elapsedToDurationRatio), int refreshRateMillis = 20}) {
  assert(update != null);
  assert(() {
    if (update == null && V != dynamic && V != double && V != num) {
      print('Error: Must provide update function as parameter for type $V.');
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

// Repeater getTransitionObject(Object key) {
//   return _keyToRepeater[key];
// }

/// Clears all transitions when no `key` or `context` are provided.
///
/// Receives optional `key` or `context` to clear only the associated
/// transitions. If both of them are provided, `key` takes precedence and
/// `context` is not used.
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

/// Resets all transitions when no `key` or `context` are provided.
///
/// Can provide optional `key` or `context`, but not both. If so, only the
/// associated transitions will get resetted.
void resetTransitions({Key key, BuildContext context}) {
  if (key != null) {
    _resetTransition(key);
  } else if (context != null) {
    _contextToKeys[context]?.forEach(_resetTransition);
  } else {
    _keyToRepeater.keys.forEach(_resetTransition);
  }
}

void _applyToTransitions(Function(Key) apply, Key key, BuildContext context) {
  if (key != null) {
    apply(key);
  } else if (context != null) {
    _contextToKeys[context]?.forEach(apply);
  } else {
    _keyToRepeater.keys.forEach(apply);
  }
}

void _resetTransition(Key key) {
  if (_keyToRepeater.containsKey(key)) {
    _keyToRepeater[key]
      ..reset()
      ..start();
  }
}

void _stopTransition(Key key) {
  if (_keyToRepeater.containsKey(key)) {
    _keyToRepeater[key]..stop();
  }
}

void _startTransition(Key key) {
  var repeater = _keyToRepeater[key];
  if (repeater != null && !repeater.isRunning) {
    _keyToRepeater[key]..start();
  }
}

void _stopAndforgetTransition(Key key) {
  assert(_keyToRepeater.containsKey(key) == _keyToRatio.containsKey(key));
  _keyToRepeater.remove(key)?.stop();
  _keyToRatio.remove(key);
}

void _clearContextTransitions(Element element) {
  _contextToKeys.remove(element)?.forEach(_stopAndforgetTransition);
}

int _lastId = 0;
final Map<Key, _Transition> _keyToTransition = Map();
final ObservedMap<int, double> _idToRatio = Map();

/// Utility class to contain all fields related to a transition.
class _Transition {
  final Key key;
  final int id;
  final Element context;
  Repeater repeater;

  factory _Transition.fromKey(Key key) => _keyToTransition[key];

  _Transition(this.key, [this.context, this.repeater]) : id = _lastId++ {
    // _keyToRatio.setValue(id, 0, false);
    _idToRatio.setValue(id, 0, false);
    // repeater = Repeater.transition(durationMillis, (double progressRatio) {
    //   // The callback sets the value of the ObservedMap _idToRatio, causing
    //   // the context (element) to rebuild as the transition progresses.
    //   currentValue = progressRatio;
    // }, refreshRateMillis: refreshRateMillis, delayMillis: delayMillis)
  }

  // double get ratio => _keyToRatio[id];
  // set ratio(double r) => _keyToRatio[id] = r;
  double get currentValue => _idToRatio[id];
  set currentValue(double ratio) => _idToRatio[id] = ratio;

  stopAndRemove() {
    assert(repeater != null);
    repeater.stop();
    _keyToTransition.remove(key);
    _idToRatio.remove(id);
    // _keyToRatio.remove(id);
    // _contextToKeys[context]?.remove(id);
    // _keyToTransition.remove(key);
  }
}

Key _createMultiKey(context, durationMillis, delayMillis) {
  assert(durationMillis != null);
  if (context != null) {
    Key key = _MultiKey(context, durationMillis, delayMillis);
    Set<Key> contextKeys = _contextToKeys[context];
    if (contextKeys == null) {
      contextKeys = Set();
      _contextToKeys[context] = contextKeys;
      addUnsubscribeCallback(context, _clearContextTransitions);
    }
    contextKeys.add(key);
    return key;
  } else {
    return null;
  }
}

double _transition(
  int durationMillis, {
  int refreshRateMillis = 20,
  int delayMillis = 0,
  Object key,
}) {
  Element context = floopController.currentBuild;
  final bool canCreate = durationMillis != null && context != null;
  assert(() {
    if (!canCreate && key == null) {
      print(
          'Error: When invoking [transition] outside a widget\'s buildWithFloop\n'
          'method, the `key` parameter must be provided, as it can only be used\n'
          'to reference transitions. See [transitionEval] to create transitions\n'
          'outside build methods.'
          'If this is getting invoked from within a [Builder], check\n'
          '[transition]\'s docs to handle that case.');
      return false;
    }
    return true;
  }());
  if (canCreate && key == null) {
    key = _MultiKey(context, durationMillis, delayMillis);
  }
  var transitionObject =
      _Transition.fromKey(key); //key != null && _keyToRatio.containsKey(key);
  if (!canCreate && transitionObject == null) {
    return null;
  }
  assert(canCreate != null || transitionObject != null);
  // _contextToKeys.putIfAbsent(context, () => Set()..add(key));
  if (transitionObject == null) {
    transitionObject = _Transition(
        key,
        context,
        Repeater.transition(durationMillis, (double ratio) {
          // The callback sets the value of the ObservedMap _idToRatio, causing
          // the context (element) to rebuild as the transition progresses.
          _idToRatio[key] = ratio;
        }, refreshRateMillis: refreshRateMillis, delayMillis: delayMillis)
          ..start());
    _addToContext(context, transitionObject);
  }
  return transitionObject.currentValue;
}

final Map<Element, Set<_Transition>> _contextToTransitions = Map();

_addToContext(context, transitionObject) {
  var contextKeys = _contextToTransitions[context];
  if (contextKeys == null) {
    contextKeys = Set()..add(transitionObject);
    _contextToTransitions[context] = contextKeys;
    addUnsubscribeCallback(context, _clearContextTransitions);
  }
}
