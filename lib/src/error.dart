import 'flutter.dart';

FlutterError floopError(message) {
  return FlutterError.fromParts(
      <DiagnosticsNode>[ErrorSummary('Floop Error: ' + message + '\n')]);
}
