import 'dart:async';

import './flutter_import.dart';
import './controller.dart';
import './observed.dart';
import './mixins.dart';
import './repeater.dart';

T _doubleAsType<T>(double x) => x as T;

final Map<BuildContext, Set<Object>> _contextToKeys = Map();

typedef MillisecondsReturner = int Function();

int neverRepeat() => -1;

/// var used just to force initialization of variables.
final _ = () {
  TransitionsParams.setDefaults();
}();

/// Returns the current value of the transition registered to `key` if it
/// exists, `null` otherwise.
double transitionOf(Object key) {
  return _TransitionState.of(key)?.lastSetProgressRatio;
}

/// Returns a number that transitions from 0 to 1 inclusive in `durationMillis`
/// milliseconds when invoked from inside a [build] method, automatically
/// rebuilding the widget as the transition progresses.
///
/// `durationMillis` must not be null.
///
/// `refreshPeriodicityMillis` is the periodicity at which the transition
/// attempts to update it's progress (the context rebuilds).
///
/// The transition can be delayed by `delayMillis`.
///
/// The transition will repeat after `repeatAfterMillis`. By default it will
/// not repeat.
///
/// A `key` can be specified to uniquely identify the transition and reference
/// it with [transitionOf] or to apply operations through [Transitions] API.
/// If `key` is non null and a transition registered to `key` exists, the
/// existing transition's value is returned. When invoked outside of a widget's
/// [build] method, `key` must specified.
///
/// `tags` are used to identify transitions by groups. Many transitions can have
/// the same tag or tags. They are useful to apply operations through
/// [Transitions] API.
///
/// When `key` is not provided, transitions are internally identified by all
/// the other input parameters. If any input parameter is different on a
/// context rebuild, a new transition will be created.
///
/// References to transitions created from within build methods are kept until
/// the build context is disposed or they are canceled through [Transitions]
/// API. Until they are disposed their clock keeps running even after they
/// have reached their full duration (number reaches 1).
///
/// [transitionEval] is a more flexibile function for creating transitions from
/// outside build methods. It accepts an evaluate function that is invoked
/// every time the transition updates its progress.
///
/// This method does not work inside builders, like [LayoutBuilder], as
/// builders build outside of the encompassing build method.
/// A workaround is to use a `var t = transition(...)` in the body of the
/// [build] method and then reference the var from within the builder body.
/// Another alternative is to define the transition with a key and then
/// reference it with [transitionOf].
///
/// Example:
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
///         ...onPressed: () => transitionEval(3000, evaluate: (t) => floop['y'] = t),
///         ...
///     ...
///   }
/// }
/// ```
///
/// In the example above, `x` transitions from 0 to 1 in five seconds when it
/// builds and `floop['y']` transitions from 0 to 1 in three seconds when there
/// is a click event. The `Text` widget will always display the updated values.
///
/// Created transitions references get cleared automatically when the
/// corresponding build context gets unmounted.
double transition(
  int durationMillis, {
  int refreshPeriodicityMillis = 20,
  int delayMillis = 0,
  int repeatAfterMillis,
  Object key,
  List<String> tags,
}) {
  FloopElement context = ObservedController.activeListener;
  final bool canCreate =
      durationMillis != null && (context != null || key != null);
  assert(() {
    if (durationMillis == null) {
      print('Error: [transition] was invoked with `durationMillis` as null. '
          'To retrieve the value of a keyed transition, use [transitionOf].');
    }
    if (!canCreate && key == null) {
      print('Error: When invoking [transition] outside a Floop widget\'s '
          'build method, the `key` parameter must be not null, otherwise the '
          'transition can have no effect outside of itself.\n'
          'See [transitionEval] to create transitions outside build methods. '
          'If this is getting invoked from within a [Builder], check '
          '[transition] docs to handle that case.');
      return false;
    }
    return true;
  }());
  if (canCreate && key == null) {
    final tagIdentifier = tags?.join('_');
    key = _createKey(
      context,
      durationMillis,
      delayMillis,
      repeatAfterMillis,
      tagIdentifier,
    );
  }
  var transitionState = _Registry.stateOfKey(key);
  if (!canCreate && transitionState == null) {
    return null;
  }
  assert(canCreate != null || transitionState != null);
  if (transitionState == null) {
    _addKeyToContext(key, context);
    tags = tags?.toList(growable: false);
    Transitions._newContextTransition(durationMillis, refreshPeriodicityMillis,
        delayMillis, repeatAfterMillis, key, tags);
  }
  return transitionState.lastSetProgressRatio;
}

/// Transitions a number from 0 to 1 inclusive in `durationMillis` milliseconds,
/// invoking `evaluate` with the number as parameter on every update.
///
/// Returns the key of the existing or created transition. The key can be used
/// to reference the transition from [transitionOf] or [Transitions].
///
/// `durationMillis` and `evaluate` must not be null.
///
/// `refreshPeriodicityMillis` is the periodicity in milliseconds at which the
/// transition refreshes it's value.
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
  int refreshPeriodicityMillis = 20,
  int delayMillis = 0,
  Object key,
}) {
  assert(() {
    if (ObservedController.isListening) {
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
  _TransitionState transitionObj;
  if (key != null) {
    transitionObj = _TransitionState.of(key);
  }
  key ??= _createKey();
  if (transitionObj == null) {
    _TransitionEval(
      key,
      durationMillis,
      evaluate,
      // refreshRateMillis,
      delayMillis,
    );
  }
  return key;
}

abstract class TransitionsParams {
  /// The default refresh periodicity for transitions.
  ///
  /// It defines how often a transition should update it's state. It is only
  /// used when the periodicity is not specified in the transition itself.
  static int refreshPeriodicityMillis = 25;

  /// The minimum size of time steps of transition updates.
  ///
  /// Defaults to the max granularity of one millisecond. It can be useful to
  /// set to bigger values to limit the transitions possible states. For
  /// example if it is set to the same value as [refreshPeriodicityMillis],
  /// then the transitions states will consistenly reproduce when shifting time
  /// forwards or backwards.
  static int timeGranularityMillis = 1;

  static final Stopwatch _stopwatch = Stopwatch();

  /// The clock used to measure the transitions progress.
  ///
  /// By default it returns the elapsed milliseconds of an internal stopwatch.
  static MillisecondsReturner referenceClock;

  static double _timeDilation;

  /// The specified time dilation factor in [setTimeDilatingClock].
  ///
  /// This factor does not necessarily correspond to the current time dilation,
  /// because [referenceClock] could be set directly.
  static double get lastTimeDilationFactor => _timeDilation;

  /// Sets a time dilating [referenceClock] that continues the current time.
  ///
  /// `dilationFactor` can be any double and it is used as a factor of the time
  /// measured by an internal stopwatch.
  static void setTimeDilatingClock(double dilationFactor) {
    _timeDilation = dilationFactor;
    final baseTime = referenceClock();
    final timeOffset = _stopwatch.elapsedMilliseconds;
    referenceClock = () {
      final dilatedTime =
          ((_stopwatch.elapsedMilliseconds - timeOffset) * dilationFactor)
              .toInt();
      final currentTime = baseTime + dilatedTime;
      return currentTime - (currentTime % timeGranularityMillis);
    };
  }

  /// Sets the default config values used by [Transitions].
  static void setDefaults() {
    refreshPeriodicityMillis = 25;
    timeGranularityMillis = 10;
    referenceClock =
        () => _stopwatch.elapsedMilliseconds % timeGranularityMillis;
    _stopwatch
      ..reset()
      ..start();
  }
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
  // static int _lastUpdateTime;

  /// `null` refreshRate represents the default refresh rate.
  static Map<int, _TransitionGroupUpdater> _refreshRateToGroup = Map();

  static _TransitionState _newContextTransition(
    int durationMillis,
    int periodicityMillis,
    int delayMillis,
    Object key,
    int repeatAfterMillis,
    List<String> tags,
  ) {
    final group = _refreshRateToGroup.putIfAbsent(
        periodicityMillis, () => _TransitionGroupUpdater(periodicityMillis));
    final state = _TransitionState(
        key, durationMillis, delayMillis, repeatAfterMillis, tags, group);
    _Registry.add(state);
    return state;
  }

  // static int lastUpdateTime() => _lastUpdateTime;

  // /// Updates the progress of transitions with given `refreshRate`.
  // static void _updateTransitionsProgress([int refreshRate]) {
  //   final transitionsToUpdate = _refreshRateToTransitions[refreshRate];
  //   for (var transition in transitionsToUpdate) {
  //     transition.update();
  //   }
  // }

  // static void _updateTransitionsCallback(int refreshRate) {
  //   final elapsedMillis = currentElapsedMillis;
  //   _lastUpdateTime =
  //       elapsedMillis - elapsedMillis % _transitionsMillisGranularity;
  //   final millisForNextCallback =
  //       _refreshRateMillis - (elapsedMillis - _lastUpdateTime);
  //   _updateTransitionsProgress(refreshRate);
  // }

  // static void _addTransition(_TransitionState t, int refreshRate) {
  //   _refreshRateToTransitions.putIfAbsent(refreshRate, () => Set()).add(t);
  //   refreshRate ??= TransitionsConfig.refreshPeriodicityMillis;
  //   Timer.periodic(Duration(milliseconds: refreshRate), (timer) {
  //     _updateTransitionsCallback(refreshRate);
  //   });
  //   Timer(Duration(milliseconds: millisForNextCallback),
  //       () => _updateTransitionsCallback(refreshRate));
  //   // ??= TransitionsConfig.refreshRateMillis
  // }

  /// Pauses transitions.
  ///
  /// Note that paused transitions that are not associated to any
  /// [BuildContext] will remain stored (taking memory) until they are resumed
  /// with [resume] or get disposed with [clear].
  static pause({Object key, BuildContext context}) {
    _applyToTransitions(_pause, key, context);
  }

  static _pause(_TransitionState t) => t?.pause();

  static resume({Object key, BuildContext context}) {
    _applyToTransitions(_resume, key, context);
  }

  static _resume(_TransitionState t) => t?.resume();

  static resumeOrPause({Object key, BuildContext context}) {
    _applyToTransitions(_resumeOrPause, key, context);
  }

  static _resumeOrPause(_TransitionState t) {
    if (t?.isPaused == false) {
      t.pause();
    } else if (t != null) {
      t.resume();
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

  static _restart(_TransitionState t) => t?.restart();

  /// Shifts the transition by `shiftTimeMillis`.
  ///
  /// If `shiftTimeMillis` is null, the transition will be advanced to it's
  /// total duration time (finished).
  ///
  /// Identical to [shiftTime], but this method will get removed in later
  /// versions to keep the more explicit shiftTime name.
  @deprecated
  static shift({int shiftTimeMillis, Object key, BuildContext context}) {
    _applyToTransitions(
        (_TransitionState t) => t?.shift(shiftTimeMillis), key, context);
  }

  /// Shifts the time of transitions by `shiftMillis`.
  ///
  /// If `shiftMillis` is null, the transition will be advanced to it's
  /// total duration time (finished).
  static shiftTime({int shiftMillis, Object key, BuildContext context}) {
    _applyToTransitions(
        (_TransitionState t) => t?.shift(shiftMillis), key, context);
  }

  /// Clear all transitions. Equivalent to invoking `Transitions.clear()`.
  static clearAll() =>
      _TransitionState.all().toList().forEach((t) => t.dispose());

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

  static _clear(_TransitionState t) => t?.dispose();
}

const oneSecondInMillis = 1000;

class _TransitionGroupUpdater {
  static int get currentTime => TransitionsParams.referenceClock();
  static int get stopwatchCurrent =>
      TransitionsParams._stopwatch.elapsedMilliseconds;

  final _transitions = Set<_TransitionState>();

  final int _periodicityMillis;
  int get periodicityMillis =>
      _periodicityMillis ?? TransitionsParams.refreshPeriodicityMillis ?? 0;

  /// Number of frames per second (with updated transition progress).
  double refreshRate;

  int _updateTime;
  int get updateTime => _updateTime;

  Duration _referenceTimeStamp;

  int _targetUpdateTime;

  Duration get lastFrameUpdateTimeStamp =>
      WidgetsBinding.instance.currentSystemFrameTimeStamp;

  bool get willUpdate =>
      _referenceTimeStamp == lastFrameUpdateTimeStamp ||
      currentTime < _targetUpdateTime + periodicityMillis;

  _refreshUpdateValues() {
    final now = currentTime;
    refreshRate = oneSecondInMillis / (now - _updateTime);
    _updateTime = now;
  }

  _TransitionGroupUpdater(this._periodicityMillis) : _updateTime = currentTime;

  _delayedUpdate(_) {
    _referenceTimeStamp = lastFrameUpdateTimeStamp;
    final timeToNextUpdate = _targetUpdateTime - stopwatchCurrent;
    Future.delayed(Duration(milliseconds: timeToNextUpdate), performUpdates);
  }

  /// Updates are performed by two chained async callbacks. The first one waits
  /// for Flutter to render a new frame. The second one in [_delayedUpdate]
  /// waits for the time remaining. This ensures that the refresh rate
  /// corresponds to the UI rendering updates.
  _updateNext() {
    _targetUpdateTime = stopwatchCurrent + periodicityMillis;
    _referenceTimeStamp = lastFrameUpdateTimeStamp;
    WidgetsBinding.instance.addPostFrameCallback(_delayedUpdate);
  }

  add(_TransitionState transitionState) {
    _transitions.add(transitionState);
    assert(transitionState.group == this);
    activatePeriodicUpdates();
  }

  activatePeriodicUpdates() {
    if (!willUpdate) {
      _updateNext();
    }
  }

  performUpdates() {
    _refreshUpdateValues();
    bool active = false;
    for (var transition in _transitions) {
      active |= transition.update();
    }
    if (active) {
      _updateNext();
    }
  }
}

Set<T> _createEmptySet<T>() => Set();

class _Registry {
  static final Map<Object, _TransitionState> _keyToTransition = Map();
  static final Map<String, Set<_TransitionState>> _tagToTransitions = Map();

  static _TransitionState stateOfKey(Object key) => _keyToTransition[key];

  static Iterable<_TransitionState> statesForTag(String tag) =>
      _tagToTransitions[tag];

  static Iterable<_TransitionState> all() => _keyToTransition.values;

  static add(_TransitionState transitionState) {
    final key = transitionState.key;
    if (_keyToTransition.containsKey(key)) {
      assert(() {
        print('Error: transitions API error, attempting to create a '
            'transition that already exists.');
        return false;
      }());
      _keyToTransition[key].dispose();
    }
    _keyToTransition[key] = transitionState;
    for (var tag in transitionState.tags) {
      _tagToTransitions.putIfAbsent(tag, _createEmptySet).add(transitionState);
    }
  }

  static remove(_TransitionState transitionState) {
    _keyToTransition.remove(transitionState.key);
    for (var tag in transitionState.tags) {
      assert(_tagToTransitions.containsKey(tag));
      _tagToTransitions[tag]?.remove(transitionState);
    }
  }
}

enum _Status {
  active,
  inactive,
  defunct,
}

const _mediumInt = 1 << 31;
const _largeInt = 1 << 52 | (1 << 31);

class _TransitionBase with FastHashCode {}

class _TransitionState with FastHashCode {
  static final Map<Object, _TransitionState> _keyToTransition = Map();

  factory _TransitionState.of(Object key) => _keyToTransition[key];

  static Iterable<_TransitionState> all() => _keyToTransition.values;

  /// Variables for external use (avoids extra maps)
  final Object key;
  final Iterable<String> tags;
  final _TransitionGroupUpdater group;

  /// State variables
  final int durationMillis;
  final int delayMillis;
  final int repeatAfterMillis;

  int get aggregatedDuration => durationMillis + delayMillis;

  final ObservedValue<double> observedRatio = ObservedValue(0);

  double get lastSetProgressRatio => observedRatio.value;

  _TransitionState(
    this.key,
    this.durationMillis, [
    // this.evaluate,
    // int refreshRateMillis = 20,
    this.delayMillis = 0,
    this.repeatAfterMillis,
    this.tags,
    this.group,
  ]) {
    // if (_keyToTransition.containsKey(key)) {
    //   assert(() {
    //     print('Error: transition api error, attempting to create a '
    //         'transition that already exists.');
    //     return false;
    //   }());
    //   _keyToTransition[key].dispose();
    // }
    baseTime = clockMillis;
    group.add(this);
    // _keyToTransition[key] = this;
  }

  int baseTime;
  int shiftedMillis = 0;
  int _pauseTime;

  _Status _status = _Status.active;

  /// Active should represent (elapsedMillis < aggregatedDuration) on the last
  /// update.
  bool get isActive => _status == _Status.active;

  /// Pause is different from active, a transition only reaches inactive status
  /// when it finishes (reaches its max duration).
  bool get isPaused => _pauseTime != null;

  int get clockMillis => _pauseTime ?? TransitionsParams.referenceClock();

  int get elapsedMillis => clockMillis + shiftedMillis - baseTime;

  double computeProgressRatio([int timeMillis]) =>
      (((timeMillis ?? elapsedMillis) - delayMillis) / durationMillis)
          .clamp(0, 1)
          .toDouble();

  pause() {
    _pauseTime = clockMillis;
  }

  resume() {
    if (isPaused) {
      shiftedMillis += _pauseTime - clockMillis;
      _pauseTime = null;
    }
  }

  reset() {
    baseTime = clockMillis;
    if (isPaused) {
      _pauseTime = baseTime;
    }
    shiftedMillis = 0;
    activate();
  }

  restart() {
    reset();
    resume();
  }

  shift([int shiftMillis]) {
    // If shiftMillis is null, shift to total duration
    shiftMillis ??= aggregatedDuration - elapsedMillis;
    shiftedMillis += shiftMillis;
    if (!isActive && elapsedMillis < aggregatedDuration) {
      activate();
    }
  }

  dispose() {
    assert(_status == _Status.inactive);
    _keyToTransition.remove(key);
    observedRatio.dispose();
    assert(() {
      _status = _Status.defunct;
      return true;
    }());
  }

  int referenceElapsedMillis;

  activate() {
    _status = _Status.active;
    group.activatePeriodicUpdates();
  }

  _repeatOrDeactivate() {
    if (repeatAfterMillis >= 0) {
      baseTime = elapsedMillis + repeatAfterMillis;
    } else {
      _status = _Status.inactive;
    }
  }

  _updateStatusOrRepeat() {
    if (referenceElapsedMillis >= aggregatedDuration) {
      if (isActive) {
        _repeatOrDeactivate();
      }
    } else if (!isActive) {
      activate();
    }
  }

  /// Updates the transition state and progress ratio.
  update() {
    assert(_status != _Status.defunct);
    referenceElapsedMillis = elapsedMillis;
    _updateStatusOrRepeat();
    double ratio = computeProgressRatio(referenceElapsedMillis);
    observedRatio.value = ratio;
    return isActive;
  }
}

class _TransitionEval extends _TransitionState {
  final TransitionCallback evaluate;

  _TransitionEval(
    key,
    durationMillis, [
    this.evaluate,
    // int refreshRateMillis = 20,
    delayMillis = 0,
  ]) : super(key, durationMillis, delayMillis);

  @override
  update() {
    super.update();
    evaluate(observedRatio.value);
    if (!isActive) {
      dispose();
    }
  }
}

class _MultiKey extends LocalKey {
  final a, b, c, d, e;
  final int _hash;

  _MultiKey([this.a, this.b, this.c, this.d, this.e])
      : _hash = hashValues(a, b, c, d, e);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _MultiKey &&
        this.a == other.a &&
        this.b == other.b &&
        this.c == other.c &&
        this.d == other.d &&
        this.e == other.e;
  }

  @override
  int get hashCode => _hash;
}

typedef TransitionCallback = Function(double elapsedToDurationRatio);
typedef ValueCallback<V> = V Function(V transitionValue);

Key _createKey([context, duration, delay, repeatAfter, tagIdentifier]) {
  if (context != null) {
    return _MultiKey(context, duration, delay, repeatAfter, tagIdentifier);
  } else {
    return UniqueKey();
  }
}

_addKeyToContext(key, FloopBuildContext context) {
  assert(key != null && context != null);
  var contextKeys = _contextToKeys[context];
  if (contextKeys == null) {
    contextKeys = Set();
    _contextToKeys[context] = contextKeys;
    context.addUnmountCallback(() => _clearContextTransitions(context));
  }
  contextKeys.add(key);
}

void _applyToTransitions(
    Function(_TransitionState) apply, Object key, BuildContext context) {
  if (key != null && _TransitionState._keyToTransition.containsKey(key)) {
    apply(_TransitionState.of(key));
  } else if (context != null) {
    _contextToKeys[context]?.forEach((key) => apply(_TransitionState.of(key)));
  } else {
    _TransitionState.all().forEach(apply);
  }
}

void _stopAndDispose(Object key) {
  _TransitionState.of(key)?.dispose();
}

void _clearContextTransitions(FloopBuildContext element) {
  _contextToKeys.remove(element)?.forEach(_stopAndDispose);
}

/// Integer version of [transitionNumber].
int transitionInt(int start, int end, int durationMillis,
    {int refreshRateMillis = 20, int delayMillis = 0, Object key}) {
  return (start +
          (end - start) *
              transition(durationMillis,
                  refreshPeriodicityMillis: refreshRateMillis,
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
              refreshPeriodicityMillis: refreshRateMillis,
              delayMillis: delayMillis,
              key: key);
}

/// Transitions a string starting from length 0 to it's full length.
///
/// Can only be invoked from within [build] methods. See [transition] for
/// detailed documentation about transitions.
String transitionString(String string, int durationMillis,
    {int refreshRateMillis = 20, int delayMillis = 0, Object key}) {
  int length = (string.length *
          transition(durationMillis,
              refreshPeriodicityMillis: refreshRateMillis,
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
