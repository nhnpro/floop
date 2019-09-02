## Core implementation - Performance:
- Make [FullController] to behave as a [LightController] and extend it's functionality on demand doing some checks. There is a cost of extra checks, but it's worth if most applications only read one [ObservedMap] per build cycle.
- Experiment with different approaches. For example it's probably better to use one cannonical internal [_ObservedMapCore] that can be listened and other [ObservedMap] just connect them by creating an internal unique id, relating it's key with the id. This has a cost on reads and writes outside build methods, but greatly increases the performance inside.
- Reduce the number of functions.
- Add extra checks that might be worth for the general use cases, like reteadly reading form the same map, or reading the same key, etc.

## Tests
- Tests for each controller and [ObservedListener]
- Tests for all overriden operations in [ObservedMap]
- Tests for transitions API

## Benchmarks
- Compare and profile the differences between using [Floop] and a [StatefulWidget].
- Create a wider variety of scenarios for benchmarking. Reading from different maps during the same cycle, reading the same values mutiple times, etc.
- Prune the benchmarks, also some of them are bad, like reading or writing few values with a for loop (the for loop overhead is too big).
