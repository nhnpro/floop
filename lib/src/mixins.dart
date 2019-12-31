import 'package:floop/floop.dart';

import './flutter.dart';
import './controller.dart';

mixin DisposableWidget on Widget {
  /// Invoked when `context` is mounted (builds for the first time).
  ///
  /// Useful to override for initializing values in an [ObservedMap], or any
  /// other resources that are related only to `context`.
  ///
  /// During the widget tree build cycle [initContext] and [disposeContext] are
  /// methods where it is safe to write values in and [ObservadMap] or
  /// [ObservedValue].
  ///
  /// Default implementation is no-op, it's not necessary to call super.
  ///
  /// See also:
  ///
  ///  * [disposeContext] invoked when the context is unmounted.
  ///  * [DynamicWidget.initDyn] invoked when the dyn member created.
  @protected
  void initContext(BuildContext context) {}

  /// Invoked when `context` is unmounted (not going to be used anymore).
  ///
  /// Useful for disposing values that are were initialized in [initContext],
  /// or any other resources like listeners that are only related to `context`.
  ///
  /// Default implementation is no-op, it's not necessary to call super.
  @protected
  void disposeContext(BuildContext context) {}
}

/// Mixin that causes the Widget be listened while building.
///
/// Include this mixin in a StatelessWidget and it will autoupdate on value
/// changes detected to [ObservedMap] instances read during the build.
/// Example: `MyWidget extends StatelessWidget with Floop {...}`.
mixin Floop on StatelessWidget implements DisposableWidget {
  @override
  void disposeContext(BuildContext context) {}

  @override
  void initContext(BuildContext context) {}

  @override
  StatelessElement createElement() {
    return StatelessElementFloop(this);
  }
}

/// `class MyWidget extends FloopWidget` is equivalent to
/// `class MyWidget extends StatelessWidget with Floop`.
abstract class FloopWidget extends StatelessWidget with Floop {
  const FloopWidget({Key key}) : super(key: key);
}

abstract class FloopBuildContext extends BuildContext
    implements ObservedListener {
  void addUnmountCallback(VoidCallback callback);

  /// Whether the context is active.
  ///
  /// This is intended to make public Flutter _active member. It only works in
  /// debug mode, in release mode it should return always true.
  bool get active;
}

mixin FloopElement on Element implements FloopBuildContext {}

mixin FloopElementMixin on Element implements FloopElement {
  // Value used to register when the postponed notifications callback was
  // created. This is used a security mechanism in case a callback fails and
  // the posponed observeds are not updated.
  static Duration _referenceFrameTimeStamp;

  static _updateReferenceFrameTimeStamp() {
    _referenceFrameTimeStamp =
        WidgetsBinding.instance.currentSystemFrameTimeStamp;
  }

  /// This method is necessary to prevent Flutter assertions error when
  /// invoking markNeedsBuild on the elements.
  static _debugRemoveInactiveElementsFromPostponedList() {
    _postponedElementsForMarking.retainWhere((element) => element.active);
  }

  static void _notifyingCallback([_]) {
    assert(() {
      _debugRemoveInactiveElementsFromPostponedList();
      return true;
    }());
    // Set postponing to false in case there was an error and the value didn't
    // set back to false.
    shouldPostponeMarking = false;
    _updateReferenceFrameTimeStamp();
    _postponedElementsForMarking.forEach((e) => e.markNeedsBuild());
    _postponedElementsForMarking.clear();
  }

  static _createMarkNeedsBuildCallback() {
    _updateReferenceFrameTimeStamp();
    WidgetsBinding.instance.scheduleFrameCallback(_notifyingCallback);
  }

  static final Set<FloopElementMixin> _postponedElementsForMarking = Set();

  static bool get _shouldCreateMarkNeedsBuildCallback =>
      _postponedElementsForMarking.isEmpty ||
      _referenceFrameTimeStamp !=
          WidgetsBinding.instance.currentSystemFrameTimeStamp;

  /// During mounting or unmounting dynamic values could change. The
  /// change notifications are postponed until the frame finishes rendering.
  static void postponeMarking(FloopElementMixin element) {
    assert(element != null);
    if (_shouldCreateMarkNeedsBuildCallback) {
      _createMarkNeedsBuildCallback();
    }
    _postponedElementsForMarking.add(element);
  }

  static bool shouldPostponeMarking;

  DisposableWidget get disposableWidget => widget;

  @override
  void mount(Element parent, dynamic newSlot) {
    shouldPostponeMarking = true;
    disposableWidget.initContext(this);
    super.mount(parent, newSlot);
    shouldPostponeMarking = false;
    assert(() {
      _debugActivate();
      return true;
    }());
  }

  _debugActivate() {
    _debugActive = true;
  }

  @override
  activate() {
    assert(!_debugActive);
    assert(() {
      _debugActivate();
      return true;
    }());
    super.activate();
  }

  _debugDeactivate() {
    _debugActive = false;
  }

  @override
  deactivate() {
    super.deactivate();
    assert(() {
      _debugDeactivate();
      return true;
    }());
  }

  /// Used keep track of the Elements status in debug mode. The [Element]
  /// `_debugActive` field is private.
  bool _debugActive = false;

  bool get active {
    bool active = true;
    assert(() {
      active = _debugActive;
      return true;
    }());
    return active;
  }

  @override
  void unmount() {
    shouldPostponeMarking = true;
    ObservedController.unsubscribeListener(this);
    _unmountCallbacks.forEach((cb) => cb());
    super.unmount();
    disposableWidget.disposeContext(this);
    shouldPostponeMarking = false;
  }

  final Set<VoidCallback> _unmountCallbacks = Set();

  void addUnmountCallback(VoidCallback callback) {
    assert(callback != null);
    _unmountCallbacks.add(callback);
  }

  Set<ObservedNotifier> notifiers;

  @protected
  onObservedChange(ObservedNotifier notifier, [bool postpone = false]) {
    assert(notifiers.contains(notifier));
    if (shouldPostponeMarking || postpone) {
      postponeMarking(this);
    } else {
      markNeedsBuild();
    }
  }
}

/// Wrapper class of StatelessElement used to catch calls to unmount.
///
/// When unmount is called, all references to the Element in Floop are
/// cleaned and the widget's [Floop.disposeContext] is invoked.
class StatelessElementFloop extends StatelessElement
    with FloopElementMixin, FastHashCode
    implements FloopElement {
  StatelessElementFloop(Floop widget) : super(widget);

  Widget _buildWithFloopListening() {
    ObservedController.startListening(this);
    // ignore: invalid_use_of_protected_member
    final childWidget = widget.build(this);
    ObservedController.stopListening();
    return childWidget;
  }

  @override
  Widget build() => _buildWithFloopListening();
}

/// Mixin for StatefulWidgets. Use this mixin in a State class to enable
/// widget builds to be observed by Floop.
mixin FloopStateful on StatefulWidget implements DisposableWidget {
  void initContext(BuildContext context) {}

  void disposeContext(BuildContext context) {}

  @override
  StatefulElement createElement() => StatefulElementFloop(this);
}

/// `class MyState extends FloopState` is equivalent to
/// `class MyWidget extends State with FloopStateMixin`.
abstract class FloopStatefulWidget extends StatefulWidget with FloopStateful {
  const FloopStatefulWidget({Key key}) : super(key: key);
}

class StatefulElementFloop extends StatefulElement
    with FloopElementMixin, FastHashCode
    implements FloopElement {
  StatefulElementFloop(FloopStateful widget) : super(widget);

  Widget _buildWithFloopListening() {
    ObservedController.startListening(this);
    // ignore: invalid_use_of_protected_member
    final childWidget = state.build(this);
    ObservedController.stopListening();
    return childWidget;
  }

  @override
  Widget build() => _buildWithFloopListening();
}

/// Wrapper class used for the mere purpose of skipping the [Widget] class
/// immutable annotation, since the [ObservedMap] requires to be written after
/// a widget has been instantiated.
class _ObservedMapWrapper {
  DynMap map;
}

/// A Floop widget that keeps a mutable [ObservedMap] instance that can be
/// accessed through [dyn].
///
/// To initialize values in [dyn], override the [initDyn] method, which is the
/// equivalent of what [State.initState] would be.
///
/// The existing widget's [dyn] member gets passed on to new [DynamicWidget]
/// instances that update an element (unless the new widget has already been
/// initialized). It can be therefore assumed that [dyn] is persistent on
/// every build cycle.
abstract class DynamicWidget extends FloopWidget {
  DynamicWidget({Key key}) : super(key: key);

  /// Wrapper that hold the internal [ObservedMap].
  ///
  /// A wrapper is used to bypass the annotation warnings.Ideally the map
  /// should be stored directly as a variable `ObservedMap _dyn`, but the
  /// [Widget] `@immutable` annotation requires all fields to be final.
  final _ObservedMapWrapper _dyn = _ObservedMapWrapper();

  /// An internal [ObservedMap] instance that provides dynamic values.
  ///
  /// It gets passed on to new [DynamicWidget] instances whenever the context
  /// rebuilds. Assume [dyn] is persistent on calls to [build].
  DynMap get dyn => _dyn.map;

  /// Invoked when the widget's [dyn] member is created.
  ///
  /// A new [dyn] member will be created is two scenarios:
  ///   1. Automatically: when [dyn] is null and an [Element] instance with
  ///      this widget is mounted (builds for the first time).
  ///   2. Manually: by invoking [forceInit].
  ///
  /// Override to initialize any dynamic values that are used in the [build]
  /// method. It can be thought of as the equivalent of [State.initState].
  @protected
  initDyn() {}

  /// Creates a new [dyn] member and invokes [initDyn].
  ///
  /// Normally the widget is automatically initialized, but it can be useful
  /// to initialize it using [forceInit] when the widget is created outside
  /// of a [build] method and it is desired to pre-set its state.
  ///
  /// An initialized widget can be to replace an active [DynamicWidget] with
  /// one with another that has it's own [dyn]. For example sometimes the same widget
  /// is stored in different states and a parent widget switches them when
  /// certain events trigger.
  ///
  /// invoke [forceInit] when the widget is created to initialize it's own
  /// [dyn] member.
  forceInit() {
    _init();
  }

  _init() {
    _dyn.map = DynMap();
    initDyn();
  }

  /// Invoked on mount of the context.
  ///
  /// It invokes [initDyn] when the [dyn] member of the widget is null.
  @mustCallSuper
  @protected
  void initContext(BuildContext context) {
    if (dyn == null) {
      _init();
    }
  }

  @override
  StatelessElement createElement() => DynamicWidgetElement(this);
}

class DynamicWidgetElement extends StatelessElementFloop {
  DynamicWidgetElement(DynamicWidget widget) : super(widget);

  DynamicWidget get widget => super.widget;

  update(DynamicWidget newWidget) {
    newWidget._dyn.map ??= widget._dyn.map;
    super.update(newWidget);
  }
}
