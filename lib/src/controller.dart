import 'package:flutter/widgets.dart';

import './observed.dart';

final FloopController controller = FloopController();

class FloopController {
  Element _currentBuild;
  Set<Observed> _currentBuildSubscriptions;
  Map<Element, Set<Observed>> _subscriptions = {};

  /// [BuildContext] of the ongoing [buildWithFloop].
  Element get currentBuild => _currentBuild;

  Iterable<Observed> get currentBuildSubscriptions => _currentBuildSubscriptions;

  @visibleForTesting
  Map<Element, Set<Observed>> get subscriptions => _subscriptions;

  void startListening(covariant Element element) {
    assert(() {
      if(currentBuild != null) {
        stopListening();
        // _subscriptions.keys.forEach((e) => controller.unsubscribeFromAll(e));
        return false;
      }
      return true;
    }());
    assert(_currentBuildSubscriptions == null);
    unsubscribeFromAll(element);
    _currentBuild = element;
    _currentBuildSubscriptions = Set<Observed>();
  }

  void stopListening() {
    assert(currentBuild != null);
    assert(_currentBuildSubscriptions != null);
    // print('Finished building $currentBuild with subscribed maps $_currentBuildSubscriptions');
    _subscriptions[currentBuild] = _currentBuildSubscriptions;
    _currentBuild = null;
    _currentBuildSubscriptions = null;
    // print('Subscribed elements ${_subscriptions.keys}');
  }

  void markElementsAsNeedBuild(Set<Element> elements) {
    if(_currentBuild!=null) {
      throw StateError(
        'A Floop widget is building while setting a value in floop map.\n'
        'This is not allowed as it could cause an infinite build recursion.');
    } else if (elements!=null) {
      for(var ele in elements) {
        ele.markNeedsBuild();
      }
    }
  }

  void unsubscribeFromAll(Element element) {
    assert(element != null);
    if(_subscriptions[element] != null) {
      _subscriptions[element].forEach((observed) => observed.unsubscribeElement(element));
    }
    _subscriptions.remove(element);
  }

  void subscribeObserved(Observed observed) {
    assert(currentBuild!=null);
    _currentBuildSubscriptions.add(observed);
  }
}
