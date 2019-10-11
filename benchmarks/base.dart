import 'dart:math';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:flutter/widgets.dart';

import 'package:floop/floop.dart';
import 'package:floop/src/controller.dart';

typedef MapCreator = Map Function();

typedef BenchmarkFunction = void Function(Map);

class MockListener with FastHashCode, ObservedListener {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) =>
      super.toString();

  @override
  noSuchMethod(Invocation invocation) {}
}

void doNothing([v]) {}

double benchmarkFunction(f,
    [messagePrefix = 'Function',
    int minumumMillis = 2000,
    int invocationsCount = 10]) {
  fManyTimes() {
    for (int i = 0; i < invocationsCount; i++) {
      f();
    }
  }

  var avgTime = BenchmarkBase.measureFor(fManyTimes, minumumMillis);
  print('$messagePrefix average time: $avgTime us');
  return avgTime;
}

addObservedSubscriptions(ObservedMap observed, [int numberOfKeys = 10]) {
  numberOfKeys =
      numberOfKeys > observed.length ? observed.length : numberOfKeys;
  warmUpController(
      100, observed, observed.keys.toList().sublist(0, numberOfKeys));
}

void warmUpController(int numberOfElements,
    [ObservedMap readMap, Iterable keys]) {
  assert(() {
    ObservedController.debugReset();
    return true;
  }());
  readMap = readMap != null ? readMap : ObservedMap.of(createMapWithValues(3));
  keys = keys != null ? keys : readMap.keys;
  for (int i = 0; i < numberOfElements; i++) {
    ObservedController.startListening(MockListener());
    plainRead(readMap, keys);
    ObservedController.stopListening();
  }
  assert(() {
    if (ObservedController.debugSubscribedListenersCount != numberOfElements &&
        keys.isNotEmpty) {
      print('Inconsistency: ${ObservedController} elements is\n'
          '${ObservedController.debugSubscribedListenersCount} but should be $numberOfElements.\n');
      return false;
    }
    return true;
  }());
}

// String keyFuncion(int i) => 'field$i';
// String valueFuncion(int i) => 'insertion number $i';
int keyFuncion(int i) => i; //'field$i';
int valueFuncion(int i) => i; //'insertion number $i';

createMapWithValues(int numberOfValues,
    [indexToKey = keyFuncion, indexToValue = valueFuncion]) {
  var map = Map();
  var numbers = randomIntList(numberOfValues);
  for (var i in numbers) {
    map[indexToKey(i)] = indexToValue(i);
  }
  return map;
}

Iterable randomIntList(length) {
  Random random = Random();
  int maxInt = length * 100;
  Set<int> result = Set();
  while (result.length < length) {
    result.add(random.nextInt(maxInt));
  }
  return result;
}

plainRead(Map data, Iterable keys) {
  for (var k in keys) {
    data[k];
  }
}

createValueReader(Map map, [int numberOfReads]) {
  numberOfReads ??= map.length;
  var keys = map.keys.toList().sublist(0, numberOfReads);
  return () {
    for (var k in keys) {
      map[k];
    }
  };
}
