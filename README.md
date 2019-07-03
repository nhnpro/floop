# Floop

A super simplified state management for flutter. No need to manage state anymore. Inspired by [react-recollect](https://github.com/davidgilbertson/react-recollect).

Floop uses an observed 'global store' state management paradigm. Widgets will always display the current value in the store. With Floop it's possible to build a whole interactive app using purely stateless widgets.

### Example

```diff
-class Clicker extends StatelessWidget {
+class Clicker extends StatelessWidget with Floop {
+// class ClickerState extends State with FloopState {  // for stateful Widgets

  @override
-Widget build(BuildContext context)
+Widget buildWithFloop(BuildContext context) {
+// do not modify store like floop['myValue'] += 1 inside buildWithFloop, it's the only forbidden use
    return Scaffold(
      body: Center(
          child: Text(floop['clicks'].toString())    // widget displays with the current value of `floop['clicks']`
        ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => floop['clicks']++    // change 'clicks' from anywhere in the app and the widget will get updated
      ),
    );
  }
}
```

The example above displays everything required to use the library, you may keep reading to learn more [details](#details)), but it's not necessary. See the full example [here](../blob/master/examples/clicker.dart).

In summary, the two rules two use Floop:
1. Widget will always rebuild with the last value in the store
2. Do not modify the store during the build

Any kind of values can be kept in the global store `floop`.

## Install

Add floop dependency to your project's `pubspec.yaml`

```yaml
depedencies:
  floop: any
```

Run `flutter pub get` in the root folder of your project.

## Why use Floop

- It's an intuitive way of building UI. Many people expect that when they add a component `Text(myText)`, the UI will display whatever value is set on the var myText. That's exactly what happens if you do `Text(floop['myText'])`.
- There is no learning curve. Anyone can use it and understand it immediately, the example above is all there is.
- It's efficient and has good performance (see [performance](#performance)), it only updates the widgets that need to be updated.
- Animations simplified: a different animation paradigm. Animations can be completely decoupled from the component, allowing you to use the basic stateless components you already know and just make them read values that will be changing. Create oscillating values, put them in the store and read those values in the widgets you want to animate. A convenient class [Repeating] is included in the library to repeatedly call a function with any given frequency. [Animation example](../blob/master/examples/animated_icons.dart).

## <a name="details">Details</a>

`floop` is just an instance of [ObservedMap], which implements [Map], create alternative 'stores' doing `Map myStore = ObservedMap()` ([Map<K, V>] also possible).

Widgets are always only subscribed to the keys **read during their last build**. 

[Map] and [Iterable] values will not be stored by reference, but rather they'll get deep copied (automatically). Every [Map] will be copied as an [ObservedMap] instance, while lists get copied using [List.unmodifiable].

## <a name="performance">Performance</a>
In short, `buildWithFloop` is like adding 20 lines of variable read-write operations to a widget (imaging wrapping your widget with a widget that has 20 initialization fields). Each  On average the Building widgets is blazingly fast. All you do in a build operation is instantiate a bunch of objects. You can

In practice, Floop performs very well for simple animated applications. Overall using Floop should improve performance, by updating and rebuilding directly the Widgets that have changed, instead of having a parent widgets that manage state, have to rebuild a whole tree of child widgets. In practice, building the Widget tree is a lightweight operation compared to the whole rending cycle, so performance wise the impact is negligible.

There are some benchmark files intending to answer two questions:

1. How much slower is the ObservedMap operation overhead (not while listening a Widget's build) compared to the base LinkedHashMap?
Good benchmarks need yet to be done. Different approaches were tried, some resulted in an overhead of up to 3.5 times slower, but the latest plain read benchmark throws an overhead of 1.5 times. Note that this is negligible, it's hard to believe that reading Maps while building Widget's is more than 1% of the total build time. 
2. How much slower does the Widget build method run when being listened by Floop?

