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
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) =>
      super.toString();
}

void subscribeKeyToElement(ObservedMap observed, Object key, Element element) {
  FloopController.startListening(element);
  observed[key];
  FloopController.stopListening();
}

void main() {
  ObservedMap observedMap;

  setUp(() {
    FloopController.reset();
    assert(FloopController.length == 0);
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
      FloopController.startListening(mockEle);
      expect(FloopController.length, 0);
      expect(FloopController.isListening, true);

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
      expect(FloopController.length, 0);
      expect(FloopController.currentBuild, equals(mockEle));
      // expect(observedMap['tasks'][0].keySubscriptions, hasLength(1));

      FloopController.stopListening();
      expect(FloopController.length, 1);
      expect(FloopController.contains(mockEle), true);
      // expect((FloopController as FloopController).subscriptions[mockEle].length,
      //     2);
    });

    test('`[]=` calls updates Element when key is not in the ObservedMap', () {
      var mockEle = MockElement();
      subscribeKeyToElement(observedMap, 'boo', mockEle);
      expect(FloopController.contains(mockEle), true);
      observedMap['boo'] = [1, 2, 3];
      verify(mockEle.markNeedsBuild()).called(greaterThan(0));
    });

    test('only keys read during the last listening cycle should be subscribed',
        () {
      var mockEle = MockElement();
      subscribeKeyToElement(observedMap, 'boo', mockEle);
      subscribeKeyToElement(observedMap, 'faz', mockEle); // should forget 'boo'
      observedMap['boo'] = 123;
      verifyNever(mockEle.markNeedsBuild());

      observedMap['faz'] = 'salsa';
      verify(mockEle.markNeedsBuild()).called(greaterThan(0));
    });

    test('set value when multiple elements are subscribed', () {
      var mockEle = MockElement();
      subscribeKeyToElement(observedMap, 'tennis', mockEle);
      var mockEle2 = MockElement();
      subscribeKeyToElement(observedMap, 'tennis', mockEle2);
      expect(FloopController.length, 2);

      // set operation updates both elements
      observedMap['tennis'] = 'match point';
      verify(mockEle.markNeedsBuild()).called(greaterThan(0));
      verify(mockEle2.markNeedsBuild()).called(greaterThan(0));
    });

    test('unsubscribing elements', () {
      var mockEle = MockElement();
      subscribeKeyToElement(observedMap, 'tennis', mockEle);
      var mockEle2 = MockElement();
      subscribeKeyToElement(observedMap, 'tennis', mockEle2);
      expect(FloopController.contains(mockEle), true);
      expect(FloopController.contains(mockEle2), true);
      expect(observedMap.length, 1);
      // expect(observedMap.keySubscriptions['tennis'], unorderedEquals([mockEle, mockEle2]));

      FloopController.unsubscribeElement(mockEle);
      expect(FloopController.contains(mockEle), false);
      // expect(observedMap.keySubscriptions['tennis'], isNot(contains(mockEle)));

      FloopController.unsubscribeElement(mockEle2);
      expect(FloopController.contains(mockEle2), false);
      // expect(observedMap.keySubscriptions, hasLength(0));
      // expect(observedMap.elementSubscriptions, hasLength(0));
    });
  });
}
