import './flutter_import.dart';

/// Class with the core methods that register reads and updates elements.
///
/// This class is connected to [ObservedValue] and [ObservedMap] through the
/// [ObservedListener] mixin.
abstract class FloopController {
  /// Element that is currently building.
  static Element _currentBuild;

  /// [BuildContext] of the ongoing [build].
  static Element get currentBuild => _currentBuild;

  /// Returns true if this controller is on listening mode.
  static bool get isListening => _currentBuild != null;

  /// The count of Elements subscribed to the controller.
  static int get length => _elementToListeners.length;

  /// The Elements subscribed to the controller.
  static Iterable<Element> get subscribedElements =>
      _elementToListeners.keys.toList();

  static bool contains(Element element) =>
      _elementToListeners.containsKey(element);

  static bool _postFrameUpdates = false;

  static void startListening(Element element) {
    if (isListening) {
      // If this happens it means there was an error while the a [FloopWidget]
      // instance was building.
      stopListening();
    }
    _currentBuild = element;
  }

  static void stopListening() {
    assert(_currentBuild != null);
    _commitObservedReads();
    _currentBuild = null;
  }

  static void enablePostFrameUpdatesMode() {
    assert(() {
      // If this happens it means there was an error during an [Element]
      // instance mount or unmount.
      if (_postFrameUpdates) {
        _postFrameUpdates = false;
        return false;
      }
      return true;
    }());
    _postFrameUpdates = true;
  }

  static void disablePostFrameUpdatesMode() {
    assert(_postFrameUpdates);
    _postFrameUpdates = false;
  }

  /// Unsubscribes all Elements (Widgets) from the registered Observeds.
  static void reset() {
    if (isListening) {
      stopListening();
    }
    _elementToListeners.keys.toList().forEach(unsubscribeElement);
    assert(_elementToListeners.isEmpty);
  }

  static Object _debugLastKeyChange;
  static Element _debugUnmounting;

  static debugUnmounting(Element element) => _debugUnmounting = element;
  static debugfinishUnmounting() => _debugUnmounting = null;

  static final Map<Element, Set<ObservedListener>> _elementToListeners = Map();

  static Set<ObservedListener> _currentListeners = Set();

  static void _commitObservedReads() {
    var element = _currentBuild;
    var previousListeners = _elementToListeners[element];
    // If `element` isn't registered yet, it is registered and associated with
    // all current read listeners.
    if (previousListeners == null) {
      if (_currentListeners.isNotEmpty) {
        _elementToListeners[element] = _currentListeners;
        for (var listener in _currentListeners) {
          listener._registerElement(element);
        }
        _currentListeners = Set();
      }
      return;
    }
    // Most element rebuilds should read the same keys, a quick check is done
    // to handle that case.
    // Not sure how [Set.containsAll] is implemented, but there is a potential
    // performance gain, by using a cummulative hash for fast Set comparison.
    // This would imply losing a one hundred percent consistency (very rare
    // collision case), but certainly worth it for a performance gain.
    // Most of the time the same Map keys are accesed when rebuilding widgets,
    // so if a Set has the same length and same cummulative hash, a 99.9999%
    // of the time they will have the same objects stored.
    if (_currentListeners.length == previousListeners.length &&
        previousListeners.containsAll(_currentListeners)) {
      _currentListeners.clear();
      return;
    }

    for (var listener in _currentListeners) {
      if (!previousListeners.remove(listener)) {
        listener._registerElement(element);
      }
    }
    // Unregister element from unread listeners (previousListeners - currentListeners).
    for (var listener in previousListeners) {
      listener._unregisterElement(element);
    }
    _elementToListeners[element] = _currentListeners;
    _currentListeners = previousListeners..clear();
  }

  static void registerListenerRead(ObservedListener listener) {
    assert(isListening);
    _currentListeners.add(listener);
  }

  static void unsubscribeElement(Element element) {
    _elementToListeners
        .remove(element)
        ?.forEach((listener) => listener._unregisterElement(element));
  }

  static void forgetListener(ObservedListener listener) {
    for (var element in listener.subscribedElements) {
      assert(_elementToListeners.containsKey(element));
      _elementToListeners[element]?.remove(listener);
      listener._unregisterElement(element);
    }
  }

  static final Set<Element> _posponedListenersToUpdate = Set();

  static void _markAsNeedsBuildCallback([_]) {
    assert(_posponedListenersToUpdate.isNotEmpty);
    _posponedListenersToUpdate
      ..retainAll(subscribedElements)
      ..forEach(markElementAsNeedsBuild)
      ..clear();
  }

  static void _posponeMarkAsNeedsBuild(Element element) {
    if (_posponedListenersToUpdate.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(_markAsNeedsBuildCallback);
    }
    _posponedListenersToUpdate.add(element);
  }

  static void markElementAsNeedsBuild(Element element) {
    assert(element != null);
    if (_postFrameUpdates) {
      assert(() {
        if (!element.owner.debugBuilding) {
          disablePostFrameUpdatesMode();
          return false;
        }
        return true;
      }());
      _posponeMarkAsNeedsBuild(element);
      return;
    }
    assert(() {
      if (isListening) {
        print('Error: Floop widget `${currentBuild.widget}` is building while '
            'setting value of key `$_debugLastKeyChange` in an '
            '[ObservedMap]. Avoid writing to an [ObservedMap] while '
            'bulding Widgets.');
        assert(false);
      }
      if (_debugUnmounting != null) {
        print('Error: Element $_debugUnmounting of Floop widget '
            '${_debugUnmounting.widget} is unmounting while attempting to '
            'mark an [Element] as need build. This happens due to the '
            'widget\'s [Floop.onContextUnmount] method changing or removing '
            'the value of an [ObservadMap] that is read by other widgets.');
        assert(false);
      }
      return true;
    }());
    assert(() {
      try {
        element.markNeedsBuild();
      } catch (e) {
        print('Error: FloopController is invoking markNeedsBuild on $element '
            'when it\'s not allowed or on an invalid Element. This is most '
            'likely due to initContext or disposeContext methods writing '
            'values to an ObservedMap instance.');
      }
      return true;
    }());
    element.markNeedsBuild();
  }
}

enum ListenerStatus {
  active,
  defunct,
}

mixin ObservedListener {
  Set<Element> _elements = Set();

  List<Element> get subscribedElements => _elements.toList();

  // int _id;

  // _disposeId(int id) {
  //   id = null;
  // }

  _registerElement(Element element) {
    assert(_debugDisposed == ListenerStatus.active);
    _elements.add(element);
  }

  _unregisterElement(Element element) {
    assert(_debugDisposed == ListenerStatus.active);
    _elements.remove(element);
  }

  forgetAllSubscriptions() {
    assert(_debugDisposed == ListenerStatus.active);
    FloopController.forgetListener(this);
  }

  var _debugDisposed = ListenerStatus.active;

  dispose() {
    assert(_debugDisposed == ListenerStatus.active);
    forgetAllSubscriptions();
    assert(() {
      _debugDisposed = ListenerStatus.defunct;
      return true;
    }());
  }

  notifyRead() {
    assert(_debugDisposed == ListenerStatus.active);
    if (FloopController.isListening) {
      FloopController.registerListenerRead(this);
      // if (_id == null) {
      //   _id = FloopController.createSubscriptionId(this);
      // } else {
      //   FloopController.registerIdRead(id);
      // }
    }
  }

  notifyMutation() {
    assert(_debugDisposed == ListenerStatus.active);
    // FloopController.updateSubscribedElements(_id);
    _elements.forEach(FloopController.markElementAsNeedsBuild);
  }
}
