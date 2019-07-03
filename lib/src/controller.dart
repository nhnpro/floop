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


  // var _currentBuildObservedToKeys = Map<Observed, Set<dynamic>>();
  // var _currentBuildMutationSubscriptions = Set<Observed>();  


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
    // great performance improvement chance here, there is no need to unsubscribe
    // unsubscribeFromAll(element);
    _currentBuild = element;
    _currentBuildSubscriptions = Set<Observed>();
  }

  void stopListening() {
    assert(currentBuild != null);
    assert(_currentBuildSubscriptions != null);
    // print('Finished building $currentBuild with subscribed maps $_currentBuildSubscriptions');
    // if(_subscriptions[currentBuild]!=null) {
    //   unsubscribeFromObserveds(
    //     _currentBuild, _subscriptions[currentBuild].difference(_currentBuildSubscriptions));
    // }
    // for(Observed obs in _currentBuildSubscriptions)
    //   obs.commitCurrentSubscriptions();
    // if(_currentBuildSubscriptions.isNotEmpty)
    //   _subscriptions[currentBuild] = _currentBuildSubscriptions;
    // if(_currentBuildSubscriptions.isNotEmpty)
    _commitCurrentBuildSubscriptions();
    _currentBuild = null;
    _currentBuildSubscriptions = null;
    _currentBuildObservedToKeys.clear();
    _currentBuildObservedToKeys.clear();
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

  void unsubscribeFromObserveds(Element element, Iterable<Observed> observeds) {
    assert(element != null);
    observeds.forEach((obs) => obs.unsubscribeElement(element));
  }

  void unsubscribeFromAll(Element element) {
    assert(element != null);
    if(_subscriptions[element]==null) return;
    // _subscriptions[element]?.forEach((observed) => observed.unsubscribeElement(element));
    unsubscribeFromObserveds(element, _subscriptions[element]);
    _subscriptions.remove(element);
  }

  var _currentBuildObservedToKeys = Map<Observed, Set<dynamic>>();
  // Subscription to Observed mutations during the current build. Mutation sensitive reads are
  // unlikely on many different, therefore List is probably more efficient. Consider change.
  var _currentBuildMutationSubscriptions = Set<Observed>();  

  _commitCurrentBuildSubscriptions() {
    Set<Observed> previousSubscriptions =_subscriptions[currentBuild];
    // unsubscribes from Observed that were not read during the build
    if(previousSubscriptions!=null) {
      previousSubscriptions.removeAll(_currentBuildSubscriptions);
      unsubscribeFromObserveds(_currentBuild, previousSubscriptions);
    }
    // updates subscriptions of Observed read during the current widget build.
    for(var obs in _currentBuildSubscriptions) {
      obs.updateElementKeySubscriptions(_currentBuild, _currentBuildObservedToKeys[obs]);
      obs.updateMutationSubscription(
        _currentBuild, _currentBuildMutationSubscriptions.contains(_currentBuild));
    }
    _subscriptions[currentBuild] = _currentBuildSubscriptions;
  }

  void subscribeKey(Observed observed, Key key) {
    assert(currentBuild!=null);
    _currentBuildObservedToKeys.putIfAbsent(observed, () => Set()).add(key);
    _currentBuildSubscriptions.add(observed);
  }

  void subscribeMutation(Observed observed) {
    _currentBuildMutationSubscriptions.add(observed);
    _currentBuildSubscriptions.add(observed);
  }

  void subscribeObserved(Observed observed) {
    assert(currentBuild!=null);
    _currentBuildSubscriptions.add(observed);
  }
}
