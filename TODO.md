## Core implementation - Performance:
- Make [FullController] to behave as a [LightController] and extend it's functionality on demand doing some checks. There is a cost of extra checks, but it's worth if most applications only read one [ObservedMap] per build cycle.
- Experiment with different approaches. For example it's probably better to use one cannonical internal [_ObservedMapCore] that can be listened and other [ObservedMap] just connect them by creating an internal unique id, relating it's key with the id. This has a cost on reads and writes outside build methods, but greatly increases the performance inside.
- Reduce the number of functions.
- Add extra checks that are worth for general use cases, like reteadly reading from the same map, reading the same key, etc.
- Create a custom Set that saves a cummulutive hash to rapidly compare equality with another Set in O(1). This would almost always correctly update the widgets, which might be good enough.

## Tests
- Tests for each controller and [ObservedListener]
- Tests for all overriden operations in [ObservedMap]
- Tests for transitions API

## Benchmarks
- Compare and profile the differences between using [Floop] and a [StatefulWidget].
- Create a wider variety of scenarios for benchmarking. Reading from different maps during the same cycle, reading the same values mutiple times, etc.
- Prune the benchmarks, also some of them are bad, like reading or writing few values within a for loop (the for loop overhead is too big).
