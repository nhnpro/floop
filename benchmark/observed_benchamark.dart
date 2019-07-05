import 'package:floop/floop.dart';
import 'package:floop/src/controller.dart';

import 'base.dart';

/// Benchmarks for the ObservedMap implementation.
/// 
/// Run benchmarks by entering 'flutter test .\benchmark\observed_benchamark.dart' in 
/// console, inside the root folder.

main() {

  print('');
  print('-------Read benchmarks 10 Values-----------------------------------');
  readBenchmarks(10);

  print('-------Read benchmarks 1000 Values-----------------------------------');
  readBenchmarks(1000);

  print('-------Read benchmarks 10000 Values-----------------------------------');
  readBenchmarks(10000);

  print('-----------------------------------------------------');
  print('-------------End Read BenchMarks------------------------------------');
  print('-----------------------------------------------------');
  
  floopController.reset();

  runWriteBenchmark(10, 'Write benchmark 10 values');
  print('-----------------------------------------------------');
  runWriteBenchmark(1000, 'Write benchmark 10000 values');
}

void readBenchmarks([int numberOfValues=1000]) {
  Map data = createMapWithValues(numberOfValues);
  Iterable keys = data.keys.toList();
  runReadBenchmark(data, keys, 'Ordered keys read benchmark');
  print('-----------------------------------------------------');
  keys = data.keys.toList()..shuffle();
  runReadBenchmark(data, keys, 'Shuffled keys read benchmark');
}

runReadBenchmark(Map data, Iterable keys, [String bencharkHeadLine='Running Benchmark']) {
  print('\n${bencharkHeadLine.toUpperCase()}\n');
  print('floopController : ${floopController.runtimeType}\n');
  FloopController.setDefaultControllerToFull();
  FloopController.switchToFullControllerUntilFinishBuild();
  floopController.reset();

  Map readMap = ObservedMap.of(data);
  var obsTime = benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap 1 warm up');

  readMap = Map.of(data);
  var refTime = benchmarkFunction(() => plainRead(readMap, keys), 'LinkedHashMap 1 warm up');

  print('');

  readMap = ObservedMap.of(data);
  obsTime = benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap');

  readMap = Map.of(data);
  refTime = benchmarkFunction(() => plainRead(readMap, keys), 'LinkedHashMap');

  readMap = ObservedMap.of(data);
  floopController.startListening(MockElement());
  var obsTimeListening = benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap while listening');
  floopController.stopListening();

  readMap = ObservedMap.of(data);
  addObservedSubscriptions(readMap);  // loads the controller with subscriptions
  floopController.startListening(MockElement());
  var obsTimeListening2 = benchmarkFunction(
    () => plainRead(readMap, keys), 'ObservadMap while listening with filled controller');
  floopController.stopListening();

  // Ligh controller
  FloopController.setDefaultControllerToLight();
  floopController.reset();
  print('\nfloopController : ${floopController.runtimeType}\n');

  readMap = ObservedMap.of(data);
  floopController.startListening(MockElement());
  var obsTimeLightListening = benchmarkFunction(
    () => plainRead(readMap, keys), 'ObservadMap while listening with Light controller');
  floopController.stopListening();

  readMap = ObservedMap.of(data);
  addObservedSubscriptions(readMap);  // loads the controller with subscriptions
  floopController.startListening(MockElement());
  var obsTimeLightListening2 = benchmarkFunction(
    () => plainRead(readMap, keys), 'ObservadMap while listening with filled Light controller');
  floopController.stopListening();

  FloopController.setDefaultControllerToFull();

  benchmarkFunction(() {
    for(var k in keys);
  }, 'Iterate keys');

  print('\nObserved access time overhead x${(obsTime/refTime).toStringAsFixed(2)}');
  print('Observed access time overhead while listening x${(obsTimeListening/refTime).toStringAsFixed(2)}');
  print('Observed access time overhead while listening with controller Standard filled x${(obsTimeListening2/refTime).toStringAsFixed(2)}');
  print('Observed access time overhead while listening Light x${(obsTimeLightListening/refTime).toStringAsFixed(2)}');
  print('Observed access time overhead while listening with controller Light filled x${(obsTimeLightListening2/refTime).toStringAsFixed(2)}');
  print('');
}

runWriteBenchmark([int writeCount=10000, String bencharkHeadLine='Running Benchmark', ]) {
  print('\n${bencharkHeadLine.toUpperCase()}\n');

  FloopController.switchToFullControllerUntilFinishBuild();
  warmUpController(0);

  Map writeMap = ObservedMap();
  var obsTime = benchmarkFunction(() => plainWrite(writeMap, writeCount), 'ObservadMap 1 warm up');

  writeMap = Map();
  var refTime = benchmarkFunction(() => plainWrite(writeMap, writeCount), 'LinkedHashMap 1 warm up');

  writeMap = ObservedMap();
  obsTime = benchmarkFunction(() => plainWrite(writeMap, writeCount), 'ObservadMap');

  writeMap = Map();
  refTime = benchmarkFunction(() => plainWrite(writeMap, writeCount), 'LinkedHashMap');
  
  // writeMap = ObservedMap.of(createMapWithValues(5, (i) => i, (i) => i));
  // warmUpController(5)
  // var obsTimeSubscriptions5 = benchmarkFunction(() => plainWrite(writeMap, writeCount), 'ObservadMap');

  // writeMap = ObservedMap.of(createMapWithValues(100, (i) => i, (i) => i));
  // var obsTimeSubscriptions5 = benchmarkFunction(() => plainWrite(writeMap, writeCount), 'ObservadMap');

  benchmarkFunction(() {
    for(var i=0; i<writeCount; i++);
  }, 'Iterate keys');

  print('\nObserved write time overhead x${(obsTime/refTime).toStringAsFixed(2)}');
  print('');
}

plainWrite(Map map, int n) {
  for(var i=0; i<n; i++) map[i] = i;
}
