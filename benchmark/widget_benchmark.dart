import 'dart:math';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:floop/floop.dart';
import 'package:floop/src/controller.dart';
import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';

/// Benchmarks for the Widget build time.
/// 
/// Run benchmarks by entering 'flutter test .\benchmark\observed_benchamark.dart' in 
/// console, inside the root folder.

typedef MapCreator = Map Function();
typedef BenchmarkFunction = void Function(Map);

class MockElement extends Mock implements Element {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) => super.toString();
}

Map store;
MockElement mockEle = MockElement();

Function widgetCreatorReference;
Function widgetCreatorFloop;
String widgetName;

main() {
  
  widgetCreatorReference = () => LightWidget(plainRead);
  widgetCreatorFloop = () => LightWidgetFloop(plainRead);
  widgetName = 'LightWidget';
  print('Benchmarks for LightWidget');
  runBenchmarks();

  widgetCreatorReference = () => MediumWeightWidget(plainRead);
  widgetCreatorFloop = () => MediumWeightWidgetFloop(plainRead);
  widgetName = 'Scaffold';
  print('Benchmarks for ScaffoldWidget (heavier)');
  runBenchmarks();
}

void runBenchmarks() {
  widgetBuildBenchmark(1, 'Read 1 key');
  widgetBuildBenchmark(5, 'Read 5 keys');
  widgetBuildBenchmark(20, 'Read 20 keys');
  widgetBuildBenchmark(100, 'Read 100 keys (unrealistic)');
}

void widgetBuildBenchmark(int numberKeys, [String bencharkHeadLine='Running Benchmark']) {
  print('\n${bencharkHeadLine.toUpperCase()}\n');

  Map data = createMapWithValues(numberKeys);
  warmUpController(100);
    
  Function readOperation = plainRead;
  StatelessWidget widget;

  buildManyTimes() {
    for(int i=0; i<1000; i++) widget.build(mockEle);
  }
  
  print('Controller subscribed element count: ${controller.subscriptions.length}');
  
  store = Map.of(data);
  widget = LightWidget(readOperation);
  var refTime = benchmarkFunction(buildManyTimes, '$widgetName');

  store = ObservedMap.of(data);
  widget = LightWidgetFloop(readOperation);
  var floopTime = benchmarkFunction(buildManyTimes, '${widgetName}Floop');

  store = Map.of(createMapWithValues(numberKeys+2));
  benchmarkFunction(() {
    for(int i=0; i<1000; i++) plainRead();
    }, 'Read Map ${numberKeys+2}');

  store = ObservedMap.of(store);
  benchmarkFunction(() {
    for(int i=0; i<1000; i++) plainRead();
    }, 'Read ObservedMap ${numberKeys+2}');

  // store = ObservedMap.of(data);
  // floopTime = benchmarkFunction(() => plainRead(readMap, readMap.keys), 'ObservadMap');

  // print('data.keys.length: ${data.keys.length},  keys.length: ${keys.length}');

  print('\nObserved access time overhead x${(floopTime/refTime).toStringAsFixed(2)}');
  print('');
}

benchmarkFunction(f, [messagePrefix='Function']) {
  var avgTime = BenchmarkBase.measureFor(f, 2000);
  print('$messagePrefix benchmark average time: $avgTime us');
  return avgTime;
}

createMapWithValues(int n) {
  var map = Map();
  for(var i = 0; i < n; i++) {
    map['field$i'] = 'insertion number $i';
  }
  return map;
}

var _;
plainRead() {  //Map data, Iterable keys
  for(var k in store.keys) _ = store[k];
}

void warmUpController(int n) {
  controller.subscriptions.keys.toList().forEach((e) => controller.unsubscribeFromAll(e));
  store = ObservedMap.of(createMapWithValues(3));
  print('warm up keys: ${store.keys.length} $_');
  StatelessWidget widget = LightWidgetFloop(() => plainRead());
  for(int i=0; i<100; i++) {
    widget.build(MockElement());
  }
  // print('warm up subscription: ${(store as ObservedMap).keySubscriptions.length}');
}


class LightWidget extends StatelessWidget {
  final Function readOperation;

  LightWidget(this.readOperation);
  
  Widget buildWithFloop(BuildContext context) {
    readOperation();
    return Container(
      child: RaisedButton(
        onPressed: () => print(3),
        child: Text('My test widget ${Random().nextInt(1000000)}'),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildWithFloop(context);
  }
}

class LightWidgetFloop = LightWidget with Floop;

class MediumWeightWidget extends StatelessWidget {
  final Function readOperation;

  MediumWeightWidget(this.readOperation);

  @override
  Widget buildWithFloop(BuildContext context) {
    readOperation();
    return Scaffold(
      appBar: AppBar(
        title: Text('My Sacffold widget'),
      ),
      body: Center(
        child: Column(
          children: [
            Text('Body of my app ${Random().nextInt(1000000)}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
            Text('Body of my app}'),
          ]
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => print('Floating action'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildWithFloop(context);
  }
}

class MediumWeightWidgetFloop = MediumWeightWidget with Floop;
