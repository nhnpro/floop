import 'dart:async';

import './flutter_import.dart';
import './controller.dart';
import './observed.dart';
import './mixins.dart';
import './repeater.dart';

T _doubleAsType<T>(double x) => x as T;

// final Map<BuildContext, Set<Object>> _contextToKeys = Map();

typedef MillisecondsReturner = int Function();

const _largeInt = 1 << 62 | 1 << 53 | (1 << 31) | (1 << 30);

/// Returns the current progess value of the transition registered to `key` if
/// it exists, `null` otherwise.
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
      refreshPeriodicityMillis,
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
    transitionState = _TransitionState(key, durationMillis,
        refreshPeriodicityMillis, delayMillis, repeatAfterMillis, tag, context);

    // _Transitions.addContextTransition(
    //     context, transitionState, refreshPeriodicityMillis);
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
    transitionState = _TransitionEvalState(key, durationMillis, evaluate,
        refreshPeriodicityMillis, delayMillis, repeatAfterMillis, tag);
    // _Transitions.addTransition(transitionState, refreshPeriodicityMillis);

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
  /// Set to 1 to get the maximum possible refresh rate.
  static int _refreshPeriodicityMillis = 20;
  static int get refreshPeriodicityMillis => _refreshPeriodicityMillis;
  static set refreshPeriodicityMillis(int newPeriodicityMillis) {
    assert(newPeriodicityMillis != null && newPeriodicityMillis > 0);
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
  static void _refreshAll() {
    for (var transitionState in _Registry.all()) {
      transitionState.update();
    }
  }

  static setTimeDilation(double dilationFactor) {
    TransitionsConfig.setTimeDilatingClock(dilationFactor);
    _refreshAll();
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

  /// Returns the last measured refresh rate in Herz (frames per second) of
  /// transitions with the default [TransitionsConfig.refreshPeriodicityMillis]
  /// or with `refreshPeriodicityMillis` if provided.
  ///
  /// `null` is returned if no transitions have been created for the refresh
  /// periodicity.
  ///
  /// If the Flutter engine is not under stress, the refresh rate should be
  /// close to the inverse of the refresh periodicty. For example if the
  /// periodicity is 50 milliseconds, the refreh rate should be 20 Hz.
  double currentRefreshRate([int refreshPeriodicityMillis]) {
    return _TransitionState
        ._periodicityToUpdater[refreshPeriodicityMillis]?.refreshRate;
  }

  static _resumePeriodicUpdates(_TransitionState t) {
    t.update();
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

  /// Shifts the progress time of transitions by `shiftMillis`.
  ///
  /// If `shiftMillis` is null, the transition's progress will be set to it's
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

  /// Clear all transitions. Equivalent to invoking `Transitions.cancel()`.
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
    t.dispose();
  }
}

Set<T> _createEmptySet<T>() => Set();

abstract class _Registry {
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
    // _keyToTransition.remove(transitionState.key);
    // _tagToTransitions[transitionState.tag]?.remove(transitionState);
    _unregister(transitionState);
    _contextToTransitions[transitionState.context]?.remove(transitionState);
  }

  static _unregister(_TransitionState transitionState) {
    _keyToTransition.remove(transitionState.key);
    _tagToTransitions[transitionState.tag]?.remove(transitionState);
  }

  // static Iterable<_TransitionState> _removeContext(BuildContext context) {
  //   assert(_contextToTransitions.containsKey(context));
  //   return _contextToTransitions.remove(context);
  // }

  static unregisterContext(BuildContext context) {
    return _contextToTransitions.remove(context)..forEach(_unregister);
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

const oneSecondInMillis = 1000;

/// Class used to update transitions synchronously.
///
/// _SyncUpdater does two things:
/// 1. Provides the reference time used to compute the transition's progress
/// 2. Creates the callback that updates transitions
///
/// Transitions with the same refreshPeriodicity are synchronized by using the
/// same _SyncUpdater.
class _SynchronousUpdater {
  static get _stopwatchPlainTime =>
      TransitionsConfig._stopwatch.elapsedMilliseconds;

  var _transitionsToUpdate = List<_TransitionState>();

  _SynchronousUpdater(this._periodicityMillis) {
    // : _periodicityMillis = (periodicity ?? 1).clamp(1, _largeInt)
    print(
        'updater periodicity: $periodicityMillis, config periodicity: ${TransitionsConfig.refreshPeriodicityMillis}');
    assert(periodicityMillis > 0);
    _timeStep = currentTimeStep;
  }

  final int _periodicityMillis;
  int get periodicityMillis =>
      _periodicityMillis ?? TransitionsConfig.refreshPeriodicityMillis;

  /// Returns the number truncated to a periodicity multiple.
  int truncateTime(int number) {
    number -= number % periodicityMillis;
    return number;
  }

  /// Times used for updating.

  /// Time measured directly from a stopwatch.
  ///
  /// Used for calculating the refresh rate with real time and not not scaled,
  /// paused, rounded, etc, like [currentTimeStep] could be.
  int _lastPlainTime = 0;

  /// The time used by the transitions to measure their progress.
  int _timeStep;

  /// The synchronized clock time. It is a multiple of the periodicity.
  int get currentTimeStep {
    if (newFrameWasRendered()) {
      _timeStep = truncateTime(TransitionsConfig.referenceClock());
    }
    return _timeStep;
  }

  /// The target update time for the next update.
  ///
  /// It's null when no future updates are going to be performed.
  int _targetUpdateTime = -_largeInt;

  /// Number of frames per second (with updated transition progress).
  double refreshRate;

  /// This time stamp is used to record whether or not an update callback is
  /// queued before a new frame is rendered. If the app slows down, the updates
  /// will slow down accordingly.
  Duration _referenceTimeStamp;

  Duration get lastFrameUpdateTimeStamp =>
      WidgetsBinding.instance.currentSystemFrameTimeStamp;

  bool newFrameWasRendered() => _referenceTimeStamp != lastFrameUpdateTimeStamp;

  /// Whether a future update is scheduled.
  ///
  /// If _targetUpdateTime!=null an update is scheduled. The second condition
  /// is used as fallback mechanism in case there is an error and
  /// _targetUpdateTime is never set back to null.
  bool willUpdate() =>
      _transitionsToUpdate.isNotEmpty &&
      _targetUpdateTime != null &&
      (_stopwatchPlainTime < _targetUpdateTime + periodicityMillis ||
          !newFrameWasRendered());

  _updateRefreshRateAndPlainTime() {
    final now = _stopwatchPlainTime;
    refreshRate = oneSecondInMillis / (now - _lastPlainTime);
    _lastPlainTime = now;
  }

  _delayedUpdate() {
    if (_referenceTimeStamp == lastFrameUpdateTimeStamp) {
      // Do not update yet if no new frame has been rendered since last update.
      // This will happen for small periodicities.
      WidgetsBinding.instance.scheduleFrameCallback(_updateCallback);
    } else {
      _updateCallback();
    }
  }

  /// Updates are performed by two chained async callbacks. The first one waits
  /// for Flutter to render a new frame. The second one in [_delayedUpdate]
  /// waits for the time remaining. This ensures that the refresh rate
  /// corresponds to the UI refresh rate.
  _scheduleUpdate() {
    _targetUpdateTime = _lastPlainTime + periodicityMillis;
    _referenceTimeStamp = lastFrameUpdateTimeStamp;
    final timeToNextUpdate = _targetUpdateTime - _stopwatchPlainTime;
    Future.delayed(Duration(milliseconds: timeToNextUpdate), _delayedUpdate);
  }

  scheduleUpdate(_TransitionState transitionState) {
    if (!lockUpdateScheduling && !willUpdate()) {
      _scheduleUpdate();
    }
    _transitionsToUpdate.add(transitionState);
  }

  _updateCallback([_]) {
    _targetUpdateTime = null;
    _updateRefreshRateAndPlainTime();
    update();
  }

  bool lockUpdateScheduling = false;

  /// Updates the transitions and returns true if there are active transitions.
  update() {
    // print('updating transitions with periodicity $periodicityMillis[ms]');
    final transitions = _transitionsToUpdate;
    _transitionsToUpdate = List();
    assert(_transitionsToUpdate.isEmpty);
    try {
      // Disallow transitions from scheduling update callbacks
      lockUpdateScheduling = true;
      for (var transitionState in transitions) {
        transitionState.update();
      }
      if (_transitionsToUpdate.isNotEmpty) {
        _scheduleUpdate();
      }
    } finally {
      lockUpdateScheduling = false;
    }
  }
}

enum _Status {
  active,
  inactive,
  defunct,
}

// const _mediumInt = 1 << 31;
// const _largeInt = 1 << 52 | (1 << 31);

// class _TransitionBase with FastHashCode {}

class _TransitionState with FastHashCode {
  static final Map<int, _SynchronousUpdater> _periodicityToUpdater = Map();

  /// Variables saved as storage for external use (avoids creating extra maps).
  final Object key;
  final String tag;
  final FloopBuildContext context;
  final _SynchronousUpdater updater;

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
    int refreshPeriodicityMillis,
    this.delayMillis,
    this.repeatAfterMillis,
    this.tag,
    // this.group,
    this.context,
  ]) :
        // TransitionsConfig._initialize always checks to null. It was added
        // as a hack to avoid the compiler tree shaking leaves the variable
        // out and config is never initialized.
        updater = TransitionsConfig._initialize ??
            _periodicityToUpdater.putIfAbsent(refreshPeriodicityMillis,
                () => _SynchronousUpdater(refreshPeriodicityMillis)) {
    assert(
        repeatAfterMillis == null || repeatAfterMillis > -aggregatedDuration);
    shiftedMillis = -currentTimeStep;
    if (context != null && !_Registry.contextIsRegistered(context)) {
      context.addUnmountCallback(() => _Registry.unregisterContext(context));
    }
    _Registry.register(this);
    updater.scheduleUpdate(this);
  }

  bool matches(String refTag, BuildContext refContext) =>
      (refTag == null || tag == refTag) &&
      (refContext == null || context == refContext);

  // int cycleMillis;
  int shiftedMillis = 0;
  int _pauseTime;

  _Status _status = _Status.active;

  /// Active represents elapsedMillis < aggregatedDuration on the last update.
  bool get isActive => _status == _Status.active;

  /// Pause is different from active, a transition only reaches inactive status
  /// when it finishes (reaches its max duration).
  bool get isPaused => _pauseTime != null;

  /// Whether this transition should keep updating periodically.
  bool get shouldKeepUpdating => isActive && !isPaused;

  int get currentTimeStep => updater.currentTimeStep;

  int get elapsedMillis {
    var elapsed = (_pauseTime ?? currentTimeStep) + shiftedMillis;
    if (repeatAfterMillis != null) {
      if (elapsed > aggregatedDuration) {
        elapsed = (elapsed - aggregatedDuration) %
            (aggregatedDuration + repeatAfterMillis);
      }
    }
    return elapsed;
  }

  double computeProgressRatio(int timeMillis) =>
      ((timeMillis - delayMillis) / durationMillis).clamp(0, 1).toDouble();

  pause() {
    _pauseTime = lastUpdateTime;
  }

  resume() {
    if (isPaused) {
      shiftedMillis += _pauseTime - currentTimeStep;
      _pauseTime = null;
    }
    _updateStatusAndScheduleUpdate();
  }

  reset() {
    if (isPaused) {
      _pauseTime = 0;
    }
    shiftedMillis = -currentTimeStep;
    update();
  }

  restart() {
    reset();
    resume();
  }

  shift(int shiftMillis) {
    // If shiftMillis is null, shift to total duration
    shiftMillis ??= aggregatedDuration - elapsedMillis;
    shiftedMillis += shiftMillis;
    update();
  }

  /// Invoked when the transition is not going to be used again.
  dispose() {
    assert(_status != _Status.defunct);
    observedRatio.dispose();
    _Registry.unregister(this);
    assert(() {
      _status = _Status.defunct;
    }());
  }

  int lastUpdateTime = 0;

  activate() {
    _status = _Status.active;
    // updater.updateInNextRound(this);
  }

  _repeatOrDeactivate() {
    if (repeatAfterMillis == null) {
      _status = _Status.inactive;
      // updater.remove(this);
    }
  }

  _updateStatusAndScheduleUpdate() {
    if (lastUpdateTime >= aggregatedDuration) {
      if (isActive) {
        _repeatOrDeactivate();
      }
    } else if (!isActive) {
      _status = _Status.active;
      // updater.add(this);
      // activate();
    }
    if (shouldKeepUpdating) {
      updater.scheduleUpdate(this);
    }
  }

  /// Updates the transition state and returns the new progress ratio.
  double update() {
    assert(_status != _Status.defunct);
    // lastUpdateElapsedMillis = computeElapsedMillis(clock.currentTimeStep);
    lastUpdateTime = elapsedMillis;
    double ratio = computeProgressRatio(lastUpdateTime);
    setProgressRatio(ratio);
    _updateStatusAndScheduleUpdate();
    return ratio;
  }
}

class _TransitionEvalState extends _TransitionState {
  final RatioEvaluator evaluate;

  _TransitionEvalState(
    key,
    durationMillis, [
    this.evaluate,
    int refreshRateMillis,
    int delayMillis = 0,
    int repeatAfterMillis,
    String tag,
    // _TransitionGroupUpdater group,
  ]) : super(key, durationMillis, refreshRateMillis, delayMillis,
            repeatAfterMillis, tag);

  @override
  double update([int referenceTimeMillis]) {
    double ratio = super.update();
    evaluate(ratio);
    if (!isActive) {
      dispose();
    }
    return ratio;
  }
}

class _MultiKey extends LocalKey {
  final a, b, c, d, e, f;
  final int _hash;

  _MultiKey([this.a, this.b, this.c, this.d, this.e, this.f])
      : _hash = hashValues(a, b, c, d, e, f);

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
        this.e == other.e &&
        this.f == other.f;
  }

  @override
  int get hashCode => _hash;
}

typedef RatioEvaluator = Function(double elapsedToDurationRatio);
typedef ValueCallback<V> = V Function(V transitionValue);

Key _createKey(
    [context, duration, periodicity, delay, repeatAfter, tagIdentifier]) {
  if (context != null) {
    return _MultiKey(
        context, duration, periodicity, delay, repeatAfter, tagIdentifier);
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

abstract class Lerp {
  static int integer(int start, int end, double t) {
    return (start + (end - start) * t).toInt();
  }

  static double number(double start, double end, double t) {
    return (start + (end - start) * t);
  }

  static string(String start, String end, double t) {
    return end.substring(0, (end.length * t).toInt()) +
        start.substring((start.length * t).toInt());
  }
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
