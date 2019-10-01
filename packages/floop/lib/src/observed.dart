import 'dart:collection';
import './controller.dart';

/// Dynamic values provider to widgets.
///
/// Read values like reading from any [Map] within a widget's build method
/// and the widget will automatically rebuild on changes to the values read.
///
/// `floop` is just instance of [ObservedMap], other [ObservedMap] objects
/// can be instantiated and will also provide dynamic values to widgets.
final ObservedMap<Object, dynamic> floop = ObservedMap();

/// A special [Map] implementation that provides dynamic values to widgets.
///
/// Retrieving values from an [ObservedMap] instance within a widget's build
/// method will trigger automatic rebuilds of the [BuildContext] on changes to
/// the values retrieved.
class ObservedMap<K, V> with MapMixin<K, V>, ObservedListener {
  final Map<K, V> _keyToValue = Map();

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

  /// Retrieves the `value` of `key`. When invoked from within a [build]
  /// method, the context being built gets subscribed to
  /// the key in order to rebuild when the key value changes.
  operator [](key) {
    valueRetrieved(key);
    return _keyToValue[key];
  }

  /// Returns the keys of this [ObservedMap], retrieved from an internal
  /// [LinkedHashMap] instance.
  ///
  /// Retrieving [keys] during a [Widget] or [State] build cycle will
  /// subscribe the correspnding widget to any insertions or removals of
  /// keys in the Map, regardless of the keys being iterated over or not.
  /// It does not make the subscription sensitive to the keys corresponding
  /// values.
  @override
  Iterable<K> get keys {
    keysRetrieved();
    return _keyToValue.keys;
  }

  /// Sets the `value` of `key`. When `value` is of type [Map] or [List] a
  /// deep copy of `value` is created and stored instead of `value`.
  ///
  /// Subscribed elements to the `key` will get updated if `this[key]!=value`.
  ///
  /// Use [setValue] to update a key without deep copying [Map] or [List] or
  /// for setting values without triggering element updates.
  ///
  /// [Map] and [List] values are recursively traversed saving copied versions
  /// of them. For values of type [Map] an [ObservedMap] copy of it is stored.
  /// Values of type [List] are copied using [List.unmodifiable].
  operator []=(Object key, V value) {
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
    if (_keyToValue[key] != value || !_keyToValue.containsKey(key)) {
      valueChanged(key);
    }
  }

  /// Updates all elements subscribed to they key.
  ///
  /// It should be rare to use this method, `operator []=` automatically
  /// triggers updates when the `key` value changes.
  void forceUpdate(Object key) {
    valueChanged(key);
  }

  @override
  void clear() {
    _keyToValue.clear();
    cleared();
  }

  @override
  V remove(Object key, [bool triggerUpdates = true]) {
    if (triggerUpdates && _keyToValue.containsKey(key)) {
      valueChanged(key);
      mutation();
    }
    return _keyToValue.remove(key);
  }
}
