library floop;

export 'package:floop/src/observed.dart' show floop, ObservedController, ObservedMap;
export 'package:floop/src/mixins.dart' show Floop, FloopState;

// import 'package:flutter/cupertino.dart';
// import 'package:flutter/foundation.dart';
// import 'package:meta/meta.dart';
// import 'package:flutter/material.dart';

// @visibleForTesting
// final FloopController controller = FloopController();

// final ObservedMap floop = ObservedMap();

// void noop() {}

// class FloopController {
//   Element _currentBuild;
//   Set<Observed> _currentBuildSubscriptions;
//   Map<Element, Set<Observed>> _subscriptions = {};

//   Element get currentBuild => _currentBuild;

//   @visibleForTesting
//   Set<Observed> get currentBuildSubscriptions => _currentBuildSubscriptions;
//   @visibleForTesting
//   Map<Element, Set<Observed>> get subscriptions => _subscriptions;

//   void startListening(e) {
//     assert(() {
//       if(currentBuild != null) {
//         stopListening();
//         subscriptions.keys.forEach((e) => controller.unsubscribeFromAll(e));
//         return false;
//       }
//       return true;
//     }());
//     assert(currentBuildSubscriptions == null);
//     unsubscribeFromAll(e);
//     _currentBuild = e;
//     _currentBuildSubscriptions = Set<Observed>();
//     print('Start building $currentBuild');
//   }

//   void stopListening() {
//     assert(currentBuild != null);
//     assert(currentBuildSubscriptions != null);
//     print('Finished building $currentBuild with subscribed maps $currentBuildSubscriptions');
//     _subscriptions[currentBuild] = currentBuildSubscriptions;
//     _currentBuild = null;
//     _currentBuildSubscriptions = null;
//     print('Subscribed elements ${_subscriptions.keys}');
//   }

//   void updateElements(Set elements) {
//     if(_currentBuild!=null) {
//       throw StateError('A floop widget is building while setting a value in floop, this is not allowed (infinite build recursion)');
//     } else {
//       elements?.forEach((obj) {
//         assert(obj is Element || obj is State);
//         if(obj is Element) obj.markNeedsBuild();
//         else obj.setState(noop);
//       });
//     }
//   }

//   void unsubscribeFromAll(Element element) {
//     assert(element != null);
//     if(_subscriptions[element] != null) {
//       _subscriptions[element].forEach((observed) => observed.unsubscribeElement(element));
//     }
//     _subscriptions.remove(element);
//   }

//   void subscribeObserved(Observed observed) {
//     assert(currentBuild!=null);
//     _currentBuildSubscriptions.add(observed);
//   }

//   // Element forgetIfNoAncestor(Element e) {
//   //   Element parent;
//   //   bool visit(Element p) {
//   //     parent = p;
//   //     return false;
//   //   }
//   //   e.visitAncestorElements(visit);
//   //   return parent;
//   // }
// }
  
// abstract class Observed {
//   @visibleForTesting
//   Map<dynamic, Set<Element>> get keySubscriptions => Map();
//   @visibleForTesting
//   Map<Element, Set> get elementSubscriptions;

//   void subscribeKeyIfListening(Object key);
//   void unsubscribeElement(Element element);
// }
    
// class ObservedMap extends Observed {

//   Map<String, dynamic> _keyToValue = Map();
//   Map<String, Set<Element>> _keySubscriptions = Map();
//   Map<Element, Set> _elementSubscriptions = Map();

//   get keySubscriptions => _keySubscriptions;
//   get elementSubscriptions => _elementSubscriptions;

//   ObservedMap();

//   ObservedMap.of(Map map) {
//     addAll(map);
//   }

//   _subscribeKeyToElement(key, element) {
//     var keySubs = keySubscriptions.putIfAbsent(key, () => Set<Element>());
//     var eleSubs = elementSubscriptions.putIfAbsent(element, () => Set<String>());
//     keySubs.add(element);
//     eleSubs.add(key);
//   }

//   subscribeKeyIfListening(key) {
//     Element ele = controller.currentBuild;
//     if(ele != null) {
//       controller.subscribeObserved(this);
//       _subscribeKeyToElement(key, ele);
//     }
//   }

//   void unsubscribeElement(Element element) {
//     assert(elementSubscriptions[element] != null);
//     elementSubscriptions[element].forEach((key) {
//       assert(keySubscriptions[key] != null);
//       keySubscriptions[key].remove(element);
//       // clean map in case key has no more subscriptions
//       if(keySubscriptions[key].isEmpty) {
//         keySubscriptions.remove(key);
//       }
//     });
//     elementSubscriptions.remove(element);
//   }

//   convert(value) {
//     var res = value;
//     if(value is Map) {
//       res = ObservedMap.of(value);
//     } else if (value is List) {
//       res = value.map((v) => convert(v)).toList();
//     }
//     return res;
//   }

//   void add(key, value) {
//     _keyToValue[key] = convert(value);
//   }

//   void addAll(Map map) {
//     map.forEach((key, value) => add(key, value));
//   }

//   operator [](k) {
//     print('Get $k while building ${controller.currentBuild}');
//     subscribeKeyIfListening(k);
//     return _keyToValue[k];
//   }

//   operator []=(k, v) {
//     print('Setting \'$k\'');
//     controller.updateElements(keySubscriptions[k]);
//     add(k, v);
//   }
// }
