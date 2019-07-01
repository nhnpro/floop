import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:floop/floop.dart';

/// Benchmarks for the ObservedMap implementation.
/// 
/// Run benchmarks by entering 'flutter test .\benchmark\observed_benchamark.dart' in 
/// console, inside the root folder.

typedef MapCreator = Map Function();
typedef BenchmarkFunction = void Function(Map);

final dataPlain = {};

int totalReads = 0;
int totalWrites = 0;

main() {
  initializeData();
  readBenchmarks();
  // writeBenchmarks();
}

void readBenchmarks() {
  Iterable keys = dataPlain.keys.toList();
  runReadBenchmark(dataPlain, keys, 'Ordered keys read benchmark');

  keys = dataPlain.keys.toList()..shuffle();
  runReadBenchmark(dataPlain, keys, 'Shuffled keys read benchmark');
}

initializeData() {
  for(var i = 0; i < 10000; i++) {
    dataPlain['field$i'] = 'insertion number $i';
  }
}

runReadBenchmark(Map data, Iterable keys, [String bencharkHeadLine='Running Benchmark']) {
  print('\n${bencharkHeadLine.toUpperCase()}\n');

  Map  readMap = ObservedMap.of(data);
  var obsTime = benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap 1');

  readMap = Map.of(data);
  var refTime = benchmarkFunction(() => plainRead(readMap, keys), 'LinkedHashMap');

  readMap = ObservedMap.of(data);
  obsTime = benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap');
  
  // print('data.keys.length: ${data.keys.length},  keys.length: ${keys.length}');
  benchmarkFunction(() {
    for(var v in keys) noop(data[v]);
  }, 'Iterate keys');

  print('\nObserved access time overhead x${(obsTime/refTime).toStringAsFixed(2)}');
  print('');
}

void noop([v]) {}

plainRead(Map data, Iterable keys) {
  for(var k in keys) noop(data[k]);
}

benchmarkFunction(f, [messagePrefix='Function']) {
  var avgTime = BenchmarkBase.measureFor(f, 2000);
  print('$messagePrefix benchmark average time: $avgTime us');
  return avgTime;
}

runWriteBenchmark(Map data, Iterable keys, [String bencharkHeadLine='Running Benchmark']) {
  print('\n${bencharkHeadLine.toUpperCase()}\n');

  Map  readMap = ObservedMap.of(data);
  var obsTime = benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap 1');

  readMap = Map.of(data);
  var refTime = benchmarkFunction(() => plainRead(readMap, keys), 'LinkedHashMap');

  readMap = ObservedMap.of(data);
  obsTime = benchmarkFunction(() => plainRead(readMap, keys), 'ObservadMap');
  
  // print('data.keys.length: ${data.keys.length},  keys.length: ${keys.length}');
  benchmarkFunction(() {
    for(var v in keys) noop(data[v]);
  }, 'Iterate keys');

  print('\nObserved access time overhead x${(obsTime/refTime).toStringAsFixed(2)}');
  print('');
}

plainWrite() {

}
