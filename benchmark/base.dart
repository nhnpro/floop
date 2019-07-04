import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:flutter/widgets.dart';
import 'package:mockito/mockito.dart';

import 'package:floop/floop.dart';
import 'package:floop/src/controller.dart';


class MockElement extends Mock implements Element {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) => super.toString();
}

double benchmarkFunction(f, [messagePrefix='Function']) {
  var avgTime = BenchmarkBase.measureFor(f, 2000);
  print('$messagePrefix average time: $avgTime us');
  return avgTime;
}

addObservedSubscriptions(ObservedMap observed, [int n=100]) {

}

void warmUpController(int n) {
  floopController.subscriptions.keys.toList().forEach((e) => floopController.unsubscribeFromAll(e));
  store = ObservedMap.of(createMapWithValues(3));
  print('warm up keys: ${store.keys.length} $_');
  StatelessWidget widget = LightWidgetFloop(() => plainRead());
  for(int i=0; i<100; i++) {
    widget.build(MockElement());
  }
  // print('warm up subscription: ${(store as ObservedMap).keySubscriptions.length}');
}

createMapWithValues(int n) {
  var map = Map();
  for(var i = 0; i < n; i++) {
    map['field$i'] = 'insertion number $i';
  }
  return map;
}
