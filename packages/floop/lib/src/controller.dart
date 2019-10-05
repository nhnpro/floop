import './flutter_import.dart';

/// Class with the core static methods that listen reads and updates
/// Elements when value changes are notified by an [FloopListener].
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
    // _commitObservedReads();
    _commitSubscriptions();
    assert(_currentIds.isEmpty);
    _currentBuild = null;
  }

  static void enablePostFrameUpdatesMode() {
    _postFrameUpdates = true;
  }

  static void disablePostFrameUpdatesMode() {
    assert(_postFrameUpdates);
    _postFrameUpdates = false;
  }

  /// Unsubscribes all Elements (Widgets) from the registered Observeds.
  static void reset() {
    assert(!isListening);
    _elementToIds.keys.toList().forEach(unsubscribeElement);
    assert(_elementToIds.isEmpty);
  }

  static Object _debugLastKeyChange;
  static Element _debugUnmounting;

  static debugUnmounting(Element element) => _debugUnmounting = element;
  static debugfinishUnmounting() => _debugUnmounting = null;

  static debugLastKeyChange(Object key) => _debugLastKeyChange = key;

  // An id is used as intermediate between the Subscriber and Element, because
  // there is a huge performance drop when using a map that connects them
  // directly. I pressume this has to do with Set<int> being much faster than
  // Set<Object>, specially when the ints are dense. Or maybe it's bug.
  static final Map<int, ElementSubscriber> _idToSubscriber = Map();
  static final Map<Element, Set<int>> _elementToIds = Map();

  static Set<int> _currentIds = Set();

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
        // _idToElements[id].add(element);
      }
    }
    // Unregister element from unread ids (previousIds - currentIds).
    for (var id in previousIds) {
      // _unregisterElementFromId(element, id);
    }
    _elementToIds[element] = _currentIds;
    _currentIds = previousIds..clear();
  }

  static void registerIdRead(id) {
    _currentIds.add(id);
  }

  // static void _unregisterElementFromId(Element element, int id) {
  //   final elementSet = _idToElements[id];
  //   assert(elementSet.contains(element));
  //   elementSet.remove(element);
  //   // If elementSet is empty, the id is not going to be used again, therefore
  //   // it is disposed.
  //   if (elementSet.isEmpty) {
  //     _idToListener.remove(id).disposeId(id);
  //     _idToElements.remove(id);
  //   }
  // }

  /// The elements are not added together a Set, because the iterables might
  /// might change after the frame finishes updating. Some elements might have
  /// unmounted.
  static final Set<Iterable<Element>> _elementsToUpdate = Set();

  static void _posposeUpdatesCallback([_]) {
    assert(_elementsToUpdate.isNotEmpty);
    _elementsToUpdate
      ..forEach(updateElements)
      ..clear();
  }

  static void _posponeUpdates(Iterable<Element> elements) {
    if (_elementsToUpdate.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(_posposeUpdatesCallback);
    }
    _elementsToUpdate.add(elements);
  }

  // static void markElementsAsNeedBuild(int id) {
  //   if (_postFrameUpdates) {
  //     posponeMarkAsNeedBuild(id);
  //     return;
  //   }
  //   assert(() {
  //     if (isListening) {
  //       print('Error: Floop widget `${currentBuild.widget}` is building while '
  //           'setting value of key `$_debugLastKeyChange` in an '
  //           '[ObservedMap]. Avoid writing to an [ObservedMap] while '
  //           'bulding Widgets.');
  //       assert(false);
  //     }
  //     if (_debugUnmounting != null) {
  //       print('Error: Element $_debugUnmounting of Floop widget '
  //           '${_debugUnmounting.widget} is unmounting while attempting to '
  //           'mark an [Element] as need build. This happens due to the '
  //           'widget\'s [Floop.onContextUnmount] method changing or removing '
  //           'the value of an [ObservadMap] that is read by other widgets.');
  //       assert(false);
  //     }
  //     return true;
  //   }());
  //   assert(() {
  //     var ele;
  //     try {
  //       final elements = _idToElements[id];
  //       if (elements != null) {
  //         for (ele in elements) {
  //           ele.markNeedsBuild();
  //         }
  //       }
  //     } catch (e) {
  //       print('Error: FloopController is invoking markNeedsBuild on $ele when '
  //           'it\'s not allowed or on an invalid Element. This is most likely '
  //           'due to initContext or disposeContext methods writing values to '
  //           'an ObservedMap instance.');
  //     }
  //     return true;
  //   }());
  //   _idToElements[id]?.forEach((element) => element.markNeedsBuild());
  // }

  static void register(ElementSubscriber subscriber) {
    int id = subscriber.subscriptionId;
    if (id == null) {
      id = _lastId++;
      subscriber.subscriptionId = id;
      subscriber.elements ??= Set();
      _idToSubscriber[id] = subscriber;
    }
    _currentIds.add(id);
  }

  static void updateElements(Iterable<Element> elements) {
    if (_postFrameUpdates) {
      _posponeUpdates(elements);
      return;
    }
    assert(_debugUnmounting == null);
    assert(() {
      if (isListening) {
        print('Error: Floop widget `${currentBuild.widget}` is building while '
            'setting value of an [ObservedMap] or [ObservedValue].');
        assert(false);
      }
      // if (_debugUnmounting != null) {
      //   print('Error: Element $_debugUnmounting of Floop widget '
      //       '${_debugUnmounting.widget} is unmounting while attempting to '
      //       'mark an [Element] as need build. This happens due to the '
      //       'widget\'s [Floop.onContextUnmount] method changing or removing '
      //       'the value of an [ObservadMap] that is read by other widgets.');
      //   assert(false);
      // }
      return true;
    }());
    // assert(() {
    //   var ele;
    //   try {
    //     if (elements != null) {
    //       for (ele in elements) {
    //         ele.markNeedsBuild();
    //       }
    //     }
    //   } catch (e) {
    //     print('Error: FloopController is invoking markNeedsBuild on $ele when '
    //         'it\'s not allowed or on an invalid Element. This is most likely '
    //         'due to initContext or disposeContext methods writing values to '
    //         'an ObservedMap instance.');
    //   }
    //   return true;
    // }());
    for (var element in elements) {
      element.markNeedsBuild();
    }
  }

  static void _commitSubscriptions() {
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
    else if (_currentIds.length == previousIds.length &&
        previousIds.containsAll(_currentIds)) {
      _currentIds.clear();
      return;
    }

    // Associate new ids to the element.
    for (var id in _currentIds) {
      if (!previousIds.remove(id)) {
        _idToSubscriber[id].elements.add(element);
      }
    }
    // Unregister element from unread ids (previousIds - currentIds).
    for (var id in previousIds) {
      _unsubscribeElement(element, id);
    }
    _elementToIds[element] = _currentIds;
    _currentIds = previousIds..clear();
  }

  static void _unsubscribeElement(Element element, int subscriptionId) {
    final subscriber = _idToSubscriber[subscriptionId];
    assert(subscriber.elements.contains(element));
    subscriber.elements.remove(element);
    if (subscriber.elements.isEmpty) {
      subscriber.subscriptionId = null;
      _idToSubscriber.remove(subscriptionId);
    }
  }

  // static void _updateKeepers() {
  //   final element = _currentBuild;
  //   var previousKeepers = _elementToKeepers[element];
  //   // If `element` isn't registered yet, it is registered and associated with
  //   // all current read listeners.
  //   if (previousKeepers == null) {
  //     // if (_currentKeepers.isNotEmpty) {
  //     //   _elementToKeepers[element] = _currentKeepers;
  //     //   for (var keeper in _currentKeepers) {
  //     //     keeper.elements.add(element);
  //     //   }
  //     //   _currentKeepers = Set();
  //     // }
  //     if (_currentKeepers.isEmpty) {
  //       return;
  //     }
  //     previousKeepers = Set();
  //   }
  //   // Most element rebuilds should read the same keys, a quick check is done
  //   // to handle that case.
  //   // Not sure how [Set.containsAll] is implemented, but there is a potential
  //   // performance gain, by using a cummulative hash for fast Set comparison.
  //   // This would imply losing a one hundred percent consistency (very rare
  //   // collision case), but certainly worth it for a performance gain.
  //   // Most of the time the same Map keys are accesed when rebuilding widgets,
  //   // so if a Set has the same length and same cummulative hash, a 99.9999%
  //   // of the time they will have the same objects stored.
  //   if (_currentKeepers.length == previousKeepers.length &&
  //       previousKeepers.containsAll(_currentKeepers)) {
  //     _currentKeepers.clear();
  //     return;
  //   }

  //   for (var keeper in _currentKeepers) {
  //     if (!previousKeepers.remove(keeper)) {
  //       keeper.register(element);
  //     }
  //   }
  //   // Unregister element from unread listeners (previousListeners - currentListeners).
  //   for (var keeper in previousKeepers) {
  //     keeper.unregister(element);
  //   }
  //   _elementToKeepers[element] = _currentKeepers;
  //   _currentKeepers = previousKeepers..clear();
  // }

  static void unsubscribeElement(Element element) {
    _elementToIds
        .remove(element)
        ?.forEach((id) => _unsubscribeElement(element, id));
  }

  static void forgetSubscriber(ElementSubscriber subscriber) {
    final id = subscriber.subscriptionId;
    subscriber.subscriptionId = null;
    _idToSubscriber.remove(id);
    for (var element in subscriber.elements) {
      _elementToIds[element].remove(id);
    }
    subscriber.elements.clear();
  }
}

mixin ElementSubscriber {
  @protected
  Set<Element> elements;

  @protected
  int subscriptionId;
}

enum ListenerStatus {
  active,
  defunct,
}

mixin FloopListener implements ElementSubscriber {
  var _debugStatus = ListenerStatus.active;

  Set<Element> elements;

  @protected
  int subscriptionId;

  void notifyRead() {
    assert(_debugStatus == ListenerStatus.active);
    if (FloopController.isListening) {
      FloopController.register(this);
    }
  }

  notifyChange() {
    assert(_debugStatus == ListenerStatus.active);
    if (elements != null && elements.isNotEmpty) {
      FloopController.updateElements(elements);
    }
  }

  forgetSubscriptions() {
    assert(_debugStatus == ListenerStatus.active);
    if (subscriptionId != null) {
      FloopController.forgetSubscriber(this);
    }
  }

  dispose() {
    assert(_debugStatus == ListenerStatus.active);
    forgetSubscriptions();
    assert(() {
      _debugStatus = ListenerStatus.defunct;
      return true;
    }());
  }
}

/// This mixin provides the functionality to connect [ObservedMap] with
/// [FloopController]. Mixed in by [ObservedMap].
// abstract class ObservedListener {
//   final Set<Element> _elements = Set();

//   List<Element> get subscribedElements => _elements.toList();

//   _registerElement(Element element) {
//     assert(_debugDisposed == ListenerStatus.active);
//     _elements.add(element);
//   }

//   _unregisterElement(Element element) {
//     assert(_debugDisposed == ListenerStatus.active);
//     _elements.remove(element);
//   }

//   forgetAllSubscriptions() {
//     assert(_debugDisposed == ListenerStatus.active);
//     // FloopController.forgetListener(this);
//   }

//   var _debugDisposed = ListenerStatus.active;

//   dispose() {
//     assert(_debugDisposed == ListenerStatus.active);
//     forgetAllSubscriptions();
//     assert(() {
//       _debugDisposed = ListenerStatus.defunct;
//       return true;
//     }());
//   }

// notifyRead() {
//   assert(_debugDisposed == ListenerStatus.active);
//   if (FloopController.isListening) {
//     FloopController.registerListenerRead(this);
//   }
// }

// notifyMutation() {
//   assert(_debugDisposed == ListenerStatus.active);
//   _elements.forEach(FloopController.markElementAsNeedsBuild);
// }
// }
