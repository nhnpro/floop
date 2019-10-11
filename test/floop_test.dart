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

// ignore_for_file: invalid_use_of_protected_member

class MockObservedListener extends Mock implements ObservedListener {
  Set<ObservedNotifier> notifiers;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) =>
      super.toString();
}

void subscribeKeyToListener(
    ObservedMap observed, Object key, ObservedListener element) {
  ObservedController.startListening(element);
  // observed[key] ??= UniqueKey();
  observed[key];
  ObservedController.stopListening();
}

void main() {
  ObservedMap observedMap;

  setUp(() {
    ObservedController.debugReset();
    assert(ObservedController.debugSubscribedListenersCount == 0);
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

  group('ObservedController tests', () {
    test('listener key subscriptions, mutiple keys', () {
      var listener = MockObservedListener();
      ObservedController.startListening(listener);
      expect(ObservedController.debugSubscribedListenersCount, 0);
      expect(ObservedController.isListening, true);

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
      // that notify changes.
      observedMap['tasks'][0]['title'];
      expect(ObservedController.debugSubscribedListenersCount, 0);
      expect(ObservedController.activeListener, equals(listener));

      ObservedController.stopListening();
      expect(ObservedController.debugSubscribedListenersCount, 1);
      expect(ObservedController.debugContainsListener(listener), true);
    });

    test(
        '`[]=` operators alerts ObservedListener', //when key is not in the ObservedMap
        () {
      var listener = MockObservedListener();
      subscribeKeyToListener(observedMap, 'boo', listener);
      expect(ObservedController.debugContainsListener(listener), true);
      observedMap['boo'] = [1, 2, 3];
      verify(listener.onObservedChange(any)).called(1);
    });

    test('only keys read during the last listening cycle should be subscribed',
        () {
      var listener = MockObservedListener();
      subscribeKeyToListener(observedMap, 'boo', listener);
      subscribeKeyToListener(
          observedMap, 'faz', listener); // should forget 'boo'
      observedMap['boo'] = 123;
      verifyNever(listener.onObservedChange(any));

      observedMap['faz'] = 'salsa';
      verify(listener.onObservedChange(any)).called(greaterThan(0));
    });

    test('set value when multiple listeners are subscribed', () {
      var listener = MockObservedListener();
      subscribeKeyToListener(observedMap, 'tennis', listener);
      var listener2 = MockObservedListener();
      subscribeKeyToListener(observedMap, 'tennis', listener2);
      expect(ObservedController.debugSubscribedListenersCount, 2);

      // set operation updates both elements
      observedMap['tennis'] = 'match point';
      verify(listener.onObservedChange(any)).called(greaterThan(0));
      verify(listener2.onObservedChange(any)).called(greaterThan(0));
    });

    test('unsubscribing listeners', () {
      var listener = MockObservedListener();
      subscribeKeyToListener(observedMap, 'tennis', listener);
      var listener2 = MockObservedListener();
      subscribeKeyToListener(observedMap, 'tennis', listener2);
      expect(observedMap.length, 1);
      expect(ObservedController.debugContainsListener(listener), true);
      expect(ObservedController.debugContainsListener(listener2), true);
      // expect(observedMap.keySubscriptions['tennis'], unorderedEquals([listener, listener2]));

      ObservedController.unsubscribeListener(listener);
      expect(ObservedController.debugContainsListener(listener), false);
      // expect(observedMap.keySubscriptions['tennis'], isNot(contains(listener)));

      ObservedController.unsubscribeListener(listener2);
      expect(ObservedController.debugContainsListener(listener2), false);
      // expect(observedMap.keySubscriptions, hasLength(0));
      // expect(observedMap.elementSubscriptions, hasLength(0));
    });
  });
}
