# floop_web

Floop implementation for Flutter web. It's literally the same code as Floop, it just imports from package flutter_web instead of flutter.

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
