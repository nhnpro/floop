# floop

Simple state management for Flutter. It automacally refreshes Widgets on data changes. Floop is meant to simplify dealing with UI interactions and asynchronous operations.

## Getting Started

See more details on Github.

https://github.com/icatalud/floop/

### Example - How to use

```diff
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
