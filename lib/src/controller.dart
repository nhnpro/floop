import 'package:flutter/widgets.dart';

import './observed.dart';

const emptyConstantList = [];

final FloopController floopController = FloopController();

class FloopController {
  Element _currentBuild;
  Set<ObservedController> _currentObservedControllers = Set();
  
  
  Map<Element, Set<ObservedController>> _subscriptions = {};

  // Map<Observed, ObservedController> _observedToControlller = {};

  /// [BuildContext] of the ongoing [buildWithFloop].
  Element get currentBuild => _currentBuild;
  bool get listening => _currentBuild != null;

  Iterable<ObservedController> get currentBuildSubscriptions => _currentObservedControllers;

  @visibleForTesting
  Map<Element, Set<ObservedController>> get subscriptions => _subscriptions;


  // var _currentBuildObservedToKeys = Map<Observed, Set<dynamic>>();
  // var _currentBuildMutationSubscriptions = Set<Observed>();  


  void startListening(covariant Element element) {
    assert(_currentObservedControllers.isEmpty);
    assert(() {
      if(listening) {
        stopListening();
        return false;
      }
      return true;
    }());
    _currentBuild = element;
    // _currentObservedControllers = Set();
  }

  void stopListening() {
    assert(currentBuild != null);
    assert(_currentObservedControllers != null);
    _commitCurrentBuildSubscriptions();
    _currentBuild = null;
    _currentObservedControllers = Set();
    // print('Subscribed elements ${_subscriptions.keys}');
  }

  void markElementsAsNeedBuild(Set<Element> elements) {
    if(listening) {
      print(
        'ERROR: A Floop widget is building while setting a value in an\n'
        'ObservedMap. Updates to widgets will not be made, because it would\n'
        'likely produce an infinite build recursion.\n'
        'Avoid writing to an ObservedMap while bulding your Widgets. A map\n'
        'write during a build can be safely done asynchronously. For example\n'
        'Future.delayed can be used to achieve this.'
      );
      assert(false);    // it should fail during debug mode
    } else if (elements!=null) {
      for(var ele in elements) {
        ele.markNeedsBuild();
      }
    }
  }

  void unsubscribeFromObserveds(Element element, Iterable<ObservedController> obsControllers) {
    assert(element != null);
    obsControllers.forEach((obs) => obs.unsubscribeElement(element));
  }

  void unsubscribeFromAll(Element element) {
    assert(element != null);
    if(_subscriptions[element]==null) return;
    // _subscriptions[element]?.forEach((observed) => observed.unsubscribeElement(element));
    unsubscribeFromObserveds(element, _subscriptions[element]);
    _subscriptions.remove(element);
  }

  _commitCurrentBuildSubscriptions() {
    Set<ObservedController> previousSubscriptions = _subscriptions[_currentBuild];

    // unsubscribes from Observed that were not read during the build
    if(previousSubscriptions != null) {
      previousSubscriptions.removeAll(_currentObservedControllers);
      unsubscribeFromObserveds(_currentBuild, previousSubscriptions);
    }

    // updates subscriptions of Observed read during the current widget build.
    for(var obs in _currentObservedControllers) {
      obs.commitCurrentReads(_currentBuild);
    }
    _subscriptions[_currentBuild] = _currentObservedControllers;
  }

  readed(ObservedController obs) {
    assert(listening);
    _currentObservedControllers.add(obs);
  }

  // void subscribeKey(Observed observed, Object key) {
  //   assert(currentBuild != null);
  //   var obsController = getController(observed)
  //     ..currentKeyReads.add(key);
  //   _currentObservedControllers.add(obsController);
  // }

  // getController(Observed observed) => _observedToControlller.putIfAbsent(
  //     observed, () => ObservedController(observed));

  // void subscribeMutation(Observed observed) {
  //   ObservedController obsController = getController(observed);
  //   _currentMutationReads.add(obsController);
  //   _currentObservedControllers.add(obsController);
  // }

  // void subscribeObserved(ObservedController observed) {
  //   assert(currentBuild!=null);
  //   _currentObservedControllers.add(observed);
  // }
}


/// ObservedController class is a utility class used by
class ObservedController {

  // Observed _observed;

  ObservedController();
  // {    // [this._observed]
  //   _observed.controller = this;
  // }

  /// The map that associates keys with the Elements that should be updated when the
  /// value of the key is updated.
  Map<Object, Set<Element>> _keyToElements = Map();
  Map get keyToElements => _keyToElements;

  /// The reverse map of `keyToElements`, it goes from Element to key
  Map<Element, Set<Object>> _elementToKeys = Map();
  
  /// The [Set] of Elements that should be updated when there is a mutation in the
  /// [Observed].
  Set<Element> _mutations = Set();

  // The keys read during curent build cycle.
  Set<Object> currentKeyReads = Set();

  bool currentMutationRead = false;

  _associateElementToKeys(Element element, Iterable keysToAdd) {
    for(var key in keysToAdd) {
      _keyToElements.putIfAbsent(key, () => Set<Element>()).add(element);
    }
    // _elementToKeys.putIfAbsent(
    //   element, () => Set()).addAll(keysToAdd.cast());
  }

  _dissociateElementFromKeys(Element element, Iterable keysToRemove) {
    for(Object key in keysToRemove) {
      assert(_keyToElements[key].contains(element));
      _keyToElements[key].remove(element);
      if(_keyToElements[key].isEmpty) {
        _keyToElements.remove(key);
      }
    }
    // _elementToKeys[element].removeAll(keysToRemove);
    // if(_elementToKeys[element].isEmpty)
    //   _elementToKeys.remove(element);
  }

  void commitCurrentReads(Element element) {
    updateElementKeys(element, currentKeyReads);
    updateMutation(element);
    currentKeyReads = currentKeyReads.isEmpty ? currentKeyReads : Set();
    currentMutationRead = false;
  }

  void updateElementKeys(Element element, Set newKeys) {
    assert(element != null);
    assert(newKeys != null);
    Set elementKeys = _elementToKeys.putIfAbsent(element, () => Set())..removeAll(newKeys);
    _dissociateElementFromKeys(element, elementKeys);
    
    if(newKeys.isEmpty) {
      _elementToKeys.remove(element);
    }
    else {
      _associateElementToKeys(element, newKeys..removeAll(elementKeys));
      _elementToKeys[element] = newKeys;
    }
  }

  void updateMutation(Element element) {
    if(currentMutationRead)
      _mutations.add(element);
    else
      _mutations.remove(element);
  }

  /// Unsubscribes the element from all keys on this [ObservedController]
  void unsubscribeElement(Element element) {
    assert(_elementToKeys.containsKey(element) || _mutations.contains(element));
    if(_elementToKeys.containsKey(element)) {
      _dissociateElementFromKeys(element, _elementToKeys[element]);
      _elementToKeys.remove(element);
    }
    _mutations.remove(element);
  }

  void notifyValueRead(Object key) {
    if(floopController.listening) {
      currentKeyReads.add(key);
      floopController.readed(this);
    }
  }

  void notifyMutationRead() {
    if(floopController.listening) {
      floopController.readed(this);
    }
  }

  void notifyMutation() {
    floopController.markElementsAsNeedBuild(_mutations);
  }

  void notifyValueChange(Object key) {
    floopController.markElementsAsNeedBuild(_keyToElements[key]);
  }
}
