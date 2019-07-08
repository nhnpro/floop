import 'dart:math';

// import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:floop/src/mixins.dart';
import 'package:flutter/material.dart';

import 'package:floop/floop.dart';
import 'package:floop/src/controller.dart';

import 'base.dart';

/// Benchmarks for the Widget build time.
/// 
/// Run benchmarks by entering 'flutter test .\benchmark\observed_benchamark.dart' in 
/// console, inside the root folder.

Map store;
MockElement mockEle = MockElement();

typedef NoArgFunction = Function();
typedef WidgetCreator = StatelessWidget Function(NoArgFunction);

Function widgetCreatorReference;
Function widgetCreatorFloop;
String widgetName;

main() => runWidgetBenchmarks();

runWidgetBenchmarks() {
  print('\n-------------Light Widget Benchmarks------------------------------------\n');
  benchmarkWidgets(
    (f) => SmallWidget(f), (f) => SmallWidgetFloop(f), (f) => SmallWidgetFloopLight(f));

  print('\n-------------Medium Widget Benchmarks------------------------------------\n');
  benchmarkWidgets(
    (f) => MediumWidget(f), (f) => MediumWidgetFloop(f), (f) => MediumWidgetFloopLight(f));

  print('-----------------------------------------------------');
  print('-------------End Widget Benchmarks--------------------------------');
  print('-----------------------------------------------------\n');
}

void benchmarkWidgets(
  Function createRefWidget, createFloopWidget, createFloopLightWidget, [String headLine='Widgets']) {
  // print('\n${headLine.toUpperCase()}\n');
  const numberKeys = [0, 1, 3, 5, 20, 100, 1000, 10000];
  for(int i in numberKeys) {
    print('\n-------Widget build time benchmarks $i Values-----------------------------------\n');
    prepareAndRunBenchmarks(i, createRefWidget, createFloopWidget, createFloopLightWidget);
    print('');
  }
}

void prepareAndRunBenchmarks(
  int numberOfReads, WidgetCreator createRefWidget, WidgetCreator createFloopWidget, WidgetCreator createFloopLightWidget) {
  
  StatelessWidget widget = createRefWidget(() {});
  var referenceTimePureBuild = runBenchmarkFunction(widget, 'pure build (no map read)');

  Map map = createMapWithValues(numberOfReads);
  widget = createRefWidget(createValueReader(map, numberOfReads));
  var referenceTime = runBenchmarkFunction(widget);

  FloopController.useFullController();
  print('----Using ${floopController.runtimeType.toString()}----');

  map = ObservedMap.of(map);
  widget = createFloopWidget(createValueReader(map, numberOfReads));
  var floopTime = runBenchmarkFunction(widget);

  addObservedSubscriptions(map, numberOfReads);
  var floopTimeFilled = runBenchmarkFunction(widget, 'with controller filled');
  
  floopController.reset();
  FloopController.useLightController();
  print('----Using ${floopController.runtimeType.toString()}----');

  map = ObservedMap.of(map);
  widget = createFloopLightWidget(createValueReader(map, numberOfReads));
  var floopLightTime = runBenchmarkFunction(widget);

  addObservedSubscriptions(map, numberOfReads);
  var floopLightTimeFilled = runBenchmarkFunction(widget, 'with controller filled');

  floopController.reset();

  print('\nWidget read map operation build overhead x${(referenceTime/referenceTimePureBuild).toStringAsFixed(2)}');
  print('\nFloopWidget build overhead x${(floopTime/referenceTime).toStringAsFixed(2)}');
  print('FloopWidget with controller filled build overhead x${(floopTimeFilled/referenceTime).toStringAsFixed(2)}');
  print('Light FloopWidget build overhead x${(floopLightTime/referenceTime).toStringAsFixed(2)}');
  print('Light FloopWidget with controller filled build overhead x${(floopLightTimeFilled/referenceTime).toStringAsFixed(2)}');
}

double runBenchmarkFunction(StatelessWidget widget, [String messageAdd='']) {
  messageAdd = messageAdd==null ? '' : ' $messageAdd';
  void buildManyTimes() {
    for(int i=0; i<1000; i++) widget.build(mockEle);
  }
  return benchmarkFunction(buildManyTimes, '${widget.runtimeType.toString()}$messageAdd');
}



class SmallWidget extends StatelessWidget {
  final Function readOperation;

  SmallWidget(this.readOperation);
  
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

class SmallWidgetFloop = SmallWidget with Floop;

class SmallWidgetFloopLight = SmallWidget with FloopLight;


class MediumWidget extends StatelessWidget {
  final Function readOperation;

  MediumWidget(this.readOperation);

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

class MediumWidgetFloop = MediumWidget with Floop;

class MediumWidgetFloopLight = MediumWidget with FloopLight;


//   var name = widgetCreator().runtimeType.toString();

//   createWidgetBuilder(Function mapCreator, int numberReads) {
//     StatelessWidget widget = createRefWidget(createValueReader(mapCreator(), numberReads));
//     MockElement mockEle = MockElement();
//     return () {
//       for(int i=0; i<1000; i++) widget.build(mockEle);
//     };
//   }

//   widgetBuildTimeBenchmark(int numberReads) {

//     benchmarkFunction(
//       createWidgetBuilder(() => Map(), numberReads), '${widget.runtimeType}');

//     obsTime = runBenchmarkFunction(() => ObservedMap(), numberReads);

//     map = ObservedMap();
//     widget = createFloopWidget(createValueReader(map, numberReads));


//   }

//   Map map = createMapWithValues(numberReads);
//   var referenceTime = runBenchmarkFunction(() => ObservedMap(), numberReads);

//   map = ObservedMap.of(map);
//   StatelessWidget widget = createFloopWidget(createValueReader(map));
//   var floopTime = runBenchmarkFunction(widget);

//   addObservedSubscriptions(map, numberOfReads);
//   var floopTimeFilled = runBenchmarkFunction(widget);

//   print('\nFloopWidget build overhead x${(floopTime/refereceTime).toStringAsFixed(2)}');
//   print('\nFloopWidget with controller filled build overhead x${(floopTimeFilled/refereceTime).toStringAsFixed(2)}');


//   var floopTimeWithSubscriptions = runBenchmarkFunction(() => ObservedMap(), numberReads);

//   var floopLightTime = runBenchmarkFunction(() => ObservedMap(), numberReads);

//   var floopLightTimeWithSubscriptions = runBenchmarkFunction(() => ObservedMap(), numberReads);



//   // widgetBuildBenchmark(0, 'Read 0 keys $name');
//   // var createWidget = createWidgetCreator(() => {});
//   // singleWidgetBuildBenchmark(createWidget, 1, 'Read 1 key $name');

//   // createWidget = createWidgetCreator(valueReaderCreator(1));
//   // singleWidgetBuildBenchmark(createWidget, 1, 'Read 1 key $name');

  

//   // widgetBuildBenchmark(3, 'Read 3 keys $name');


//   // widgetBuildBenchmark(5, 'Read 5 keys $name');


//   // widgetBuildBenchmark(20, 'Read 20 keys $name');


//   // widgetBuildBenchmark(100, 'Read 100 keys $name');


//   // widgetBuildBenchmark(1000, 'Read 1000 keys $name');
// }


// widgetBuildTimeBenchmark(widgetCreator, [String bencharkHeadLine='Running Benchmark']) {

//   Widget widget = widgetCreator();
//   MockElement mockEle = MockElement();
//   buildManyTimes() {
//     for(int i=0; i<1000; i++) widget.build(mockEle);
//   }
//   var refTime = benchmarkFunction(buildManyTimes, '$widgetName');

//   store = ObservedMap.of(data);
//   widget = SmallWidgetFloop(readOperation);
//   var floopTime = benchmarkFunction(buildManyTimes, '${widgetName}Floop');
// }


// Function widgetCreator, 

// void widgetBuildBenchmark(int numberKeys, [String bencharkHeadLine='Running Benchmark']) {
//   print('\n${bencharkHeadLine.toUpperCase()}\n');

//   Map data = createMapWithValues(numberKeys);
//   // warmUpController(100);
    
//   Function readOperation = plainRead;
//   StatelessWidget widget;

//   buildManyTimes() {
//     for(int i=0; i<1000; i++) widget.build(mockEle);
//   }
  
//   print('Controller subscribed element count: ${FloopController.length}');
  
//   store = Map.of(data);
//   widget = SmallWidget(readOperation);
//   var refTime = benchmarkFunction(buildManyTimes, '$widgetName');

//   store = ObservedMap.of(data);
//   widget = SmallWidgetFloop(readOperation);
//   var floopTime = benchmarkFunction(buildManyTimes, '${widgetName}Floop');

//   store = Map.of(createMapWithValues(numberKeys+2));
//   benchmarkFunction(() {
//     for(int i=0; i<1000; i++) plainRead();
//     }, 'Read Map ${numberKeys+2}');

//   store = ObservedMap.of(store);
//   benchmarkFunction(() {
//     for(int i=0; i<1000; i++) plainRead();
//     }, 'Read ObservedMap ${numberKeys+2}');

//   // store = ObservedMap.of(data);
//   // floopTime = benchmarkFunction(() => plainRead(readMap, readMap.keys), 'ObservadMap');

//   // print('data.keys.length: ${data.keys.length},  keys.length: ${keys.length}');

//   print('\nObserved access time overhead x${(floopTime/refTime).toStringAsFixed(2)}');
//   print('');
// }

// benchmarkFunction(f, [messagePrefix='Function']) {
//   var avgTime = BenchmarkBase.measureFor(f, 2000);
//   print('$messagePrefix benchmark average time: $avgTime us');
//   return avgTime;
// }

// createMapWithValues(int n) {
//   var map = Map();
//   for(var i = 0; i < n; i++) {
//     map['field$i'] = 'insertion number $i';
//   }
//   return map;
// }

// // var _;
// plainRead() {  //Map data, Iterable keys
//   for(var k in store.keys) store[k];
// }

// void warmUpController(int n) {
//   floopController.subscriptions.keys.toList().forEach((e) => floopController.unsubscribeFromAll(e));
//   store = ObservedMap.of(createMapWithValues(3));
//   print('warm up keys: ${store.keys.length} $_');
//   StatelessWidget widget = LightWidgetFloop(() => plainRead());
//   for(int i=0; i<100; i++) {
//     widget.build(MockElement());
//   }
//   // print('warm up subscription: ${(store as ObservedMap).keySubscriptions.length}');
// }


