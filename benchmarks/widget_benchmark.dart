import 'dart:math';
import 'package:flutter/material.dart';

import 'package:floop/src/mixins.dart';
import 'package:floop/floop.dart';
import 'package:floop/src/controller.dart';

import 'base.dart';

/// Benchmarks for the Widget build time.
///
/// Run benchmarks by entering 'flutter test .\benchmark\observed_benchamark.dart' in
/// console, in the root folder of the project.

Map store;
// MockElement mockEle = MockElement();

typedef NoArgFunction = Function();
typedef WidgetCreator = StatelessWidget Function(NoArgFunction);

Function widgetCreatorReference;
Function widgetCreatorFloop;
String widgetName;

main() => runWidgetBenchmarks();

runWidgetBenchmarks() {
  print(
      '\n-------------Light Widget Benchmarks------------------------------------\n');
  benchmarkWidgets((f) => SmallWidget(f), (f) => SmallWidgetFloop(f));

  print(
      '\n-------------Medium Widget Benchmarks------------------------------------\n');
  benchmarkWidgets((f) => MediumWidget(f), (f) => MediumWidgetFloop(f));

  print('-----------------------------------------------------');
  print('-------------End Widget Benchmarks--------------------------------');
  print('-----------------------------------------------------\n');
}

void benchmarkWidgets(Function createRefWidget, createFloopWidget,
    [createFloopLightWidget, String headLine = 'Widgets']) {
  // print('\n${headLine.toUpperCase()}\n');
  const numberKeys = [0, 1, 3, 5, 20, 100, 1000, 10000];
  for (int i in numberKeys) {
    print(
        '\n-------Widget build time benchmarks $i Values-----------------------------------\n');
    prepareAndRunBenchmarks(
        i, createRefWidget, createFloopWidget, createFloopLightWidget);
    print('');
  }
}

void prepareAndRunBenchmarks(int numberOfReads, WidgetCreator createRefWidget,
    WidgetCreator createFloopWidget, WidgetCreator createFloopLightWidget) {
  ComponentElement element = createRefWidget(() {}).createElement();
  var referenceTimePureBuild =
      runBenchmarkFunction(element, 'pure build (no map read)');

  Map map = createMapWithValues(numberOfReads);
  element =
      createRefWidget(createValueReader(map, numberOfReads)).createElement();
  var referenceTime = runBenchmarkFunction(element);

  print('----Using ${FloopController}----');

  map = ObservedMap.of(map);
  element =
      createFloopWidget(createValueReader(map, numberOfReads)).createElement();
  var floopTime = runBenchmarkFunction(element);

  addObservedSubscriptions(map, numberOfReads);
  var floopTimeFilled = runBenchmarkFunction(element, 'with controller filled');

  print(
      '\nWidget read map operation build overhead x${(referenceTime / referenceTimePureBuild).toStringAsFixed(2)}');
  print(
      '\nFloopWidget build overhead x${(floopTime / referenceTime).toStringAsFixed(2)}');
  print(
      'FloopWidget with controller filled build overhead x${(floopTimeFilled / referenceTime).toStringAsFixed(2)}');
}

double runBenchmarkFunction(ComponentElement element,
    [String messageAdd = '']) {
  messageAdd = messageAdd == null ? '' : ' $messageAdd';
  // This should be changed to use many elements. Requires some change to
  // the benchmark harrness.
  void buildManyTimes() {
    for (int i = 0; i < 10; i++) {
      element.build();
      element.build();
      element.build();
      element.build();
      element.build();
    }
  }

  FloopController.reset();
  return benchmarkFunction(
      buildManyTimes, '${element.runtimeType.toString()}$messageAdd');
}

// int _build = 0;
class SmallWidget extends StatelessWidget {
  final Function readOperation;

  SmallWidget(this.readOperation);

  Widget build(BuildContext context) {
    readOperation();
    return Container(
        child: RaisedButton(
      onPressed: () => print(3),
      child: Text('My test widget ${Random().nextInt(1000000)}'),
    ));
  }
}

class SmallWidgetFloop = SmallWidget with Floop;

// class SmallWidgetFloopLight = SmallWidget with FloopLight;

class MediumWidget extends StatelessWidget {
  final Function readOperation;

  MediumWidget(this.readOperation);

  Widget build(BuildContext context) {
    readOperation();
    return Scaffold(
      appBar: AppBar(
        title: Text('My Sacffold widget'),
      ),
      body: Center(
        child: Column(children: [
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
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => print('Floating action'),
      ),
    );
  }
}

class MediumWidgetFloop = MediumWidget with Floop;

// class MediumWidgetFloopLight = MediumWidget with FloopLight;
