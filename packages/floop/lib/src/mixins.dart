import 'package:floop/floop.dart';

import './flutter_import.dart';
import './controller.dart';

mixin DisposableWidget on StatelessWidget {
  /// Invoked when an [BuildContext] that holds this widget gets unmounted
  /// (removed from the element tree).
  ///
  /// Override to dispose any resources, like values or listeners that are
  /// related only to the context. The default implementation is empty, it's
  /// not necessary to call super.
  @protected
  void disposeContext(BuildContext context) {}

  /// Invoked when a [BuildContext] with this widget is mounted into the
  /// element tree (builds for the first time).
  ///
  /// Useful to override for initializing values that are related only to the
  /// context. It's not necessary to call super.
  @protected
  void initContext(BuildContext context) {}
}

/// Mixin that causes the Widget be listened while building.
///
/// Include this mixin in a StatelessWidget and it will autoupdate on value
/// changes detected to [ObservedMap] instances read during the build.
/// Example: `MyWidget extends StatelessWidget with Floop {...}`.
mixin Floop on StatelessWidget implements DisposableWidget {
  /// Override to dispose any resources, like values or listeners that are
  /// related only to the context.
  ///
  /// Invoked when an [BuildContext] that holds this widget gets unmounted.
  void disposeContext(BuildContext context) {}

  /// Override initialize values that are related only to the context.
  ///
  /// Invoked when a [BuildContext] with this widget has just been created.
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

mixin InitAndDisposeContextMixin on StatelessElement {
  DisposableWidget get widget => super.widget;

  void mount(Element parent, dynamic newSlot) {
    widget.initContext(this);
    super.mount(parent, newSlot);
  }

  @override
  void unmount() {
    assert(() {
      FloopController.debugUnmounting(this);
      return true;
    }());
    unsubscribeElement(this);
    // WidgetsBinding.instance
    //     .addPostFrameCallback((_) => widget.disposeContext(this));
    super.unmount();
    widget.disposeContext(this);
    assert(() {
      FloopController.debugfinishUnmounting();
      return true;
    }());
  }
}

/// Wrapper class of StatelessElement used to catch calls to unmount.
///
/// When unmount is called, all references to the Element in Floop are
/// cleaned and the widget's [Floop.disposeContext] is invoked.
class StatelessElementFloop extends StatelessElement
    with InitAndDisposeContextMixin {
  StatelessElementFloop(DisposableWidget widget) : super(widget);

  Widget _buildWithFloopListening() {
    FloopController.startListening(this);
    var childWidget = widget.build(this);
    FloopController.stopListening();
    return childWidget;
  }

  @override
  Widget build() => _buildWithFloopListening();
}

/// Mixin for StatefulWidgets. Use this mixin in a State class to enable
/// widget builds to be observed by Floop.
mixin FloopStateful on StatefulWidget {
  @override
  StatefulElement createElement() => StatefulElementFloop(this);
}

class StatefulElementFloop extends StatefulElement {
  StatefulElementFloop(FloopStateful widget) : super(widget);

  FloopStateful get widget => super.widget;

  Widget _buildWithFloopListening() {
    FloopController.startListening(this);
    var widget = state.build(this);
    FloopController.stopListening();
    return widget;
  }

  @override
  Widget build() => _buildWithFloopListening();

  @override
  void unmount() {
    assert(() {
      FloopController.debugUnmounting(this);
      return true;
    }());
    unsubscribeElement(this);
    super.unmount();
    assert(() {
      FloopController.debugfinishUnmounting();
      return true;
    }());
  }
}

/// `class MyState extends FloopState` is equivalent to
/// `class MyWidget extends State with FloopStateMixin`.
abstract class FloopStatefulWidget extends StatefulWidget with FloopStateful {
  const FloopStatefulWidget({Key key}) : super(key: key);
}

/// Wrapper class used for the mere purpose of skipping the [Widget] class
/// immutable annotation, since the [ObservedMap] requires to be written after
/// a widget have been instantiated.
class _ObservedMapWrapper {
  ObservedMap map;
}

/// A Floop widget that keeps a mutable [ObservedMap] instance that can be
/// accessed through [dyn].
///
/// The existing [dyn] gets passed on to new [DynamicWidget] instances
/// whenever the context rebuilds. It can be therefore assumed that [dyn]
/// is persistant.
abstract class DynamicWidget extends FloopWidget {
  /// Wrapper that hold the internal [ObservedMap].
  ///
  /// A wrapper is used to bypass the annotation warnings.Ideally the map
  /// should be stored directly as a variable `ObservedMap _dyn`, but the
  /// [Widget] `@immutable` annotation requires all fields to be final.
  final _ObservedMapWrapper _dyn = _ObservedMapWrapper();

  /// An internal [ObservedMap] instance that keeps dynamic values.
  ///
  /// It gets passed on to new [DynamicWidget] instances whenever the context
  /// rebuilds. Assume [dyn] is persistant on calls to [build].
  ObservedMap get dyn => _dyn.map;

  /// Invoked when the widget's [dyn] member is created.
  ///
  /// A new [dyn] member will only be created when it is null and when an
  /// [BuildContext] with this widget is mounted on the element tree (builds
  /// for the first time).
  ///
  /// Useful to override for initializing dynamic values that are used in the
  /// [build] method.
  @protected
  init() {}

  _init() {
    _dyn.map = ObservedMap();
    init();
  }

  /// Builds this widget with Floop listening.
  ///
  /// The [dyn] member holds dynamic values that can be mutated and persist on
  /// every build cycle,
  ///
  /// serving a similar purpose to a [State]. Values in
  /// will always display as what they are, therefore changing a value
  /// will automatically trigger a rebuild.
  build(BuildContext context);

  @override
  StatelessElement createElement() => DynamicWidgetElement(this);
}

class DynamicWidgetElement extends StatelessElementFloop {
  DynamicWidgetElement(DynamicWidget widget) : super(widget);

  DynamicWidget get widget => super.widget;

  update(DynamicWidget newWidget) {
    // assert(() {
    //   if (newWidget._dyn == null) {
    //     print('Error: Attempting to use an initialized [StorageWidget] to '
    //         'replace an existing StorageWidget.\n'
    //         'This is probably due to having a reusable [StorageWidget] saved '
    //         'in a variable and is being used in a context that has already '
    //         'initialized it\'s own [StorageWidget] instance.');
    //     return false;
    //   }
    //   return true;
    // }());
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
