import 'dart:async';

import './flutter_import.dart';
import './controller.dart';
import './observed.dart';
import './mixins.dart';
import './repeater.dart';

T _doubleAsType<T>(double x) => x as T;

final Map<BuildContext, Set<Object>> _contextToKeys = Map();

typedef MillisecondsReturner = int Function();

const _largeInt = 1 << 62 | 1 << 53 | (1 << 31);

/// Returns the current value of the transition registered to `key` if it
/// exists, `null` otherwise.
double transitionOf(Object key) {
  return _Registry.getForKey(key)?.lastSetProgressRatio;
}

/// Returns a number that transitions from 0 to 1 inclusive in `durationMillis`
/// milliseconds when invoked from inside a [build] method, automatically
/// rebuilding the widget as the transition progresses.
///
/// `durationMillis` must not be null.
///
/// `refreshPeriodicityMillis` is the periodicity at which the transition
/// attempts to update it's progress (the context rebuilds). Defaults to
/// [TransitionsConfig.refreshPeriodicityMillis].
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
/// `tag` is similar to `key` but it is not unique. Many transitions can have
/// the same tag. They are only useful to apply operations through
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
  int refreshPeriodicityMillis,
  int delayMillis = 0,
  int repeatAfterMillis,
  Object key,
  String tag,
}) {
  FloopElement context = ObservedController.activeListener;
  final bool canCreate = context != null || key != null;
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
    key = _createKey(
      context,
      durationMillis,
      delayMillis,
      repeatAfterMillis,
      tag,
    );
  }
  var transitionState = _Registry.getForKey(key);
  if (!canCreate && transitionState == null) {
    return null;
  }
  assert(canCreate != null || transitionState != null);
  if (transitionState == null) {
    // _addKeyToContext(key, context);
    // transitionState = Transitions._newContextTransition(
    //     context,
    //     key,
    //     durationMillis,
    //     refreshPeriodicityMillis,
    //     delayMillis,
    //     repeatAfterMillis,
    //     tag);
    transitionState = _TransitionState(
        key, durationMillis, delayMillis, repeatAfterMillis, tag, context);
    _Transitions.addContextTransition(
        context, transitionState, refreshPeriodicityMillis);
  }
  assert(transitionState.lastSetProgressRatio != null);
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
/// transition refreshes it's value and invokes evaluate. Defaults to
/// [TransitionsConfig.refreshPeriodicityMillis]
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
  RatioEvaluator evaluate, {
  int refreshPeriodicityMillis,
  int delayMillis = 0,
  int repeatAfterMillis,
  Object key,
  String tag,
}) {
  assert(() {
    if (ObservedController.isListening) {
      print('Error: should not invoke [transitionEval] while a Floop Widget '
          'is building. Use [transition]` instead.');
      return false;
    }
    if (durationMillis == null || evaluate == null) {
      print('Error: bad inputs for [transitionEval], durationMillis or '
          'evaluate cannot be null.');
      return false;
    }
    return true;
  }());
  _TransitionState transitionState;
  if (key != null) {
    transitionState = _Registry.getForKey(key);
  }
  key ??= _createKey();
  if (transitionState == null) {
    // Transitions._newTransitionEval(key, durationMillis, evaluate,
    //     refreshPeriodicityMillis, delayMillis, repeatAfterMillis, tag);
    transitionState = _TransitionEvalState(
        key, durationMillis, evaluate, delayMillis, repeatAfterMillis, tag);
    _Transitions.addTransition(transitionState, refreshPeriodicityMillis);

    // _TransitionEvalState(
    //   key,
    //   durationMillis,
    //   evaluate,
    //   // refreshRateMillis,
    //   delayMillis,
    //   repeatAfterMillis,

    // );
  }
  return key;
}

abstract class TransitionsConfig {
  /// The default refresh periodicity for transitions.
  ///
  /// It defines how often a transition should update it's state. It is only
  /// used when the periodicity is not specified in the transition itself.
  ///
  /// Set to 0 to get the maximum possible refresh rate.
  static int _refreshPeriodicityMillis = 20;
  static int get refreshPeriodicityMillis => _refreshPeriodicityMillis;
  static set refreshPeriodicityMillis(int newPeriodicityMillis) {
    assert(newPeriodicityMillis != null && newPeriodicityMillis >= 0);
    _refreshPeriodicityMillis = newPeriodicityMillis;
  }

  /// The minimum size of time steps of transition updates.
  ///
  /// Defaults to the max granularity of one millisecond. It can be useful to
  /// set to bigger values to limit the transitions possible states. For
  /// example if it is set to the same value as [refreshPeriodicityMillis],
  /// then the transitions states will consistenly reproduce when shifting time
  /// forwards or backwards.
  static int timeGranularityMillis = 1;

  static final Stopwatch _stopwatch = Stopwatch();

  static MillisecondsReturner _referenceClock;

  /// The clock used to measure the transitions progress.
  ///
  /// It could be any function, so it shouldn't be used as a reliable source
  /// for real time measuring. By default it returns the elapsed milliseconds
  /// of an internal stopwatch.
  static MillisecondsReturner get referenceClock => _referenceClock;

  static set referenceClock(MillisecondsReturner clock) {
    _referenceClock = clock;
    _Transitions.refreshAll();
  }

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
    refreshPeriodicityMillis = 20;
    timeGranularityMillis = 10;
    referenceClock = () =>
        _stopwatch.elapsedMilliseconds -
        _stopwatch.elapsedMilliseconds % timeGranularityMillis;
    _stopwatch
      ..reset()
      ..start();
  }

  /// null var used as a hack to force initialization of config parameters.
  static final _initialize = () {
    TransitionsConfig.setDefaults();
    return null;
  }();
}

abstract class _Transitions {
  /// `null` refreshPeriodicity represents the default refresh rate.
  static Map<int, _TransitionGroupUpdater> _refreshPeriodicityToGroup = Map();

  // static _TransitionState _newContextTransition(
  //   BuildContext context,
  //   Object key,
  //   int durationMillis,
  //   int periodicityMillis,
  //   int delayMillis,
  //   int repeatAfterMillis,
  //   String tag,
  // ) {
  //   final group = _refreshPeriodicityToGroup.putIfAbsent(
  //       periodicityMillis, () => _TransitionGroupUpdater(periodicityMillis));
  //   final state = _TransitionState(key, durationMillis, delayMillis,
  //       repeatAfterMillis, tag, group, context);
  //   _Registry.register(state);
  //   return state;
  // }

  static void addTransition(
      _TransitionState transitionState, int periodicityMillis) {
    final group = _refreshPeriodicityToGroup.putIfAbsent(
        periodicityMillis, () => _TransitionGroupUpdater(periodicityMillis));
    group.add(transitionState);
    _Registry.register(transitionState);
  }

  static void addContextTransition(FloopBuildContext context,
      _TransitionState transitionState, int periodicityMillis) {
    assert(context != null && context == transitionState.context);
    if (!_Registry.contextIsRegistered(context)) {
      context.addUnmountCallback(() => _removeContext(context));
    }
    addTransition(transitionState, periodicityMillis);
  }

  static void _removeTransition(_TransitionState transitionState) {
    transitionState.group.removeTransition(transitionState..dispose());
  }

  static void _removeContext(BuildContext context) {
    _Registry.unregisterContext(context)..forEach(_removeTransition);
  }

  // static _unregisterTransition(_TransitionState t) {
  //   return () {
  //     _Registry._unregisterFromKeyAndTag(t);
  //     t.dispose();
  //   };
  // }

  // static _unregisterContext(BuildContext context) {
  //   _Registry._removeContext(context).forEach(_unregisterTransition);
  // }

  static void refreshAll() {
    for (var group in _refreshPeriodicityToGroup.values) {
      if (group.update()) {
        group.activatePeriodicUpdates();
      }
    }
  }
}

/// [Transitions] allow manipulating the transitions created by this library.
///
/// For operations [pause], [resume], [restart] and [cancel], parameters `key`
/// `tag` or `context` can be provided to apply the operation to the
/// corresponding specific transition (`key`) or group of them (`context`). If
/// none of them is specified, the operation is applied to all transitions. If
/// both of them are provided, only `key` is used.
///
/// The transitions registered to `context` are the ones that were created
/// while the context was building.
abstract class Transitions {
  static setTimeDilation(double dilationFactor) {
    TransitionsConfig.setTimeDilatingClock(dilationFactor);
    _Transitions.refreshAll();
  }
  // static int _lastUpdateTime;

  // static _TransitionState _newTransitionEval(
  //   Object key,
  //   int durationMillis,
  //   RatioEvaluator evaluate,
  //   int periodicityMillis,
  //   int delayMillis,
  //   int repeatAfterMillis,
  //   String tag,
  // ) {
  //   final group = _refreshPeriodicityToGroup.putIfAbsent(
  //       periodicityMillis, () => _TransitionGroupUpdater(periodicityMillis));
  //   final state = _TransitionEvalState(key, durationMillis, evaluate,
  //       delayMillis, repeatAfterMillis, tag, group);
  //   _Registry.register(state);
  //   return state;
  // }

  /// Returns the last measured refresh rate in Herz (updates per second) of
  /// transitions with the default [TransitionsConfig.refreshPeriodicityMillis]
  /// or with `refreshPeriodicityMillis` if provided.
  ///
  /// `null` is returned if no transitions have been created for the refresh
  /// periodicity.
  ///
  /// If the Flutter engine is not under stress, the refresh rate should be
  /// close to the inverse of the refresh periodicty. For example if the
  /// periodicity is 50 milliseconds, the refreh rate should be 20 Hz.
  ///
  /// When [TransitionsConfig.refreshPeriodicityMillis] is 0 the Flutter engine
  /// will be forcefully stressed to render new frames as soon as possible, by
  /// updating transitions immediately after each frame renders.
  double currentRefreshRate([int refreshPeriodicityMillis]) {
    return _Transitions
        ._refreshPeriodicityToGroup[refreshPeriodicityMillis]?.refreshRate;
  }

  static _resumePeriodicUpdates(_TransitionState t) {
    t.group.updateTransition(t);
    if (t.shouldKeepUpdating) {
      t.group.activatePeriodicUpdates();
    }
  }

  /// Pauses transitions.
  ///
  /// Note that paused transitions that are not associated to any
  /// [BuildContext] will remain stored (taking memory) until they are resumed
  /// with [resume] or get disposed with [cancel].
  static pause({Object key, BuildContext context}) {
    _applyToTransitions(_pause, key, context);
  }

  static _pause(_TransitionState t) => t.pause();

  static resume({Object key, BuildContext context}) {
    _applyToTransitions(_resume, key, context);
  }

  static _resume(_TransitionState t) {
    _resumePeriodicUpdates(t..resume());
  }

  static resumeOrPause({Object key, BuildContext context}) {
    _applyToTransitions(_resumeOrPause, key, context);
  }

  static _resumeOrPause(_TransitionState t) {
    if (t.isPaused) {
      _resume(t);
    } else {
      _pause(t);
    }
  }

  /// Restarts transitions as if they were just created.
  ///
  /// For restarting context transitions, [cancel] might be more suitable, since
  /// the transitions will be created again once the context rebuilds, while
  /// restarting them would cause transitions that are created within
  /// conditional statements to replay before the condition triggers.
  static restart({Object key, BuildContext context}) {
    _applyToTransitions(_restart, key, context);
  }

  static _restart(_TransitionState t) => _resumePeriodicUpdates(t..restart());

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
        (_TransitionState t) => _resumePeriodicUpdates(t..shift(shiftMillis)),
        key,
        context);
  }

  // static _shift(_TransitionState t, int shiftMillis) {
  //   _resumePeriodicUpdates(t..shift(shiftMillis));
  // }

  /// Clear all transitions. Equivalent to invoking `Transitions.clear()`.
  static cancelAll() => _Registry.all().toList().forEach(_cancel);

  /// Stops and removes references to transitions.
  ///
  /// Particularly useful for causing a context to rebuild as if it was being
  /// built for the first time.
  static cancel({Object key, BuildContext context}) {
    if (key == null && context == null) {
      cancelAll();
    } else {
      _applyToTransitions(_cancel, key, context);
    }
  }

  static _cancel(_TransitionState t) {
    t.observedRatio.notifyChange();
    _Transitions._removeTransition(t);
  }
}

const oneSecondInMillis = 1000;

class _TransitionGroupUpdater {
  static get _stopwatchPlainTime =>
      TransitionsConfig._stopwatch.elapsedMilliseconds;

  final _transitions = Set<_TransitionState>();

  _TransitionGroupUpdater(this._periodicityMillis) {
    _updateTimeStep = currentClockTimeStep;
  }

  final int _periodicityMillis;
  int get periodicityMillis =>
      _periodicityMillis ?? TransitionsConfig._refreshPeriodicityMillis;

  /// Returns the number truncated to a periodicity multiple.
  int truncateTime(int number) {
    // The periodicity is clamped in case it were 0.
    number -= number % periodicityMillis.clamp(1, _largeInt);
    return number;
  }

  /// Times used for updating. Update times used are multiples of the
  /// periodicity. This way the transitions of the same refresh periodicity
  /// are synchronized.

  /// Time measured directly from a stopwatch.
  ///
  /// Used for calculating the refresh rate with real time and not not scaled,
  /// paused, rounded, etc, like [currentClockTimeStep] could be.
  int _lastPlainTime = 0;

  /// The current clock time as multiple of the periodicity.
  int get currentClockTimeStep {
    int time = TransitionsConfig.referenceClock();
    return truncateTime(time);
  }

  /// The target update time for the next update.
  ///
  /// It's null when no future updates are going to be performed.
  int _targetUpdateTime = -_largeInt;

  /// The last performed update time.
  int _updateTimeStep;

  refreshUpdateTimeStep() {
    _updateTimeStep = truncateTime(TransitionsConfig.referenceClock());
  }

  /// Number of frames per second (with updated transition progress).
  double refreshRate;

  /// This time stamp is used to record whether or not an update callback is
  /// queued before a new frame is rendered. If the app slows down, the updates
  /// will slow down accordingly.
  Duration _referenceTimeStamp;

  Duration get lastFrameUpdateTimeStamp =>
      WidgetsBinding.instance.currentSystemFrameTimeStamp;

  /// Whether a future update is scheduled.
  ///
  /// If _targetUpdateTime!=null a fugure update should be scheduled. The
  /// second condition is used as a safety mechanism in case there is an error
  /// somewhere and _tagetUpdateTime is never set to null.
  bool get willUpdate =>
      _targetUpdateTime != null &&
      (_referenceTimeStamp == lastFrameUpdateTimeStamp ||
          _stopwatchPlainTime < _targetUpdateTime + periodicityMillis);

  _updateRefreshRateAndPlainTime() {
    final now = _stopwatchPlainTime;
    refreshRate = oneSecondInMillis / (now - _lastPlainTime);
    _lastPlainTime = now;
  }

  _delayedUpdate(_) {
    _referenceTimeStamp = lastFrameUpdateTimeStamp;
    final timeToNextUpdate = _targetUpdateTime - _stopwatchPlainTime;
    Future.delayed(Duration(milliseconds: timeToNextUpdate), _updateCallback);
  }

  /// Updates are performed by two chained async callbacks. The first one waits
  /// for Flutter to render a new frame. The second one in [_delayedUpdate]
  /// waits for the time remaining. This ensures that the refresh rate
  /// corresponds to the UI refresh rate.
  _updateNext() {
    _targetUpdateTime = _lastPlainTime + periodicityMillis;
    _referenceTimeStamp = lastFrameUpdateTimeStamp;
    WidgetsBinding.instance.addPostFrameCallback(_delayedUpdate);
  }

  add(_TransitionState transitionState) {
    transitionState.group = this;
    _transitions.add(transitionState);
    // transitionState.shiftedMillis = nextUpdateTime;
    assert(transitionState.group == this);
    activatePeriodicUpdates();
  }

  activatePeriodicUpdates() {
    if (!willUpdate) {
      _lastPlainTime = _stopwatchPlainTime;
      _updateNext();
    }
  }

  updateTransition(_TransitionState transitionState) {
    assert(_transitions.contains(transitionState));
    transitionState.update(_updateTimeStep);
    if (transitionState._status == _Status.defunct) {
      removeTransition(transitionState);
    }
  }

  removeTransition(_TransitionState transitionState) {
    assert(transitionState._status == _Status.defunct);
    _transitions.remove(transitionState);
    _Registry.unregister(transitionState);
  }

  _updateCallback() {
    _targetUpdateTime = null;
    _updateRefreshRateAndPlainTime();
    refreshUpdateTimeStep();
    if (update()) {
      _updateNext();
    }
  }

  bool update() {
    bool active = false;
    for (var transitionState in _transitions) {
      updateTransition(transitionState);
      active |= transitionState.shouldKeepUpdating;
    }
    return active;
  }
}

Set<T> _createEmptySet<T>() => Set();

class _Registry {
  static final Map<BuildContext, Set<_TransitionState>> _contextToTransitions =
      Map();
  static final Map<Object, _TransitionState> _keyToTransition = Map();
  static final Map<String, Set<_TransitionState>> _tagToTransitions = Map();

  static _TransitionState getForKey(Object key) => _keyToTransition[key];

  static Iterable<_TransitionState> getForTag(String tag) =>
      _tagToTransitions[tag];

  static Iterable<_TransitionState> getForContext(BuildContext context) =>
      _contextToTransitions[context];

  static bool contextIsRegistered(BuildContext context) =>
      _contextToTransitions.containsKey(context);

  static Iterable<_TransitionState> all() => _keyToTransition.values;

  static register(_TransitionState transitionState) {
    final key = transitionState.key;
    assert(key != null);
    if (_keyToTransition.containsKey(key)) {
      assert(() {
        print('Error: transitions API error, attempting to create a '
            'transition that already exists.');
        return false;
      }());
      unregister(_keyToTransition[key]);
    }
    _keyToTransition[key] = transitionState;
    if (transitionState.tag != null) {
      _tagToTransitions
          .putIfAbsent(transitionState.tag, _createEmptySet)
          .add(transitionState);
    }
    if (transitionState.context != null) {
      _contextToTransitions
          .putIfAbsent(transitionState.context, _createEmptySet)
          .add(transitionState);
    }
  }

  // static void _associateTransitionToContext(
  //     FloopBuildContext context, _TransitionState transitionState) {
  //   assert(transitionState.key != null && context != null);
  //   var contextKeys = _contextToTransitions[context];
  //   if (contextKeys == null) {
  //     contextKeys = Set();
  //     _contextToTransitions[context] = contextKeys;
  //   }
  //   contextKeys.add(transitionState);
  // }

  static unregister(_TransitionState transitionState) {
    assert(transitionState != null);
    _keyToTransition.remove(transitionState.key);
    _tagToTransitions[transitionState.tag]?.remove(transitionState);
    _contextToTransitions[transitionState.context]?.remove(transitionState);
  }

  // static Iterable<_TransitionState> _removeContext(BuildContext context) {
  //   assert(_contextToTransitions.containsKey(context));
  //   return _contextToTransitions.remove(context);
  // }

  static Iterable<_TransitionState> unregisterContext(BuildContext context) {
    return _contextToTransitions.remove(context);
  }

  // static _unregisterKey(Object key) {
  //   assert(_keyToTransition.containsKey(key));
  //   _keyToTransition.remove(key);
  // }

  // static _unregisterFromKeyAndTag(_TransitionState transitionState) {
  //   assert(_keyToTransition.containsKey(transitionState.key));
  //   _keyToTransition.remove(transitionState.key);
  //   if (transitionState.tag != null) {
  //     assert(transitionState.tag != null &&
  //         _tagToTransitions[transitionState.tag].contains(transitionState));
  //     _tagToTransitions[transitionState.tag].remove(transitionState);
  //   }
  // }
}

/// Disposes the transition. [_Registry.unregister] gets called at some point.
// _disposeTransition(_TransitionState transitionState) =>
//     transitionState.dispose();

enum _Status {
  active,
  inactive,
  defunct,
}

// const _mediumInt = 1 << 31;
// const _largeInt = 1 << 52 | (1 << 31);

// class _TransitionBase with FastHashCode {}

class _TransitionState with FastHashCode {
  // static final Map<Object, _TransitionState> _keyToTransition = Map();

  // factory _TransitionState.of(Object key) => _keyToTransition[key];

  // static Iterable<_TransitionState> all() => _keyToTransition.values;

  // static ObservedMap<Object, double> _keyToRatio = ObservedMap();

  /// Variables saved as storage for external use (avoids creating extra maps).
  final Object key;
  final String tag;
  final FloopBuildContext context;
  _TransitionGroupUpdater group;

  /// State variables
  final int durationMillis;
  final int delayMillis;
  final int repeatAfterMillis;

  int get aggregatedDuration => durationMillis + delayMillis;

  final ObservedValue<double> observedRatio = ObservedValue(0);

  double setProgressRatio(double ratio) => observedRatio.value = ratio;
  double get lastSetProgressRatio => observedRatio.value;

  // double setProgressRatio(double ratio) => _keyToRatio[key] = ratio;
  // double get lastSetProgressRatio => _keyToRatio[key];

  _TransitionState(
    this.key,
    this.durationMillis, [
    // this.evaluate,
    // int refreshRateMillis = 20,
    this.delayMillis,
    this.repeatAfterMillis,
    this.tag,
    // this.group,
    this.context,
  ]) :
        // TransitionsConfig_initialized is written just to reference it, otherwise
        // the compiler tree shaking might leave the variable out and config is
        // never initialized. This is a hack.
        shiftedMillis = TransitionsConfig._initialize ?? 0
  //  {
  // if (_keyToRatio.containsKey(key)) {
  //   assert(() {
  //     print('Error: transition api error, attempting to create a '
  //         'transition that already exists.');
  //     return false;
  //   }());
  // }
  // TransitionsConfig_initialized is written just to reference it, otherwise
  // the compiler tree shaking might leave the variable out and config is
  // never initialized.
  // TransitionsConfig._initialize;
  // assert(!_keyToRatio.containsKey(key));
  // shiftedMillis = -clockMillis;
  // _keyToRatio[key] = 0;
  // _keyToTransition[key] = this;
  // }
  {
    _Registry.register(this);
  }

  bool matches(String refTag, BuildContext refContext) =>
      (refTag == null || tag == refTag) &&
      (refContext == null || context == refContext);

  int cycleMillis = 0;
  int shiftedMillis;
  int _pauseTime;

  _Status _status = _Status.active;

  /// Active represents elapsedMillis < aggregatedDuration on the last update.
  bool get isActive => _status == _Status.active;

  /// Pause is different from active, a transition only reaches inactive status
  /// when it finishes (reaches its max duration).
  bool get isPaused => _pauseTime != null;

  /// Whether this transition should keep updating periodically.
  bool get shouldKeepUpdating => isActive && !isPaused;

  int get clockMillis => _pauseTime ?? TransitionsConfig.referenceClock();

  int get elapsedMillis => clockMillis + shiftedMillis - cycleMillis;

  int computeElapsedMillis(int timeMillis) =>
      timeMillis + shiftedMillis - cycleMillis;

  double computeProgressRatio([int timeMillis]) =>
      (((timeMillis ?? elapsedMillis) - delayMillis) / durationMillis)
          .clamp(0, 1)
          .toDouble();

  pause() {
    _pauseTime = lastUpdateElapsedMillis;
  }

  resume() {
    if (isPaused) {
      shiftedMillis += _pauseTime - clockMillis;
      _pauseTime = null;
    }
  }

  reset() {
    cycleMillis = clockMillis;
    if (isPaused) {
      _pauseTime = cycleMillis;
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

  /// Invoked when the transition is not going to be used again.
  dispose() {
    assert(_status != _Status.defunct);
    observedRatio.dispose();
    _status = _Status.defunct;
  }

  int lastUpdateElapsedMillis = 0;

  activate() {
    _status = _Status.active;
  }

  _repeatOrDeactivate() {
    if (repeatAfterMillis != null) {
      cycleMillis += aggregatedDuration + repeatAfterMillis;
    } else {
      _status = _Status.inactive;
    }
  }

  _updateStatusOrRepeat() {
    if (lastUpdateElapsedMillis >= aggregatedDuration) {
      if (isActive) {
        _repeatOrDeactivate();
      }
    } else if (!isActive) {
      activate();
    }
  }

  /// Updates the transition state and returns the new progress ratio.
  double update(int referenceTimeMillis) {
    assert(_status != _Status.defunct);
    lastUpdateElapsedMillis = computeElapsedMillis(referenceTimeMillis);
    _updateStatusOrRepeat();
    double ratio = computeProgressRatio(lastUpdateElapsedMillis);
    setProgressRatio(ratio);
    return ratio;
  }
}

class _TransitionEvalState extends _TransitionState {
  final RatioEvaluator evaluate;

  _TransitionEvalState(
    key,
    durationMillis, [
    this.evaluate,
    // int refreshRateMillis = 20,
    int delayMillis = 0,
    int repeatAfterMillis,
    String tag,
    // _TransitionGroupUpdater group,
  ]) : super(key, durationMillis, delayMillis, repeatAfterMillis, tag);

  @override
  double update(int referenceTimeMillis) {
    double ratio = super.update(referenceTimeMillis);
    evaluate(ratio);
    // if (!isActive) {
    //   dispose();
    // }
    return ratio;
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

typedef RatioEvaluator = Function(double elapsedToDurationRatio);
typedef ValueCallback<V> = V Function(V transitionValue);

Key _createKey([context, duration, delay, repeatAfter, tagIdentifier]) {
  if (context != null) {
    return _MultiKey(context, duration, delay, repeatAfter, tagIdentifier);
  } else {
    return UniqueKey();
  }
}

// _addKeyToContext(key, FloopBuildContext context) {
//   assert(key != null && context != null);
//   var contextKeys = _contextToKeys[context];
//   if (contextKeys == null) {
//     contextKeys = Set();
//     _contextToKeys[context] = contextKeys;
//     context
//         .addUnmountCallback(() => _Registry.removeContextTransitions(context));
//   }
//   contextKeys.add(key);
// }

Iterable<_TransitionState> _filter(String tag, BuildContext context) {
  return _Registry.all()
      .where((transitionState) => transitionState.matches(tag, context));
  // Iterable<_TransitionState> transitions;
  // if (tag != null && context != null) {
  //   transitions = _Registry.getForTag(tag)
  //       ?.where((transitionState) => transitionState.matches(tag, context));
  // } else if (tag != null) {
  //   transitions = _Registry.getForTag(tag);
  // } else if (context != null) {
  //   transitions = _Registry.getForContext(context);
  // } else {
  //   transitions = _Registry.all();
  // }
  // return transitions ?? const [];
}

void _applyToTransitions(
    Function(_TransitionState) apply, Object key, BuildContext context,
    [String tag]) {
  // final transitions = _filter(key, tag, context);
  if (key != null) {
    final transitionState = _Registry.getForKey(key);
    if (transitionState != null && transitionState.matches(tag, context)) {
      apply(_Registry.getForKey(key));
    }
  } else {
    _filter(tag, context).forEach(apply);
  }
}

// void _stopAndDispose(Object key) {
//   _Registry.getTransition(key)?.dispose();
// }

// void _clearContextTransitions(FloopBuildContext element) {
//   _contextToKeys.remove(element)?.forEach(_stopAndDispose);
// }

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
