import 'dart:collection';
import './controller.dart';

final ObservedMap<String, dynamic> floop = ObservedMap();

abstract class Observed<K, V> {
  ObservedListener _listener = ObservedListener();
}

/// The basic Map data structure that is listened by Floop when reading
/// or setting values.
///
/// Any reads from an [ObservedMap] inside a Floop's Widget [buildWithFloop]
/// method, subscribes the read keys to the widget's [Element] (context).
/// Whenever a key value changes, any subscribed context will be rebuilt in
/// the next frame.
class ObservedMap<K, V> extends MapMixin<K, V> with Observed<K, V> {
  Map<K, V> _keyToValue = Map();

  ObservedMap();

  ObservedMap.of(Map map) {
    addAll(map);
  }

  convert(value) {
    if (value is Map) {
      return ObservedMap.of(value);
    } else if (value is List) {
      return List.unmodifiable(value.map((v) => convert(v)));
    } else {
      return value;
    }
  }

  operator [](key) {
    _listener.valueRetrieved(key);
    return _keyToValue[key];
  }

  /// Returns the keys of this [ObservedMap], retrieved from an internal
  /// [LinkedHashMap] instance.
  ///
  /// Retrieving [keys] during a [Widget] or [State] `buildWithFloop` cycle will subscribe
  /// the correspnding widget to any insertions or removals of keys in this Map, regardless
  /// of the keys being iterated over or not. It does not make the widget subscription
  /// sensitive to the keys corresponding values (unless the value is also retrieved
  /// during the build cycle), so later setting a key to a different value will
  /// not trigger rebuilds.
  @override
  Iterable<K> get keys {
    // if(_prepareAndCheckIfListening()) _subscribeMutation();
    _listener.mutationRead();
    return _keyToValue.keys;
  }

  /// Sets the `value` of `key`. When `value` is of type [Map] or [List] a
  /// deep copy of `value` is created and stored instead of `value`.
  ///
  /// Subscribed elements to the `key` will get updated if `this[key]!=value`.
  ///
  /// Check [ObservadMap.setValue] to update a key with more options.
  ///
  /// [Map] and [List] values are recursively traversed saving copied versions of them.
  /// Stored [Map] values can be modified while [List] values are unmodifiable.
  ///
  /// For each value of type [Map] it will create an [ObservedMap] copy of it.
  /// For each value of type [List] it will create a copy using [List.unmodifiable].
  operator []=(Object key, V value) {
    // print('Setting \'$key\'  subscriptions: ${keySubscriptions[key]}');
    _notifyListenerIfChange(key, value);
    _keyToValue[key] = convert(value);
  }

  /// Sets the `value` of the `key` exactly as it is given.
  ///
  /// Potential [Element] updates can be avoided by passing `triggerUpdates`
  /// as false.
  setValue(Object key, V value, [bool triggerUpdates = true]) {
    if (triggerUpdates) {
      _notifyListenerIfChange(key, value);
    }
    _keyToValue[key] = value;
  }

  _notifyListenerIfChange(Object key, V value) {
    if (!_keyToValue.containsKey(key) || _keyToValue[key] != value) {
      _listener.valueChanged(key);
    }
  }

  /// Updates all elements subscribed to they key.
  ///
  /// It should be rare to use this method, `operator []=` automatically
  /// triggers updates when the `key` value changes.
  void forceUpdate(Object key) {
    _listener.valueChanged(key);
  }

  @override
  void clear() {
    _keyToValue.clear();
    _listener.cleared();
  }

  @override
  V remove(Object key, [bool triggerUpdates = true]) {
    if (triggerUpdates && _keyToValue.containsKey(key)) {
      _listener.valueChanged(key);
    }
    return _keyToValue.remove(key);
  }
}
