import 'package:meta/meta.dart' show visibleForOverriding;
import './flutter_import.dart';
import './controller.dart';

// It's not possible to mix mixins in Dart. If it ever becomes possible,
// all other mixins should use FloopBuilder.
mixin FloopBuilder {
  Widget build(BuildContext context);

  @visibleForOverriding
  Widget _buildWithFloopListening(BuildContext context) {
    FloopController.startListening(context);
    var widget = build(context);
    FloopController.stopListening();
    return widget;
  }
}

/// Mixin that causes the Widget be listened while building.
///
/// Include this mixin in a StatelessWidget and it will autoupdate on value
/// changes detected to [ObservedMap] instances read during the build.
/// Example: `MyWidget extends StatelessWidget with Floop {...}`.
mixin Floop on StatelessWidget {
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

/// Wrapper class of StatelessElement used to catch calls to unmount.
///
/// When unmount is called, all references to the Element in Floop are
/// cleaned and the widget's [Floop.disposeContext] is invoked.
class StatelessElementFloop extends StatelessElement {
  StatelessElementFloop(Floop widget) : super(widget);

  Floop get widget => super.widget;

  Widget _buildWithFloopListening() {
    FloopController.startListening(this);
    var childWidget = widget.build(this);
    FloopController.stopListening();
    return childWidget;
  }

  @override
  Widget build() => _buildWithFloopListening();

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
    //     .addPostFrameCallback((_) => widget.onContextUnmount(this));
    super.unmount();
    widget.disposeContext(this);
    assert(() {
      FloopController.debugfinishUnmounting();
      return true;
    }());
  }
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

// abstract class DynamicWidget extends FloopWidget {
//   const DynamicWidget({Key key}) : super(key: key);

//   @override
//   StatelessElement createElement() => DynamicValuesElement(this);
// }

// class DynamicValuesElement extends StatelessElementFloop {
//   DynamicValuesElement(DynamicWidget widget) : super(widget);

//   DynamicWidget get widget => super.widget;

//   @override
//   void mount(Element parent, newSlot) {
//     // TODO: implement mount
//     super.mount(parent, newSlot);
//   }
// }
