import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import './controller.dart';

/// A given widget can be included in the tree zero or more times. In particular
/// a given widget can be placed in the tree multiple times. Each time a widget
/// is placed in the tree, it is inflated into an [Element], which means a
/// widget that is incorporated into the tree multiple times will be inflated
/// multiple times.
mixin Floop on StatelessWidget {

  // static FloopController controller = floopController;
  
  // static switchToDefaultController() => FloopController.switchToDefaultController();

  // static switchToFullControllerUntilFinishBuild() => FloopController.switchToFullControllerUntilFinishBuild();

  // static switchToLightControllerUntilFinishBuild() => FloopController.switchToLightControllerUntilFinishBuild();

  // static setDefaultControllerToFull() => FloopController.setDefaultControllerToFull();

  // static setDefaultControllerToLight() => FloopController.setDefaultControllerToLight();

  /// Override this method as you would normally override the [build] method.
  /// Do NOT override [build] or floop will fail to listen reads to it's global state.
  Widget buildWithFloop(BuildContext context);

  /// Do NOT override this method, use [buildWithFloop] to build your widget.
  @visibleForOverriding
  Widget build(BuildContext context) {
    floopController.startListening(context);
    var widget = buildWithFloop(context);
    floopController.stopListening();
    return widget;
  }

  @override
  StatelessElement createElement() {
    return StatelessElementFloop(this);
  }
}

/// Wrapper class of StatelessElement used to catch calls to unmount
class StatelessElementFloop extends StatelessElement {
  StatelessElementFloop(StatelessWidget widget) : super(widget);
  
  @override
  void unmount() {
    floopController.unsubscribeFromAll(this);
    super.unmount();
  }
}

mixin FloopState on State { //on StatelessWidget 
  Widget buildWithFloop(BuildContext context);

  @visibleForOverriding
  Widget build(BuildContext context) {
    floopController.startListening(context);
    var widget = buildWithFloop(context);
    floopController.stopListening();
    return widget;
  }

  @override
  deactivate() {
    floopController.unsubscribeFromAll(this.context);
    super.deactivate();
  }

  @override
  dispose() {
    floopController.unsubscribeFromAll(this.context);
    super.dispose();
  }
}
