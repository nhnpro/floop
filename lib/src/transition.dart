import 'dart:async';
import 'dart:math' as math;

import './flutter.dart';
import './controller.dart';
import './observed.dart';
import './mixins.dart';
import './repeater.dart';
import './error.dart';
import './time.dart';

T _doubleAsType<T>(double x) => x as T;

typedef MillisecondsReturner = int Function();

/// Returns the value of a transition registered with `key` if it exists,
/// `null` otherwise.
double transitionOf(Object key) {
  return _Registry.getForKey(key)?.currentValueDynamic;
}

/// Returns a dynamic value that transitions from 0 to 1 in `durationMillis`.
///
/// Specially designed to be invoked from within Floop widgets [build]. Input
/// parameters should be the same on every rebuild.
///
/// `durationMillis` must not be null.
///
/// `refreshPeriodicityMillis` is the periodicity at which it attempts to
/// update it's progress.
///
/// It will start after a delay of `delayMillis`.
///
/// If provided, it will repeat after `repeatAfterMillis`.
///
/// `key` is a unique identifier. When invoked outside of a [build] method
/// `key` must be specified. The value of a transition can be retrieved by
/// with its key in [transitionOf].
///
/// `tag` is a non unique identifier.
///
/// Transitions can be referenced and controlled using their `key` or `tag`
/// with [TransitionGroup].
///
/// If `bindContext` is provided, the transition is deleted when the context
/// unmounts, otherwise when it's deleted when it finishes. Invocations from
/// inside Floop widgets [build] methods are bound by default to `context`.
///
/// Example:
///
/// ```
/// class MyWidget extends StatelessWidget with Floop {
///   ...
///
///   @override
///   Widget build(BuildContext context, MyButtonState state) {
///     double t = transition(5000);
///     return ...
///         Text('T is at $t'),
///         ...
///         ...onPressed: () => TransitionGroup(context: context).restart(),
///         ...
///     ...
///   }
/// }
/// ```
///
/// In the example above, `x` transitions from 0 to 1 in five seconds and when
/// there is a click event the transition is restarted. The `Text` widget will
/// always display the updated value.
///
/// Details:
///
///  *
///
///  * The default refresh periodicity for transitions can be set in
///    [TransitionsConfig.refreshPeriodicityMillis].
///
///  * If `key` is non null and a transition registered to `key` exists, the
///    existing transition's value is returned.
///
///  * When `key` is not provided, transitions are identified by all other
///    input parameters. If any input parameter is different on a context
///    rebuild, a new transition will be created. Input parameters should
///    not change on rebuilds or it will create infinite rebuild cycles.
///
///  * This method does not work inside builders, like [LayoutBuilder], as
///    builders build outside of the encompassing [build] method. A workaround
///    is to use a `var t = transition(...)` in the body of the [build] method
///    and then reference the var from within the builder function.
///
/// See also:
///  * [TransitionGroup] to control transitions.
///  * [transitionOf] to retrieve the value of ongoing transitions.
///  * [transitionEval] a more versatile function for creating transitions from
///    outside build methods.
///  * [Repeater.transition] to create custom transitions objects that are not
///    synchronized and not connected to the [Transitions] API.
double transition(
  int durationMillis, {
  int refreshPeriodicityMillis,
  int delayMillis = 0,
  int repeatAfterMillis,
  Object key,
  Object tag,
  FloopBuildContext bindContext,
}) {
  return _getOrCreateTransition(durationMillis,
          refreshPeriodicityMillis: refreshPeriodicityMillis,
          delayMillis: delayMillis,
          repeatAfterMillis: repeatAfterMillis,
          key: key,
          tag: tag,
          bindContext: bindContext)
      .currentValueDynamic;
}

_Transition _getOrCreateTransition(
  int durationMillis, {
  int refreshPeriodicityMillis,
  int delayMillis = 0,
  int repeatAfterMillis,
  Object key,
  Object tag,
  FloopBuildContext bindContext,
}) {
  bindContext ??= ObservedController.activeListener;
  final bool canCreate = (bindContext != null) || key != null;
  assert(() {
    if (durationMillis == null) {
      throw floopError('[transition] invoked with `durationMillis` as null.\n'
          'To retrieve the value of a keyed transition, use [transitionOf].');
    }
    if (!canCreate && key == null) {
      throw floopError(
          'When invoking [transition] outside a Floop widget\'s build method, '
          'the `key` parameter must be not null.\n'
          'Without a key a transition can\'t have effect outside of itself.\n'
          'If this is getting invoked from within a [Builder], check '
          '[transition] docs for an explanation to handle that case.');
    }
    return true;
  }());
  if (canCreate && key == null) {
    key = _createKey(
      bindContext,
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
    transitionState = _Transition(key, durationMillis, refreshPeriodicityMillis,
        delayMillis, repeatAfterMillis, tag, bindContext);
  }
  assert(transitionState.currentValueDynamic != null);
  return transitionState;
}

/// Creates a transition with a computed value. Returns its key. Cannot be used
/// within Floop widgets [build] methods.
///
/// `durationMillis` and `evaluate` must not be null.
///
/// The value is computed on every update by evaluating the progress ratio on
/// `evaluate`.
///
/// If `key` is not provided, a unique key is generated.
///
/// Refer to [transition] for further description about the parameters.
///
/// Example:
///
/// ```
/// class MyWidget extends StatelessWidget with Floop {
///   ...
///   static int _clicks = 0;
///
///   @override
///   Widget build(BuildContext context, MyButtonState state) {
///     int t = (transitionOf(#key) ?? 0.0).toInt();
///     return ...
///         Text('Total clicks is... $t'),
///         ...
///         ...onPressed: () {
///              final clicks = _clicks++;
///              TransitionGroup(key: #key).cancel();
///              transitionEval(5000, (r) => r * clicks, key: #key,
///                  bindContext: bindContext, repeatAfterMillis: 1000);
///              }
///            },
///         ...
///     ...
///   }
/// }
/// ```
///
/// In the example above when there is a click event, a new repeating
/// transition is created whose evaluate function scales the value to the
/// current number of clicks. On every click event the evaluate function
/// changes (because clicks increases), therefore the old transitions is
/// canceled in order to register a new one.
Object transitionEval(
  int durationMillis,
  RatioEvaluator evaluate, {
  FloopBuildContext bindContext,
  int refreshPeriodicityMillis,
  int delayMillis = 0,
  int repeatAfterMillis,
  Object key,
  Object tag,
}) {
  assert(() {
    if (ObservedController.isListening) {
      throw floopError(
          'Cannnot invoke [transitionEval] while a Floop widget is building. '
          'Using [transition] and evaluating its value directly could .');
    }
    if (durationMillis == null || evaluate == null) {
      throw floopError('Bad inputs for [transitionEval], durationMillis and '
          'evaluate cannot be null.');
    }
    return true;
  }());
  _Transition transitionState;
  if (key != null) {
    transitionState = _Registry.getForKey(key);
  }
  key ??= UniqueKey();
  if (transitionState == null) {
    transitionState = _TransitionEval(
        key,
        durationMillis,
        evaluate,
        refreshPeriodicityMillis,
        delayMillis,
        repeatAfterMillis,
        tag,
        bindContext);
  }
  return key;
}

abstract class TransitionsConfig {
  static int _updateDelayLimitThreshold;

  /// (Advanced) The delay time that an async update callback can take before
  /// the library determines it took too long and creates a new one.
  ///
  /// This is a safety mechanism that the library uses to recover in case an
  /// error caused the periodic updates to stop. It shouldn't have an impact
  /// on apps that run smoothly.
  static int get updateDelayLimitThreshold =>
      _initialize ?? _updateDelayLimitThreshold;

  static set updateDelayLimitThreshold(int thresholdMillis) {
    _setDefaults();
    assert(thresholdMillis > 0);
    _updateDelayLimitThreshold = thresholdMillis;
  }

  static int _refreshPeriodicityMillis;

  static final _dynRefreshPeriodicity = DynValue<int>();

  /// The default refresh periodicity for transitions as a dynamic value.
  ///
  /// It defines how often a transition should update it's state. When the
  /// periodicity is specified in the transition, this value is not used.
  ///
  /// Set to 1 to get the maximum possible refresh rate.
  static int get refreshPeriodicityMillis =>
      _initialize ?? _dynRefreshPeriodicity.value;

  static set refreshPeriodicityMillis(int periodicityMillis) {
    _setDefaults();
    assert(periodicityMillis != null && periodicityMillis > 0);
    _dynRefreshPeriodicity.value = periodicityMillis;
    _refreshPeriodicityMillis = periodicityMillis;
  }

  /// The minimum size of time steps for transition updates.
  ///
  /// Defaults to the max granularity of one millisecond. Setting larger values
  /// serves to limit the possible states of transitions. For example if it is
  /// set to the same value as [refreshPeriodicityMillis], then the states will
  /// consistenly reproduce when shifting time forwards or backwards.
  static int timeGranularityMillis;

  static MillisecondsReturner _referenceClock;

  static int _defaultClock() {
    final time = milliseconds();
    return time - time % timeGranularityMillis;
  }

  /// The clock used to measure the transitions progress.
  ///
  /// This could be any function, it shouldn't be used as a reliable source
  /// for time measuring. By default it returns the elapsed milliseconds of
  /// an internal stopwatch.
  static MillisecondsReturner get referenceClock => _referenceClock;

  /// Sets the reference clock used by transitions to update their state.
  ///
  /// This resets timeDilationFactor to 1.
  static set referenceClock(MillisecondsReturner clock) {
    _setDefaults();
    _dynTimeDilation.value = 1.0;
    _referenceClock = clock;
  }

  static final _dynTimeDilation = DynValue<double>();

  /// The time dilation as a dynamic value.
  ///
  /// The time dilation does not affect the refresh rate of the transitions, it
  /// affects their progress rate. The default refresh periodicity can be
  /// modified by [TransitionsConfig.refreshPeriodicityMillis].
  static double get timeDilationFactor => _dynTimeDilation.value;

  /// Sets a time dilating [referenceClock] that continues the current time.
  ///
  /// The time dilation does not affect the refresh rate of the transitions, it
  /// affects their progress rate. The default refresh periodicity can be
  /// modified by [TransitionsConfig.refreshPeriodicityMillis].
  static set timeDilationFactor(double dilationFactor) {
    return _setTimeDilation(dilationFactor);
  }

  static void _setTimeDilation(double dilationFactor) {
    _setDefaults();
    _dynTimeDilation.value = dilationFactor;
    final baseTime = referenceClock();
    final timeOffset = milliseconds();
    _referenceClock = () {
      final dilatedTime =
          ((milliseconds() - timeOffset) * dilationFactor).toInt();
      final currentTime = baseTime + dilatedTime;
      return currentTime - (currentTime % timeGranularityMillis);
    };
  }

  /// Sets the default config values.
  static void setDefaults() {
    _initialized = true;
    _updateDelayLimitThreshold = 50;
    refreshPeriodicityMillis = 20;
    timeGranularityMillis = 1;
    _dynTimeDilation.value = 1.0;
    referenceClock = _defaultClock;
  }

  static bool _initialized = false;

  static void _setDefaults() {
    if (!_initialized) {
      setDefaults();
    }
  }

  /// Value used as a trick to force initialization of config parameters.
  static final _initialize = () {
    _setDefaults();
    return null;
  }();
}

enum ShiftType {
  /// Shifts the current time of the transition.
  current,

  /// Sets the transition to it's last starting time and then shifts the time.
  /// If the current progress is prior to its starting time, then the behavior
  /// is equivalent to `current`.
  begin,

  /// Sets the transition to it's next end time and then shifts the time.
  /// If the current progress exceeded its end time, then the behavior is
  /// equivalent to `current`.
  end,
}

/// An object that can be used to control group of transitions.
class TransitionGroup {
  /// The frames per second as a dynamic value.
  ///
  /// It targets the refresh rate for transitions with periodicity
  /// `refreshPeriodicityMillis` if provided, otherwise it targets the default
  /// refresh periodicity.
  ///
  /// Returns `null` if no transitions have been created for the periodicity.
  ///
  /// If the Flutter engine is not under stress, the refresh rate should be
  /// close to the inverse of the refresh periodicty. For example if the
  /// periodicity is 50 milliseconds, the refreh rate should be around 20 Hz.
  ///
  /// See also:
  ///  * [currentRefreshRate] for the non dynamic value version.
  static double currentRefreshRateDynamic([int refreshPeriodicityMillis]) {
    return _SynchronousUpdater.getForPeriodicity(refreshPeriodicityMillis)
        ?.refreshRate;
  }

  /// The frames per second for transitions with the given refresh periodicity.
  ///
  /// Refer to [currentRefreshRateDynamic] for further documentation.
  static currentRefreshRate([int refreshPeriodicityMillis]) {
    _SynchronousUpdater._periodicityToUpdater
        .getDynValue(// ignore: invalid_use_of_protected_member
            refreshPeriodicityMillis)
        ?.getSilently()
        ?._observedRefreshRate
        ?.getSilently();
  }

  static _pause(_Transition t) => t.pause();
  static _resume(_Transition t) => t.resume();
  static _resumeOrPause(_Transition t) {
    if (t.isPaused) {
      _resume(t);
    } else {
      _pause(t);
    }
  }

  static _reverse(_Transition t) => t.reverse();
  static _restart(_Transition t) => t.restart();
  static _reset(_Transition t) => t.reset();
  static _shiftEnd(_Transition t) => t.shiftEnd();
  static _shiftBegin(_Transition t) => t.shiftBegin();
  static _cancel(_Transition t) => t.cancel();

  final Object key;
  final Object tag;
  final BuildContext context;

  /// Transitions of this group evaluate true when passed to [matcher].
  TransitionMatcher matcher;

  /// Creates an instance that controls transitions that match the parameters.
  ///
  /// Non null `key`, `tag` and/or `context` are matched.
  ///
  /// `matcher` can be provided for advanced filtering.
  ///
  /// Methods accept `rootContext` parameter and if set the operation is
  /// applied to transitions of this group that are bound to contexts that
  /// belong to the widget tree that starts at `rootContext`.
  ///
  /// Transitions cannot be controlled inside build methods.
  ///
  /// A transition group with no parameters represents all transitions.
  TransitionGroup({this.key, this.tag, this.context, this.matcher});

  _apply(operation, BuildContext rootContext) {
    assert(() {
      if (ObservedController.isListening) {
        throw floopError(
            'Cannnot invoke [TransitionGroup] methods while a Floop widget '
            'is building.');
      }
      return true;
    }());
    applyToTransitions(operation, key, context, tag, rootContext, matcher);
  }

  resume({BuildContext rootContext}) {
    _apply(_resume, rootContext);
  }

  pause({BuildContext rootContext}) {
    _apply(_pause, rootContext);
  }

  /// Resumes paused and pauses active.
  resumeOrPause({BuildContext rootContext}) {
    _apply(_resumeOrPause, rootContext);
  }

  /// Resumes the time direction.
  reverse({BuildContext rootContext}) {
    _apply(_reverse, rootContext);
  }

  /// Equivalent to reset + resume.
  restart({BuildContext rootContext}) {
    _apply(_restart, rootContext);
  }

  reset({BuildContext rootContext}) {
    _apply(_reset, rootContext);
  }

  /// Shifts the progress time by `shiftMillis`.
  shiftTime(
      {int shiftMillis = 0,
      ShiftType shiftType = ShiftType.current,
      BuildContext rootContext}) {
    if (shiftType == ShiftType.begin) {
      _apply(_shiftBegin, rootContext);
    } else if (shiftType == ShiftType.end) {
      _apply(_shiftEnd, rootContext);
    }
    _apply((_Transition t) => t.shift(shiftMillis), rootContext);
  }

  /// Deletes the transitions.
  ///
  /// Particularly useful to cause a context to rebuild as if it was being
  /// built for the first time.
  ///
  /// `TransitionGroup().cancel()` cancels all transitions.
  cancel({BuildContext rootContext}) {
    _apply(_cancel, rootContext);
  }
}

int _sort(Element a, Element b) {
  if (a.depth < b.depth) return -1;
  if (b.depth < a.depth) return 1;
  return 0;
}

Set<Element> _findDescendants(
    Set<Element> descendantCandidates, Element rootContext) {
  final resultSet = Set<Element>()..add(rootContext);
  final minAncestorDepth = rootContext.depth;
  Iterable<Element> childrenCandidatesIterable = (descendantCandidates
        ..removeWhere((ele) => ele.depth <= minAncestorDepth))
      .toList()
        ..sort(_sort);
  assert(() {
    // This is necessary to avoid Flutter inactive Element assertion error.
    childrenCandidatesIterable = childrenCandidatesIterable
        .where((element) => (element as FloopElement).active);
    return true;
  }());
  descendantCandidates = childrenCandidatesIterable.toSet();

  _visitAncestors(Element child) {
    assert((child as FloopBuildContext).active);
    child.visitAncestorElements((ancestor) {
      if (ancestor.depth == minAncestorDepth) {
        if (ancestor == rootContext) {
          resultSet.add(child);
        }
        return false;
      } else if (descendantCandidates.contains(ancestor)) {
        if (resultSet.contains(ancestor)) {
          resultSet.add(child);
        }
        return false;
      }
      assert(child.depth > minAncestorDepth);
      return true;
    });
  }

  childrenCandidatesIterable.forEach(_visitAncestors);
  return resultSet;
}

Iterable<_Transition> _filterByRootContext(
    Iterable<_Transition> transitions, BuildContext rootContext) {
  var elements = Set<Element>.from(
      [for (var t in transitions) if (t.context != null) t.context as Element]);
  elements = _findDescendants(elements, rootContext);
  var result = transitions.where((t) => elements.contains(t.context));
  return result;
}

/// This filter is faster than a plain Matcher filter, because it takes
/// advantage on how transitions are stored in the registry.
Iterable<_Transition> _filter(key, tag, BuildContext context) {
  Iterable<_Transition> filtered;
  if (key != null) {
    final transitionState = _Registry.getForKey(key);
    if (transitionState?.matches(tag, context) == true) {
      filtered = [transitionState];
    }
  } else if (context != null) {
    filtered = _Registry.getForContext(context)
        ?.where((transitionState) => transitionState.matches(tag, null));
  } else if (tag != null) {
    filtered = _Registry.getForTag(tag);
  } else {
    filtered = _Registry.allTransitions();
  }
  return filtered ?? const [];
}

typedef TransitionMatcher = bool Function(TransitionView);

applyToTransitions(Function(_Transition) apply, Object key,
    BuildContext context, Object tag, BuildContext rootContext,
    [TransitionMatcher matcher]) {
  Iterable<_Transition> filtered = _filter(key, tag, context);
  if (matcher != null) {
    filtered = filtered.where((t) => matcher(t));
  }
  if (rootContext == null) {
    filtered = filtered.toList();
  } else {
    filtered = _filterByRootContext(filtered, rootContext);
  }
  filtered.forEach(apply);
}

Set<T> _createEmptySet<T>() => Set();

abstract class _Registry {
  static final Map<BuildContext, Set<_Transition>> _contextToTransitions =
      DynMap();
  static final Map<Object, _Transition> _keyToTransition = DynMap();
  static final Map<Object, Set<_Transition>> _tagToTransitions = DynMap();

  static _Transition getForKey(Object key) => _keyToTransition[key];

  static Iterable<_Transition> getForTag(Object tag) => _tagToTransitions[tag];

  static Iterable<_Transition> getForContext(BuildContext context) =>
      _contextToTransitions[context];

  static bool contextIsRegistered(BuildContext context) =>
      _contextToTransitions.containsKey(context);

  static Iterable<_Transition> allTransitions() => _keyToTransition.values;

  static register(_Transition transitionState) {
    final key = transitionState.key;
    assert(key != null);
    if (_keyToTransition.containsKey(key)) {
      assert(() {
        debugPrint('Floop internal error, attempting to create a transition '
            'that already exists. Please fill an issue in the repository '
            '(this should not happen).');
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

  static unregister(_Transition transitionState) {
    assert(transitionState != null);
    _unregister(transitionState);
    _contextToTransitions[transitionState.context]?.remove(transitionState);
  }

  static _unregister(_Transition transitionState) {
    _keyToTransition.remove(transitionState.key);
    _tagToTransitions[transitionState.tag]?.remove(transitionState);
  }

  static Iterable<_Transition> unregisterContext(BuildContext context) {
    return _contextToTransitions.remove(context);
  }
}

const oneSecondInMillis = 1000;

/// Class used to update transitions synchronously.
///
/// _SyncUpdater does two things:
/// 1. Provides the reference time used to compute the transition's progress
/// 2. Creates the callback that updates transitions
///
/// Transitions with the same refreshPeriodicity are synchronized by using the
/// same [_SynchronousUpdater] instance.
class _SynchronousUpdater {
  static int get elapsedMillis => milliseconds();

  static final DynMap<int, _SynchronousUpdater> _periodicityToUpdater =
      DynMap();

  static _SynchronousUpdater getForPeriodicity(int periodicityMillis,
      [bool createIfAbsent = false]) {
    periodicityMillis ??= 0;
    var updater = _periodicityToUpdater[periodicityMillis];
    if (updater == null && createIfAbsent) {
      updater = _SynchronousUpdater(periodicityMillis);
      _periodicityToUpdater
        ..setValue(periodicityMillis, updater, false)
        ..notifyListenersOfKey(periodicityMillis,
            postponeNotificationHandling: true);
    }
    return updater;
  }

  var _transitionsToUpdate = Set<_Transition>();

  _SynchronousUpdater(periodicityMillis)
      : _periodicityMillis = (periodicityMillis ??= 0) {
    assert(periodicityMillis >= 0);
    // TransitionsConfig._initialize always checks to null. It was added
    // as a trick to initialize static values of the library.
    // _initialize is lazily evaluated the first iime it is referenced (here).
    _timeStep = TransitionsConfig._initialize;
    newTimeStep();
  }

  final int _periodicityMillis;
  int get periodicityMillis => _periodicityMillis > 0
      ? _periodicityMillis
      : TransitionsConfig._refreshPeriodicityMillis;

  /// Returns the number truncated to a periodicity multiple.
  int truncateTime(int number) {
    number -= number % periodicityMillis;
    return number;
  }

  /// Times used for updating.

  /// The time used by the transitions to measure their progress.
  int _timeStep;

  void newTimeStep() {
    _timeStep = truncateTime(TransitionsConfig.referenceClock());
  }

  /// The synchronized clock time for this updater.
  ///
  /// It will only change after a new frame has been rendered.
  int get currentTimeStep {
    if (!updatingLock && !willUpdate) {
      newTimeStep();
    }
    return _timeStep;
  }

  /// Number of frames per second (with updated transition progress).
  DynValue<double> _observedRefreshRate =
      TimedDynValue(Duration(milliseconds: 500), 0);

  double get refreshRate => _observedRefreshRate.value;
  set refreshRate(double rate) => _observedRefreshRate.value = rate;

  static const _numberSamples = 10;
  final _samples = List.filled(_numberSamples, elapsedMillis);
  var _sampleIndex = 0;

  int get lastSampleIndex => (_sampleIndex - 1) % _numberSamples;

  int get lastStopwatchTime => _samples[lastSampleIndex];

  _updateRefreshRate() {
    final now = elapsedMillis;
    final index = _sampleIndex++ % _numberSamples;
    _samples[index] = now;
    final referenceIndex =
        _sampleIndex > _numberSamples ? _sampleIndex % _numberSamples : 0;
    refreshRate =
        1000 * _numberSamples / (_samples[index] - _samples[referenceIndex]);
  }

  int get idealUpdateTime =>
      truncateTime(lastStopwatchTime) + periodicityMillis;

  /// The time limit for the delayed update to take place.
  int _updateTimeLimit;

  /// The last Flutter frame time stamp when a frame callback was scheduled.
  int _referenceFrameTimeStamp;

  int get lastFrameTimeStamp =>
      WidgetsBinding.instance.currentSystemFrameTimeStamp.inMilliseconds;

  bool get delayedCallbackExists =>
      _updateTimeLimit != null && elapsedMillis < _updateTimeLimit;

  bool get scheduledFrameCallbackIsRegistered =>
      _referenceFrameTimeStamp == lastFrameTimeStamp;

  /// Whether a future update is scheduled.
  bool get willUpdate =>
      scheduledFrameCallbackIsRegistered || delayedCallbackExists;

  _scheduleFrameCallback() {
    // It could happen that a secondary delayed triggers if the first one
    // takes too long.
    if (!scheduledFrameCallbackIsRegistered) {
      _referenceFrameTimeStamp = lastFrameTimeStamp;
      WidgetsBinding.instance..scheduleFrameCallback(update);
    }
    assert(WidgetsBinding.instance.hasScheduledFrame);
  }

  _delayedUpdate() {
    final updateTime = idealUpdateTime;
    final waitTime = updateTime - elapsedMillis;
    if (waitTime > 0) {
      _updateTimeLimit =
          updateTime + TransitionsConfig._updateDelayLimitThreshold;
      Future.delayed(Duration(milliseconds: waitTime), _scheduleFrameCallback);
    } else {
      _scheduleFrameCallback();
    }
  }

  scheduleUpdate(_Transition transitionState) {
    if (!updatingLock && !willUpdate) {
      _delayedUpdate();
    }
    _transitionsToUpdate.add(transitionState);
  }

  cancelScheduledUpdate(_Transition transitionState) {
    _transitionsToUpdate.remove(transitionState);
  }

  bool updatingLock = false;

  /// Performs the scheduled updates.
  update([_]) {
    try {
      // Lock prevents scheduling updates and changing currentTimeStep.
      updatingLock = true;
      _updateTimeLimit = null;
      _referenceFrameTimeStamp = null;
      _updateRefreshRate();
      newTimeStep();
      final transitions = _transitionsToUpdate;
      _transitionsToUpdate = Set();
      for (var transitionState in transitions) {
        // A transition could get concurrently deleted by UI interactions.
        if (!transitionState.isDisposed) {
          transitionState.update();
        }
      }
    } finally {
      updatingLock = false;
      if (_transitionsToUpdate.isNotEmpty) {
        _delayedUpdate();
      }
    }
  }
}

abstract class TransitionView {
  Object get key;
  Object get tag;
  BuildContext get context;

  /// The value set in the last update.
  double get currentValue;
}

enum _Status {
  active,
  inactive,
  defunct,
}

class _Transition extends TransitionView with FastHashCode {
  static cancelContextTransitions(BuildContext context) {
    _Registry.unregisterContext(context)..forEach(_disposeTransition);
  }

  static _disposeTransition(_Transition transitionState) {
    transitionState.dispose();
  }

  /// Variables saved as storage for external use (avoids creating extra maps).
  final Object key;
  final Object tag;
  final FloopBuildContext context;
  final _SynchronousUpdater updater;

  /// State variables
  final int durationMillis;
  final int delayMillis;
  final int repeatAfterMillis;

  int get aggregatedDuration => durationMillis + delayMillis;

  final DynValue<double> dynRatio = DynValue(0);

  double setProgressRatio(double ratio) => dynRatio.value = ratio;

  double get currentValueDynamic => dynRatio.value.clamp(0.0, 1.0);
  double get currentValue => dynRatio.getSilently().clamp(0.0, 1.0);

  _Transition(
    this.key,
    this.durationMillis, [
    int refreshPeriodicityMillis,
    this.delayMillis,
    this.repeatAfterMillis,
    this.tag,
    this.context,
  ]) : updater = _SynchronousUpdater.getForPeriodicity(
            refreshPeriodicityMillis, true) {
    assert(
        repeatAfterMillis == null || repeatAfterMillis > -aggregatedDuration);
    if (context != null && !_Registry.contextIsRegistered(context)) {
      context.addUnmountCallback(() => cancelContextTransitions(context));
    }
    _Registry.register(this);
    lastUpdateTimeStep = currentTimeStep;
    updater.scheduleUpdate(this);
  }

  bool matches(Object refTag, BuildContext refContext) =>
      (refTag == null || tag == refTag) &&
      (refContext == null || context == refContext);

  int progressTime = 0;

  _Status _status = _Status.active;

  /// Active represents that the transition has not finished.
  bool get isActive => _status == _Status.active;

  bool get isDisposed => _status == _Status.defunct;

  /// Pause is different from active, a transition only reaches inactive status
  /// when it finishes (reaches its max duration).
  bool get isPaused => _timeDirection % 2 == 0;

  bool get shouldDispose => !isActive && context == null;

  /// Whether this transition should keep updating periodically.
  bool get shouldKeepUpdating => isActive && !isPaused;

  /// The updater time. It updates asynchronously.
  int get currentTimeStep => updater.currentTimeStep;

  int get cycleTime => aggregatedDuration + repeatAfterMillis + 1;

  int get baseRepeatTime {
    if (repeatAfterMillis != null &&
        progressTime > aggregatedDuration &&
        repeatAfterMillis < 0) {
      return -repeatAfterMillis;
    }
    return 0;
  }

  int _repeatTime(int elapsed) {
    if (repeatAfterMillis < 0) {
      elapsed -= aggregatedDuration;
      elapsed %= cycleTime;
      // The transition starts advanced, finishing right at its end time.
      elapsed -= repeatAfterMillis;
    } else {
      elapsed %= cycleTime;
    }
    return elapsed;
  }

  int get elapsedMillis {
    var elapsed = progressTime;
    if (repeatAfterMillis != null && elapsed > aggregatedDuration) {
      elapsed = _repeatTime(elapsed);
    }
    return elapsed;
  }

  double computeAbsoluteProgressRatio(int timeMillis) =>
      (timeMillis - delayMillis) / durationMillis;

  pause() {
    if (!isPaused) {
      _timeDirection *= 2;
    }
  }

  resume() {
    if (isPaused) {
      _forceUpdateProgressTime(0);
      _timeDirection ~/= 2;
      if (shouldKeepUpdating) {
        _scheduleNextUpdate();
      }
    }
  }

  reverse([bool forceForward = false]) {
    _forceUpdateProgressTime(timeFactor);
    if (forceForward) {
      _timeDirection = _timeDirection.abs();
    } else {
      _timeDirection *= -1;
    }
    update();
  }

  reset() {
    _forceUpdateProgressTime(0);
    // Sets time to default direction.
    _timeDirection = _timeDirection.abs();
    progressTime = 0;
    update();
  }

  restart() {
    reset();
    resume();
  }

  _shiftBegin() {
    int elapsed = elapsedMillis - baseRepeatTime;
    if (elapsed > 0) {
      progressTime -= elapsed;
    }
  }

  shiftBegin() {
    _forceUpdateProgressTime(timeFactor);
    int t = timeDirection;
    if (t == -1) {
      _shiftEnd();
    } else {
      assert(t == 1);
      _shiftBegin();
    }
  }

  _shiftEnd() {
    int diff = aggregatedDuration - elapsedMillis;
    if (diff > 0) {
      progressTime += diff;
    }
  }

  shiftEnd() {
    _forceUpdateProgressTime(timeFactor);
    int t = timeDirection;
    if (t == -1) {
      _shiftBegin();
    } else {
      assert(t == 1);
      _shiftEnd();
    }
  }

  shift(int shiftMillis) {
    progressTime += shiftMillis * timeDirection;
    update();
  }

  _forceUpdateProgressTime(int forcedTimeFactor) {
    progressTime += (currentTimeStep - lastUpdateTimeStep) * forcedTimeFactor;
    lastUpdateTimeStep = currentTimeStep;
  }

  cancel() {
    dynRatio.notifyChange();
    dispose();
  }

  /// Invoked when the transition is not going to be used again.
  dispose() {
    assert(_status != _Status.defunct);
    updater.cancelScheduledUpdate(this);
    dynRatio.dispose();
    _Registry.unregister(this);
    _status = _Status.defunct;
  }

  int lastUpdateTimeStep = 0;

  activate() {
    _status = _Status.active;
  }

  _repeatOrDeactivate() {
    if (repeatAfterMillis == null) {
      _status = _Status.inactive;
    }
  }

  _updateStatus() {
    final reversed = _timeDirection < 0;
    final ratio = dynRatio.getSilently();
    if (ratio >= 1 && !reversed) {
      _repeatOrDeactivate();
    } else if (ratio <= 0 && reversed) {
      _repeatOrDeactivate();
    } else if (!isActive) {
      _status = _Status.active;
    }
  }

  _scheduleNextUpdate() {
    updater.scheduleUpdate(this);
  }

  /// Used to represent the time direction. If it is multiple of 2, then the
  /// transition is paused.
  int _timeDirection = 1;

  int get timeDirection => _timeDirection.sign;

  /// The time factor is 0 when the transition is paused.
  int get timeFactor => (_timeDirection % 2) * _timeDirection;

  _updateTime() {
    if (!isPaused) {
      progressTime += (currentTimeStep - lastUpdateTimeStep) * timeDirection;
    }
    lastUpdateTimeStep = currentTimeStep;
  }

  _updateValue() {
    double ratio = computeAbsoluteProgressRatio(elapsedMillis);
    setProgressRatio(ratio);
  }

  /// Updates the transition state.
  void update() {
    assert(_status != _Status.defunct);
    _updateTime();
    _updateValue();
    _updateStatus();
    if (shouldDispose) {
      dispose();
    } else if (shouldKeepUpdating) {
      _scheduleNextUpdate();
    }
  }
}

class _TransitionEval extends _Transition {
  final RatioEvaluator evaluate;

  double _value;

  double get currentValueDynamic {
    // Invoke notifyRead as if it were a value read.
    dynRatio.notifyRead();
    return _value;
  }

  _TransitionEval(
    Object key,
    int durationMillis, [
    this.evaluate,
    int refreshPeriodicityMillis,
    int delayMillis = 0,
    int repeatAfterMillis,
    Object tag,
    FloopBuildContext context,
  ]) : super(key, durationMillis, refreshPeriodicityMillis, delayMillis,
            repeatAfterMillis, tag, context) {
    _value = evaluate(0);
  }

  update() {
    super.update();
    // Retrieve ratio through getSilently because dynRatio could be disposed.
    _value = evaluate(dynRatio.getSilently().clamp(0.0, 1.0));
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

typedef RatioEvaluator = double Function(double elapsedToDurationRatio);

Key _createKey(
    [context, duration, periodicity, delay, repeatAfter, tagIdentifier]) {
  return _MultiKey(
      context, duration, periodicity, delay, repeatAfter, tagIdentifier);
}

/// Useful patterns build on top of [transiton] for build methods.
///
/// The patterns pass the output of [transition] through a function and return.
/// The underlying transition value is the same as invoking [transition]
/// directly.
abstract class Transition {
  /// A number transitions between `start` and `end`.
  static double number(
    int durationMillis, {
    num start = 0.0,
    num end = 1.0,
    int refreshPeriodicityMillis,
    int delayMillis = 0,
    int repeatAfterMillis,
    Object key,
    Object tag,
    FloopBuildContext bindContext,
  }) {
    return Lerp.number(
        start,
        end,
        _getOrCreateTransition(durationMillis,
                refreshPeriodicityMillis: refreshPeriodicityMillis,
                delayMillis: delayMillis,
                repeatAfterMillis: repeatAfterMillis,
                key: key,
                tag: tag,
                bindContext: bindContext)
            .currentValueDynamic);
  }

  /// An [int] transitions between `start` and `end`.
  static int integer(
    int start,
    int end,
    int durationMillis, {
    int refreshPeriodicityMillis,
    int delayMillis = 0,
    int repeatAfterMillis,
    Object key,
    Object tag,
    FloopBuildContext bindContext,
  }) {
    return Lerp.integer(
        start,
        end,
        _getOrCreateTransition(durationMillis,
                refreshPeriodicityMillis: refreshPeriodicityMillis,
                delayMillis: delayMillis,
                repeatAfterMillis: repeatAfterMillis,
                key: key,
                tag: tag,
                bindContext: bindContext)
            .currentValueDynamic);
  }

  /// A string transitions from `initial` to `end`.
  static String string(
    String end,
    int durationMillis, {
    String initial = '',
    int refreshPeriodicityMillis,
    int delayMillis = 0,
    int repeatAfterMillis,
    Object key,
    Object tag,
    FloopBuildContext bindContext,
  }) {
    return Lerp.string(
        initial,
        end,
        _getOrCreateTransition(durationMillis,
                refreshPeriodicityMillis: refreshPeriodicityMillis,
                delayMillis: delayMillis,
                repeatAfterMillis: repeatAfterMillis,
                key: key,
                tag: tag,
                bindContext: bindContext)
            .currentValueDynamic);
  }

  /// A value that oscillates between 0 and 1.
  ///
  /// Useful for smoothing the value of repeating transitions.
  static double sin(
    int durationMillis, {
    int refreshPeriodicityMillis,
    int delayMillis = 0,
    int repeatAfterMillis,
    Object key,
    Object tag,
    FloopBuildContext bindContext,
  }) {
    return math.sin(2 *
        math.pi *
        _getOrCreateTransition(durationMillis,
                refreshPeriodicityMillis: refreshPeriodicityMillis,
                delayMillis: delayMillis,
                repeatAfterMillis: repeatAfterMillis,
                key: key,
                tag: tag,
                bindContext: bindContext)
            .currentValueDynamic);
  }
}

abstract class Lerp {
  static int integer(int start, int end, double t) {
    return (start + (end - start) * t).toInt();
  }

  static double number(double start, double end, double t) {
    return (start + (end - start) * t);
  }

  static String string(String start, String end, double t) {
    return end.substring(0, (end.length * t).toInt()) +
        start.substring((start.length * t).toInt());
  }
}

/// Returns the same value it receives.
double identity(double ratio) => ratio;

/// Provides [transitionEval] patterns.
abstract class TransitionEval {
  static _Transition _get(Object key, bool cancelIfExists) {
    var transitionState = _Registry.getForKey(key);
    if (cancelIfExists) {
      transitionState?.cancel();
      return null;
    }
    return transitionState;
  }

  /// Creates and pauses a transition. Returns it's key.
  ///
  /// If `cancelIfExists` is true it cancels the existing transition registered
  /// to `key`.
  static Object paused(
    int durationMillis, {
    RatioEvaluator evaluate = identity,
    int refreshPeriodicityMillis,
    int delayMillis = 0,
    int repeatAfterMillis,
    @required Object key,
    Object tag,
    FloopBuildContext bindContext,
    bool cancelIfExists = true,
  }) {
    assert(key != null);
    var transitionState = _get(key, cancelIfExists);
    if (transitionState == null) {
      transitionState = _TransitionEval(
          key,
          durationMillis,
          evaluate,
          refreshPeriodicityMillis,
          delayMillis,
          repeatAfterMillis,
          tag,
          bindContext);
    }
    transitionState.pause();
    return key;
  }

  /// Creates and restarts a transition. Returns it's key.
  ///
  /// If `cancelIfExists` is true it cancels the existing transition registered
  /// to `key`.
  static Object restarted(
    int durationMillis, {
    RatioEvaluator evaluate = identity,
    int refreshPeriodicityMillis,
    int delayMillis = 0,
    int repeatAfterMillis,
    @required Object key,
    Object tag,
    FloopBuildContext bindContext,
    bool cancelIfExists = true,
  }) {
    assert(key != null);
    var transitionState = _get(key, cancelIfExists);
    if (transitionState == null) {
      transitionState = _TransitionEval(
          key,
          durationMillis,
          evaluate,
          refreshPeriodicityMillis,
          delayMillis,
          repeatAfterMillis,
          tag,
          bindContext);
    } else {
      transitionState.restart();
    }
    return key;
  }
}

/// Transitions the value of `key` in `map` using a [Repeater]. Unsynchronized.
///
/// This transition is unsynchronized (it's independent), it can only be
/// controlled throught the returned [Repeater] instance.
///
/// Useful for transitiong an [DynMap] key-value and cause the subscribed
/// widgets to auto rebuild.
Repeater transitionKeyValue<V>(
    Map<dynamic, V> map, Object key, int durationMillis,
    {V update(double elapsedToDurationRatio),
    int refreshPeriodicityMillis = 20}) {
  assert(update != null);
  assert(() {
    if (update == null && V != dynamic && V != double && V != num) {
      throw floopError(
          'Must provide an update function as parameter for type $V in '
          '[transitionKeyValue].');
    }
    return true;
  }());
  update ??= _doubleAsType;
  return Repeater.transition(durationMillis, (double ratio) {
    map[key] = update(ratio);
  }, refreshPeriodicityMillis: refreshPeriodicityMillis);
}
