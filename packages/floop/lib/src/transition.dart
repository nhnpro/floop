import './flutter_import.dart';
import './controller.dart';
import './observed.dart';
import './repeater.dart';

T _doubleAsType<T, V>(V x) => x as T;

final Map<BuildContext, Set<Object>> _contextToKeys = Map();

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

Key _createKey([context, durationMillis, delayMillis]) {
  if (context != null) {
    return _MultiKey(context, durationMillis, delayMillis);
  } else {
    return UniqueKey();
  }
}

_addKeyToContext(key, context) {
  assert(key != null && context != null);
  var contextKeys = _contextToKeys[context];
  if (contextKeys == null) {
    contextKeys = Set();
    _contextToKeys[context] = contextKeys;
    addUnsubscribeCallback(context, _clearContextTransitions);
  }
  contextKeys.add(key);
}

/// Transitions a number from 0 to 1 inclusive in `durationMillis`
/// milliseconds when invoked from inside a [build] method, automatically
/// rebuilding the widget as the transition progresses.
///
/// `durationMillis` must not be null.
///
/// `refreshRateMillis` is the frequency in milliseconds at which the
/// transition updates it's value.
///
/// The transition can be delayed by `delayMillis` milliseconds.
///
/// Use [transitionEval] to create transitions from outside build methods, or
/// [transitionOf] to retrieve the value of a keyed transition.
///
/// If `key` is non null and a transition registered to `key` exists, it's
/// current value is returned. Keys can be used to reference and apply
/// operations to transitions through [Transitions] static methods.
/// When invoked from outside [build] methods, this function is
/// equivalent to [transitionOf], the only used parameter is `key`.
///
/// Note that this method does not work inside builders, like [LayoutBuilder],
/// as builders build outside of the encompassing build method.
/// The workaround is to use a `var t = transition(...)` in the body of the
/// [build] method and then reference the var from within the builder body.
/// Another alternative is to define the transition with a key and then
/// reference it with [transitionOf].
///
/// In the following example `x` transitions from 0 to 1 in five seconds when
/// it builds and `floop['y']` transitions from 0 to 1 in three seconds when
/// there is a click event. The `Text` widget will always display the updated
/// values.
///
/// ```dart
/// class MyWidget extends StatelessWidget with Floop {
///   ...
///
///   @override
///   Widget build(BuildContext context, MyButtonState state) {
///     double t = transition(5000);
///     return ...
///         Text('T is at $t and Y is at: ${floop['y']}'),
///         ...
///         ...onPressed: () => transitionEval(3000, evaluate: (x) => floop['y'] = x),
///         ...
///     ...
///   }
/// }
/// ```
///
/// Created transitions references get cleared automatically when the
/// corresponding build context gets unmounted.
double transition(
  int durationMillis, {
  int refreshRateMillis = 20,
  int delayMillis = 0,
  Object key,
}) {
  BuildContext context = FloopController.currentBuild;
  final bool canCreate =
      durationMillis != null && (context != null || key != null);
  assert(() {
    if (durationMillis == null) {
      print('Error: [transition] was invoked with `durationMillis` as null.');
    }
    if (!canCreate && key == null) {
      print('Error: When invoking [transition] outside a Floop widget\'s '
          'build method, the `key` parameter must be not null, otherwise the '
          'transition can have no effect outside of itself.\n'
          'See [transitionEval] to create transitions outside build methods. '
          'If this is getting invoked from within a [Builder], check '
          '[transition]\'s docs to handle that case.');
      return false;
    }
    return true;
  }());
  if (canCreate && key == null) {
    key = _createKey(context, durationMillis, delayMillis);
  }
  var transitionObject = _Transition.get(key);
  if (!canCreate && transitionObject == null) {
    return null;
  }
  assert(canCreate != null || transitionObject != null);
  if (transitionObject == null) {
    _addKeyToContext(key, context);
    transitionObject = _Transition(
        key, durationMillis, null, refreshRateMillis, delayMillis, false)
      ..start();
  }
  return transitionObject.currentValue;
}

/// Transitions a number from 0 to 1 inclusive in `durationMillis` milliseconds,
/// invoking `evaluate` with the number as parameter on every update.
///
/// Returns the key of the existing or created transition. The key can be used
/// to reference the transition from [transitionOf] or [Transitions].
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
///
/// Once the transition finishes, all references to it get cleared.
///
/// This function cannot be invoked from within a widget's [build].
/// Refer to [transition] for that use case.
///
/// See [Repeater.transition] to create more customized transitions.
Object transitionEval(
  int durationMillis,
  TransitionCallback evaluate, {
  int refreshRateMillis = 20,
  int delayMillis = 0,
  Object key,
}) {
  assert(() {
    if (FloopController.currentBuild != null) {
      print('Error: should not invoke [transitionEval] while a Floop Widget '
          'is building. Use [transition]` instead.');
      return false;
    }
    if (durationMillis == null || evaluate == null) {
      print('Error: bad inputs for [transitionEval], durationMillis '
          'and evaluate cannot be null.');
      return false;
    }
    return true;
  }());
  _Transition transitionObj;
  if (key != null) {
    transitionObj = _Transition.get(key);
  }
  key ??= _createKey();
  if (transitionObj == null) {
    _Transition(
      key,
      durationMillis,
      evaluate,
      refreshRateMillis,
      delayMillis,
    )..start();
  }
  return key;
}

/// [Transitions] allow manipulating the transitions created by this library.
///
/// For operations [pause], [resume], [restart] and [clear], parameters `key`
/// or `context` can be provided to apply the operation to the corresponding
/// specific transition (`key`) or group of them (`context`). If none of them
/// is specified, the operation is applied to all transitions. If both of them
/// are provided, only `key` is used.
///
/// The transitions registered to `context` are the ones that were created
/// while the context was building.
abstract class Transitions {
  /// Pauses transitions.
  ///
  /// Note that paused transitions that are not associated to any
  /// [BuildContext] will remain stored (taking memory) until they are resumed
  /// with [resume] or get disposed with [clear].
  static pause({Object key, BuildContext context}) {
    _applyToTransitions(_pause, key, context);
  }

  static _pause(_Transition t) => t?.stop();

  static resume({Object key, BuildContext context}) {
    _applyToTransitions(_resume, key, context);
  }

  static _resume(_Transition t) => t?.start();

  static resumeOrPause({Object key, BuildContext context}) {
    _applyToTransitions(_resumeOrPause, key, context);
  }

  static _resumeOrPause(_Transition t) {
    if (t?.isRunning == true) {
      t.stop();
    } else if (t != null) {
      t.start();
    }
  }

  /// Restarts transitions as if they were just created.
  ///
  /// For restarting context transitions, [clear] might be more suitable, since
  /// the transitions will be created again once the context rebuilds, while
  /// restarting them would cause transitions that are created within
  /// conditional statements to replay before the condition triggers.
  static restart({Object key, BuildContext context}) {
    _applyToTransitions(_restart, key, context);
  }

  static _restart(_Transition t) => t?.restart();

  /// Advances the transition by `advanceTimeMillis`.
  ///
  /// If `advanceTimeMillis` is null, the transition will be advanced to it's
  /// total duration time.
  static advance({int advanceTimeMillis, Object key, BuildContext context}) {
    _applyToTransitions(
        (_Transition t) => t?.advance(advanceTimeMillis), key, context);
  }

  /// Clear all transitions. Equivalent to invoking `Transitions.clear()`.
  static clearAll() =>
      _Transition.all().toList().forEach((t) => t.stopAndDispose());

  /// Stops and removes references to transitions.
  ///
  /// Particularly useful for causing a context to rebuild as if it was being
  /// built for the first time.
  static clear({Object key, BuildContext context}) {
    if (key == null && context == null) {
      clearAll();
    } else {
      _applyToTransitions(_clear, key, context);
    }
  }

  static _clear(_Transition t) => t?.stopAndDispose();
}

/// Integer version of [transitionNumber].
int transitionInt(int start, int end, int durationMillis,
    {int refreshRateMillis = 20, int delayMillis = 0, Object key}) {
  return (start +
          (end - start) *
              transition(durationMillis,
                  refreshRateMillis: refreshRateMillis,
                  delayMillis: delayMillis,
                  key: key))
      .toInt();
}

/// Invokes [transition] and scales the return value between `start` and `end`.
///
/// Can only be invoked from within [build] methods. See [transition] for
/// detailed documentation about transitions.
num transitionNumber(num start, num end, int durationMillis,
    {int refreshRateMillis = 20, int delayMillis = 0, Object key}) {
  return start +
      (end - start) *
          transition(durationMillis,
              refreshRateMillis: refreshRateMillis,
              delayMillis: delayMillis,
              key: key);
}

/// Transitions a string from length 0 to the full string.
///
/// Can only be invoked from within [build] methods. See [transition] for
/// detailed documentation about transitions.
String transitionString(String string, int durationMillis,
    {int refreshRateMillis = 20, int delayMillis = 0, Object key}) {
  int length = (string.length *
          transition(durationMillis,
              refreshRateMillis: refreshRateMillis,
              delayMillis: delayMillis,
              key: key))
      .toInt();
  return string.substring(0, length);
}

/// Transitions the value of `key` in the provided `map`.
///
/// The transition lasts for `durationMillis` and updates it's value
/// with a rate of `refreshRateMillis`.
///
/// Useful for easily transitiong an [ObservedMap] key-value and cause the
/// subscribed widgets to auto rebuild while the transition lasts.
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
    // var value = update(ratio);
    map[key] = update(ratio);
  }, refreshRateMillis: refreshRateMillis);
}

void _applyToTransitions(
    Function(_Transition) apply, Object key, BuildContext context) {
  if (key != null) {
    apply(_Transition.get(key));
  } else if (context != null) {
    _contextToKeys[context]?.forEach((key) => apply(_Transition.get(key)));
  } else {
    _Transition.all().forEach(apply);
  }
}

void _stopAndDispose(Object key) {
  _Transition.get(key)?.stopAndDispose();
}

void _clearContextTransitions(BuildContext context) {
  _contextToKeys.remove(context)?.forEach(_stopAndDispose);
}

/// Returns the current value of the transition registered to `key` if it
/// exists, `null` otherwise.
double transitionOf(Object key) {
  return _Transition.get(key)?.currentValue;
}

class _ObservedDouble {
  static final ObservedMap<int, double> _idToValue = ObservedMap();
  static int _lastId = 0;

  final int id;
  _ObservedDouble() : id = _lastId++ {
    _idToValue.setValue(id, 0, false);
  }

  double get value => _idToValue[id];
  set value(double value) => _idToValue[id] = value;

  dispose() => _idToValue.remove(id);
}

class _Transition extends Repeater {
  static final Map<Object, _Transition> _keyToTransition = Map();

  static _Transition get(key) => _keyToTransition[key];

  static Iterable<_Transition> all() => _keyToTransition.values;

  final Object key;
  final int durationMillis;
  final int delayMillis;
  final bool disposeOnFinish;
  final TransitionCallback evaluate;

  final _ObservedDouble observedRatio = _ObservedDouble();

  _Transition(this.key, this.durationMillis,
      [this.evaluate,
      int refreshRateMillis = 20,
      this.delayMillis = 0,
      this.disposeOnFinish = true])
      : super(null, refreshRateMillis, durationMillis + delayMillis) {
    if (_keyToTransition.containsKey(key)) {
      assert(() {
        print('Error: transition api error, attempting to create a '
            'transition that already exists.');
        return false;
      }());
      _keyToTransition[key].stopAndDispose();
    }
    _keyToTransition[key] = this;
  }

  int timeShift = 0;

  int get elapsedMilliseconds => super.elapsedMilliseconds + timeShift;

  double get progressRatio =>
      ((elapsedMilliseconds - delayMillis) / durationMillis)
          .clamp(0, 1)
          .toDouble();

  double get currentValue => observedRatio.value;

  stopAndDispose() {
    super.stop();
    _keyToTransition.remove(key);
    observedRatio.dispose();
  }

  reset([bool notUsed = true]) {
    timeShift = 0;
    super.reset(false);
  }

  restart() {
    reset();
    start();
  }

  advance([int timeMillis]) {
    timeMillis ??= durationMillis + delayMillis - super.elapsedMilliseconds;
    timeShift += timeMillis;
  }

  @override
  update() {
    double ratio = progressRatio;
    // Stop and dispose first in case `evaluate` callback creates a new
    // transition with the same key.
    if (ratio == 1 && disposeOnFinish) {
      stopAndDispose();
    }
    observedRatio.value = ratio;
    if (evaluate != null) {
      evaluate(ratio);
    }
  }
}
