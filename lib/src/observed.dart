import 'dart:collection';
import 'package:flutter/widgets.dart';

import './controller.dart';

final ObservedMap<String, dynamic> floop = ObservedMap();

abstract class Observed<K, V> {
  // static Iterable<Element> get allSubscribedElements => controller.subscriptions.keys;
  Map<K, Set<Element>> _keySubscriptions = Map();
  Map<Element, Set<K>> _elementSubscriptions = Map();
  Set<Element> _mutationSubscriptions = Set();

  /// The map that associates keys with the Elements that should be updated when the
  /// value of the key is updated.
  Map<K, Set<Element>> get keySubscriptions => _keySubscriptions;

  /// The reverse map of `keySubscriptions`, it goes from Element to key
  Map<Element, Set<K>> get elementSubscriptions => _elementSubscriptions;

  /// The [Set] of Elements that should be updated when there is a mutation (insertions
  /// or removals) to [this]
  Set<Element> get mutationSubscriptions => _mutationSubscriptions;

  // it would be preferable to hold this on the controller, however performance-wise
  // this is faster.
  Element _currentElement;
  Set<K> _currentKeys;

  bool isListening() {
    _currentElement = controller.currentBuild;
    return _currentElement!=null;
  }
  
  /// Subscribes the key if a floop [Widget]'s build is ongoing.
  // void subscribeKeyIfListening(Object key) {
  //   if(!isListening()) return;
  //   subscribeKey(key);
  // }

  /// Subscribes the key if a floop [Widget]'s build is ongoing.
  void _subscribeKey(Object key) {
    controller.subscribeObserved(this);
    _currentKeys.add(key);
    // var keySubs = _keySubscriptions.putIfAbsent(key, () => Set<Element>());
    // var eleSubs = _elementSubscriptions.putIfAbsent(_currentElement, () => Set<K>());
    // keySubs.add(_currentElement);
    // eleSubs.add(key);
  }

  _subscribeMutation() {
    controller.subscribeObserved(this);
    _mutationSubscriptions.add(_currentElement);
  }

  // subscribeMutationIfListening() {
  //   if(!isListening()) return;
  //   subscribeMutation();
  // }

  // _unsubscribeCurrentDifferences() {
  //   var differenceKeys = _elementSubscriptions[_currentElement]?.difference(_currentKeys);
  //   if(differenceKeys!=null) {
  //     differenceKeys
  //       .forEach((K key) {
  //         assert(keySubscriptions[key].contains(_currentElement));
  //         keySubscriptions[key].remove(_currentElement);
  //       });
  //     _elementSubscriptions[_currentElement] = _currentKeys;
  //   }
  // }

  _subscribeElementToKeys(Element element, Set keysToAdd) {
    for(K key in keysToAdd) {
      assert(keySubscriptions[key].contains(element));
      keySubscriptions.putIfAbsent(key, () => Set<Element>()).add(element);
    }
    _elementSubscriptions.putIfAbsent(
      element, () => Set<K>()).addAll(keysToAdd.cast<K>());
  }

  _unsubscribeElementFromKeys(Element element, Set keysToRemove) {
    for(K key in keysToRemove) {
      assert(keySubscriptions[key].contains(element));
      keySubscriptions[key].remove(element);
      if(_keySubscriptions[key].isEmpty) {
        _keySubscriptions.remove(key);
      }
    }
    _elementSubscriptions[element].removeAll(keysToRemove);
    if(_elementSubscriptions[element].isEmpty)
      _elementSubscriptions.remove(element);
  }

  void updateElementKeySubscriptions(Element element, Set newKeys) {
    assert(element != null);
    assert(newKeys != null);
    Set<K> previousKeys = _elementSubscriptions[element];
    if(previousKeys==null) {
      _subscribeElementToKeys(element, newKeys);
    }
    else {
      _unsubscribeElementFromKeys(element, previousKeys.difference(newKeys));
      _subscribeElementToKeys(element, newKeys..removeAll(previousKeys));
    }
  }

  void updateMutationSubscription(Element element, [bool add=true]) {
    if(add)
      _mutationSubscriptions.add(element);
    else
      _mutationSubscriptions.remove(element);
  }

  // commitCurrentSubscriptions() {
  //   // _unsubscribeCurrentDifferences();
  //   var differenceKeys = _elementSubscriptions[_currentElement]?.difference(_currentKeys);
  //   if(differenceKeys!=null) {
  //     differenceKeys
  //       .forEach((K key) {
  //         assert(keySubscriptions[key].contains(_currentElement));
  //         keySubscriptions[key].remove(_currentElement);
  //       });
  //     _elementSubscriptions[_currentElement] = _currentKeys;
  //   }
  //   _currentElement = null;
  //   _currentKeys = null;
  // }

  // _unsubscribeElementFromKey(Element element, K key) {
  //   assert(_keySubscriptions[key].contains(element));
  //   _elementSubscriptions[element].remove(key);
  //   _keySubscriptions[key].remove(element);
  // }

  /// Unsubscribes the element from all keys on this [Observed]
  void unsubscribeElement(Element element) {
    assert(_elementSubscriptions[element] != null);
    // if(_elementSubscriptions[element]==null) return;
    for(var key in _elementSubscriptions[element]) {
      assert(() {
        var keySubs = _keySubscriptions[key];
        return keySubs != null ? keySubs.contains(element) : false;
      }());
      _keySubscriptions[key].remove(element);
      // clean map in case key has no more subscriptions
      if(_keySubscriptions[key].isEmpty) {
        _keySubscriptions.remove(key);
      }
    };
    _elementSubscriptions.remove(element);
    _mutationSubscriptions.remove(element);
  }
}
    
class ObservedMap<K, V> extends MapMixin<K, V> with Observed<K, V> {

  Map<K, V> _keyToValue = Map();

  ObservedMap();

  ObservedMap.of(Map map) {
    addAll(map);
  }

  convert(value) {
    if(value is Map) {
      return ObservedMap.of(value);
    }
    else if (value is List) {
      return List.unmodifiable(value.map((v) => convert(v)));
    }
    else {
      return value;
    }
  }

  bool _prepareAndCheckIfListening() {
    assert(_currentElement==null || _currentElement == controller.currentBuild);
    if(controller.currentBuild==null) return false;
    if(_currentElement!=null) return true;
    _currentElement = controller.currentBuild;
    _currentKeys = Set();
    return true;
  }

  operator [](k) {
    // print('Get $k while building ${controller.currentBuild}');
    if(_prepareAndCheckIfListening()) _subscribeKey(k);
    return _keyToValue[k];
  }

  _checkAndMarkIfRequireRebuild(Object key, V value) {
    if(!_keyToValue.containsKey(key)) controller.markElementsAsNeedBuild(_mutationSubscriptions);
    if(_keyToValue[key] != value) controller.markElementsAsNeedBuild(_keySubscriptions[key]);
  }

  /// Sets the `value` of the `key`. A deep copy of `value` will be stored when it is of 
  /// type [Map] or [List].
  /// 
  /// [Map] and [List] values will be recursively traversed saving copied versions of them.
  /// Stored [Map] values can be modified while [List] values are unmodifiable.
  /// 
  /// For each value of type [Map] it will create an [ObservedMap] copy of it.
  /// For each value of type [List] it will create a copy using [List.unmodifiable].
  /// 
  /// If the `key` was already in [this], the subscribed widgets to the `key` will only get
  /// updated when `this[key]!=value`. When there is a desire to update all subscribed widgets
  /// to they key without setting a new value use `forceUpdate` instead.
  operator []=(Object key, V value) {
    // print('Setting \'$key\'  subscriptions: ${keySubscriptions[key]}');
    _checkAndMarkIfRequireRebuild(key, value);
    _keyToValue[key] = convert(value);
  }

  /// Sets the `value` of the `key`.
  /// Use this method instead of `[]=` to store a value exactly as it is given (no deep copy).
  setValueRaw(Object key, V value) {
    _checkAndMarkIfRequireRebuild(key, value);
    _keyToValue[key] = value;
  }

  /// Updates all widgets subscribed to they key. Avoid using this method, it's hard to think
  /// of a use case.
  /// The `operator []=` already update subscribed widgets to the `key` when a value changes,
  /// which is only case when a widget should get updated.
  void forceUpdate(Object key) {
    controller.markElementsAsNeedBuild(_keySubscriptions[key]);
  }

  @override
  void clear() {
    _keyToValue.clear();
    // updating all elements will unsubscribe all keys during the refresh cycle
    controller.markElementsAsNeedBuild(_elementSubscriptions.keys);
    controller.markElementsAsNeedBuild(_mutationSubscriptions);
  }

  /// Returns the keys of this [ObservedMap], retrieved from an internal [LinkedHashMap]
  /// instance.
  /// 
  /// Retrieving `keys` during a [Widget] or [State] `buildWithFloop` cycle will subscribe
  /// the correspnding widget to any insertions or removals of keys in this Map, regardless
  /// of the keys being iterated over or not. It does not make the widget subscription
  /// sensitive to a key's corresponding value though (unless the value is also retrieved
  /// during the build cycle), so setting a key to a different value will not trigger rebuilds.
  @override
  Iterable<K> get keys {
    if(_prepareAndCheckIfListening()) _subscribeMutation();
    return _keyToValue.keys;
  }

  @override
  V remove(Object key) {
    controller.markElementsAsNeedBuild(_keySubscriptions.remove(key));
    controller.markElementsAsNeedBuild(_mutationSubscriptions);
    return _keyToValue.remove(key);
  }
}
