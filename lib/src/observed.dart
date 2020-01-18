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
///  * [DynValue2] for a single dynamic value.
final DynMap<Object, dynamic> floop = DynMap();

class Dyn = Object with ObservedNotifierMixin, FastHashCode;

convert(value) {
  if (value is Dyn) {
    return value;
  } else if (value is Map) {
    return DynMap.of(value);
  } else if (value is List) {
    return DynList.from(value);
  } else {
    return value;
  }
}

class ValueWrapper<T> {
  T value;
  ValueWrapper([this.value]);
}

/// An object that stores a dynamic value.
class DynValue<T> extends Dyn {
  T _value;
  DynValue([T initialValue]) : _value = initialValue;

  /// Retrieves the dynamic value.
  T get value {
    notifyRead();
    return _value;
  }

  /// Sets the dynamic value.
  set value(T newValue) {
    if (newValue != _value) {
      _value = newValue;
      notifyChange();
    }
  }

  /// Sets the value without triggering updates.
  T setSilently(T newValue) {
    return _value = newValue;
  }

  /// Retrieves value without registering a read.
  T getSilently() {
    return _value;
  }
}

/// An dynamic value that notifies value changes with a frequency restriction.
///
/// Change notifications to listeners (Floop widgets) are performed at most
/// once in any time interval of length `minTimeBetweenNotificationsMicros`.
///
/// If not enough time has passed since the last notification, an asynchronous
/// notification callback is created.
class TimedDynValue<T> extends DynValue<T> {
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

/// A [List] implementation that provides dynamic values to widgets.
///
/// Retrieving values from a [DynList] instance within a widget's build method
/// will trigger automatic rebuilds of the widget when the values change.
class DynList<T> extends Dyn with ListMixin<T> {
  final _dynValues;

  DynList([int length]) : _dynValues = List<DynValue<T>>(length);
  DynList.from(Iterable<T> elements)
      : _dynValues = List<DynValue<T>>()..length = elements.length {
    var i = 0;
    for (var ele in elements) {
      this[i++] = ele;
    }
  }

  @override
  int get length {
    notifyRead();
    return _dynValues.length;
  }

  set length(int newLength) {
    if (_dynValues.length != newLength) {
      notifyChange();
    }
    _dynValues.length = newLength;
  }

  @override
  operator [](int index) {
    return _dynValues[index]?.value;
  }

  @override
  void operator []=(int index, value) {
    (_dynValues[index] ??= DynValue(value)).value = convert(value);
  }
}

/// A special [Map] implementation that provides dynamic values to widgets.
///
/// Retrieving values from a [DynMap] instance within a widget's build method
/// will trigger automatic rebuilds of the widget when the values change.
class DynMap<K, V> extends Dyn with MapMixin<K, V> {
  final Map<K, DynValue<V>> _keyToValue = Map();

  // Stores keys that were accessed but have not been set (phantom keys).
  final Map<K, DynValue<V>> _unexistingKeyToNullValue = Map();

  DynMap() : super();

  DynMap.of(Map<K, V> map) {
    for (var entry in map.entries) {
      _keyToValue[entry.key] = DynValue(entry.value);
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
              _unexistingKeyToNullValue.putIfAbsent(key, () => DynValue()))
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

  /// The keys of [this].
  ///
  /// Retrieving [keys] while building a Floop widget subscribes the widget to
  /// insertions or removals of keys in the Map.
  @override
  Iterable<K> get keys {
    notifyRead();
    return _keyToValue.keys;
  }

  _setValue(K key, V value) {
    var observedValue = _keyToValue[key];
    if (observedValue == null) {
      observedValue = _unexistingKeyToNullValue.remove(key);
      if (observedValue == null) {
        _keyToValue[key] = DynValue(value);
      } else {
        _keyToValue[key] = observedValue;
        observedValue.value = value;
      }
    } else {
      assert(!_unexistingKeyToNullValue.containsKey(key));
      observedValue.value = value;
    }
  }

  /// Sets the `value` of `key`. Values of type [Map] or [List] that are not
  /// [Dyn] are copied into a new [DynMap] or [DynList].
  ///
  /// Widgets subscribed to `key` will get updated if `this[key]!=value`.
  ///
  /// See also:
  ///  * [setValue] updates a key without copying [Map] or [List] and widget
  ///    updates can be disabled.
  operator []=(Object key, V value) {
    _setValue(key, convert(value));
  }

  /// Sets the `value` for the `key` as it is given.
  ///
  /// Widget updates can be avoided by passing `triggerUpdates` as false.
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
      observedValue = _unexistingKeyToNullValue.remove(key) ?? DynValue();
      observedValue.setSilently(value);
      _keyToValue[key] = observedValue;
    }
  }

  /// Updates all widgets subscribed to they key.
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
