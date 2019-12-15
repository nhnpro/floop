import 'dart:async';

import 'package:floop/src/time.dart';
import 'package:floop/transition.dart';

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
  return _Registry.getForKey(key)?.lastSetValue;
}

/// Returns a dynamic value that transitions from 0 to 1 in `durationMillis`.
///
/// Specially designed to be invoked from within Floop widgets [build]. Input
/// parameters should remain constant on every rebuild.
///
/// `durationMillis` must not be null.
///
/// `refreshPeriodicityMillis` is the periodicity at which the transition
/// attempts to update it's progress.
///
/// The transition can start after a delay of `delayMillis`.
///
/// If provided, the transition will repeat after `repeatAfterMillis`.
///
/// A `key` uniquely identifies a transition. When invoked outside of a [build]
/// method `key` must be specified.
///
/// `tag` can be specified to identify transitions non uniquely.
///
/// Transitions can be referenced using the `key` or `tag` to apply operations
/// to them through [Transitions] or retrieve the value with [transitionOf].
///
/// `bindContext` binds the transitions to the context. Inside [build] methods
/// it defaults to the [BuildContext] being built.
///
/// Details:
///
///  * If no `bindContext` is provided, the transition is deleted as soon as it
///    finishes, otherwise it is deleted when `bindContext` unmounts.
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
///    not be changing on rebuilds or it will create infinite rebuild cycles.
///
///  * This method does not work inside builders, like [LayoutBuilder], as
///    builders build outside of the encompassing [build] method. A workaround
///    is to use a `var t = transition(...)` in the body of the [build] method
///    and then reference the var from within the builder function.
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
///         ...onPressed: () => Transitions.restart(context: context),
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
/// See also:
///  * [Transitions], an API to modify the ongoing transitions state.
///  * [transitionEval] a more versatile function for creating transitions from
///    outside build methods.
///  * [transitionOf] to retrieve the value of ongoing transitions.
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
  bindContext ??= ObservedController.activeListener;
  final bool canCreate = (bindContext != null) || key != null;
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
  assert(transitionState.lastSetValue != null);
  return transitionState.lastSetValue;
}

/// Creates a transition that returns the evaluation of it's progress ratio by
/// the function `evaluate`.
///
/// Should not be invoked from within a Floop widget's [build] method.
///
/// `durationMillis` and `evaluate` must not be null.
///
/// Refer to [transition] for full description about the parameters.
///
/// It is suggested to provide `bindContext`. Bound transitions are
/// automatically deleted when the context unmounts. Otherwise (if not careful)
/// unreferenced long or repeating transitions will keep running indefinitely
/// in the background until they are canceled with [Transition.cancelAll].
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
///              Transitions.cancel(key: #key);
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
/// transition is created whose `evaluate` function scales the value to the
/// current number of clicks. On every click event the evaluate function
/// changes (because clicks increases), therefore the old transitions is
/// canceled in order to register a new one.
///
/// See also:
///  * [transition]
///  * [Transitions.cancelAll] to delete all registered transitions.
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
      print('Error: should not invoke [transitionEval] while a Floop widget '
          'is building. Use [transition] instead.');
      return false;
    }
    if (durationMillis == null || evaluate == null) {
      print('Error: bad inputs for [transitionEval], durationMillis and '
          'evaluate cannot be null.');
      return false;
    }
    return true;
  }());
  _Transition transitionState;
  if (key != null) {
    transitionState = _Registry.getForKey(key);
  }
  key ??= _createKey();
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
  static int _refreshPeriodicityMillis = 20;

  /// The default refresh periodicity for transitions.
  ///
  /// It defines how often a transition should update it's state. It is only
  /// used when the periodicity is not specified in the transition itself.
  ///
  /// Set to 1 to get the maximum possible refresh rate.
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
    final timeOffset = milliseconds();
    referenceClock = () {
      final dilatedTime =
          ((milliseconds() - timeOffset) * dilationFactor).toInt();
      final currentTime = baseTime + dilatedTime;
      return currentTime - (currentTime % timeGranularityMillis);
    };
  }

  /// Sets the default config values used by [Transitions].
  static void setDefaults() {
    refreshPeriodicityMillis = 20;
    timeGranularityMillis = 10;
    referenceClock =
        () => milliseconds() - milliseconds() % timeGranularityMillis;
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
    for (var transitionState in _Registry.allTransitions()) {
      transitionState.update();
    }
  }

  static setTimeDilation(double dilationFactor) {
    TransitionsConfig.setTimeDilatingClock(dilationFactor);
    _refreshAll();
  }

  /// Returns the frames per second read from a Floop dynamic value.
  ///
  /// It targets the refresh rate for transitions with periodicity
  /// `refreshPeriodicityMillis` if provided, otherwise it returns it for the
  /// default [TransitionsConfig.refreshPeriodicityMillis].
  ///
  /// Returns `null` if no transitions have been created for the periodicity.
  ///
  /// If the Flutter engine is not under stress, the refresh rate should be
  /// close to the inverse of the refresh periodicty. For example if the
  /// periodicity is 50 milliseconds, the refreh rate should be around 20 Hz.
  ///
  /// See also:
  ///  *
  static double currentRefreshRateDynamic([int refreshPeriodicityMillis]) {
    return _SynchronousUpdater.getForPeriodicity(refreshPeriodicityMillis)
        ?.refreshRate;
  }

  static currentRefreshRate([int refreshPeriodicityMillis]) {
    _SynchronousUpdater._periodicityToUpdater[refreshPeriodicityMillis ?? 0]
        ?._observedRefreshRate
        ?.getSilently();
  }

  /// Pauses transitions.
  ///
  /// Note that paused transitions that are not associated to any
  /// [BuildContext] will remain stored (taking memory) until they are resumed
  /// with [resume] or get disposed with [cancel].
  static pause({Object tag, Object key, BuildContext context}) {
    _applyToTransitions(_pause, key, context, tag);
  }

  static _pause(_Transition t) => t.pause();

  static resume({Object tag, Object key, BuildContext context}) {
    _applyToTransitions(_resume, key, context, tag);
  }

  static _resume(_Transition t) {
    t..resume();
  }

  /// Reverts the state of transitions.
  ///
  /// `tag`, `key` and `context` can be specified to filter transitions.
  ///
  /// If `applyToChildContextsTransitions` is set, the operation will also
  /// be applied to all child contexts transitions. This makes the function
  /// considerable more expensive.
  static resumeOrPause(
      {Object tag,
      Object key,
      BuildContext context,
      bool applyToChildContextsTransitions = false}) {
    if (applyToChildContextsTransitions) {
      _applyToAllChildContextTransitions(_resumeOrPause, key, context, tag);
    } else {
      _applyToTransitions(_resumeOrPause, key, context, tag);
    }
  }

  static _resumeOrPause(_Transition t) {
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
  static restart({Object tag, Object key, BuildContext context}) {
    _applyToTransitions(_restart, key, context, tag);
  }

  static _restart(_Transition t) => t..restart();

  static reset({Object tag, Object key, BuildContext context}) {
    _applyToTransitions(_reset, key, context, tag);
  }

  static _reset(_Transition t) => t..reset();

  /// Shifts the transition by `shiftTimeMillis`.
  ///
  /// If `shiftTimeMillis` is null, the transition will be advanced to it's
  /// total duration time (finished).
  ///
  /// Identical to [shiftTime], but this method will get removed in later
  /// versions to keep the more explicit shiftTime name.
  // @deprecated
  // static shift({int shiftTimeMillis, Object key, BuildContext context}) {
  //   _applyToTransitions(
  //       (_TransitionState t) => t?.shift(shiftTimeMillis), key, context);
  // }

  /// Shifts the progress time of transitions by `shiftMillis`.
  ///
  /// If `shiftMillis` is null, the transition's progress will be set to it's
  /// total duration.
  static shiftTime(
      {int shiftMillis, Object tag, Object key, BuildContext context}) {
    _applyToTransitions(
        (_Transition t) => t..shift(shiftMillis), key, context, tag);
  }

  // static _shift(_TransitionState t, int shiftMillis) {
  //   _resumePeriodicUpdates(t..shift(shiftMillis));
  // }

  /// Clear all transitions. Equivalent to invoking `Transitions.cancel()`.
  static cancelAll() => _Registry.allTransitions().toList().forEach(_cancel);

  /// Stops and removes references to transitions.
  ///
  /// Particularly useful for causing a context to rebuild as if it was being
  /// built for the first time.
  static cancel({Object tag, Object key, BuildContext context}) {
    if (key == null && context == null) {
      cancelAll();
    } else {
      _applyToTransitions(_cancel, key, context);
    }
  }

  static _cancel(_Transition t) {
    t.cancel();
  }
}

Iterable<_Transition> _filter(Object tag, BuildContext context) {
  // return _Registry.allTransitions()
  //     .where((transitionState) => transitionState.matches(tag, context));
  Iterable<_Transition> transitions;
  if (tag != null && context != null) {
    transitions = _Registry.getForContext(context)
        ?.where((transitionState) => transitionState.tag == tag);
  } else if (tag != null) {
    transitions = _Registry.getForTag(tag);
  } else if (context != null) {
    transitions = _Registry.getForContext(context);
  } else {
    transitions = _Registry.allTransitions();
  }
  return transitions ?? const [];
}

int _minDepth(int depth, Element element) {
  if (element.depth < depth) {
    return element.depth;
  }
  return depth;
}

int _sort(Element a, Element b) {
  if (a.depth < b.depth)
    return -1; // ignore: curly_braces_in_flow_control_structures
  if (b.depth < a.depth)
    return 1; // ignore: curly_braces_in_flow_control_structures
  return 0;
}

Iterable<Element> _getAllChildElements(Iterable<Element> referenceElements) {
  // final referenceElements = [for (var t in transitions) t.context as Element];
  final resultSet = referenceElements.toSet();

  final minAncestorDepth = referenceElements.fold(_largeInt, _minDepth);
  var childrenCandidatesIterable = (_Registry.allRegisteredContexts()
          .cast<Element>()
          .where(
              (ele) => ele.depth > minAncestorDepth && !resultSet.contains(ele))
          .toList()
            ..sort(_sort))
      .reversed;
  assert(() {
    childrenCandidatesIterable = childrenCandidatesIterable
        .where((element) => (element as FloopElement).active);
    return true;
  }());
  final childrenCandidates = childrenCandidatesIterable.toSet();
  final visited = Set<Element>();

  // Prevents Flutter assertion error.

  // Visits ancesostors and adds registered children to result.
  _visitAncestors(Element child) {
    // if (!visitingTargets.contains(child)) {
    //   return;
    // }
    assert((child as FloopBuildContext).active);
    if (visited.contains(child)) {
      return;
    }
    visited.add(child);
    var candidates = <Element>[child];
    child.visitAncestorElements((ancestor) {
      if (resultSet.contains(ancestor)) {
        resultSet.addAll(candidates);
        return false;
      }
      assert(child.depth >= minAncestorDepth);
      visited.add(ancestor);
      if (childrenCandidates.remove(ancestor)) {
        candidates.add(ancestor);
      }
      if (ancestor.depth == minAncestorDepth) {
        return false;
      }
      return true;
    });
  }

  childrenCandidatesIterable.forEach(_visitAncestors);
  return resultSet;
}

void _applyToAllChildContextTransitions(
    Function(_Transition) apply, Object key, BuildContext context,
    [Object tag]) {
  _apply(BuildContext branchContext) {
    _applyToTransitions(apply, null, branchContext);
  }

  Iterable<_Transition> transitions;
  if (key != null) {
    final transitionState = _Registry.getForKey(key);
    if (transitionState?.context != null &&
        transitionState.matches(tag, context)) {
      transitions = [transitionState];
    }
  } else {
    transitions = _filter(tag, context);
  }
  var elements = <Element>[
    for (var t in transitions) if (t.context != null) t.context as Element
  ];
  var childElements = _getAllChildElements(elements);
  childElements.forEach(_apply);
}

void _applyToTransitions(
    Function(_Transition) apply, Object key, BuildContext context,
    [Object tag]) {
  if (key != null) {
    final transitionState = _Registry.getForKey(key);
    if (transitionState != null && transitionState.matches(tag, context)) {
      apply(_Registry.getForKey(key));
    }
  } else {
    // final filtered = _filter(tag, context);
    // print('Filtered transition legnth: ${filtered.length}');
    _filter(tag, context).forEach(apply);
  }
}

Set<T> _createEmptySet<T>() => Set();

abstract class _Registry {
  static final Map<BuildContext, Set<_Transition>> _contextToTransitions =
      ObservedMap();
  static final Map<Object, _Transition> _keyToTransition = ObservedMap();
  static final Map<Object, Set<_Transition>> _tagToTransitions = ObservedMap();

  static _Transition getForKey(Object key) => _keyToTransition[key];

  static Iterable<_Transition> getForTag(Object tag) => _tagToTransitions[tag];

  static Iterable<_Transition> getForContext(BuildContext context) =>
      _contextToTransitions[context];

  static bool contextIsRegistered(BuildContext context) =>
      _contextToTransitions.containsKey(context);

  static Iterable<BuildContext> allRegisteredContexts() =>
      _contextToTransitions.keys;

  static Iterable<_Transition> allTransitions() => _keyToTransition.values;

  static register(_Transition transitionState) {
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
/// same _SyncUpdater.
class _SynchronousUpdater {
  static final ObservedMap<int, _SynchronousUpdater> _periodicityToUpdater =
      ObservedMap();

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
    _timeStep = TransitionsConfig._initialize ?? currentTimeStep;
  }

  final int _periodicityMillis;
  int get periodicityMillis => _periodicityMillis > 0
      ? _periodicityMillis
      : TransitionsConfig.refreshPeriodicityMillis;

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
  int _lastStopwatchTime = milliseconds();

  /// The time used by the transitions to measure their progress.
  int _timeStep;

  /// The synchronized clock time for this updater.
  ///
  /// It will only change after a new frame has been rendered.
  int get currentTimeStep {
    if (newFrameWasRendered()) {
      _timeStep = truncateTime(TransitionsConfig.referenceClock());
    }
    return _timeStep;
  }

  int get nextUpdateMinWaitTime =>
      periodicityMillis - (lastFrameUpdateTimeStamp - _lastUpdateTimeStamp);

  /// The target update time for the next update.
  ///
  /// It's null when no future updates are going to be performed.
  int _targetUpdateTime = -_largeInt;

  /// Number of frames per second (with updated transition progress).
  ObservedValue<double> _observedRefreshRate =
      TimedDynValue(Duration(milliseconds: 500), 0);
  double get refreshRate => _observedRefreshRate.value;
  set refreshRate(double rate) => _observedRefreshRate.value = rate;

  /// Records the last Flutter frame time stamp when an update was performed.
  int _lastUpdateTimeStamp = 0;

  // Duration get lastUpdateTimeStamp => _lastUpdateTimeStamp;

  int get lastFrameUpdateTimeStamp =>
      WidgetsBinding.instance.currentSystemFrameTimeStamp.inMilliseconds;

  bool newFrameWasRendered() =>
      _lastUpdateTimeStamp != lastFrameUpdateTimeStamp;

  /// Whether a future update is scheduled.
  ///
  /// If _targetUpdateTime!=null an update is scheduled. The second condition
  /// is used as fallback mechanism in case there is an error and
  /// _targetUpdateTime is never set back to null.
  bool willUpdate() =>
      _transitionsToUpdate.isNotEmpty &&
      _targetUpdateTime != null &&
      (milliseconds() < _targetUpdateTime + periodicityMillis ||
          !newFrameWasRendered());

  static const smoothFactor = 0.85;

  static const _numberSamples = 50;
  final _samples = List.filled(_numberSamples, milliseconds());
  var _sampleIndex = 0;

  _updateRefreshRateAndPlainTime() {
    final now = milliseconds();
    // final newRefreshRate =
    //     (oneSecondInMillis / (now - _lastStopwatchTime));
    _lastStopwatchTime = now;
    final index = _sampleIndex++;
    _samples[index] = now;
    _sampleIndex %= _numberSamples;
    refreshRate =
        1000 * _numberSamples / (_samples[index] - _samples[_sampleIndex]);
    // refreshRate =
    //     smoothFactor * refreshRate + (1 - smoothFactor) * newRefreshRate;
  }

  _delayedUpdate() {
    if (_lastUpdateTimeStamp == lastFrameUpdateTimeStamp) {
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
  _scheduleUpdate([int waitTime]) {
    waitTime ??= nextUpdateMinWaitTime;
    _targetUpdateTime = _lastStopwatchTime + waitTime;
    _lastUpdateTimeStamp = lastFrameUpdateTimeStamp;
    final timeToNextUpdate = _targetUpdateTime - _lastStopwatchTime;
    Future.delayed(Duration(milliseconds: timeToNextUpdate), _delayedUpdate);
  }

  scheduleUpdate(_Transition transitionState) {
    if (!lockUpdateScheduling && !willUpdate()) {
      _scheduleUpdate();
    }
    _transitionsToUpdate.add(transitionState);
  }

  cancelScheduledUpdates(_Transition transitionState) {
    _transitionsToUpdate.remove(transitionState);
  }

  _updateCallback([_]) {
    _targetUpdateTime = null;
    update();
  }

  bool lockUpdateScheduling = false;

  /// Updates the transitions and returns true if there are active transitions.
  update() {
    // print('updating transitions with periodicity $periodicityMillis[ms]');
    final transitions = _transitionsToUpdate;
    _transitionsToUpdate = Set();
    _updateRefreshRateAndPlainTime();
    try {
      // Disallow transitions from scheduling update callbacks
      lockUpdateScheduling = true;
      for (var transitionState in transitions) {
        transitionState
          // ..notifyChange()
          ..update();
      }
      if (_transitionsToUpdate.isNotEmpty) {
        _scheduleUpdate(periodicityMillis);
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

class _Transition with FastHashCode {
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

  final ObservedValue<double> observedRatio = ObservedValue(0);

  double setProgressRatio(double ratio) =>
      observedRatio.value = ratio; //observedRatio.setSilently(ratio);
  double get lastSetProgressRatio => observedRatio.getSilently();

  double get lastSetValue => observedRatio.value.clamp(0.0, 1.0);

  _Transition(
    this.key,
    this.durationMillis, [
    // this.evaluate,
    int refreshPeriodicityMillis,
    this.delayMillis,
    this.repeatAfterMillis,
    this.tag,
    // this.group,
    this.context,
  ]) : updater = _SynchronousUpdater.getForPeriodicity(
            refreshPeriodicityMillis, true) {
    assert(
        repeatAfterMillis == null || repeatAfterMillis > -aggregatedDuration);
    shiftedMillis = -currentTimeStep;
    if (context != null && !_Registry.contextIsRegistered(context)) {
      context.addUnmountCallback(() => cancelContextTransitions(context));
    }
    _Registry.register(this);
    updater.scheduleUpdate(this);
  }

  bool matches(Object refTag, BuildContext refContext) =>
      (refTag == null || tag == refTag) &&
      (refContext == null || context == refContext);

  int shiftedMillis = 0;
  int _pauseTime;

  _Status _status = _Status.active;

  /// Active represents elapsedMillis < aggregatedDuration on the last update.
  bool get isActive => _status == _Status.active;

  /// Pause is different from active, a transition only reaches inactive status
  /// when it finishes (reaches its max duration).
  bool get isPaused => _pauseTime != null;

  bool get shouldDispose => !isActive && context == null;

  /// Whether this transition should keep updating periodically.
  bool get shouldKeepUpdating => isActive && !isPaused;

  /// The updater time. It updates asynchronously.
  int get currentTimeStep => updater.currentTimeStep;

  int _repeatTime(int elapsed) {
    if (repeatAfterMillis < 0) {
      // If repeatAfterMillis is negative, the transition starts advanced,
      // such that it always reaches its end value.
      final duration = aggregatedDuration;
      elapsed -= duration;
      // Starting from the third cycle the repeat time needs to be added.
      if (elapsed > duration) {
        elapsed = -repeatAfterMillis + elapsed % (duration + repeatAfterMillis);
      }
    } else {
      elapsed %= aggregatedDuration + repeatAfterMillis;
    }
    return elapsed;
  }

  int get elapsedMillis {
    var elapsed = (_pauseTime ?? lastUpdateTimeStep) + shiftedMillis;
    if (repeatAfterMillis != null && elapsed > aggregatedDuration) {
      elapsed = _repeatTime(elapsed);
    }
    return elapsed;
  }

  /// Observed values are set silently, the synchronous updater should trigger
  /// value change notifications using this method.
  notifyChange() => observedRatio.notifyChange();

  double computeAbsoluteProgressRatio(int timeMillis) =>
      (timeMillis - delayMillis) / durationMillis;

  pause() {
    _pauseTime = lastUpdateTimeStep;
  }

  resume() {
    if (isPaused) {
      // print('pause time: $_pauseTime, current time: $currentTimeStep');
      shiftedMillis += _pauseTime - currentTimeStep;
      _pauseTime = null;
      update();
      // print('resuming time: $elapsedMillis ');
    }
  }

  reset() {
    if (isPaused) {
      _pauseTime = currentTimeStep;
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

  cancel() {
    notifyChange();
    dispose();
  }

  /// Invoked when the transition is not going to be used again.
  dispose() {
    assert(_status != _Status.defunct);
    updater.cancelScheduledUpdates(this);
    observedRatio.dispose();
    _Registry.unregister(this);
    assert(() {
      _status = _Status.defunct;
      return true;
    }());
  }

  int lastUpdateTimeStep = 0;

  activate() {
    _status = _Status.active;
    // updater.updateInNextRound(this);
  }

  _repeatOrDeactivate() {
    if (repeatAfterMillis == null) {
      _status = _Status.inactive;
    }
  }

  _updateStatus() {
    if (lastSetProgressRatio > 1) {
      _repeatOrDeactivate();
    } else if (!isActive) {
      _status = _Status.active;
    }
  }

  _scheduleNextUpdate() {
    updater.scheduleUpdate(this);
  }

  _updateValue() {
    double ratio = computeAbsoluteProgressRatio(elapsedMillis);
    setProgressRatio(ratio);
  }

  /// Updates the transition state.
  void update() {
    assert(_status != _Status.defunct);
    lastUpdateTimeStep = currentTimeStep;
    _updateValue();
    _updateStatus();
    if (shouldDispose) {
      dispose();
    } else {
      if (shouldKeepUpdating) {
        _scheduleNextUpdate();
      }
    }
  }
}

class _TransitionEval extends _Transition {
  final RatioEvaluator evaluate;

  double _value = 0;
  double get lastSetValue {
    // Invoked to activate a dynamic value read.
    observedRatio.notifyRead();
    return _value;
  }

  _TransitionEval(
    key,
    durationMillis, [
    this.evaluate,
    int refreshPeriodicityMillis,
    int delayMillis = 0,
    int repeatAfterMillis,
    Object tag,
    FloopBuildContext context,
  ]) : super(key, durationMillis, refreshPeriodicityMillis, delayMillis,
            repeatAfterMillis, tag, context);

  setProgressRatio(double ratio) {
    super.setProgressRatio(ratio);
    _value = evaluate(ratio.clamp(0.0, 1.0));
    return ratio;
  }

  // @override
  // void update() {
  //   super.update();
  //   if(isActive) {
  //     _value = evaluate(super.lastSetValue);
  //   }
  // }
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

// void _stopAndDispose(Object key) {
//   _Registry.getTransition(key)?.dispose();
// }

// void _clearContextTransitions(FloopBuildContext element) {
//   _contextToKeys.remove(element)?.forEach(_stopAndDispose);
// }

// extension IntegerLerp on int {
//   lerp(int end, double t) {
//     return (this + (end - this) * t).toInt();
//   }
// }

// extension DoubleLerp on double {
//   lerp(double end, double t) {
//     return (this + (end - this) * t);
//   }
// }

// extension StringLerp on String {
//   lerp(String end, double t) {
//     return end.substring(0, (end.length * t).toInt()) +
//         substring((length * t).toInt());
//   }
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
