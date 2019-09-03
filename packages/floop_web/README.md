# floop_web

Dynamic values for Flutter Widgets. It's the same as floop library.

https://pub.dev/packages/floop

## Getting Started

See more details on Github.

https://github.com/icatalud/floop/

### Example - How to use

```diff
+import 'package:floop_web/floop_web.dart';

-class Clicker extends StatelessWidget {
+class Clicker extends StatelessWidget with Floop {

  @override
-Widget build(BuildContext context) {
+Widget buildWithFloop(BuildContext context) {
buildWithFloop
    return Scaffold(
      body: Center(
+          child: Text(floop['clicks'].toString())
        ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
+        onPressed: () => floop['clicks']++    // change 'clicks' from anywhere in the app and the widget will get updated
      ),
    );
  }
}
```

On StatefulWidgets: `...extends State with FloopStateMixin`.

## Install

Add floop dependency to the project's `pubspec.yaml`. Currently there are problems publishing flutter_web projects, because flutter_web does not exist on pub.dev. If adding the dependency like a regular pub.dev project does not work, try the following:

```yaml
depedencies:
  floop:
    git: https://github.com/icatalud/floop
    path: packages/floop_web
```

Run `flutter pub get` in the root folder of your project.
