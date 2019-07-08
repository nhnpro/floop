import 'dart:collection';
import 'package:flutter/widgets.dart';

import './controller.dart';

final ObservedMap<String, dynamic> floop = ObservedMap();

abstract class Observed<K, V> {

  ObservedListener _listener = ObservedListener();

  // set controller(ObservedListener listener) {
  //   assert(_listener == null);
  //   _listener = listener;
  // }
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

  // bool _prepareAndCheckIfListening() {
  //   assert(_currentElement==null || _currentElement == controller.currentBuild);
  //   if(controller.currentBuild==null) return false;
  //   if(_currentElement!=null) return true;
  //   _currentElement = controller.currentBuild;
  //   _currentKeys = Set();
  //   return true;
  // }

  operator [](key) {
    // print('Get $k while building ${controller.currentBuild}');
    _listener.valueRetrieved(key);
    return _keyToValue[key];
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
    // if(_prepareAndCheckIfListening()) _subscribeMutation();
    _listener.mutationRead();
    return _keyToValue.keys;
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
    _notifySetValue(key, value);
    _keyToValue[key] = convert(value);
  }

  /// Sets the `value` of the `key`.
  /// Use this method instead of `[]=` to store a value exactly as it is given (no deep copy).
  setValueRaw(Object key, V value) {
    _notifySetValue(key, value);
    _keyToValue[key] = value;
  }

  _notifySetValue(Object key, V value) {
    if(!_keyToValue.containsKey(key))
      _listener.mutated();
    else if(_keyToValue[key] != value)
      _listener.valueChanged(key);
  }

  /// Updates all widgets subscribed to they key. Avoid using this method unless strictly necessary.
  /// The `operator []=` already updates subscribed widgets to the `key` when a value changes,
  /// which is the only case when a widget should get updated.
  void forceUpdate(Object key) {
    _listener.valueChanged(key);
  }

  @override
  void clear() {
    _keyToValue.clear();
    _listener.cleared();
  }

  @override
  V remove(Object key) {
    if(!_keyToValue.containsKey(key)) {
      _listener.valueChanged(key);
      _listener.mutated();
    }
    return _keyToValue.remove(key);
  }
}
