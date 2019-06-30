# Floop

A super easy state management for flutter. Inspired by [react-recollect](https://github.com/davidgilbertson/react-recollect).

Floop uses a 'global store' state management paradigm. Widgets subscribed to keys in the store are automatically updated when the key's value is set. With Floop it's possible to build a whole interactive app using purely stateless widgets.

## Getting Started

Add floop dependency to your project's `pubspec.yaml`

```yaml
depedencies:
  floop: any
```

Run `flutter pub get` in the root folder of your project.

### Example use

```diff
-class Clicker extends StatelessWidget {
+class Clicker extends StatelessWidget with Floop {

  @override
-Widget build(BuildContext context)
+Widget buildWithFloop(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Text(floop['clicks'].toString())    // reads to the global store 'floop'
        ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => floop['clicks']++
      ),
    );
  }
}
```

In the above example the widget gets automatically subscribed to the key `'clicks'`. Floop automatically rebuilds the widget whenever `floop['clicks']` value is set.

That's it, your widgets will update whenever a key's value read during the build is set.

## How does it work?



## Performance

