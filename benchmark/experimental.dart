import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:floop/floop.dart';

/// Benchmarks for the ObservedMap implementation.

typedef MapCreator = Map Function();
typedef BenchmarkFunction = void Function(Map);

const emptyList = <int>[];

const dataSmall = {
    'porcu': 'pine',
    'pets' : {'dog': 'bone', 'bird': 'fly'},
  };

final dataPlain = {};
final dataComplex = {};
final dataDeep = {};

int totalReads = 0;
int totalWrites = 0;

/// Enter 'flutter test .\benchmark\observed_benchamark.dart' in console to run this benchmark.
main() {
  initializeData();
  readBenchmarks();
  // writeBenchmarks();
}

void readBenchmarks() {
  runReadBenchmark(dataSmall, 'Small data READ benchmark');
  runReadBenchmark(dataPlain, 'Plain data READ benchmark');
  runReadBenchmark(dataComplex, 'Complex data READ benchmark');
  runReadBenchmark(dataDeep, 'Deep data READ benchmark');  
}

initializeData() {
  for(var i = 0; i < 10000; i++) {
    dataPlain['field$i'] = 'insertion number $i';
  }

  for(var i = 0; i < 1000; i++) {
    dataComplex['$i'] = [Map.of(dataSmall), Map.of(dataSmall), Map.of(dataSmall)];
  }

  Map nested = dataDeep;
  for(var i = 0; i < 200; i++) {
    nested['$i'] = {'value': Map.of(dataSmall)};
    nested = nested['$i'];
  }
}

runReadBenchmark(Map data, [String bencharkHeadLine='Running Benchmark']) {
  print('\n${bencharkHeadLine.toUpperCase()}\n');
  final referenceBenchmark =  MapReadBenchmark(
    () => Map(), data, mapName: 'LinkedHashMap', benchmarkFunction: plainRead);
  var refTime = referenceBenchmark.measure();
  print('time: $refTime');
  final observedBenchmark =  MapReadBenchmark(
    () => ObservedMap(), data, mapName: 'ObservedMap', benchmarkFunction: plainRead);
  var obsTime = observedBenchmark.measure();
  print('time: $obsTime');
  final loopBenchmark =  MapReadBenchmark(
    () => Map(), data, mapName: 'Plain loop (no map read)', benchmarkFunction: plainLoop);
  var loopTime = loopBenchmark.measure();
  print('time: $loopTime');

  referenceBenchmark.report();
  observedBenchmark.report();
  loopBenchmark.report();

  print('\nObserved access time overhead x${(obsTime/refTime).toStringAsFixed(2)}');
  print('\nObserved access time minus loop time overhead x${((obsTime-loopTime)/(refTime-loopTime)).toStringAsFixed(2)}');
  print('');
}

plainLoop(Map data) {
  for(var k in data.keys);
  // var limit = data.keys.length;
  // for(var k = 0; k<limit; k++);
}

plainRead(Map data) {
  for(var k in data.keys) data[k];
}


abstract class MapBenchmark extends BenchmarkBase {

  final data;
  Function benchmarkFunction;
  MapCreator mapCreator;
  Map startMap;
  double result;

  MapBenchmark(
    this.mapCreator, this.data, {String mapName='Map', this.benchmarkFunction})
      : super("$mapName Benchamark") {
        if(benchmarkFunction==null) benchmarkFunction = benchmarkOperation;
      }

  benchmarkOperation(obj);

  void run() {
    benchmarkFunction(startMap);
  }

  @override
  double measure() {
    if(result==null) result = super.measure();
    return result;
  }
}

traverse(obj) {
  if(obj is Map) obj = obj.values;
  else if(!(obj is Iterable)) return;
  
  for(var v in obj) {
    traverse(v);
  }
  totalReads += obj.length;
}


class MapReadBenchmark extends MapBenchmark {

  MapReadBenchmark(
    mapCreator, data, {String mapName='Map', benchmarkFunction})
      : super(mapCreator, data, mapName:mapName, benchmarkFunction: benchmarkFunction);

  benchmarkOperation(obj) {
    traverse(obj);
    // if(obj is Map) obj = obj.values;
    // else if(!(obj is List)) obj = emptyList;
    
    // for(var v in obj) {
    //   benchmarkOperation(v);
    // }
    // totalReads += obj.length;
  }

  run() => traverse(startMap);

  void setup() {
    startMap = mapCreator()..addAll(data);
    totalReads = 0;
  }

  @override
  double measure() {
    if(result==null) result = super.measure();
    return result;
  }

  report() {
    print('Accessed $totalReads values');
    super.report();
  }
}


// Write benchmarks here

void writeBenchmarks() {
  runWriteBenchmark(dataSmall, 'Small data WRITE benchmark');
  runWriteBenchmark(dataPlain, 'Plain data WRITE benchmark');
  runWriteBenchmark(dataComplex, 'Complex data WRITE benchmark');
  runWriteBenchmark(dataDeep, 'Deep data WRITE benchmark');  
}

runWriteBenchmark(Map data, [String bencharkHeadLine='Running Benchmark']) {
  print('\n${bencharkHeadLine.toUpperCase()}\n');
  final referenceBenchmark =  MapWriteBenchmark(
    () => Map(), data, mapName: 'LinkedHashMap');
  var refTime = referenceBenchmark.measure();
  final observedBenchmark =  MapWriteBenchmark(
    () => ObservedMap(), data, mapName: 'ObservedMap');
  var obsTime = observedBenchmark.measure();

  referenceBenchmark.report();
  observedBenchmark.report();

  print('\nObserved access time overhead x${(obsTime/refTime).toStringAsFixed(2)}');
  print('');
}


// This wrapper class is used to avoid deepcopy of ObservadMap when
class Wrapper {
  Object wrap;
  Wrapper(this.wrap);
}

class MapWriteBenchmark extends MapBenchmark {

  MapWriteBenchmark(
    mapCreator, data, {String mapName='Map'})
      : super(mapCreator, data, mapName:mapName);

  benchmarkOperation(obj) {
    Iterable result = emptyList;
    if(obj is Map) {
      var map = mapCreator();
      obj.forEach((k, v) => map[k]=Wrapper(v));
      obj = obj.values;
    } else if(!(obj is Iterable)) {
      obj = emptyList;
    }
    // else {
    //   obj = List.of(obj);
    // }
    for(var v in obj) {
      benchmarkOperation(v);
    }
    totalWrites += result.length;
  }

  void setup() {
    startMap = data;
    totalWrites = 0;
  }

  @override
  double measure() {
    if(result==null) result = super.measure();
    return result;
  }

  report() {
    print('Wrote $totalWrites values');
    super.report();
  }
}
