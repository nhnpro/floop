final Stopwatch _stopwatch = Stopwatch()..start();

/// The time of a generic non-stop stopwatch.
int milliseconds() => _stopwatch.elapsedMilliseconds;

/// The time of a generic non-stop stopwatch.
int microseconds() => _stopwatch.elapsedMicroseconds;
