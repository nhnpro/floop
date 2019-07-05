import 'package:flutter/widgets.dart';

import './observed.dart';

const emptyConstantList = [];

final FloopFullController fullController = FloopFullController();
final FloopLightController lightController = FloopLightController();

FloopController floopController = fullController;

abstract class FloopController {

  static FloopController _defaultController = fullController;

  static switchToDefaultController() => floopController = _defaultController;

  /// Switches the global Floop state controller to [FloopFullController] for one
  /// widget build cycle. After it finishes, the listener is set back to the
  /// default controller.
  static switchToFullControllerUntilFinishBuild() => floopController = fullController;

  /// Switches the global Floop state controller to [FloopLightController] for one
  /// widget build cycle. After it finishes, the listener is set back to the
  /// default controller.
  static switchToLightControllerUntilFinishBuild() => floopController = lightController;

  static setDefaultControllerToFull() {
    _defaultController = fullController;
    switchToDefaultController();
  }

  static setDefaultControllerToLight() {
    _defaultController = lightController;
    switchToDefaultController();
  }

  static Set<Element> _subscriptions = Set();

  /// Total amount of subscribed elements (Widgets).
  static int get length => _subscriptions.length;

  static void unsubscribeElement(Element element) {
    if(fullController.contains(element)) {
      fullController.unsubscribeFromAll(element);
      assert(!lightController.contains(element));
    }
    else if(lightController.contains(element)) {
      lightController.unsubscribeFromAll(element);
    }
  }

  /// Element corresponding to widget on build.
  Element _currentBuild;

  /// [BuildContext] of the ongoing [buildWithFloop].
  Element get currentBuild => _currentBuild;

  /// Returns true if this controller is on listening mode.
  bool get listening => _currentBuild != null;

  void startListening(covariant Element element) {
    assert(() {
      if(listening) {
        stopListening();
        return false;
      }
      return true;
    }());
    _currentBuild = element;
  }

  void stopListening() {
    assert(currentBuild != null);
    _commitCurrentBuildSubscriptions();
    _currentBuild = null;
    switchToDefaultController();
  }

  void _commitCurrentBuildSubscriptions();

  void unsubscribeFromAll(Element element);

  /// Checks wheter the element is subscribed to this controller.
  bool contains(Element element);

  void readed(ObservedController controller);

  /// Unsubscribes all Elements (Widgets) from the registered Observeds.
  /// Used mainly for testing purposes.
  @visibleForTesting
  void reset();

  void markDirty(Set<Element> elements) {
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
        assert(contains(ele));
        ele.markNeedsBuild();
      }
    }
  }
}

class FloopFullController extends FloopController {

  Element _currentBuild;

  Set<ObservedController> _currentObservedControllers = Set();
  
  Map<Element, Set<ObservedController>> _subscriptions = {};

  @visibleForTesting
  Map<Element, Set<ObservedController>> get subscriptions => _subscriptions;

  @override
  bool contains(Element element) => _subscriptions.containsKey(element);  

  @override
  void unsubscribeFromAll(Element element) {
    assert(element != null);
    assert(_subscriptions.containsKey(element));
    // _subscriptions[element]?.forEach((observed) => observed.unsubscribeElement(element));
    unsubscribeFromObserveds(element, _subscriptions[element]);
    _subscriptions.remove(element);
  }

  @override
  _commitCurrentBuildSubscriptions() {
    assert(_currentObservedControllers != null);
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
    _currentObservedControllers = Set();
  }

  readed(ObservedController controller) {
    assert(listening);
    _currentObservedControllers.add(controller);
  }

  @override
  void reset() {
    _subscriptions.keys.toList().forEach(unsubscribeFromAll);
    assert(_subscriptions.isEmpty);
  }

  void unsubscribeFromObserveds(Element element, Iterable<ObservedController> obsControllers) {
    assert(element != null);
    assert(obsControllers != null);
    obsControllers?.forEach((obs) => obs.unsubscribeElement(element));
  }
}

class FloopLightController extends FloopController {

  ObservedController _currentController;

  Map<Element, ObservedController> _subscriptions = {};

  @visibleForTesting
  Map<Element, ObservedController> get subscriptions => _subscriptions;

  @override
  bool contains(Element element) => _subscriptions.containsKey(element);

  @override
  void readed(ObservedController controller) {
    assert(listening);
    if(_currentController == controller)
      return;
    else if(_currentController == null)
      _currentController = controller;
    else {
      print(
        'ERROR: When using FloopLightController, there shouldn\'t be more than\n'
        'one ObservedMap read during the build cycle of a widget, otherwise\n'
        'subscriptions will not correctly commit.\n'
        'Switching to Floop standard controller will fix this issue. Call\n'
        'Floop.switchToStandardController at the beginning of the build or\n'
        'call Floop.defaultToStandardController() at the beginning of the app.\n'
      );
      assert(false);
    }
  }

  @override
  void _commitCurrentBuildSubscriptions() {
    _currentController.commitCurrentReads(_currentBuild);
    _currentController = null;
  }

  @override
  void reset() {
    _subscriptions.keys.forEach(unsubscribeFromAll);
    assert(_subscriptions.isEmpty);
  }

  @override
  void unsubscribeFromAll(Element element) {
    assert(_subscriptions.containsKey(element));
    _subscriptions[element].unsubscribeElement(element);
    _subscriptions.remove(element);
  }

}


/// ObservedController class is a utility class used by
class ObservedController {

  ObservedController();

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
  }

  _dissociateElementFromKeys(Element element, Iterable keysToRemove) {
    for(Object key in keysToRemove) {
      assert(_keyToElements[key].contains(element));
      _keyToElements[key].remove(element);
      if(_keyToElements[key].isEmpty) {
        _keyToElements.remove(key);
      }
    }
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

  void commitCurrentReads(Element element) {
    updateElementKeys(element, currentKeyReads);
    updateMutation(element);
    currentKeyReads = currentKeyReads.isEmpty ? currentKeyReads : Set();
    currentMutationRead = false;
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

  void valueRetrieved(Object key) {
    if(floopController.listening) {
      currentKeyReads.add(key);
      floopController.readed(this);
    }
  }

  void mutationRead() {
    if(floopController.listening) {
      floopController.readed(this);
    }
  }

  void mutated() {
    floopController.markDirty(_mutations);
  }

  void valueChanged(Object key) {
    floopController.markDirty(_keyToElements[key]);
  }

  void cleared() {
    // updating all elements will unsubscribe all keys during the refresh cycle
    floopController.markDirty(_mutations);
    floopController.markDirty(_keyToElements.keys);
  }
}
