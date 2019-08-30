import 'package:meta/meta.dart' show visibleForOverriding;
import './flutter_import.dart';
import './controller.dart';

mixin FloopBuilder {
  FloopController _controller() => fullController;

  /// Override this method as you would normally override the [build] method.
  /// Do NOT override [build] or floop will fail to listen reads to it's global state.
  Widget buildWithFloop(BuildContext context);

  /// Do NOT override this method, use [buildWithFloop] to build your widget.
  @visibleForOverriding
  Widget build(BuildContext context) {
    try {
      _controller().startListening(context);
      var widget = buildWithFloop(context);
      return widget;
    } finally {
      _controller().stopListening();
    }
  }
}

/// Mixin that causes the Widget be listened while building. Include this
/// mixin in a StatelessWidget and override [buildWithFloop] method.
mixin Floop on StatelessWidget implements FloopBuilder {
  // FloopController _controller() => fullController;

  /// Override this method as you would normally override the [build] method.
  /// Do NOT override [build] or floop will fail to listen reads to it's global state.
  Widget buildWithFloop(BuildContext context);

  /// Do NOT override this method, use [buildWithFloop] to build your widget.
  @visibleForOverriding
  Widget build(BuildContext context) {
    try {
      fullController.startListening(context);
      var widget = buildWithFloop(context);
      return widget;
    } finally {
      fullController.stopListening();
    }
  }

  /// Gets by the element that context when unmounting
  onContextUnmount(Element element) {}

  @override
  StatelessElement createElement() {
    return StatelessElementFloop(this);
  }
}

/// `class MyWidget extends FloopStatelessWidget` is equivalent to
/// `class MyWidget extends StatelessWidget with Floop`.
abstract class FloopWidget extends StatelessWidget with Floop {
  // FloopController _controller() => fullController;

  const FloopWidget({Key key}) : super(key: key);

  @override
  StatelessElement createElement() {
    return StatelessElementFloop(this);
  }
}

/// Experimental lighter version of Floop. It only allows reading from one
/// observed at each Widget build cycle. It has increased performance.
mixin FloopLight on StatelessWidget implements FloopWidget {
  /// Override this method as you would normally override the [build] method.
  /// Do NOT override [build] or floop will fail to listen reads to it's global state.
  Widget buildWithFloop(BuildContext context);

  /// Do NOT override this method, use [buildWithFloop] to build your widget.
  @visibleForOverriding
  Widget build(BuildContext context) {
    lightController.startListening(context);
    var widget = buildWithFloop(context);
    lightController.stopListening();
    return widget;
  }

  onContextUnmount(Element element) {}

  @override
  StatelessElement createElement() {
    return StatelessElementFloop(this);
  }
}

/// Wrapper class of StatelessElement used to catch calls to unmount.
///
/// When unmount is called the all references to the Element in Floop are
/// cleaned. Addiontally
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
    widget.onContextUnmount(this);
    super.unmount();
    assert(() {
      floopController.debugfinishUnmounting();
      return true;
    }());
  }

  // void deactivateChild(child) {
  //   print('deactivating $child, ${child.widget}');
  //   super.deactivateChild(child);
  // }
}

/// Mixin for StatefulWidgets. Use this mixin in a State class to enable
/// widget builds to be observed by Floop.
mixin FloopStateMixin<T extends StatefulWidget> on State<T>
    implements FloopBuilder {
  /// Override this method as you would normally override the [build] method.
  /// Do NOT override [build] or floop will fail to listen reads to [ObservedMaps].
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
