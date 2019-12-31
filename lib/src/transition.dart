import 'dart:async';

import './flutter.dart';
import './controller.dart';
import './observed.dart';
import './mixins.dart';
import './repeater.dart';
import './error.dart';
import './time.dart';

// ignore_for_file: deprecated_member_use_from_same_package

T _doubleAsType<T>(double x) => x as T;

typedef MillisecondsReturner = int Function();

const _largeInt = 1 << 62 | 1 << 53 | (1 << 31) | (1 << 30);

/// Returns the value of a transition registered with `key` if it exists,
/// `null` otherwise.
double transitionOf(Object key) {
  return _Registry.getForKey(key)?.lastSetValue;
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
/// A `key` is a unique identifier. When invoked outside of a [build] method
/// `key` must be specified. To retrieve the value of a transition using
/// [transitionOf], `key` must be specified.
///
/// `tag` is non unique identifier.
///
/// Transitions can be referenced using the `key` or `tag` and control them
/// with [TransitionGroup].
///
/// `bindContext` binds the transitions to the context. Inside [build] methods
/// it defaults to the [BuildContext] being built.
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
          'the `key` parameter must be not null, otherwise the transition can '
          'have no effect outside of itself.\n'
          'If this is getting invoked from within a [Builder], check '
          '[transition] docs to handle that case.');
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
/// transition is created whose `evaluate` function scales the value to the
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
  static int _updateDelayLimitThreshold;

  /// The delay time that the asynchronous updates can take before the library
  /// determines they have taken too long and creates new ones.
  ///
  /// This is a safety mechanism that the library uses to recover in case
  /// something goes wrong. Generally it shouldn't have an impact on apps
  /// that run smoothly.
  static int get updateDelayLimitThreshold =>
      _initialize ?? _updateDelayLimitThreshold;

  static set updateDelayLimitThreshold(int thresholdMillis) {
    _setDefaults();
    assert(thresholdMillis > 0);
    _updateDelayLimitThreshold = thresholdMillis;
  }

  static int _refreshPeriodicityMillis;

  /// The default refresh periodicity for transitions.
  ///
  /// It defines how often a transition should update it's state. When the
  /// periodicity is specified in the transition, this value is not used.
  ///
  /// Set to 1 to get the maximum possible refresh rate.
  static int get refreshPeriodicityMillis =>
      _initialize ?? _refreshPeriodicityMillis;

  static set refreshPeriodicityMillis(int periodicityMillis) {
    _setDefaults();
    assert(periodicityMillis != null && periodicityMillis > 0);
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

  static DynValue _dynTimeDilation;

  /// The time dilation as a dynamic value.
  ///
  /// The time dilation does not affect the refresh rate of the transitions, it
  /// affects their progress rate. The default refresh periodicity can be
  /// modified by [TransitionsConfig.refreshPeriodicityMillis].
  static double get timeDilationFactor => _dynTimeDilation.value;

  /// Sets a time dilating [referenceClock] that continues the current time.
  static set timeDilationFactor(double dilationFactor) {
    return setTimeDilation(dilationFactor);
  }

  /// Sets a time dilating [referenceClock] that continues the current time.
  ///
  /// `dilationFactor` can be any double and it is used as a factor of the
  /// time since the dilation was set.
  ///
  /// The time dilation does not affect the refresh rate of the transitions, it
  /// affects their progress rate. The default refresh periodicity can be
  /// modified by [TransitionsConfig.refreshPeriodicityMillis].
  @Deprecated('Set using [timeDilationFactor] instead.')
  static void setTimeDilation(double dilationFactor) {
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
    _dynTimeDilation = DynValue(1.0);
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

/// [Transitions] allow controlling created the transitions.
@Deprecated('Methods have been replaced by TransitionGroup')
abstract class Transitions {
  static void _refreshAll() {
    for (var transitionState in _Registry.allTransitions()) {
      transitionState.update();
    }
  }

  static setTimeDilation(double dilationFactor) {
    TransitionsConfig.setTimeDilation(dilationFactor);
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

  /// Pauses transitions.
  ///
  /// `tag`, `key` and `context` can be specified to filter transitions.
  ///
  /// Refer to [restart] for detailed documentation about filtering.
  ///
  /// If `applyToChildren` is set, the operation will be applied to all
  /// filtered transitions contexts and children context transitions.
  @Deprecated('TransitionGroup should be used instead.')
  static pause(
      {Object tag,
      Object key,
      BuildContext context,
      bool applyToChildren = false}) {
    applyToTransitions(_pause, key, context, tag, applyToChildren);
  }

  static _pause(_Transition t) => t.pause();

  /// Resume paused transitions.
  ///
  /// `tag`, `key` and `context` can be specified to filter transitions.
  ///
  /// If `applyToChildren` is set, the operation will be applied to all
  /// filtered transitions contexts and children context transitions.
  @Deprecated('TransitionGroup should be used instead.')
  static resume(
      {Object tag,
      Object key,
      BuildContext context,
      bool applyToChildren = false}) {
    applyToTransitions(_resume, key, context, tag, applyToChildren);
  }

  static _resume(_Transition t) {
    t..resume();
  }

  /// Reverts the state of transitions.
  ///
  /// `tag`, `key` and `context` can be specified to filter transitions.
  ///
  /// If `applyToChildren` is set, the operation will be applied to all
  /// filtered transitions contexts and children context transitions.
  @Deprecated('TransitionGroup should be used instead.')
  static resumeOrPause(
      {Object tag,
      Object key,
      BuildContext context,
      bool applyToChildren = false}) {
    applyToTransitions(_resumeOrPause, key, context, tag, applyToChildren);
  }

  static _resumeOrPause(_Transition t) {
    if (t.isPaused) {
      _resume(t);
    } else {
      _pause(t);
    }
  }

  /// Reverses the time progress of transitions.
  ///
  /// `tag`, `key` and `context` can be specified to filter transitions. Null
  /// represents any.
  ///
  /// If `applyToChildren` is set, the operation will be applied to all
  /// filtered transitions contexts and children context transitions.
  @Deprecated('TransitionGroup should be used instead.')
  static reverse(
      {Object tag,
      Object key,
      BuildContext context,
      bool applyToChildren = false}) {
    applyToTransitions(_reverse, key, context, tag, applyToChildren);
  }

  static _reverse(_Transition t) => t.reverse();

  /// Restarts transitions.
  ///
  /// Restart is equivalent to applying [reset] and [resume].
  ///
  /// `tag`, `key` and `context` can be specified to filter transitions. They
  /// can be either a [Match] closure or a value. Passing a value produces the
  /// same output as passing a [Match] closure that checks for equality.
  ///
  ///
  /// If `applyToChildren` is set, the operation will be applied to all
  /// filtered transitions contexts and children context transitions.
  @Deprecated('TransitionGroup should be used instead.')
  static restart(
      {Object tag,
      Object key,
      BuildContext context,
      bool applyToChildren = false}) {
    applyToTransitions(_restart, key, context, tag, applyToChildren);
  }

  static _restart(_Transition t) => t..restart();

  /// Resets the values from transtions.
  ///
  /// `tag`, `key` and `context` can be specified to filter transitions.
  ///
  /// If `applyToChildren` is set, the operation will be applied to all
  /// filtered transitions contexts and children context transitions.
  @Deprecated('TransitionGroup should be used instead.')
  static reset(
      {Object tag,
      Object key,
      BuildContext context,
      bool applyToChildren = false}) {
    applyToTransitions(_reset, key, context, tag, applyToChildren);
  }

  static _reset(_Transition t) => t..reset();

  /// Shifts the progress time by `shiftMillis`.
  ///
  /// `tag`, `key` and `context` can be specified to filter transitions.
  ///
  /// If `applyToChildren` is set, the operation will be applied to all
  /// filtered transitions contexts and children context transitions.
  @Deprecated('TransitionGroup should be used instead.')
  static shiftTime(
      {int shiftMillis,
      ShiftType shiftType = ShiftType.current,
      Object tag,
      Object key,
      BuildContext context,
      bool applyToChildren = false}) {
    if (shiftType == ShiftType.begin) {
      applyToTransitions(_shiftBegin, key, context, tag, applyToChildren);
    } else if (shiftType == ShiftType.end) {
      applyToTransitions(_shiftEnd, key, context, tag, applyToChildren);
    }
    if (shiftMillis != null) {
      applyToTransitions((_Transition t) => t.shift(shiftMillis), key, context,
          tag, applyToChildren);
    }
  }

  static _shiftEnd(_Transition t) => t.shiftEnd();
  static _shiftBegin(_Transition t) => t.shiftBegin();

  /// Deletes all transitions. Equivalent to `TransitionGroup().cancel()`.
  static cancelAll() => _Registry.allTransitions().toList().forEach(_cancel);

  /// Deletes transitions.
  ///
  /// Particularly useful to cause a context to rebuild as if it was being
  /// built for the first time.
  ///
  /// `tag`, `key` and `context` can be specified to filter transitions.
  ///
  /// If `applyToChildren` is set, the operation will be applied to all
  /// filtered transitions contexts and children context transitions.
  @Deprecated('TransitionGroup should be used instead.')
  static cancel(
      {Object tag,
      Object key,
      BuildContext context,
      bool applyToChildren = false}) {
    if (key == null && context == null) {
      cancelAll();
    } else {
      applyToTransitions(_cancel, key, context, tag, applyToChildren);
    }
  }

  static _cancel(_Transition t) {
    t.cancel();
  }
}

/// An object that can be used to apply operations to group of transitions.
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

  final Object key;
  final Object tag;
  final BuildContext context;

  /// Transitions of this group evaluate true when passed to [matcher].
  TransitionMatcher matcher;

  /// Create an object that represents transitions that match the parameters
  /// and provides methods to control them.
  ///
  /// Non null `key`, `tag` and/or `context` are matched.
  ///
  /// `matcher` can be provided for advanced filtering.
  ///
  /// Operations accept an `applyToChildren` parameter and if set the operation
  /// is applied to all transitions that are bound to the context and child
  /// contexts of the transitions from this group.
  ///
  /// A transition group with no parameters represents all transitions.
  TransitionGroup({this.key, this.tag, this.context, this.matcher});

  _apply(operation, bool applyToChildren) {
    applyToTransitions(operation, key, context, tag, applyToChildren, matcher);
  }

  resume({bool applyToChildren = false}) {
    _apply(Transitions._resume, applyToChildren);
  }

  pause({bool applyToChildren = false}) {
    _apply(Transitions._pause, applyToChildren);
  }

  /// Resumes paused and pauses active.
  resumeOrPause({bool applyToChildren = false}) {
    _apply(Transitions._resumeOrPause, applyToChildren);
  }

  /// Resumes the time direction.
  reverse({bool applyToChildren = false}) {
    _apply(Transitions._reverse, applyToChildren);
  }

  /// Equivalent to reset + resume.
  restart({bool applyToChildren = false}) {
    _apply(Transitions._restart, applyToChildren);
  }

  reset({bool applyToChildren = false}) {
    _apply(Transitions._reset, applyToChildren);
  }

  /// Shifts the progress time by `shiftMillis`.
  shiftTime(
      {int shiftMillis = 0,
      ShiftType shiftType = ShiftType.current,
      bool applyToChildren = false}) {
    if (shiftType == ShiftType.begin) {
      _apply(Transitions._shiftBegin, applyToChildren);
    } else if (shiftType == ShiftType.end) {
      _apply(Transitions._shiftEnd, applyToChildren);
    }
    _apply((_Transition t) => t.shift(shiftMillis), applyToChildren);
  }

  /// Deletes the transitions.
  ///
  /// Particularly useful to cause a context to rebuild as if it was being
  /// built for the first time.
  ///
  /// `TransitionGroup().cancel()` cancels all transitions.
  cancel({bool applyToChildren = false}) {
    _apply(Transitions._cancel, applyToChildren);
  }
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

void _addChildElements(Set<Element> referenceElements) {
  final resultSet = referenceElements;
  final minAncestorDepth = referenceElements.fold(_largeInt, _minDepth);
  var childrenCandidatesIterable = (_Registry.allRegisteredContexts()
          .cast<Element>()
          .where(
              (ele) => ele.depth > minAncestorDepth && !resultSet.contains(ele))
          .toList()
            ..sort(_sort))
      .reversed;
  assert(() {
    // This is necessary to avoid Flutter assertion errors in debug mode.
    childrenCandidatesIterable = childrenCandidatesIterable
        .where((element) => (element as FloopElement).active);
    return true;
  }());
  final childrenCandidates = childrenCandidatesIterable.toSet();

  // Visits ancesostors and adds registered children to result.
  _visitAncestors(Element child) {
    assert((child as FloopBuildContext).active);
    if (!childrenCandidates.remove(child)) {
      // Already visited.
      return;
    }
    var candidates = <Element>[child];
    child.visitAncestorElements((ancestor) {
      if (childrenCandidates.remove(ancestor)) {
        candidates.add(ancestor);
      }
      if (resultSet.contains(ancestor)) {
        resultSet.addAll(candidates);
        return false;
      }
      assert(child.depth >= minAncestorDepth);
      if (ancestor.depth == minAncestorDepth) {
        return false;
      }
      return true;
    });
  }

  childrenCandidatesIterable.forEach(_visitAncestors);
}

Iterable<_Transition> _getContextAndDescendantContextTransitions(
    Iterable<_Transition> transitions) {
  final elements = Set<Element>.from(
      [for (var t in transitions) if (t.context != null) t.context as Element]);
  _addChildElements(elements);
  var result = Iterable<_Transition>.empty();
  for (var context in elements) {
    result = result.followedBy(_Registry.getForContext(context));
  }
  return result;
}

Iterable<_Transition> _filter(key, tag, BuildContext context) {
  Iterable<_Transition> filtered;
  if (key != null) {
    final transitionState = _Registry.getForKey(key);
    if (transitionState?.matches(tag, context) == true) {
      filtered = [transitionState];
    }
  } else if (context != null) {
    filtered = _Registry.getForContext(context)
            ?.where((transitionState) => transitionState.matches(tag, null)) ??
        const [];
  } else if (tag != null) {
    filtered = _Registry.getForTag(tag) ?? const [];
  } else {
    filtered = _Registry.allTransitions();
  }
  return filtered ?? const [];
}

abstract class TransitionView {
  Object get key;
  Object get tag;
  BuildContext get context;
}

typedef TransitionMatcher = bool Function(TransitionView);

applyToTransitions(Function(_Transition) apply, Object key,
    BuildContext context, Object tag, bool applyToChildren,
    [TransitionMatcher matcher]) {
  Iterable<_Transition> filteredTransitions = _filter(key, tag, context);
  if (matcher != null) {
    filteredTransitions = filteredTransitions.where((t) => matcher(t));
  }
  if (applyToChildren) {
    filteredTransitions =
        _getContextAndDescendantContextTransitions(filteredTransitions);
  }
  filteredTransitions.toList().forEach(apply);
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
        debugPrint('Internal error, attempting to create a transition that '
            'already exists. Filling an issue in the repository is '
            'appreciated (this should not happen).');
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
  ObservedValue<double> _observedRefreshRate =
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
        transitionState.update();
      }
    } finally {
      updatingLock = false;
      if (_transitionsToUpdate.isNotEmpty) {
        _delayedUpdate();
      }
    }
  }
}

enum _Status {
  active,
  inactive,
  defunct,
}

class _Transition with FastHashCode implements TransitionView {
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

  double get lastSetValue => dynRatio.value.clamp(0.0, 1.0);

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
    assert(() {
      _status = _Status.defunct;
      return true;
    }());
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
    if (ratio > 1 && !reversed) {
      _repeatOrDeactivate();
    } else if (ratio < 0 && reversed) {
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
  double get lastSetValue {
    // Invoke notifyRead as if is were a value read.
    dynRatio.notifyRead();
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
  ])  : _value = evaluate(0),
        super(key, durationMillis, refreshPeriodicityMillis, delayMillis,
            repeatAfterMillis, tag, context);

  update() {
    super.update();
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

/// Invokes [transition] and scales the return value between `start` and `end`.
int transitionInt(int start, int end, int durationMillis,
    {int refreshPeriodicityMillis = 20, int delayMillis = 0, Object key}) {
  return Lerp.integer(
      start,
      end,
      transition(durationMillis,
          refreshPeriodicityMillis: refreshPeriodicityMillis,
          delayMillis: delayMillis,
          key: key));
}

/// Invokes [transition] and scales the return value between `start` and `end`.
num transitionNumber(num start, num end, int durationMillis,
    {int refreshPeriodicityMillis = 20, int delayMillis = 0, Object key}) {
  return Lerp.number(
      start,
      end,
      transition(durationMillis,
          refreshPeriodicityMillis: refreshPeriodicityMillis,
          delayMillis: delayMillis,
          key: key));
}

/// Transitions a string starting from length 0 to it's full length.
String transitionString(String string, int durationMillis,
    {int refreshPeriodicityMillis = 20, int delayMillis = 0, Object key}) {
  return Lerp.string(
      '',
      string,
      transition(durationMillis,
          refreshPeriodicityMillis: refreshPeriodicityMillis,
          delayMillis: delayMillis,
          key: key));
}

/// Transitions the value of `key` in the provided `map`.
///
/// The transition lasts for `durationMillis` and updates it's value
/// with a rate of `refreshRateMillis`.
///
/// Useful for easily transitiong an [DynMap] key-value and cause the
/// subscribed widgets to auto rebuild while the transition lasts.
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
    // var value = update(ratio);
    map[key] = update(ratio);
  }, refreshPeriodicityMillis: refreshPeriodicityMillis);
}
