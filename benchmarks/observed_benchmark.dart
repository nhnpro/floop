import 'package:floop/floop.dart';
import 'package:floop/src/controller.dart';
import 'package:floop/src/observed.dart';

import 'base.dart';

/// Benchmarks for the ObservedMap implementation.
///
/// Enter 'flutter test .\benchmark\observed_benchamark.dart' in console
/// from the root folder of the project to run the benchmarks.

main() => runObservedBenchmarks();

runObservedBenchmarks() {
  print('');

  const readCounts = [1, 3, 5, 10, 100, 1000, 10000, 100000];
  for (var i in readCounts) {
    print('-------Read benchmarks $i Values-----------------------');
    readBenchmarks(i);
  }
  print('-----------------------------------------------------');
  print(
      '-------------End Observed Read BenchMarks---------------------------------');
  print('-----------------------------------------------------\n');

  const writeCounts = [1, 3, 5, 10, 100, 1000, 10000, 100000];
  for (var i in writeCounts) {
    print('-------Write benchmarks $i Values-----------------------');
    runWriteBenchmark(i, 'Write benchmark $i values');
    print('-----------------------------------------------------');
  }

  print(
      '-------------End Observed Write Benchmarks--------------------------------');
  print('-----------------------------------------------------\n');
}

void readBenchmarks([int numberOfValues = 1000]) {
  Map data = createMapWithValues(numberOfValues);
  Iterable keys = data.keys.toList();
  runReadBenchmark(data, keys, 'Ordered keys read benchmark');
}

runReadBenchmark(Map data, Iterable keys,
    [String benchmarkHeadLine = 'Running Benchmark']) {
  print('\n${benchmarkHeadLine.toUpperCase()}\n');
  MockElement mockElement = MockElement();

  FloopController.reset();

  Map readMap = ObservedMap.of(data);
  var obsTime =
      benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap warm up');

  readMap = Map.of(data);
  var refTime = benchmarkFunction(
      () => plainRead(readMap, keys), 'LinkedHashMap warm up');

  print('');

  readMap = ObservedMap.of(data);
  obsTime = benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap');

  readMap = Map.of(data);
  refTime = benchmarkFunction(() => plainRead(readMap, keys), 'LinkedHashMap');

  print('----Using ${FloopController}----');

  readMap = ObservedMap.of(data);
  FloopController.startListening(mockElement);
  var obsTimeListening = benchmarkFunction(
      () => plainRead(readMap, keys), 'ObservadMap while listening');
  FloopController.stopListening();

  readMap = ObservedMap.of(data);
  addObservedSubscriptions(readMap); // loads the controller with subscriptions
  FloopController.startListening(mockElement);
  var obsTimeListening2 = benchmarkFunction(() => plainRead(readMap, keys),
      'ObservadMap while listening with filled controller');
  FloopController.stopListening();
  FloopController.reset();

  readMap = ObservedMap.of(data);
  var obsTimeListeningCycle = benchmarkFunction(() {
    FloopController.startListening(mockElement);
    plainRead(readMap, keys);
    FloopController.stopListening();
  }, 'ObservadMap complete listening cycle');

  readMap = ObservedMap.of(data);
  addObservedSubscriptions(readMap);
  var obsTimeListeningCycle2 = benchmarkFunction(() {
    FloopController.startListening(mockElement);
    plainRead(readMap, keys);
    FloopController.stopListening();
  }, 'ObservadMap complete listening cycle with filled controller');

  FloopController.reset();

  // For experimental comparison controller
  // Using Light controller
  // UnifiedController.useLightController();
  // UnifiedController.reset();
  // print('----Using ${UnifiedController}----');

  // readMap = ObservedMap.of(data);
  // UnifiedController.startListening(mockElement);
  // var obsTimeLightListening = benchmarkFunction(() => plainRead(readMap, keys),
  //     'ObservadMap while listening with Light controller');
  // UnifiedController.stopListening();

  // readMap = ObservedMap.of(data);
  // addObservedSubscriptions(readMap); // loads the controller with subscriptions
  // UnifiedController.startListening(mockElement);
  // var obsTimeLightListening2 = benchmarkFunction(() => plainRead(readMap, keys),
  //     'ObservadMap while listening with filled Light controller');
  // UnifiedController.stopListening();

  // readMap = ObservedMap.of(data);
  // var obsTimeLightListeningCycle = benchmarkFunction(() {
  //   UnifiedController.startListening(mockElement);
  //   plainRead(readMap, keys);
  //   UnifiedController.stopListening();
  // }, 'ObservadMap complete listening cycle');

  // UnifiedController.reset();
  // readMap = ObservedMap.of(data);
  // addObservedSubscriptions(readMap);
  // var obsTimeLightListeningCycle2 = benchmarkFunction(() {
  //   UnifiedController.startListening(mockElement);
  //   plainRead(readMap, keys);
  //   UnifiedController.stopListening();
  // }, 'ObservadMap complete listening cycle with filled controller');

  FloopController.reset();
  // UnifiedController.useFullController();

  benchmarkFunction(() {
    for (var k in keys);
  }, 'Iterate keys');

  print(
      '\nObserved access time overhead x${(obsTime / refTime).toStringAsFixed(2)}');
  print(
      'Observed access time overhead while listening x${(obsTimeListening / refTime).toStringAsFixed(2)}');
  print(
      'Observed access time overhead while listening with controller Standard filled x${(obsTimeListening2 / refTime).toStringAsFixed(2)}');
  // print(
  //     'Observed access time overhead while listening Light x${(obsTimeLightListening / refTime).toStringAsFixed(2)}');
  // print(
  //     'Observed access time overhead while listening with controller Light filled x${(obsTimeLightListening2 / refTime).toStringAsFixed(2)}');
  print('----Full cycle ratios----');
  print(
      'Complete listen cycle access time overhead x${(obsTimeListeningCycle / refTime).toStringAsFixed(2)}');
  print(
      'Complete listen cycle access time overhead with controller Standard filled x${(obsTimeListeningCycle2 / refTime).toStringAsFixed(2)}');
  // print(
  //     'Complete listen cycle access time overhead Light x${(obsTimeLightListeningCycle / refTime).toStringAsFixed(2)}');
  // print(
  //     'Complete listen cycle access time overhead with controller Light filled x${(obsTimeLightListeningCycle2 / refTime).toStringAsFixed(2)}');
  print('');
}

runWriteBenchmark([
  int writeCount = 10000,
  String benchmarkHeadLine = 'Running Benchmark',
]) {
  print('\n${benchmarkHeadLine.toUpperCase()}\n');

  Map writeMap = ObservedMap();
  var obsTime = benchmarkFunction(
      () => plainWrite(writeMap, writeCount), 'ObservadMap 1 warm up');

  writeMap = Map();
  var refTime = benchmarkFunction(
      () => plainWrite(writeMap, writeCount), 'LinkedHashMap 1 warm up');

  writeMap = ObservedMap();
  obsTime =
      benchmarkFunction(() => plainWrite(writeMap, writeCount), 'ObservadMap');

  writeMap = Map();
  refTime = benchmarkFunction(
      () => plainWrite(writeMap, writeCount), 'LinkedHashMap');

  benchmarkFunction(() {
    for (var i = 0; i < writeCount; i++);
  }, 'Iterate keys');

  print(
      '\nObserved write time overhead x${(obsTime / refTime).toStringAsFixed(2)}');
  print('');
}

plainWrite(Map map, int n) {
  for (var i = 0; i < n; i++) {
    map[i] = i;
  }
}
