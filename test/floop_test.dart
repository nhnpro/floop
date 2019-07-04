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

void subscribeKeyToElement(ObservedMap observed, key, element) {
  floopController.startListening(element);
  observed[key];
  floopController.stopListening();
}


void main() {

  ObservedMap observedMap;

  setUp(() {
    floopController.subscriptions.clear();
    assert(floopController.currentBuildSubscriptions==null);
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
      expect(floopController.subscriptions, isEmpty);
      expect(floopController.currentBuildSubscriptions, isEmpty);

      expect(() => observedMap['boo'] = 123, throwsStateError);
      observedMap['boo'];
      observedMap['tennis'];
      // There are three reads in next statement, observedMap['tasks'], [0] and ['title].
      // However observedMap['tasks'] is a [List], and Lists are copied as [UnmodifiableList]
      // internally by observadMap (see ObservadMap.convert for details), which are of course
      // not Observed (there is no point in observing a structure that cannot change).
      // Only observedMap and observedMap['tasks'][0] are the observed
      observedMap['tasks'][0]['title'];
      expect(floopController.subscriptions, isEmpty);
      expect(floopController.currentBuild, equals(mockEle));
      expect(floopController.currentBuildSubscriptions, hasLength(2));
      expect(observedMap.keySubscriptions, hasLength(3));
      expect(observedMap['tasks'][0].keySubscriptions, hasLength(1));

      floopController.stopListening();
      expect(floopController.subscriptions, hasLength(1));
      expect(floopController.subscriptions, contains(mockEle));
      expect(floopController.subscriptions[mockEle], unorderedEquals([observedMap, observedMap['tasks'][0]]));
    });

    test('set value calls markNeedsBuild on Elements', () {
      var mockEle = MockElement();
      subscribeKeyToElement(observedMap, 'boo', mockEle);
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
      expect(floopController.subscriptions, hasLength(2));

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
      expect(floopController.subscriptions[mockEle], unorderedEquals([observedMap]));
      expect(observedMap.keySubscriptions, hasLength(1));
      expect(observedMap.keySubscriptions['tennis'], unorderedEquals([mockEle, mockEle2]));

      floopController.unsubscribeFromAll(mockEle);
      expect(floopController.subscriptions[mockEle], isNull);
      expect(observedMap.keySubscriptions['tennis'], isNot(contains(mockEle)));

      floopController.unsubscribeFromAll(mockEle2);
      expect(floopController.subscriptions[mockEle2], isNull);
      expect(observedMap.keySubscriptions, hasLength(0));
      expect(observedMap.elementSubscriptions, hasLength(0));
    });
  });
}
