# Floop

Dynamic values for Flutter widgets. Inspired by [react-recollect](https://github.com/davidgilbertson/react-recollect).

Floop removes any complexity related with data changes that need to be displayed, change the data and all widgets that use it will automatically refresh. Build a whole interactive app using purely stateless widgets.

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

The example above displays everything required to use the library, keep reading to learn more [details](#details), but it's not necessary. Full example [here](../master/examples/clicker.dart).

`floop` is just an instance of an [ObservedMap] that comes with the library, but any number of [ObservedMap] can be created instead, for example: `Map<String, int> myDynamicInts = ObservedMap()`.

On Stateful widgets: `...extends FloopState` (the Widget itself is left unchanged).

## Install

Add floop dependency to your project's `pubspec.yaml`

```yaml
depedencies:
  floop: any
```

Run `flutter pub get` in the root folder of your project.

## Advantages of using Floop

- There is no learning curve.

- It's an intuitive way of building UI, the UI shows whatever the current value of the variable is.

- When data that is common to the whole app changes (for example user data), automatically all widgets that use that data get updated.

- Automatically the widgets become animatable. Easily achieve simple animations on any widget you wish. A transitions comes bundled in with the library.

- Eliminates the added complexity of having to learn concepts to deal with async events, like StreamBuilders. Store the async data on `floop` and conditionally check `floop['myData'] == null ? LoadingWidget() : DisplayDataWidget(floop['myData'])`. [Example](../master/examples/image_list.dart)

## <a name="details">Details</a>

`floop` is an instance of [ObservedMap], which implements [Map]. create alternative 'stores' doing `Map myStore = ObservedMap()` ([Map<K, V>] also possible).

Widgets only subscribe to the keys **read during the last build**. This means that keys that were read in a previous build that for example are used inside conditions that didn't trigger, will not get "subscribed" to the widget and will therefore not update the widget. This is consistent, if a key is not read during the last build, a change on it's value has no impact on the widget's buildWithFloop output.

[Map] and [List] values will not be stored as they are, but rather they'll get deep copied (automatically). Every [Map] gets copied as an [ObservedMap] instance, while lists get copied using [List.unmodifiable]. Maps and Lists can be stored as they are using the method [ObservedMap.setValueRaw], however by doing so the values inside the Map or List will not update Widgets when they change.

Performance hit by using [Floop] shouldn't be an issue. However, when attempting to optimize the app, switch from the [Floop] mixin to [FloopLight] mixin whenever possible. [FloopLight] only allows listening to one [ObservedMap] during each Widget's build. This should satisfy most use cases, but it's uncompatible with transitions API if also reading from an [ObservedMap] while building the widget.

## <a name="performance">Performance</a>
As a rule of thumb, including Floop in a Widget can be considered (being pessimistic) as wrapping the Widget with a small Widget. In practice it's better than that, because there is only one widget, so there is not impact that goes beyond the Widget's build time. It also has to be considered that a Widget's build time is far from being the bottleneck of the rendering process in Flutter. Even an order of magnitude of performance hit in the Widgets build time might go unnoticed.

The following performance impact exist on the Floop Widget build time when reading data from an [ObservedMap], compared to building the Widget without Floop and reading the same data from a [LinkedHashMap]. Bear in mind these are rough numbers, the benchmarks had quite some variability and they depend on the device where they are run.

In very small Widgets (less than 10 lines in the build method), including Floop implies the following performance hit in build time:
- x1.6 when Floop is included, but no value is read from an ObservedMap.
- x4.5 when up to 5 values are read.
- x7 when up to 20 values are read.

In medium Widgets:
- x1.35 when Floop is included, but no value is read from an ObservedMap.
- x3 when up to 5 values are read.
- x4.5 when up to 20 values are read.

If more values are read, the [Map] read operation starts becoming the bottleneck of the Widget's build time even when reading from a regular [Map] and so the performance hit starts approaching the difference between reading from a [Map] and an [ObservedMap] while listening. The performance hit when reading from an [ObservedMap] in comparison to a regular [LinkedHashMap] is the following:

- x1.25 using the map like a regular map.
- x2.5 while Floop is on 'listening' mode (when a Widget is building).
- x5 - x8 considering the whole preprocessing (start listening) and post processing (stop listening), which means preparing to listen and commiting all the reads that were 'observed' during the build of a widget.

Benchmarks have quite some variability on each run, it depends if debugging or not, the type of data being written or read, the amount of data, etc. Generally the performance hit is proportional to the amount of data read, converging at about x7 for 100 values read, then it increases logarithmically (x8 for 100000 thousand).

For optimizing the app, the alternative [FloopLight] mixin can be used, which converges at about x4 build time increase (less than 2x for few values). It has the limitation of being able to read from at most one ObservedMap (any number of values can be read) during `buildWithFloop`. FloopLight should satisfy most use cases, as normally just a few values (one or two) are read from only one [ObservedMap]. It's not the default mixin to make Floop safe in any use case and avoid users from having unexpected errors.

### Writing performance
Writing to an [ObservedMap] has a rough performance hit of x3.2 in all circumstances, unless there are widgets subscribed to the key, in which case there is the extra time that takes Flutter to run [Element.markNeedsBuild]. This time is not counted, since that method would be called anyways to update the Widget.

## Collaborate
Feel free to collaborate, report bugs, give advice or ideas to improve the library.
