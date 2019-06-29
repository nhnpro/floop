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

  Element _currentElement;

  bool isListening() {
    _currentElement = controller.currentBuild;
    return _currentElement!=null;
  }
  
  /// Subscribes the key if a floop [Widget]'s build is ongoing.
  void subscribeKeyIfListening(Object key) {
    if(!isListening()) return;
    controller.subscribeObserved(this);
    var keySubs = _keySubscriptions.putIfAbsent(key, () => Set<Element>());
    var eleSubs = _elementSubscriptions.putIfAbsent(_currentElement, () => Set<K>());
    keySubs.add(_currentElement);
    eleSubs.add(key);
  }

  subscribeMutationIfListening() {
    if(!isListening()) return;
    controller.subscribeObserved(this);
    _mutationSubscriptions.add(_currentElement);
  }

  /// Unsubscribes the element from all keys on this [Observed]
  void unsubscribeElement(Element element) {
    assert(_elementSubscriptions[element] != null);
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
    var res = value;
    // if(value is UnmodifiableMapView) {
    //   print('UNMODIFIABLEMAP');
    //   res = value;
    // } else
    if(value is Map) {
      res = ObservedMap.of(value);
    } else if (value is List) {
      res = UnmodifiableListView(value.map((v) => convert(v)).toList());
    }
    return res;
  }

  operator [](k) {
    // print('Get $k while building ${controller.currentBuild}');
    subscribeKeyIfListening(k);
    return _keyToValue[k];
  }

  
  _checkAndMarkIfRequireRebuild(Object key) {
    if(!_keyToValue.containsKey(key)) controller.markElementsAsNeedBuild(_mutationSubscriptions);
    controller.markElementsAsNeedBuild(_keySubscriptions[key]);
  }
  
  /// Behaves 
  setValueRaw(Object key, V value) {
    _checkAndMarkIfRequireRebuild(key);
    _keyToValue[key] = value;
  }

  /// Sets the value of the given key.
  /// In the cases of [Map] or [List] values, it will recursively traverse them and
  /// save copied versions of them.
  /// For each value of type [Map] it will create an [ObservedMap] copy of it.
  /// For each value of type [List] it will create a [UnmodifiableListView] copy of it.
  operator []=(Object key, V value) {
    // print('Setting \'$key\'  subscriptions: ${keySubscriptions[key]}');
    _checkAndMarkIfRequireRebuild(key);
    _keyToValue[key] = convert(value);
  }

  @override
  void clear() {
    _keyToValue.clear();
    // updating all elements will unsubscribe all keys during the refresh cycle
    controller.markElementsAsNeedBuild(_elementSubscriptions.keys);
    controller.markElementsAsNeedBuild(_mutationSubscriptions);
  }

  /// Returns the keys of this ObservedMap, retrieved from an internal [LinkedHashMap]
  /// instance.
  /// 
  /// Retrieving `keys` during a [Widget] or [State] `buildWithFloop` cycle will subscribe
  /// the correspnding widget to any insertions or removals of keys in this Map, regardless
  /// of the keys being iterated over or not. It does not make the widget subscription
  /// sensitive to a key's corresponding value though (unless the value is also retrieved
  /// during the build cycle), so setting a key to a different value will not trigger a rebuild.
  @override
  Iterable<K> get keys {
    subscribeMutationIfListening();
    return _keyToValue.keys;
  }

  @override
  V remove(Object key) {
    controller.markElementsAsNeedBuild(_keySubscriptions.remove(key));
    controller.markElementsAsNeedBuild(_mutationSubscriptions);
    return _keyToValue.remove(key);
  }
}
