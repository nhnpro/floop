import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:floop/floop.dart';
import 'package:floop/src/controller.dart';

const tasks = [
  {'id': 1, 'title': 'My First', 'steps': 0},
  {'id': 2, 'title': 'My Second', 'steps': 0},
  {'id': 3, 'title': 'My Third', 'steps': 0},
];

class MockElement extends Mock implements Element {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) => super.toString();
}

void subscribeKeyToElement(ObservedMap observed, Object key, Element element) {
  floopController.startListening(element);
  observed[key];
  floopController.stopListening();
}

void main() {

  ObservedMap observedMap;

  setUp(() {
    floopController.reset();
    assert(floopController.length==0);
    observedMap = ObservedMap();
    observedMap.addAll({'tasks': tasks});
  });

  group('ObservedMap tests', () {
    test('get operations', () {
      expect(observedMap['tasks'].hashCode, isNot(equals(tasks.hashCode)));
      expect(observedMap['tasks'], equals(tasks));
      expect(observedMap['tasks'][0]['id'], equals(1));
      expect(observedMap['tasks'], isList);
      expect(observedMap['tasks'][1], isInstanceOf<ObservedMap>());
    });

    test('set operations', () {
      observedMap['foo'] = 'bar';
      expect(observedMap['foo'], equals('bar'));

      var oldTasks = observedMap['tasks'];
      observedMap['tasks'] = tasks;
      expect(observedMap['tasks'].hashCode, isNot(equals(oldTasks.hashCode)));
      expect(observedMap['tasks'], equals(oldTasks));

      observedMap['tasks'][0]['id'] = 'one';
      expect(observedMap['tasks'][0]['id'], equals('one'));
    });
  });

  group('FloopController tests', () {
    test('listener key subscriptions, mutiple keys', () {
      var mockEle = MockElement();
      floopController.startListening(mockEle);
      expect(floopController.length, 0);
      expect(floopController.listening, true);

      // Set value of 'boo'. Because there are no key subscriptions, this
      // is not a problem.
      expect(() => observedMap['boo'] = 123, isNot(throwsAssertionError));
      observedMap['boo'];
      observedMap['tennis'];
      // There are three reads in next statement, observedMap['tasks'], [0] and ['title].
      // ObservedMap['tasks'] is a [List], and Lists are copied as [UnmodifiableList]
      // internally by observadMap (see ObservadMap.convert for details), which are
      // not Observed.
      // Only observedMap and observedMap['tasks'][0] are [Observed] datastructures
      // that are listened.
      observedMap['tasks'][0]['title'];
      expect(floopController.length, 0);
      expect(floopController.currentBuild, equals(mockEle));
      // expect(observedMap['tasks'][0].keySubscriptions, hasLength(1));

      floopController.stopListening();
      expect(floopController.length, 1);
      expect(floopController.contains(mockEle), true);
      expect((floopController as FullController).subscriptions[mockEle].length, 2);
    });

    test('set value calls updates Element when key is not in ObservedMap', () {
      var mockEle = MockElement();
      subscribeKeyToElement(observedMap, 'boo', mockEle);
      expect(floopController.contains(mockEle), true);

      // ObservedListener listener = (floopController as FullController).subscriptions[mockEle].first;
      // expect(listener.keyToElements.containsKey('boo'), true);
      observedMap['boo'] = [1, 2, 3];
      verify(mockEle.markNeedsBuild()).called(1);
    });

    test('only read keys during the last listening cycle should be subscribed', () {
      var mockEle = MockElement();
      subscribeKeyToElement(observedMap, 'boo', mockEle);
      subscribeKeyToElement(observedMap, 'faz', mockEle); // should forget 'boo'
      observedMap['boo'] = 123;
      verifyNever(mockEle.markNeedsBuild());

      observedMap['faz'] = 'salsa';
      verify(mockEle.markNeedsBuild()).called(1);
    });

    test('set value when multiple elements subscribed', () {
      var mockEle = MockElement();
      subscribeKeyToElement(observedMap, 'tennis', mockEle);
      var mockEle2 = MockElement();
      subscribeKeyToElement(observedMap, 'tennis', mockEle2);
      expect(floopController.length, 2);

      // set operation updates both elements
      observedMap['tennis'] = 'match point';      
      verify(mockEle.markNeedsBuild()).called(1);
      verify(mockEle2.markNeedsBuild()).called(1);
    });

    test('unsubscribing elements', () {
      var mockEle = MockElement();
      subscribeKeyToElement(observedMap, 'tennis', mockEle);
      var mockEle2 = MockElement();
      subscribeKeyToElement(observedMap, 'tennis', mockEle2);
      expect(floopController.contains(mockEle), true);
      expect(floopController.contains(mockEle2), true);
      expect(observedMap.length, 1);
      // expect(observedMap.keySubscriptions['tennis'], unorderedEquals([mockEle, mockEle2]));

      unsubscribeElement(mockEle);
      expect(floopController.contains(mockEle), false);
      // expect(observedMap.keySubscriptions['tennis'], isNot(contains(mockEle)));

      unsubscribeElement(mockEle2);
      expect(floopController.contains(mockEle2), false);
      // expect(observedMap.keySubscriptions, hasLength(0));
      // expect(observedMap.elementSubscriptions, hasLength(0));
    });
  });
}
