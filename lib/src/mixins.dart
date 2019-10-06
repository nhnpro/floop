import 'package:floop/floop.dart';

import './flutter_import.dart';
import './controller.dart';

mixin DisposableWidget on Widget {
  /// Invoked when `context` is mounted (builds for the first time).
  ///
  /// Useful to override for initializing values in an [ObservedMap], or any
  /// other resources that are related only to `context`.
  ///
  /// Default implementation is no-op, it's not necessary to call super.
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
  void disposeContext(BuildContext context) {}

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

abstract class FloopBuildContext extends BuildContext {
  void addUnmountCallback(VoidCallback callback);
}

mixin FloopElement on Element implements FloopBuildContext, ObservedListener {}

mixin FloopElementMixin on Element implements FloopElement {
  static bool _posponeOnObservedChange = false;

  static final _posponedObserveds = Set<ObservedNotifier>();

  static void _observedChangeCallback([_]) {
    assert(_posponedObserveds.isNotEmpty);
    // for (var observed in _posponedObserveds) {
    //   _posponedObserveds.forEach(ObservedController.handleChange);
    // }
    _posponedObserveds.forEach(ObservedController.notifyChangeToListeners);
    _posponedObserveds.clear();
  }

  static int _initialPosponedNotifiersLenght;

  static void _startPosponingObservedNotifications() {
    ObservedController.posponeNotifications();
    _initialPosponedNotifiersLenght =
        ObservedController.posponedObserveds.length;
  }

  static void _finishPosponingObservedNotifications() {
    ObservedController.disablePosponeNotifications();
    if (ObservedController.posponedObserveds.length >
        _initialPosponedNotifiersLenght) {
      WidgetsBinding.instance.addPostFrameCallback(_observedChangeCallback);
    }
  }

  DisposableWidget get disposableWidget => widget;

  void mount(Element parent, dynamic newSlot) {
    _startPosponingObservedNotifications();
    disposableWidget.initContext(this);
    super.mount(parent, newSlot);
    _finishPosponingObservedNotifications();
  }

  @override
  void unmount() {
    assert(() {
      // FloopController.debugUnmounting(this);
      return true;
    }());
    _startPosponingObservedNotifications();
    ObservedController.unsubscribeListener(this);
    _unmountCallbacks.forEach((cb) => cb());
    super.unmount();
    disposableWidget.disposeContext(this);
    _finishPosponingObservedNotifications();
    assert(() {
      // FloopController.debugfinishUnmounting();
      return true;
    }());
  }

  final Set<VoidCallback> _unmountCallbacks = Set();

  void addUnmountCallback(VoidCallback callback) {
    assert(callback != null);
    _unmountCallbacks.add(callback);
  }

  final Set<ObservedNotifier> observeds = Set();

  @protected
  onObservedChange(ObservedNotifier observed) {
    assert(observeds.contains(observed));
    if (_posponeOnObservedChange) {
      if (_posponedObserveds.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(_observedChangeCallback);
      }
      _posponedObserveds.add(observed);
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
    with FloopElementMixin
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
    with FloopElementMixin
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
  ObservedMap map;
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
  ObservedMap get dyn => _dyn.map;

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
  /// of a [build] method. In those cases, if the widget has not yet been
  /// initialized and it is used to replace an existing widget, it will copy
  /// the [dyn] member of the old widget. If that behavior is undesired,
  /// invoke [forceInit] when the widget is created to initialize it's own
  /// [dyn] member.
  forceInit() {
    _init();
  }

  _init() {
    _dyn.map = ObservedMap();
    initDyn();
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

  void mount(Element parent, dynamic newSlot) {
    if (widget.dyn == null) {
      widget._init();
    }
    super.mount(parent, newSlot);
  }
}
