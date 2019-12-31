import 'dart:collection';

import './flutter.dart' show protected;
import './time.dart';

import './controller.dart';

/// Dynamic values provider to widgets.
///
/// Read values like reading from any [Map] within a widget's build method
/// and the widget will automatically rebuild on changes to the values.
///
/// See also:
///
///  * [DynValue] for a single dynamic value.
final DynMap<Object, dynamic> floop = DynMap();

/// An object that keeps a dynamic value.
abstract class DynValue<V> implements Observed, ValueWrapper<V> {
  factory DynValue([V initialValue]) => ObservedValue(initialValue);

  /// Sets the value without triggering updates to subscribed elements.
  setSilently(V newValue);

  /// Retrieves the value without notifying a value retrieval.
  getSilently();
}

/// A [Map] implementation that provides dynamic values to widgets.
///
/// Retrieving values from a [DynMap] instance within a Floop widget's build
/// method will trigger automatic rebuilds of the [BuildContext] on changes to
/// any of the values retrieved.
class DynMap<K, V> extends ObservedMap<K, V> {
  DynMap() : super();
  DynMap.of(Map<K, V> map) : super.of(map);
}

class Observed = Object with ObservedNotifierMixin, FastHashCode;

convert(value) {
  if (value is Observed) {
    return value;
  } else if (value is Map) {
    return DynMap.of(value);
  } else if (value is List) {
    return List.unmodifiable(value.map((v) => convert(v)));
  } else {
    return value;
  }
}

class ValueWrapper<T> {
  T value;
  ValueWrapper([this.value]);
}

@protected
class ObservedValue<T> extends Observed implements DynValue<T> {
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

  setSilently(T newValue) {
    _value = newValue;
  }

  getSilently() {
    return _value;
  }
}

/// An dynamic value that notifies value changes with a frequency restriction.
///
/// Changes to notifications to listeners (e.g. Floop widgets) at most
/// once in any time interval of length `minTimeBetweenNotificationsMicros`.
///
/// If not enough time has passed since the last notification, an asynchronous
/// notification callback is created.
class TimedDynValue<T> extends ObservedValue<T> {
  int _lastNotifyTime;

  /// Minimun time between change notifications in microseconds.
  int microsecondsBetweenNotifications;

  /// Creates an observed value that will not notify of changes more than once
  /// in `minTimeBetweenNotifications`.
  ///
  /// If a value change occurs when it's not allowed to notify of changes, an
  /// asynchronous callback to notify after `minTimeBetweenNotifications`
  /// has elapsed since the last notification is created.
  ///
  TimedDynValue(Duration minTimeBetweenNotifications, [T initialValue])
      : microsecondsBetweenNotifications =
            minTimeBetweenNotifications.inMicroseconds,
        _lastNotifyTime =
            microseconds() - minTimeBetweenNotifications.inMicroseconds,
        super(initialValue);

  int get minMicrosecondsToNextNotifyChange {
    if (_lastNotifyTime == null) {
      return null;
    }
    return _lastNotifyTime + microsecondsBetweenNotifications - microseconds();
  }

  _notifyChange([bool postpone = true]) {
    _lastNotifyTime = microseconds();
    _notifyLocked = false;
    super.notifyChange(postpone);
  }

  _delayedNotifyChange(int delayedMicros) {
    Future.delayed(Duration(microseconds: delayedMicros), _notifyChange);
  }

  bool _notifyLocked = false;

  notifyChange([bool postpone = false]) {
    int timeToNextNotify = minMicrosecondsToNextNotifyChange;
    if (_notifyLocked) {
      if (timeToNextNotify < -microsecondsBetweenNotifications) {
        _notifyChange(postpone);
      }
    } else if (timeToNextNotify > 0) {
      _notifyLocked = true;
      _delayedNotifyChange(timeToNextNotify);
    } else {
      _notifyChange(postpone);
    }
  }
}

/// A special [Map] implementation that provides dynamic values to widgets.
///
/// Retrieving values from an [ObservedMap] instance within a widget's build
/// method will trigger automatic rebuilds of the [BuildContext] on changes to
/// the values retrieved.
class ObservedMap<K, V> extends Observed with MapMixin<K, V> {
  final Map<K, ObservedValue<V>> _keyToValue = Map();

  // Stores keys that were accessed but have not been set (phantom keys).
  final Map<K, ObservedValue<V>> _unexistingKeyToNullValue = Map();

  ObservedMap() : super();

  ObservedMap.of(Map<K, V> map) {
    for (var entry in map.entries) {
      _keyToValue[entry.key] = ObservedValue(entry.value);
    }
  }

  /// Retrieves the value of `key`. When invoked from within a [build] method,
  /// the context gets subscribed to the key and rebuilds on value changes.
  V operator [](Object key) {
    if (controllerIsListening) {
      // Returns the value if it exists. If it doesn't, add the key to the
      // map of the retrieved but unset keys (phantom keys). This is necessary
      // to update the listener in case the key is set later.
      return (_keyToValue[key] ??
              _unexistingKeyToNullValue.putIfAbsent(key, () => ObservedValue()))
          .value;
    }
    return _keyToValue[key]?.value;
  }

  /// Retrieved the underlying DynValue that keeps the value for the key.
  ///
  /// This method is intended for internal use. `operator []` should suffice
  /// traditional uses cases.
  @protected
  DynValue<V> getDynValue(Object key) {
    return _keyToValue[key] ?? _unexistingKeyToNullValue[key];
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

  _setValue(K key, V value) {
    var observedValue = _keyToValue[key];
    if (observedValue == null) {
      observedValue = _unexistingKeyToNullValue.remove(key);
      if (observedValue == null) {
        _keyToValue[key] = ObservedValue(value);
      } else {
        _keyToValue[key] = observedValue;
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

  /// Sets the `value` for the `key` exactly as it is given.
  ///
  /// [Element] updates can be avoided by passing `triggerUpdates` as false.
  ///
  /// See also:
  ///  * [notifyListenersOfKey] to force a value change notification.
  setValue(Object key, V value, [bool triggerUpdates = true]) {
    if (triggerUpdates) {
      _setValue(key, value);
      return;
    }
    var observedValue = _keyToValue[key];
    if (observedValue != null) {
      assert(!_unexistingKeyToNullValue.containsKey(key));
      observedValue.setSilently(value);
    } else {
      observedValue = _unexistingKeyToNullValue.remove(key) ?? ObservedValue();
      observedValue.setSilently(value);
      _keyToValue[key] = observedValue;
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
    var value;
    if (observedValue != null) {
      value = observedValue.value;
      if (triggerUpdates) {
        observedValue.notifyChange();
      }
      observedValue.dispose();
    }
    return value;
  }

  /// Forces a value change notification to the listeners of the key.
  ///
  /// If `postponeNotificationHandling` is true, widget rebuilds will be
  /// triggered after a new frame finishes rendering.
  notifyListenersOfKey(K key, {bool postponeNotificationHandling = false}) {
    final observed = getDynValue(key);
    if (observed != null) {
      observed.notifyChange(postponeNotificationHandling);
    }
  }
}
