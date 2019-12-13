import 'package:floop/src/flutter_import.dart' show debugPrint;
import 'package:meta/meta.dart';

/// Interface required by [ObservedController] to notify changes in observeds.
///
/// Implemented by [FloopElement].
abstract class ObservedListener implements FastHashCode {
  @protected
  Set<ObservedNotifier> notifiers;

  /// Handles a change notified by an [ObservedNotifier].
  ///
  /// `postponeEventHandling` advices the listener to postpone the event
  /// handling. For example when an [ObservedValue] is being set for the first
  /// time this flag is sometimes used.
  @protected
  onObservedChange(ObservedNotifier notifier,
      [bool postponeEventHandling = false]);
}

/// Interface necessary by [ObservedController] to register and notify
/// listeners of changes.
///
/// Implemented by [Observed], [ObservedValue] and [ObservedMap].
abstract class ObservedNotifier implements FastHashCode {
  @protected
  Set<ObservedListener> listeners;
  notifyRead();
  notifyChange();
}

/// Class that subscribes [ObservedListener] to [ObservedNotifier] instances.
///
/// [FloopElement] implements [ObservedListener] to changes of [Observed] that they read when they were
/// building their respective widgets, using this controller an intermediate.
class ObservedController {
  static ObservedListener _activeListener;

  /// The object that is currently listening to [ObservedNotifier] instances.
  static ObservedListener get activeListener => _activeListener;

  static bool get isListening => _activeListener != null;

  static startListening(ObservedListener listener) {
    if (isListening) {
      stopListening();
    }
    _activeListener = listener;
  }

  static void stopListening() {
    assert(_activeListener != null);
    _commitSubscriptions();
    assert(_currentNotifiers.isEmpty);
    _activeListener = null;
  }

  static Set<ObservedNotifier> _currentNotifiers = Set();

  static registerCurrentNotifier(ObservedNotifier notifier) {
    assert(isListening);
    notifier.listeners ??= Set();
    _currentNotifiers.add(notifier);
  }

  static _commitSubscriptions() {
    final listener = _activeListener;
    final previousNotifiers = _activeListener.notifiers;
    assert(() {
      if (_currentNotifiers.isNotEmpty &&
          (previousNotifiers == null || previousNotifiers.isEmpty)) {
        ObservedController._debugSubscribedListeners.add(_activeListener);
      }
      return true;
    }());
    if (previousNotifiers == null) {
      if (_currentNotifiers.isNotEmpty) {
        for (var notifier in _currentNotifiers) {
          notifier.listeners.add(listener);
        }
        listener.notifiers = _currentNotifiers;
        _currentNotifiers = Set();
      }
      return;
    }
    // Most element rebuilds should read the same keys, a quick check is done
    // to handle that case.
    // Depending on how [Set.containsAll] is implemented, but there is a
    // potential performance gain by using a cummulative hash for fast Set
    // comparison. This would imply losing a one hundred percent consistency
    // in a rare collision case, but certainly worth it for a performance
    // gain. Most of the time the same Map keys are accesed when rebuilding
    // widgets, so if Set have the same length and same cummulative hash, a
    // 99.9999% of the time they will have the same ids stored.
    else if (previousNotifiers.length == _currentNotifiers.length &&
        previousNotifiers.containsAll(_currentNotifiers)) {
      _currentNotifiers.clear();
      return;
    }

    // Registers listener in new notifiers.
    for (var newNotifier in _currentNotifiers) {
      if (!previousNotifiers.remove(newNotifier)) {
        newNotifier.listeners.add(listener);
      }
    }
    // Unregister listener from old notifiers (previousNotifiers - currentNotifiers).
    for (var oldNotifier in previousNotifiers) {
      oldNotifier.listeners.remove(listener);
    }
    listener.notifiers = _currentNotifiers;
    _currentNotifiers = previousNotifiers..clear();
  }

  /// Flag that prevents notification events from triggering an assertion error
  /// when listening.
  static bool debugAllowNotificationsWhenListening = false;

  // static bool get allowNotifyWhenListening =>
  //     _allowNotifyWhenListening;

  // static void suggestPostponeNotificationHandling() {
  //   _allowNotifyWhenListening = true;
  // }

  // static void stopSuggestingPostponingNotificationHandling() {
  //   // assert(_postponeChangeNotifications);
  //   _allowNotifyWhenListening = false;
  // }

  // static final Set<ObservedNotifier> postponedNotifiers = Set();

  static notifyChangeToListeners(ObservedNotifier notifier,
      [bool advicePostponing = false]) {
    assert(() {
      if (isListening &&
          !advicePostponing &&
          !debugAllowNotificationsWhenListening) {
        debugPrint(
            'Error: `${activeListener}` is listening (a widget is building) '
            'while setting value of the [ObservedNotifier] $notifier. '
            '[Observed] instances like [ObservedMap] cannot be modified '
            'from within a build method.\n'
            'In [FloopWidget] classes, initContext can be used to initialize '
            'values of observeds.');
        assert(false);
      }
      return true;
    }());
    // if (_postponeChangeNotifications) {
    //   postponedNotifiers.add(notifier);
    //   return;
    // }
    for (var listener in notifier.listeners) {
      listener.onObservedChange(notifier, advicePostponing);
    }
  }

  static unsubscribeListener(ObservedListener listener) {
    assert(!isListening);
    for (var notifier in listener.notifiers) {
      assert(notifier.listeners.contains(listener));
      notifier.listeners.remove(listener);
    }
    listener.notifiers.clear();
    assert(() {
      ObservedController._debugSubscribedListeners.remove(listener);
      return true;
    }());
  }

  static unsubscribeNotifier(ObservedNotifier notifier) {
    for (var listener in notifier.listeners) {
      listener.notifiers.remove(notifier);
    }
    notifier.listeners.clear();
  }

  static final _debugSubscribedListeners = Set<ObservedListener>();

  static int get debugSubscribedListenersCount =>
      _debugSubscribedListeners.length;

  static debugReset() {
    for (var listener in _debugSubscribedListeners.toList()) {
      unsubscribeListener(listener);
    }
  }

  static bool debugContainsListener(ObservedListener listener) =>
      _debugSubscribedListeners.contains(listener);
}

/// Class to retrieve a fast hashCode.
///
/// The inherited Dart implementation of hashCode is very slow, it takes 10
/// times longer than using a fixed int. This causes a big performance drop in
/// hash data structures like Set or Map. Implementations os [ObservedNotifier]
/// and [ObservedListener] should include this mixin.
mixin FastHashCode {
  static int _lastId = 0;

  /// The value returned by [hashCode].
  ///
  /// Implementers of [FastHashCode] interface that do not include it as mixin
  /// should override [hashcode] to return this value.
  final hashId = _lastId++;

  int get hashCode => hashId;
}

enum ObservedStatus {
  active,
  defunct,
}

/// Mixin that connects observeds with [ObservedListener] instances that use
/// [ObservedController].
///
/// Included by [Observed], base class of [ObservedValue] and [ObservedMap].
abstract class ObservedNotifierMixin implements ObservedNotifier {
  var _debugStatus = ObservedStatus.active;

  ObservedListener get activeListener => ObservedController._activeListener;
  bool get controllerIsListening => ObservedController.isListening;

  // Set<ObservedListener> _listeners;
  // @protected
  // Set<ObservedListener> get listeners => _listeners ??= Set();
  // @protected
  // set listeners(Set<ObservedListener> listeners) => _listeners = listeners;

  @protected
  Set<ObservedListener> listeners;

  bool get hasRegisteredListeners => listeners != null && listeners.isNotEmpty;

  void notifyRead() {
    assert(_debugStatus != ObservedStatus.defunct);
    if (ObservedController.isListening) {
      ObservedController.registerCurrentNotifier(this);
    }
  }

  void notifyChange([bool postponeNotificationHandling = false]) {
    assert(_debugStatus != ObservedStatus.defunct);
    if (listeners != null) {
      if (listeners.isNotEmpty) {
        ObservedController.notifyChangeToListeners(
            this, postponeNotificationHandling);
      } else if (postponeNotificationHandling) {
        ObservedController.notifyChangeToListeners(this, true);
      }
    }
  }

  void forgetListeners() {
    assert(_debugStatus != ObservedStatus.defunct);
    if (hasRegisteredListeners) {
      ObservedController.unsubscribeNotifier(this);
    }
  }

  /// Dispose can be invoked when this notifier is not going to be used again.
  void dispose() {
    assert(_debugStatus == ObservedStatus.active);
    forgetListeners();
    assert(() {
      _debugStatus = ObservedStatus.defunct;
      return true;
    }());
  }
}
