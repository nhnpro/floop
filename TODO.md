## Core implementation - Performance:
- Reduce the number of functions.
- Add extra checks that are worth for general use cases, like reteadly reading from the same map, reading the same key, etc.
- Create or find an existing custom Set that stores a cummulative hash to rapidly compare equality with another Set in O(1). This would almost always (99.999%) correctly update the widgets, which should be good enough.

## Tests
- Tests for each controller and [ObservedListener]
- Tests for all overriden operations in [DynMap]
- Tests for transitions API

## Benchmarks
- Compare and profile the differences between using [Floop] and a [StatefulWidget].
- Create a wider variety of scenarios for benchmarking. Reading from different maps during the same cycle, reading the same key vs different keys and using different types of values in the maps, so far everything is done using int, which is probably the fastest.
- Prune the benchmarks, also some of them are bad, like reading or writing few values within a for loop (the for loop overhead is too big).
- Benchmarks that compare reading or setting values from maps-sets to making function calls and setting class instances members values. This has implications on taking decisions like saving last keys read or making extra conditional checks to avoid unnecessary map reads-writes.
