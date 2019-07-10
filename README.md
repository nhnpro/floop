# Floop

An automatic Widget refresh library for flutter. Inspired by [react-recollect](https://github.com/davidgilbertson/react-recollect). Alternative approach for state management.

Floop uses an observed 'global store' state management paradigm. Widgets will always display the current value in the store. With Floop it's possible to build a whole interactive app using purely stateless widgets.

### Example

```diff
-class Clicker extends StatelessWidget {
+class Clicker extends StatelessWidget with Floop {
+// class ClickerState extends State with FloopState { 

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

The example above displays everything required to use the library, you may keep reading to learn more [details](#details)), but it's not necessary. See the full example [here](../master/example/clicker.dart).

Any kind of values can be kept in the global store `floop`. Own stores can be created by `Map myStore = ObservedMap()` instead of using the built in store `floop`.

## Install

Add floop dependency to your project's `pubspec.yaml`

```yaml
depedencies:
  floop: any
```

Run `flutter pub get` in the root folder of your project.

## Advantages of Using Floop

- It's an intuitive way of building UI. Many people expect that when they add a component `Text(myText)`, the UI will display whatever value is set on the var myText. That's exactly what happens if you do `Text(floop['myText'])`.

- When data that is common for the whole app changes (for example user data), automatically all widgets that use that data get updated, so there is one thing less to worry about.

- There is no learning curve. It can be understood immediately, the example above is all there is.

- It's efficient and has good performance (see [performance](#performance)), it only updates the widgets that need to be updated, being an advantage over having few StatefulWidgets that cause a whole branch of the Widget tree to update.

- Easily make simple animations. Animations can be completely decoupled from the component, allowing the common basic stateless components to be used by reading values that will be changing. For example create oscillating values (like colors, position, size), save them in the store and read those values in the widgets that require animation. A convenient class [Repeating] is included in the library to repeatedly call a function with any given frequency. [Animation example](../master/example/animated_icons.dart). In the [play store](https://play.google.com/store/apps/details?id=com.icatalud.animaticon).

## <a name="details">Details</a>

`floop` is an instance of [ObservedMap], which implements [Map]. create alternative 'stores' doing `Map myStore = ObservedMap()` ([Map<K, V>] also possible).

Widgets only subscribe to the keys **read during the last build**. This means that keys that were read in a previous build that for example are used inside conditions that didn't trigger, will not get "subscribed" to the widget.

[Map] and [List] values will not be stored as they are, but rather they'll get deep copied (automatically). Every [Map] will be copied as an [ObservedMap] instance, while lists get copied using [List.unmodifiable]. Maps and Lists can be stored as they are using the method [ObservedMap.setValueRaw], however by doing so the values inside the Map or List will not update Widgets when they change.

## <a name="performance">Performance</a>
As a rule of thumb, including Floop in a Widget can be considered (being pessimistic) as wrapping the Widget with another Widget. In practice it's better than that, because there is only one widget, so there is not impact that goes beyond the Widget's build time. It also has to be considered that the widget build time is far from being the bottleneck of the rendering process in Flutter. Even an order of magnitude of performance hit in the Widget build time would likely be unnoticeable.

The following performances impact exist in the Widget build time compared to StatefulWidgets that would call setState manually.

In a small Widget, including Floop implies the following performance hit in build time:
- x1.15 when Floop is included, but no value is read from the an ObservedMap.
- x2 when up to 5 values are read.

In medium Widgets:
- x1 or negligible performance hit when Floop is included, but no value is read from the an ObservedMap.
- x2 when up to 15 values are read.

If more values are read, the Map read operation starts becoming the bottleneck of Widget build time even when reading from a regular Map. The more values are read from the Map, the more the performance hit approaches the difference between reading from a Map and an ObservedMap while listening. The performance hit when reading from an ObservedMap in comparison to a regular LinkedHashMap is the following:

- x1.25 using the map like a regular map.
- x2.5 while Floop is on 'listening' mode (when a Widget is building).
- x5 - x8 considering the whole preprocessing (start listening) and post processing (stop listening), which means preparing to listen and commiting all the reads that were 'observed' during the build of a widget.

Benchmarks have quite some variability, the numbers vary on each run, depending if debugging or not, the type of data being written or read, the amount of data, etc. Generally the performance hit is proportional to the amount of data read, converging around x7.

### Writing on an ObservedMap
Writing on an ObservedMap has a rough permformance hit of x3.2 in all circumstances.
