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
  Widget _buildWithFloopListening(BuildContext context) {
    FloopController.startListening(context);
    var widget = build(context);
    FloopController.stopListening();
    return widget;
  }

  /// Invoked when an [Element] (context) that holds this widget gets unmounted.
  /// Override to dispose any resources, like values or listeners that are
  /// related only to the element.
  disposeContext(Element element) {}

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

  @override
  Widget build() => widget._buildWithFloopListening(this);

  @override
  void unmount() {
    assert(() {
      FloopController.debugUnmounting(this);
      return true;
    }());
    unsubscribeElement(this);
    // WidgetsBinding.instance
    //     .addPostFrameCallback((_) => widget.onContextUnmount(this));
    widget.disposeContext(this);
    super.unmount();
    assert(() {
      FloopController.debugfinishUnmounting();
      return true;
    }());
  }
}

/// Mixin for StatefulWidgets. Use this mixin in a State class to enable
/// widget builds to be observed by Floop.
mixin FloopStateful on StatefulWidget {
  /// The build is performed through the widget which is not elegant, but
  /// rather a workaround to enable Floop's listening mode without having
  /// the user to intervene the State with another mixin.
  Widget _buildWithFloopListening(covariant StatefulElement context) {
    FloopController.startListening(context);
    var widget = context.state.build(context);
    FloopController.stopListening();
    return widget;
  }

  @override
  StatefulElement createElement() => StatefulElementFloop(this);
}

class StatefulElementFloop extends StatefulElement {
  StatefulElementFloop(FloopStateful widget) : super(widget);

  FloopStateful get widget => super.widget;

  @override
  Widget build() => widget._buildWithFloopListening(this);

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
