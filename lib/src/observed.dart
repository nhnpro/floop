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

class Observed = Object with ObservedNotifierMixin, FastHashCode;

convert(value) {
  if (value is Observed) {
    return value;
  } else if (value is Map) {
    return ObservedMap.of(value);
  } else if (value is List) {
    return List.unmodifiable(value.map((v) => convert(v)));
  } else {
    return value;
  }
}

class ObservedValue<T> extends Observed {
  T _value;
  ObservedValue([T initialValue]) : _value = initialValue;

  T get value {
    notifyRead();
    return _value;
  }

  set value(T newValue) {
    if (newValue != _value) {
      _value = newValue;
      notifyChange();
    }
  }

  /// Sets the value without triggering updates to subscribed elements.
  setSilently(T newValue) {
    _value = newValue;
  }
}

/// A special [Map] implementation that provides dynamic values to widgets.
///
/// Retrieving values from an [ObservedMap] instance within a widget's build
/// method will trigger automatic rebuilds of the [BuildContext] on changes to
/// the values retrieved.
class ObservedMap<K, V> extends Observed with MapMixin<K, V> {
  final Map<K, ObservedValue<V>> _keyToValue = Map();

  // Map used to observe keys that were accessed but have not been set.
  final Map<K, ObservedValue<V>> _unexistingKeyToNullValue = Map();

  ObservedMap() : super();

  ObservedMap.of(Map map) {
    addAll(map);
  }

  /// Retrieves the `value` of `key`. When invoked from within a [build]
  /// method, the context being built gets subscribed to
  /// the key in order to rebuild when the key value changes.
  V operator [](Object key) {
    if (isListening) {
      return (_keyToValue[key] ??
              _unexistingKeyToNullValue.putIfAbsent(key, () => ObservedValue()))
          .value;
    }
    return _keyToValue[key]?.value;
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
    notifyRead;
    return _keyToValue.keys;
  }

  // _setValueFirstTime(Key key, V value) {
  //   observedValue = _unexistingKeyToNullValue.remove(key);
  //   if (observedValue == null) {
  //     _keyToValue[key] = ObservedValue(value);
  //   } else {
  //     _keyToValue[key] = observedValue;
  //     observedValue.value = value;
  //   }
  // }

  _setValue(K key, V value) {
    var observedValue = _keyToValue[key];
    if (observedValue == null) {
      observedValue = _unexistingKeyToNullValue.remove(key);
      if (observedValue == null) {
        _keyToValue[key] = ObservedValue(value);
      } else {
        _keyToValue[key] = observedValue..value = value;
        observedValue.value = value;
      }
    } else {
      assert(!_unexistingKeyToNullValue.containsKey(key));
      observedValue.value = value;
    }
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
    _setValue(key, convert(value));
  }

  /// Sets the `value` of the `key` exactly as it is given.
  ///
  /// [Element] updates can be avoided by passing `triggerUpdates` as false.
  setValue(Object key, V value, [bool triggerUpdates = true]) {
    if (triggerUpdates) {
      _setValue(key, value);
      return;
    }
    var observedValue =
        _keyToValue[key] ?? _unexistingKeyToNullValue.remove(key);
    if (observedValue != null) {
      assert(!_unexistingKeyToNullValue.containsKey(key));
      observedValue.setSilently(value);
    } else {
      observedValue = _unexistingKeyToNullValue.remove(key) ?? ObservedValue();
      _keyToValue[key] = observedValue..setSilently(value);
    }
  }

  /// Updates all elements subscribed to they key.
  ///
  /// It should be rare to use this method, `operator []=` automatically
  /// triggers updates when the `key` value changes.
  void forceUpdate(Object key) {
    _keyToValue[key]?.notifyChange();
  }

  @override
  void clear([bool triggerUpdates = true]) {
    if (triggerUpdates) {
      for (var listener in _keyToValue.values) {
        listener.notifyChange();
      }
      notifyChange();
    }
    _keyToValue.clear();
  }

  @override
  V remove(Object key, [bool triggerUpdates = true]) {
    var observedValue = _keyToValue.remove(key);
    if (triggerUpdates) {
      observedValue.notifyChange();
    }
    return observedValue.value;
  }
}
