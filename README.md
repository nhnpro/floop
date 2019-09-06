# Floop

Dynamic values for Flutter widgets. Allows building interactive apps using purely Stateless Widgets. Inspired by [react-recollect](https://github.com/davidgilbertson/react-recollect).

### How to use

- Add `with Floop` at the end of the widget class definition
- Read any value from `floop` and the widget will reactively update on changes to the value

Example:

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

Extra step:
- Use `transition(ms)` within the build method to have a value transition from 0 to 1 in `ms` milliseconds.

On Stateful widgets use: `...with FloopStateful`.

Note when reading the readme: the behavior of the library is explained by referring to `floop`, which is just an instance of [ObservedMap], the same behavior that applies to `floop` applies to any other instance of [ObservedMap].

## Suggested use cases

- Store data that affects many widgets (eg. user data).

- Asynchronous operations like data fetching. Conditionally check `floop['myData'] == null ? LoadingWidget() : DisplayDataWidget(floop['myData'])`.

- Perform simple animations.

## Install

Add floop dependency to the project's `pubspec.yaml`

```yaml
depedencies:
  floop:
```

Run `flutter pub get` in the root directory of the project.

## <a name="transitions">Transitions and Animations</a>

All floop widgets can be easily animated using [transition], which returns a [double] that will go from 0 to 1 in the specified time. Example:

```dart
@override
Widget build(BuildContext context) {
  return Opacity(
    opacity: transition(3000), // transitions a number from 0 to 1
    child: Container(
      Text('Text will completely appear after 3 seconds')),
  );
}
```

[transition] reads internally from an [ObservadMap] instance, being basically a shortcut of what would be writing `...opacity: floop['opacityValue']` and creating an asynchronous callback that updates `floop['opacityValue']`.

**Disclaimer about animations** (to be updated when more knowledge is acquired): I have not digged into the Flutter animations API, neither have I used it. I suspect animated widgets work directly on an internal layer of the framework that makes them quite more efficient than regular widgets when updating. Making a fully animated app with Floop is possible as it can be corroborated with the examples, however I cannot ensure this is the best idea, since there is an overhead that would be unnecesary with a specialized API. What I can ensure for now is that it is perfectly fine to use [transition] for simple sporadic animations, that's what it is designed for. The great advantage is that it is flexible and easy to use.
If someone creates a fully animated app using this library and compares its performance to an equivalent app using Flutter Animations, please message me.

## <a name="special">Special Considerations</a>

### Builders

Dynamic values do not work inside [Builder] functions. A workaround is to read the dynamic values outside of the `builder` definition. Example:

**Works fine:**

```dart
  @override
  Widget build(BuildContext context) {
    final opacity = transition(3000);
    final text = floop[myText];
    return Builder(
      builder: (context) => Opacity(
        opacity: opacity,
        child: Container(
          Text(text),
      );
    );
  }
```

**Should not do:**

```dart
@override
Widget build(BuildContext context) {
  return Builder(
    builder: (context) => Opacity(
      // This is an assertion error, [transition] cannot be used outside
      // a Floop widget's build method.
      opacity: transition(3000),
      child: Container(
        // The widget will not update if floop[myText] changes.
        Text(floop[myText])),
    );
  );
}
```

Reading a value from `floop` inside a [Builder] does not subscribe the value to the context used by the builder, because the builder function is a callback that executes outside of the encompassing [build] method.


### Transitions and Keys in Stateless Widgets

Use keys on widgets that invoke [transition] when the following conditions are met:

- The widgets belong to the same array of children widgets `...children: [widget1, widget2,...],`
- They belong to the same class (more precisely, they have equal [Object.runtimeType])
- The list of children can be reordered

Which are the same conditions when keys should be used on Stateful widgets.

Reasoning: Keys are not normally useful in stateless widgets, because when the widgets are reordered, it doesn't matter if they get rebuilt from another context, there is nothing on a context that could affect their build output. When using Floop's transitions API, the transitions are internally associated with the context that created them. If a list of children with no keys defined is reordered, the contexts do not get reordered. As a result, the widgets will not rebuild using their original transitions, but rather the transition that exists in the context from where they are getting rebuilt. When using keys, the widgets are paired with their corresponding contexts and they correctly reorder together.

## <a name="details">Details</a>

### ObsevedMap

`floop` is an instance of [ObservedMap], which implements [Map]. Other instances can be created in the same way as any map is created, e.g: `Map<String, int> myDynamicInts  = ObservedMap()`.

Widgets only subscribe to the keys **read during the last build**. This is consistent, if a key is not read during the last build, a change on it's value has no impact on the widget's build output.

### Maps and Lists

[Map] and [List] values are not stored as they are when using `[]=` operator, but rather they get deep copied. Every [Map] gets copied as an [ObservedMap] instance, while lists get copied using [List.unmodifiable]. This behavior gives consistency to [ObservedMap], by ensuring that either the values cannot be changed or if they change, the changes will be detected to update elements accordingly.
Maps and lists can still be stored as they are by using the method [ObservedMap.setValue]. It also receives optional parameter to prevent triggering updates on elements.

### Initializing and Disposing a Context

[Floop.initContext] is invoked by an [Element] instance when it's added for the first time to the element tree.

[Floop.disposeContext] is invoked by an [Element] instance when it's unmounted (removed from tree to never be used again).

Those methods would be the equivalent of what [State.init] and [State.dispose] are.
It can be useful to override them to for example initialize or dispose dynamic values in `floop` that are only used by the widget. Be careful not to write values of existing keys that are subscribed to other widgets, as it would trigger a rebuild when it is not allowed, causing a Flutter error.


## <a name="performance">Performance</a>

As performance rules of thumb:

- Including [Floop] on a widget is far less impactful than wrapping a widget with another widget as child.
- Reading one value from `floop` inside a build method is like reading five [Map] values

The only impact Floop has on a widget is to its build time, which does not go beyond x1.2 on minimal widgets (a container, a button and a text). On the other hand, wrapping a widget with another widget implies having to perform another build during the element's tree building phase, causing a net build impact time of about x2 for small widgets. Besides from that, there is no impact that goes beyond the widget's build time, while wrapping widgets increases the size of the element tree.

The following build time increases can be considered as rough references when comparing reading data from an [ObservedMap] in Floop widgets, to reading the same data from a [LinkedHashMap] in widgets without Floop. Only integer numbers were used as keys and values. It was also assumed that the same context would access the same keys on every invocation to [StatelessWidget.build]. It's a bit more expensive when there are different keys read, but that should be an uncommon case.

On small Widgets (less than 10 lines in the build method), including Floop implies the following performance hits in build times:
- x1.15 when 0 values are read.
- x1.9 when up to 5 values are read.
- x2.9 when up to 20 values are read.

On medium Widgets:
- x1.1 when 0 values are read.
- x1.6 when up to 5 values are read.
- x2.5 when up to 20 values are read.

The more values that are read,the more the `Map.[]` operation starts becoming the bottleneck of the Widget's build time even when reading from a regular [Map] and so the performance hit starts approaching the difference between reading from a [Map] and an [ObservedMap] while listening. The performance hit when reading from an [ObservedMap] in comparison to a regular [LinkedHashMap] is the following:

- x1.1 using the map like a regular map (outside build methods).
- x3 while Floop is on 'listening' mode (when a Widget is building).
- x5 considering the whole preprocessing (start listening) and post processing (stop listening), which means preparing to listen and commiting all the reads that were 'observed' during the build of a widget.

The x5 performance hit is reasonable considering the amount of operations every read to an [OberservedMap] object implies for the whole build cycle. Additionally from retrieving the value, **at least** there is a secondary map read, a value added to a set and a value retrieved from a set. With only those extra operations (total of four `Map.[]` like operations instead of one) the minumum possible overhead is x4, but there is also conditional checks, function calls and iterations.

Generally the performance hit increases slightly with the amount of data read, for example it's about x4.8 for 10^4 values and x5.5 for 10^5 values read.

### Writing performance
Writing to an [ObservedMap] has a performance hit of x3.2 in all circumstances, disregarding the extra time that takes Flutter to run [Element.markNeedsBuild] in case there are widgets subscribed to the key that changed it's value.

## Collaborate
Write code, report bugs, give advice or ideas to improve the library.
