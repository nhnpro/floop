import './flutter_import.dart';
import './observed.dart';

final FullController fullController = FullController();
final LightController lightController = LightController();

FloopController floopController = fullController;

void unsubscribeElement(Element element) {
  if (fullController.contains(element)) {
    fullController.unsubscribeFromAll(element);
    assert(!lightController.contains(element));
  } else if (lightController.contains(element)) {
    lightController.unsubscribeFromAll(element);
  }
}

/// Abstract class that implements basic functionality for listening and
/// updating widgets. It defines the API of the controller required by Floop
/// Widgets.
///
/// [FullController] is the default configured controller used by the library.
/// [LightController] is an alternative faster but more limited controller.
abstract class FloopController {
  /// Switches the global Floop state controller to [FullController].
  static useFullController() => floopController = fullController;

  /// Switches the global Floop state controller to [LightController].
  static useLightController() => floopController = lightController;

  /// Element corresponding to widget on build.
  Element _currentBuild;

  /// [BuildContext] of the ongoing [buildWithFloop].
  Element get currentBuild => _currentBuild;

  /// Returns true if this controller is on listening mode.
  bool get listening => _currentBuild != null;

  /// The count of Elements (Widgets) subscribed to this controller.
  int get length;

  @mustCallSuper
  void startListening(covariant Element element) {
    floopController = this;
    assert(() {
      if (listening) {
        stopListening();
        return false;
      }
      return true;
    }());
    _currentBuild = element;
  }

  @mustCallSuper
  void stopListening() {
    assert(currentBuild != null);
    _commitObservedReads();
    _currentBuild = null;
  }

  /// Called by stopListening. This method should associate all the [Observed]
  /// reads during the build of a [Widget] with the widget's corresponding
  /// [Element].
  void _commitObservedReads();

  void unsubscribeFromAll(Element element);

  /// Checks wheter the element is subscribed to this controller.
  bool contains(Element element);

  /// Registers that the ObservedListener was read during a listening cycle.
  void registerPeekedListener(ObservedListener listener);

  /// Unsubscribes all Elements (Widgets) from the registered Observeds.
  /// Used for testing purposes.
  @visibleForTesting
  @mustCallSuper
  void reset() {
    _currentBuild = null;
  }

  @mustCallSuper
  void markAsNeedBuild(Set<Element> elements) {
    if (listening) {
      print('ERROR: A Floop widget is building ([Floop.buildWithFloop]) while\n'
          'setting a value in an ObservedMap. Update to widgets will not be\n'
          'made, because it could produce an infinite build recursion.\n'
          'Avoid writing to an ObservedMap while bulding your Widgets. A map\n'
          'write during a build can be safely done asynchronously. For example\n'
          'Future.delayed can be used to achieve this.');
      assert(false);
    } else if (elements != null) {
      for (var ele in elements) {
        assert(contains(ele));
        ele.markNeedsBuild();
      }
    }
  }
}

class FullController extends FloopController {
  Element _currentBuild;

  Set<ObservedListener> _currentObservedListeners = Set();

  Map<Element, Set<ObservedListener>> _subscriptions = {};

  @visibleForTesting
  Map<Element, Set<ObservedListener>> get subscriptions => _subscriptions;

  @override
  int get length => _subscriptions.length;

  @override
  bool contains(Element element) => _subscriptions.containsKey(element);

  @override
  void unsubscribeFromAll(Element element) {
    assert(element != null);
    assert(_subscriptions.containsKey(element));
    unsubscribeFromObserveds(element, _subscriptions[element]);
    _subscriptions.remove(element);
  }

  @override
  _commitObservedReads() {
    assert(_currentObservedListeners != null);
    Set<ObservedListener> previousSubscriptions = _subscriptions[_currentBuild];
    // Unsubscribes from Observeds that were not read during the build.
    // It should be uncommon, since widgets usually read the same
    // field from a Map.
    // Conditional reads or reading from a new Map could cause it.
    if (previousSubscriptions != null &&
        (previousSubscriptions.length > _currentObservedListeners.length ||
            !previousSubscriptions.containsAll(_currentObservedListeners))) {
      previousSubscriptions.removeAll(_currentObservedListeners);
      unsubscribeFromObserveds(_currentBuild, previousSubscriptions);
    }

    // updates subscriptions of Observed read during the current widget build.
    if (_currentObservedListeners.isNotEmpty) {
      for (var obs in _currentObservedListeners) {
        obs.commitCurrentReads(_currentBuild);
      }
      _subscriptions[_currentBuild] = _currentObservedListeners;
      _currentObservedListeners = Set();
    } else {
      _subscriptions.remove(_currentBuild);
    }
  }

  registerPeekedListener(ObservedListener listener) {
    assert(listening);
    _currentObservedListeners.add(listener);
  }

  @override
  void reset() {
    _subscriptions.keys.toList().forEach(unsubscribeFromAll);
    _currentObservedListeners.clear();
    super.reset();
    assert(_subscriptions.isEmpty);
  }

  void unsubscribeFromObserveds(
      Element element, Iterable<ObservedListener> listeners) {
    assert(element != null);
    assert(listeners != null);
    listeners?.forEach((lst) => lst.unsubscribeElement(element));
  }
}

/// Light weight controller that listens to at most one [Observed] per build cycle.
///
/// Because it holds at most one [Observed] per build cycle, widgets are
/// also associated with at most one [Observed]. This allows a gain in performance.
/// It's faster than the standard [FullController].
class LightController extends FloopController {
  ObservedListener _currentListener;

  Map<Element, ObservedListener> _subscriptions = {};

  @visibleForTesting
  Map<Element, ObservedListener> get subscriptions => _subscriptions;

  @override
  int get length => _subscriptions.length;

  @override
  bool contains(Element element) => _subscriptions.containsKey(element);

  @override
  void registerPeekedListener(ObservedListener listener) {
    assert(listening);
    if (_currentListener == null) {
      _currentListener = listener;
    } else if (_currentListener != listener) {
      print(
          'ERROR: When using FloopLightController, there shouldn\'t be more than\n'
          'one ObservedMap read during the build cycle of a widget, otherwise\n'
          'subscriptions will not correctly commit.\n'
          'Switching to FullController will fix the issue.'
          // ' Call\n'
          // 'Floop.switchToStandardController at the beginning of the build or\n'
          // 'call Floop.defaultToStandardController() at the beginning of the app.\n'
          );
      assert(false);
    }
  }

  @override
  void _commitObservedReads() {
    if (_currentListener != null) {
      _currentListener.commitCurrentReads(_currentBuild);
      _subscriptions[_currentBuild] = _currentListener;
      _currentListener = null;
    } else {
      _subscriptions.remove(_currentListener);
    }
  }

  @override
  void reset() {
    _subscriptions.keys.toList().forEach(unsubscribeFromAll);
    _currentListener = null;
    super.reset();
    assert(_subscriptions.isEmpty);
  }

  @override
  void unsubscribeFromAll(Element element) {
    assert(contains(element));
    _subscriptions[element].unsubscribeElement(element);
    _subscriptions.remove(element);
  }
}

/// ObservedController class is a utility class used by
class ObservedListener {
  /// The map that associates keys with the Elements that should be updated when the
  /// value of the key is updated.
  Map<Object, Set<Element>> _keyToElements = Map();

  @visibleForTesting
  Map get keyToElements => _keyToElements;

  /// The reverse map of `keyToElements`, it goes from Element to keys
  Map<Element, Set<Object>> _elementToKeys = Map();

  /// The [Set] of Elements that should be updated when there is a mutation in the
  /// [Observed].
  Set<Element> _mutations = Set();

  // The keys read during curent build cycle.
  Set<Object> currentKeyReads = Set();

  bool currentMutationRead = false;

  _associateElementToKeys(Element element, Iterable<Object> keysToAdd) {
    for (var key in keysToAdd) {
      _keyToElements.putIfAbsent(key, () => Set<Element>()).add(element);
    }
  }

  _dissociateElementFromKeys(Element element, Iterable<Object> keysToRemove) {
    for (Object key in keysToRemove) {
      assert(_keyToElements[key].contains(element));
      _keyToElements[key].remove(element);
      if (_keyToElements[key].isEmpty) {
        _keyToElements.remove(key);
      }
    }
  }

  void updateElementKeys(Element element, Set<Object> newKeys) {
    assert(element != null);
    assert(newKeys != null);
    Set<Object> elementKeys = _elementToKeys[element];
    if (elementKeys == null) {
      _associateElementToKeys(element, newKeys);
      _elementToKeys[element] = newKeys;
    }
    // Previous keys that are not the same as current keys only happens when
    // there are conditional or non constant key reads from the Observed.
    // It shouldn't be the most common usage.
    else if (elementKeys.length > newKeys.length ||
        !elementKeys.containsAll(newKeys)) {
      _dissociateElementFromKeys(element, elementKeys.difference(newKeys));
      _associateElementToKeys(element, newKeys.difference(elementKeys));
      _elementToKeys[element] = newKeys;
    }

    if (newKeys.isEmpty) {
      _elementToKeys.remove(element);
    } else {
      _elementToKeys[element] = newKeys;
    }
  }

  void updateMutation(Element element) {
    if (currentMutationRead)
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

  /// Unsubscribes the element from all keys on this [ObservedListener]
  void unsubscribeElement(Element element) {
    assert(_elementToKeys.containsKey(element) || _mutations.contains(element));
    if (_elementToKeys.containsKey(element)) {
      _dissociateElementFromKeys(element, _elementToKeys[element]);
      _elementToKeys.remove(element);
    }
    _mutations.remove(element);
  }

  void valueRetrieved(Object key) {
    if (floopController.listening) {
      currentKeyReads.add(key);
      floopController.registerPeekedListener(this);
    }
  }

  void mutationRead() {
    if (floopController.listening) {
      floopController.registerPeekedListener(this);
    }
  }

  void valueChanged(Object key) {
    if (_keyToElements.containsKey(key))
      floopController.markAsNeedBuild(_keyToElements[key]);
    else if (_mutations.isNotEmpty) floopController.markAsNeedBuild(_mutations);
  }

  void cleared() {
    // updating all elements will unsubscribe all keys during the refresh cycle
    floopController.markAsNeedBuild(_mutations);
    floopController.markAsNeedBuild(_keyToElements.keys);
  }
}
