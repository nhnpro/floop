import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import './controller.dart';

/// A given widget can be included in the tree zero or more times. In particular
/// a given widget can be placed in the tree multiple times. Each time a widget
/// is placed in the tree, it is inflated into an [Element], which means a
/// widget that is incorporated into the tree multiple times will be inflated
/// multiple times.
mixin Floop on StatelessWidget {
  /// override this function instead of build, do NOT override build or floop
  /// will fail to listen reads to it's state
  Widget buildWithFloop(BuildContext context);

  /// do NOT override this method, use buildWithFloop to build your widget
  @visibleForOverriding
  Widget build(BuildContext context) {
    controller.startListening(context);
    var widget = buildWithFloop(context);
    controller.stopListening();
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
    controller.unsubscribeFromAll(this);
    super.unmount();
  }
}

mixin FloopState on State { //on StatelessWidget 
  Widget buildWithFloop(BuildContext context);

  @visibleForOverriding
  Widget build(BuildContext context) {
    controller.startListening(context);
    var widget = buildWithFloop(context);
    controller.stopListening();
    return widget;
  }

  @override
  deactivate() {
    controller.unsubscribeFromAll(this.context);
    super.deactivate();
  }

  @override
  dispose() {
    controller.unsubscribeFromAll(this.context);
    super.dispose();
  }
}
