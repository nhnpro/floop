import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:flutter/widgets.dart';

import 'package:floop/floop.dart';
import 'package:floop/src/controller.dart';


typedef MapCreator = Map Function();

typedef BenchmarkFunction = void Function(Map);

class MockElement extends Object implements Element {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) => super.toString();

  @override
  noSuchMethod(Invocation invocation) {}
}

void doNothing([v]) {}


double benchmarkFunction(f, [messagePrefix='Function']) {
  var avgTime = BenchmarkBase.measureFor(f, 2000);
  print('$messagePrefix average time: $avgTime us');
  return avgTime;
}

addObservedSubscriptions(ObservedMap observed, [int numberOfKeys=10]) {
  warmUpController(100, observed, observed.keys.toList().sublist(0, 10));
}

void warmUpController(int numberOfElements, [ObservedMap readMap, Iterable keys]) {
  floopController.reset();
  readMap = readMap!=null ? readMap : ObservedMap.of(createMapWithValues(3)); 
  keys = keys!=null ? keys : readMap.keys;
  // print('warm up keys: ${observedMap.keys.length} $_');
  // StatelessWidget widget = LightWidgetFloop(() => plainRead());
  for(int i=0; i<numberOfElements; i++) {
    floopController.startListening(MockElement());
    plainRead(readMap, keys);
    floopController.stopListening();
  }
  // print('warm up subscription: ${(store as ObservedMap).keySubscriptions.length}');
}

String keyFuncion(int i) => 'field$i';
String valueFuncion(int i) => 'insertion number $i';

createMapWithValues(int numberOfValues, [indexToKey=keyFuncion, indexToValue=valueFuncion]) {
  var map = Map();
  for(var i = 0; i < numberOfValues; i++) {
    map['field$i'] = 'insertion number $i';
  }
  return map;
}

plainRead(Map data, Iterable keys) {
  for(var k in keys) data[k];
}
