# Floop

An automatic Widget refresh library for Flutter. Inspired by [react-recollect](https://github.com/davidgilbertson/react-recollect). Alternative approach for state management.

Floop uses an observed 'global store' state management paradigm. Widgets will always display the current value in the store. With Floop it's possible to build a whole interactive app using purely stateless widgets, reducing the complexity overhead of having to learn new concepts or widgets when dealing with data changes that need to be displayed.

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

The example above displays everything required to use the library, keep reading to learn more [details](#details), but it's not necessary. Full example [here](../master/example/clicker.dart).

Any kind of values can be kept in the [ObservedMap] `floop`, it implements [Map]. Own [ObservedMap]s can be created instead: `Map myStore = ObservedMap()`.

On Stateful widgets: `...extends State with FloopStateMixin` (the Widget itself is left unchanged).

## Install

Add floop dependency to your project's `pubspec.yaml`

```yaml
depedencies:
  floop: any
```

Run `flutter pub get` in the root folder of your project.

## Advantages of using Floop

- There is no learning curve. Other state management libraries (e.g. Redux) require grasping concepts like actions, reducers, observers, etc. Floop is understood immediately, the example above is all there is.

- It's an intuitive way of building UI. Many developers expect that when they add a component `Text(myText)`, the UI will display whatever value is set on the var myText. That's exactly what happens when doing `Text(floop['myText'])`.

- When data that is common to the whole app changes (for example user data), automatically all widgets that use that data get updated. One less problem to worry about.

- Loading and displaying data asynchronously (http requests) simplified. There is no need to use more complex objects like StreamBuilders to handle these cases. Store the async data on `floop` and conditionally check `floop['myData'] == null ? LoadingWidget() : DisplayDataWidget(floop['myData'])`. [Example](../master/example/image_list.dart)

- It's efficient and has good performance (see [performance](#performance)), it only updates the widgets that need to be updated, being an advantage over having few StatefulWidgets that propagate data changes down the Widget tree, causing a whole branch of the tree to update.

- Easily make simple animations. Animations can be completely decoupled from the component, allowing the common basic stateless components to be used by reading values that will be changing. For example create oscillating values (like colors, position, size), save them in the store and read those values in the widgets `buildWithFloop`. [Animation example](../master/example/animated_icons.dart). In the [play store](https://play.google.com/store/apps/details?id=com.icatalud.animaticon).

## <a name="details">Details</a>

`floop` is an instance of [ObservedMap], which implements [Map]. create alternative 'stores' doing `Map myStore = ObservedMap()` ([Map<K, V>] also possible).

Widgets only subscribe to the keys **read during the last build**. This means that keys that were read in a previous build that for example are used inside conditions that didn't trigger, will not get "subscribed" to the widget and will therefore not update the widget. This is consistent, if a key is not read during the last build, a change on it's value has no impact on the widget's buildWithFloop output.

[Map] and [List] values will not be stored as they are, but rather they'll get deep copied (automatically). Every [Map] gets copied as an [ObservedMap] instance, while lists get copied using [List.unmodifiable]. Maps and Lists can be stored as they are using the method [ObservedMap.setValueRaw], however by doing so the values inside the Map or List will not update Widgets when they change.

## <a name="performance">Performance</a>
As a rule of thumb, including Floop in a Widget can be considered (being pessimistic) as wrapping the Widget with a small Widget. In practice it's better than that, because there is only one widget, so there is not impact that goes beyond the Widget's build time. It also has to be considered that a Widget's build time is far from being the bottleneck of the rendering process in Flutter. Even an order of magnitude of performance hit in the Widgets build time might go unnoticed.

The following performance impact exist on the Widget build time compared to building the same Widget without Floop but reading the same data from a LinkedHashMap (imagine StatefulWidgets that would call setState manually).

In very small Widgets (less than 10 lines in the build method), including Floop implies the following performance hit in build time:
- x1.15 when Floop is included, but no value is read from an ObservedMap. This implies that including Floop 'just in case' in every Widget is almost negligible.
- x3 when up to 5 values are read.

In medium Widgets:
- x1 or negligible performance hit when Floop is included, but no value is read from an ObservedMap.
- x3 when up to 15 values are read.

If more values are read, the Map read operation starts becoming the bottleneck of Widget's build time even when reading from a regular Map. The more values are read from the Map, the more the performance hit approaches the difference between reading from a Map and an ObservedMap while listening. The performance hit when reading from an ObservedMap in comparison to a regular LinkedHashMap is the following:

- x1.25 using the map like a regular map.
- x2.5 while Floop is on 'listening' mode (when a Widget is building).
- x5 - x8 considering the whole preprocessing (start listening) and post processing (stop listening), which means preparing to listen and commiting all the reads that were 'observed' during the build of a widget.

Benchmarks have quite some variability on each run, it depends if debugging or not, the type of data being written or read, the amount of data, etc. Generally the performance hit is proportional to the amount of data read, converging at around x7 (for 100000 thousand values read).

To reduce the impact in build time, there is an alternative [FloopLight] mixin that can be used, which has the limitation of being able to read from at most one ObservedMap (any number of values can be read) during `buildWithFloop`. FloopLight should satisfy most use cases, as normally just a few values (one or two) are read from only one [ObservedMap]. It's not the default mixin to make Floop safe in any use case and avoid users from having unexpected errors.

### Writing performance
Writing to an [ObservedMap] has a rough performance hit of x3.2 in all circumstances, unless there are widgets subscribed to the key, in which case there is the extra time that takes Flutter to run [Element.markNeedsBuild]. This time is not counted, since that method would be called anyways to update the Widget.

## Collaborate
Feel free to collaborate, report bugs, give advice or ideas to improve the library.
