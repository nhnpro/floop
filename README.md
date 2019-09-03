# Floop

Dynamic values for Flutter widgets. Allows building interactive apps using purely Stateless Widgets. Inspired by [react-recollect](https://github.com/davidgilbertson/react-recollect).

### Example - How to use

```dart
-class Clicker extends StatelessWidget {
+class Clicker extends StatelessWidget with Floop {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Text widget always displays the current value of 'clicks'
      body: Center(
        child: Text(floop['clicks'].toString())
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        // change 'clicks' from anywhere in the app (except build methods)
        onPressed: () => floop['clicks']++,
      ),
    );
  }
}
```

Steps:

- Add `with Floop` at the end of the widget class definition or extend `FloopWidget`
- Read any value from `floop` [ObservedMap] and the widget will reactively update on changes to the value

Extra step:
- Use `transition(ms)` within the build method to have a value transition from 0 to 1 in `ms` milliseconds. See [transitions](#transitions) for more information.

On Stateful widgets: `...extends FloopState` (the Widget itself is left unchanged).

## Install

Add floop dependency to your project's `pubspec.yaml`

```yaml
depedencies:
  floop:
```

Run `flutter pub get` in the root directory of the project.

## Suggested use cases

- Store data that affects many widgets (eg. user data).

- Asynchronous operations like data fetching. Conditionally check `floop['myData'] == null ? LoadingWidget() : DisplayDataWidget(floop['myData'])`.

- Perform simple animations.

## <a name="transitions">Transitions and Animations</a>

All floop widgets can be easily animated using [transition]. Example:

```dart
@override
Widget build(BuildContext context) {
  return Opacity(
    opacity: transition(3000),
    child: Container(
      Text('Text will completely appear after 3 seconds')),
  );
}
```

**Disclaimer about animations** (to be updated when more knowledge is acquired): I have not digged into the Flutter animations API, neither have I used it. I suspect animated widgets work directly on an internal layer of the framework that makes them quite more efficient than regular widgets when updating. Making a fully animated app with Floop is possible as it can be corroborated with the examples, however I cannot ensure this is the best idea, since there is an overhead that would be unnecesary with a specialized API. What I can ensure for now is that it is perfectly fine to use [transition] for simple sporadic animations, that's what it is designed for. The great advantage is that it is flexible and easy to use.

## <a name="special">Special notes</a>

### Builders
Reading a value from `floop` inside a [Builder] does not subscribe the value to the [Element] instance created by the Builder, because the builder function is a callback that executes outside of the encompassing [build] method. The workaround is to read first the values from `floop` outside of the builder callback. The same goes for transitions. For example:

```dart
@override
Widget build(BuildContext context) {
  floop['myBuilderValue']
  return Opacity(
    opacity: transition(3000),
    child: Container(
      Text('Text will completely appear after 3 seconds')),
  );
}
```


### Builders


## <a name="details">Details</a>

`floop` is an instance of [ObservedMap], which implements [Map]. create alternative 'stores' doing `Map myStore = ObservedMap()` ([Map<K, V>] also possible).

Widgets only subscribe to the keys **read during the last build**. This is consistent, if a key is not read during the last build, a change on it's value has no impact on the widget's build output.

[Map] and [List] values are not stored as they are, but rather they get deep copied when using `[]=` operator. Every [Map] gets copied as an [ObservedMap] instance, while lists get copied using [List.unmodifiable].
Maps and lists can be stored as they are using the method [ObservedMap.setValue], but changes on them will not trigger updates on widgets. [ObservedMap.setValue] also has the option to stop widgets from updating when setting the value.

## <a name="performance">Performance</a>
As a rule of thumb, including Floop in a Widget can be considered (being pessimistic) as wrapping the Widget with a small Widget. In practice it's better than that, because there is only one widget, so there is not impact that goes beyond the Widget's build time. It also has to be considered that a Widget's build time is most likely not being the bottleneck of the rendering process in Flutter. Even an order of magnitude of performance hit in the Widgets build time could have no perceivable impact.

The following build time increase can be considered as a rough reference when comparing reading data from an [ObservedMap] in Floop widgets, to reading the same data from a [LinkedHashMap] in widgets without Floop. These are rough numbers, the benchmarks have quite some variability and they depend on many factors. It is considered that the widgets are accesing the same keys on every build, if there are differences, it's a bit more expensive, but that should be an uncommon case.

On very small Widgets (less than 10 lines in the build method), including Floop implies the following performance hit in build time:
- x1.15 when 0 values are read.
- x1.9 when up to 5 values are read.
- x2.9 when up to 20 values are read.

On medium Widgets:
- x1.1 when 0 values are read.
- x1.6 when up to 5 values are read.
- x2.5 when up to 20 values are read.

The more values that are read,the more the [Map] read operation starts becoming the bottleneck of the Widget's build time even when reading from a regular [Map] and so the performance hit starts approaching the difference between reading from a [Map] and an [ObservedMap] while listening. The performance hit when reading from an [ObservedMap] in comparison to a regular [LinkedHashMap] is the following:

- x1.1 using the map like a regular map (outside build method).
- x3 while Floop is on 'listening' mode (when a Widget is building).
- x5 considering the whole preprocessing (start listening) and post processing (stop listening), which means preparing to listen and commiting all the reads that were 'observed' during the build of a widget.

Generally the performance hit increases logarithmically with the amount of data read, about x4.8 for 10^4 values, x5.5 for 10^5 values read. 

### Writing performance
Writing to an [ObservedMap] has a rough performance hit of x2.4 in all circumstances, unless there are widgets subscribed to the key, in which case there is the extra time that takes Flutter to run [Element.markNeedsBuild]. This time is not counted, since that method would be called anyways to update the Widget.

## Collaborate
Write code, report bugs, give advice or ideas to improve the library.
