import './flutter_import.dart';
import './observed.dart';

/// Class with the core static methods that listen reads and updates
/// Elements when value changes are notified by an [ObservedListener].
abstract class FloopController {
  /// Element corresponding to widget on build.
  static Element _currentBuild;

  /// [BuildContext] of the ongoing [build].
  static Element get currentBuild => _currentBuild;

  /// Returns true if this controller is on listening mode.
  static bool get isListening => _currentBuild != null;

  /// The count of Elements (Widgets) subscribed to the controller.
  static int get length => _elementToIds.length;

  static bool contains(Element element) => _elementToIds.containsKey(element);

  static int _lastId = 0;
  static bool _postFrameUpdates = false;

  static void startListening(Element element) {
    if (isListening) {
      stopListening();
      // The controller already listening should assert to false, but it's
      // annoying when developing, as it triggers all the time when the builds
      // get interrupted by some error.
      // assert(false);
    }
    _currentBuild = element;
  }

  static void stopListening() {
    assert(_currentBuild != null);
    _commitObservedReads();
    _currentBuild = null;
  }

  static void enablePostFrameUpdatesMode() {
    assert(!_postFrameUpdates);
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
    _elementToIds.keys.toList().forEach(unsubscribeElement);
    assert(_idToElements.isEmpty);
    assert(_idToListener.isEmpty);
    assert(_elementToIds.isEmpty);
  }

  static Object _debugLastKeyChange;
  static Element _debugUnmounting;

  static debugUnmounting(Element element) => _debugUnmounting = element;
  static debugfinishUnmounting() => _debugUnmounting = null;

  static final Map<int, ObservedListener> _idToListener = Map();
  static final Map<int, Set<Element>> _idToElements = Map();
  static final Map<Element, Set<int>> _elementToIds = Map();

  static Set<int> _currentIds = Set();

  /// Returns a cannonical id used by [FloopController] to subscribe [Element]
  /// instances.
  static int createSubscriptionId(ObservedListener listener) {
    assert(isListening);
    int id = _lastId++;
    _currentIds.add(id);
    // The current element is not added to the Set yet in case there is an
    // error during the build.
    _idToElements[id] = Set();
    _idToListener[id] = listener;
    return id;
  }

  static void _commitObservedReads() {
    final element = _currentBuild;
    var previousIds = _elementToIds[element];
    // If element isn't registered yet, it is registered and associated with
    // all current read ids.
    if (previousIds == null) {
      if (_currentIds.isEmpty) {
        return;
      }
      previousIds = Set();
    }
    // Most element rebuilds should read the same keys, a quick is done to
    // handle that case.
    // Not sure how [Set.containsAll] is implemented, but there is a potential
    // performance gain, by using a cummulative hash for fast Set comparison.
    // This would imply losing a one hundred percent consistency (very rare
    // collision case), but certainly worth it for a performance gain.
    // Most of the time the same Map keys are accesed when rebuilding widgets,
    // so if Set have the same length and same cummulative hash, a 99.9999%
    // of the time they will have the same ids stored.
    if (_currentIds.length == previousIds.length &&
        previousIds.containsAll(_currentIds)) {
      _currentIds.clear();
      return;
    }

    // Associate new ids to the element.
    for (var id in _currentIds) {
      if (!previousIds.remove(id)) {
        _idToElements[id].add(element);
      }
    }
    // Unregister element from unread ids (previousIds - currentIds).
    for (var id in previousIds) {
      _unregisterElementFromId(element, id);
    }
    _elementToIds[element] = _currentIds;
    _currentIds = previousIds..clear();
  }

  static void registerIdRead(id) {
    _currentIds.add(id);
  }

  static void _unregisterElementFromId(Element element, int id) {
    final elementSet = _idToElements[id];
    assert(elementSet.contains(element));
    elementSet.remove(element);
    // If elementSet is empty, the id is not going to be used again, therefore
    // it is disposed.
    if (elementSet.isEmpty) {
      _idToElements.remove(id);
      _idToListener.remove(id)._disposeId();
    }
  }

  // static void _unregisterElementFromId(Element element, int id) {
  //   if(_idToListener[id]._unregisterElement(element)) {
  //     _idToListener.remove(id);
  //   };
  // }

  static void unsubscribeElement(Element element) {
    _elementToIds
        .remove(element)
        ?.forEach((id) => _unregisterElementFromId(element, id));
  }

  static void _forgetId(int id) {
    assert(_idToElements.containsKey(id));
    assert(_idToListener.containsKey(id));
    for (var element in _idToElements.remove(id)) {
      assert(_elementToIds.containsKey(id));
      _elementToIds[element].remove(id);
    }
    _idToListener.remove(id)._disposeId();
  }

  static final Set<int> _posponedIdsToUpdate = Set();

  static void _posponedUpdatesCallback([_]) {
    assert(_posponedIdsToUpdate.isNotEmpty);
    _posponedIdsToUpdate
      ..forEach(_markElementsAsNeedBuild)
      ..clear();
  }

  static void _posponeMarkAsNeedBuild(int id) {
    if (_posponedIdsToUpdate.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(_posponedUpdatesCallback);
    }
    _posponedIdsToUpdate.add(id);
  }

  static void _markElementsAsNeedBuild(int id) {
    if (_postFrameUpdates) {
      _posponeMarkAsNeedBuild(id);
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
      var ele;
      try {
        final elements = _idToElements[id];
        if (elements != null) {
          for (ele in elements) {
            ele.markNeedsBuild();
          }
        }
      } catch (e) {
        print('Error: FloopController is invoking markNeedsBuild on $ele when '
            'it\'s not allowed or on an invalid Element. This is most likely '
            'due to initContext or disposeContext methods writing values to '
            'an ObservedMap instance.');
      }
      return true;
    }());
    _idToElements[id]?.forEach((element) => element.markNeedsBuild());
  }
}

enum ListenerStatus {
  active,
  defunct,
}

abstract class Observed {
  notifyRead();
  notifyMutation();
}

/// This mixin provides the functionality to connect [Observed] with
/// [FloopController]. Mixed in by [ObservedMap] and [ObservedValue].
mixin ObservedListener {
  int _id;

  _disposeId() {
    _id = null;
  }

  var _debugDisposed = ListenerStatus.active;

  forgetAllSubscriptions() {
    FloopController._forgetId(_id);
  }

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
      if (_id == null) {
        _id = FloopController.createSubscriptionId(this);
      } else {
        FloopController.registerIdRead(_id);
      }
    }
  }

  notifyMutation() {
    assert(_debugDisposed == ListenerStatus.active);
    FloopController._markElementsAsNeedBuild(_id);
    // _elements.forEach(FloopController.markElementAsNeedsBuild);
  }
}
