import 'observed_benchmark.dart';
import 'widget_benchmark.dart';

/// To run all benchmarks with assertions dissabled a plugged in phone is
/// required. On the root folder of a flutter project copy paste the
/// floop/benchmark and use the following command:
///
/// flutter run --release benchmark\benchmark.dart > benchmarks.txt
///
/// Otherwise the benchmarks can be run by using:
///
/// flutter test benchmark\benchmark.dart > benchmarks.txt

void main() {
  print('Running app');
  runObservedBenchmarks();
  runWidgetBenchmarks();
  print('-----------------------------------------------------');
  print('-------------END------------------------------------');
  print('-----------------------------------------------------');
}
