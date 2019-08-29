import 'package:meta/meta.dart' show visibleForOverriding;
import './flutter_import.dart';
import './controller.dart';

/// Mixin that causes the Widget be listened while building. Include this
/// mixin in a StatelessWidget and override [buildWithFloop] method.
mixin Floop on StatelessWidget {
  /// Override this method as you would normally override the [build] method.
  /// Do NOT override [build] or floop will fail to listen reads to it's global state.
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
  StatelessElement createElement() {
    return StatelessElementFloop(this);
  }
}

/// `class MyWidget extends FloopStatelessWidget` is equivalent to
/// `class MyWidget extends StatelessWidget with Floop`.
abstract class FloopStatelessWidget extends StatelessWidget with Floop {
  const FloopStatelessWidget({Key key}) : super(key: key);
}

/// Experimental lighter version of Floop. It only allows reading from one
/// observed at each Widget build cycle. It has increased performance.
mixin FloopLight on StatelessWidget {
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

  @override
  StatelessElement createElement() {
    return StatelessElementFloop(this);
  }
}

/// Wrapper class of StatelessElement used to catch calls to unmount.
///
/// When unmount is called the all references to the Element in Floop get cleaned.
class StatelessElementFloop extends StatelessElement {
  StatelessElementFloop(StatelessWidget widget) : super(widget);

  @override
  void unmount() {
    unsubscribeElement(this);
    super.unmount();
  }
}

/// Mixin for StatefulWidgets. Use this mixin in a State class to enable
/// widget builds to be observed by Floop.
mixin FloopStateMixin<T extends StatefulWidget> on State<T> {
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
    with FloopStateMixin<T>;
