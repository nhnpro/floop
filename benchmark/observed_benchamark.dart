import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:flutter/widgets.dart';
import 'package:mockito/mockito.dart';

import 'package:floop/floop.dart';
import 'package:floop/src/controller.dart';

/// Benchmarks for the ObservedMap implementation.
/// 
/// Run benchmarks by entering 'flutter test .\benchmark\observed_benchamark.dart' in 
/// console, inside the root folder.

typedef MapCreator = Map Function();
typedef BenchmarkFunction = void Function(Map);

class MockElement extends Mock implements Element {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) => super.toString();
}

final dataPlain = {};

int totalReads = 0;
int totalWrites = 0;

main() {
  initializeData();
  
  readBenchmarks();

  print('\n-----------------------------------------------------');
  print('\n-------------End Read BenchMarks------------------------------------');
  print('\n-----------------------------------------------------');
  
  runWriteBenchmark(10, 'Write benchmark 10 values');
  print('\n-----------------------------------------------------');
  runWriteBenchmark(10000, 'Write benchmark 10000 values');
}

void readBenchmarks() {
  Iterable keys = dataPlain.keys.toList();
  runReadBenchmark(dataPlain, keys, 'Ordered keys read benchmark');
  print('\n-----------------------------------------------------');
  keys = dataPlain.keys.toList()..shuffle();
  runReadBenchmark(dataPlain, keys, 'Shuffled keys read benchmark');
}

initializeData() {
  for(var i = 0; i < 1000; i++) {
    dataPlain['field$i'] = 'insertion number $i';
  }
}

runReadBenchmark(Map data, Iterable keys, [String bencharkHeadLine='Running Benchmark']) {
  print('\n${bencharkHeadLine.toUpperCase()}\n');

  Map  readMap = ObservedMap.of(data);
  var obsTime = benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap 1 warm up');

  readMap = Map.of(data);
  var refTime = benchmarkFunction(() => plainRead(readMap, keys), 'LinkedHashMap 1 warm up');

  readMap = ObservedMap.of(data);
  obsTime = benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap');

  readMap = Map.of(data);
  refTime = benchmarkFunction(() => plainRead(readMap, keys), 'LinkedHashMap');

  readMap = ObservedMap.of(data);
  floopController.startListening(MockElement());
  var obsTimeListening = benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap while listening');
  floopController.stopListening();

  // readMap = ObservedMap.of(data);
  // floopController.startListening(MockElement());
  // var obsTimeFilledController = benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap while listening');
  // floopController.stopListening();
  
  // print('data.keys.length: ${data.keys.length},  keys.length: ${keys.length}');
  benchmarkFunction(() {
    for(var k in keys);
  }, 'Iterate keys');

  print('\nObserved access time overhead x${(obsTime/refTime).toStringAsFixed(2)}');
  print('Observed access time overhead while listening x${(obsTimeListening/refTime).toStringAsFixed(2)}');
  print('');
}

void noop([v]) {}

plainRead(Map data, Iterable keys) {
  for(var k in keys) noop(data[k]);
}

double benchmarkFunction(f, [messagePrefix='Function']) {
  var avgTime = BenchmarkBase.measureFor(f, 2000);
  print('$messagePrefix average time: $avgTime us');
  return avgTime;
}

runWriteBenchmark([int writeCount=10000, String bencharkHeadLine='Running Benchmark', ]) {
  print('\n${bencharkHeadLine.toUpperCase()}\n');

  // Map readMap = Map();
  // plainWrite(readMap, writeCount);

  Map writeMap = ObservedMap();
  var obsTime = benchmarkFunction(() => plainWrite(writeMap, writeCount), 'ObservadMap 1 warm up');

  writeMap = Map();
  var refTime = benchmarkFunction(() => plainWrite(writeMap, writeCount), 'LinkedHashMap 1 warm up');

  writeMap = ObservedMap();
  obsTime = benchmarkFunction(() => plainWrite(writeMap, writeCount), 'ObservadMap');

  writeMap = Map();
  refTime = benchmarkFunction(() => plainWrite(writeMap, writeCount), 'LinkedHashMap');

  benchmarkFunction(() {
    for(var i=0; i<writeCount; i++);
  }, 'Iterate keys');

  print('\nObserved write time overhead x${(obsTime/refTime).toStringAsFixed(2)}');
  print('');
}

plainWrite(Map map, int n) {
  for(var i=0; i<n; i++) map[i] = i;
}
