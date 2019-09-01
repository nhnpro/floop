import 'package:meta/meta.dart' show visibleForOverriding;
import './flutter_import.dart';
import './controller.dart';

mixin FloopBuilder {
  /// Override this method as you would normally override the [build] method.
  /// Do NOT override [build].
  Widget buildWithFloop(BuildContext context);

  /// Do NOT override this method, use [buildWithFloop] to build your widget.
  @visibleForOverriding
  Widget build(BuildContext context) {
    fullController.startListening(context);
    var widget = buildWithFloop(context);
    fullController.stopListening();
    return widget;
  }
}

/// Mixin that causes the Widget be listened while building. Include this
/// mixin in a StatelessWidget and override [buildWithFloop] method.
mixin Floop on StatelessWidget implements FloopBuilder {
  /// Override this method as you would normally override the [build] method.
  /// Do NOT override [build].
  Widget buildWithFloop(BuildContext context);

  /// Do NOT override this method, use [buildWithFloop] to build your widget.
  @visibleForOverriding
  Widget build(BuildContext context) {
    fullController.startListening(context);
    var widget = buildWithFloop(context);
    fullController.stopListening();
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

/// Experimental lighter version of Floop. It only allows reading from one
/// observed at each Widget build cycle. It has better performance.
mixin FloopLight on StatelessWidget implements FloopWidget {
  /// Override this method as you would normally override the [build] method.
  /// Do NOT override [build].
  Widget buildWithFloop(BuildContext context);

  /// Do NOT override this method, use [buildWithFloop] to build your widget.
  @visibleForOverriding
  Widget build(BuildContext context) {
    lightController.startListening(context);
    var widget = buildWithFloop(context);
    lightController.stopListening();
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

/// Wrapper class of StatelessElement used to catch calls to unmount.
///
/// When unmount is called, all references to the Element in Floop are
/// cleaned and it's current widget [Floop.disposeContext] is invoked.
class StatelessElementFloop extends StatelessElement {
  StatelessElementFloop(Floop widget) : super(widget);

  Floop get widget => super.widget;

  @override
  void unmount() {
    assert(() {
      floopController.debugUnmounting(this);
      return true;
    }());
    unsubscribeElement(this);
    // WidgetsBinding.instance
    //     .addPostFrameCallback((_) => widget.onContextUnmount(this));
    widget.disposeContext(this);
    super.unmount();
    assert(() {
      floopController.debugfinishUnmounting();
      return true;
    }());
  }
}

/// Mixin for StatefulWidgets. Use this mixin in a State class to enable
/// widget builds to be observed by Floop.
mixin FloopStateMixin<T extends StatefulWidget> on State<T>
    implements FloopBuilder {
  /// Override this method as you would normally override the [build] method.
  /// Do NOT override [build].
  Widget buildWithFloop(BuildContext context);

  /// Do NOT override this method, use [buildWithFloop] to build your widget.
  @visibleForOverriding
  Widget build(BuildContext context) {
    fullController.startListening(context);
    var widget = buildWithFloop(context);
    fullController.stopListening();
    return widget;
  }

  @override
  dispose() {
    unsubscribeElement(this.context);
    super.dispose();
  }
}

/// `class MyState extends FloopState` is equivalent to
/// `class MyWidget extends State with FloopStateMixin`.
abstract class FloopState<T extends StatefulWidget> = State<T>
    with FloopStateMixin<T>, FloopBuilder;
