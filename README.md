# Floop

Animation API and dynamic values for Flutter widgets. Allows building interactive apps using purely Stateless Widgets. Inspired by [react-recollect](https://github.com/davidgilbertson/react-recollect).

### How to use

- Add `with Floop` at the end of the widget class definition
- Read any value from `floop` and the widget will reactively update on changes to the value

**Extra step**:
- Use `transition(ms)` within the build method to have a value transition from 0 to 1 in `ms` milliseconds.

Example:

```dart
-class Clicker extends StatelessWidget {
+class Clicker extends StatelessWidget with Floop {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Text widget always displays the current value of #clicks
      body: Center(
        child: Opacity(
          opacity: transition(2000),
          child: Text('${floop[#clicks]}'),
        )
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          // change #clicks from anywhere in the app (except build methods)
          floop[#clicks]++;
          Transitions.restart(context: context);
        }),
      ),
    );
  }
}
```

**Other options**:
- [DynamicWidget] is a convenient Floop widget that has it's own map of dynamic values accessed through [dyn].
- `... extends StatelessWidget with Floop` is equivalent to `... extends FloopWidget`.
- `...extends StatefulWidget with FloopStateful` or extend [FloopStatefulWidget] for stateful widgets.
- Maps of dynamic values like `floop` can be instantiated using [DynMap].

## Suggested use cases

- Store data that affects many widgets (eg. user data).

- Asynchronous operations like data fetching. Conditionally check `floop['myData'] == null ? LoadingWidget() : DisplayDataWidget(floop['myData'])`.

- Animate widgets.

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

[Transitions] class offers a set of static methods to manipulate created transitions. They can be resumed, reversed, time shifted, paused, restarted, canceled, etc. This operations can be performed selectively by [BuildContext], key and/or tag of the transitions.

**Disclaimer about animations** : The performance of animations has not been benchmarked against the regular Flutter animations. If someone creates a fully animated app using this library and compares its performance to an equivalent app using Flutter Animations, please message me.

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
      // Error, [transition] cannot be invoked outside a Floop widget's build.
      opacity: transition(3000),
      child: Container(
        // The widget will not update if floop[myText] changes.
        Text(floop[myText])),
    );
  );
}
```

The builder function is a callback that executes outside of the encompassing Floop widget's [build] method and Floop does not listen to these builds.

### Transitions and Keys in Stateless Widgets

Use keys on widgets that invoke [transition] when the following conditions are met:

- The widgets belong to the same array of children widgets `...children: [widget1, widget2,...],`
- They have the same widget class
- The list of children is sometimes be reordered

They are the same conditions when keys should be used on Stateful widgets.

## <a name="details">Details</a>

### ObsevedMap

`floop` is an instance of [DynMap], which implements [Map]. Other instances can be created in the same way as any map is created, e.g: `Map<String, int> myDynInts  = DynMap()`.

Widgets only subscribe to the keys **read during the last build**. This is consistent, if a key is not read during the last build, a change on it's value has no impact on the widget's build output.

### Maps and Lists

[Map] and [List] values are not stored as they are when using `[]=` operator, but rather they get deep copied. Every [Map] gets copied as an [DynMap] instance, while lists get copied using [List.unmodifiable]. This behavior ensures that either the values cannot be changed or if they change, the changes will be detected to update elements accordingly.
Maps and lists can still be stored as they are by using the method [DynMap.setValue]. It also receives optional parameter to prevent triggering updates.

### Initializing and Disposing a Context

[Floop.initContext] is invoked by an [BuildContext] instance when it's added for the first time to the element tree.

[Floop.disposeContext] is invoked by an [BuildContext] instance when it's unmounted (removed from tree to never be used again).

Those methods would be the equivalent of what [State.init] and [State.dispose] are. They can be overriden to initialize or dispose dynamic values.

## <a name="performance">Performance</a>

Performance rules of thumb:

- Including [Floop] on a widget is far less impactful than wrapping a widget with another widget as child.
- Reading one value from `floop` inside a build method is like reading five [Map] values

The only impact Floop has on a widget is to its build time, which does not go beyond x1.2 on minimal widgets (a container, a button and a text). On the other hand, wrapping a widget with another widget implies having to perform another build during the element's tree building phase, causing a net build impact time of about x2 for small widgets.

These build time increases can be considered as rough references when comparing reading data from a [DynMap] in Floop widgets, to reading the same data from a [LinkedHashMap] in widgets without Floop. Only integer numbers were used as keys and values. It was also assumed that the same context would access the same keys on every invocation to [StatelessWidget.build]. It's more expensive when there are different keys read, but that should be an uncommon case.

On small Widgets (less than 10 lines in the build method), including Floop implies the following performance hits in build times:
- x1.15 when 0 values are read.
- x1.9 when up to 5 values are read.
- x2.9 when up to 20 values are read.

On medium Widgets:
- x1.1 when 0 values are read.
- x1.6 when up to 5 values are read.
- x2.5 when up to 20 values are read.

The performance hit when reading from an [DynMap] in comparison to a regular [LinkedHashMap] is the following:

- x1.1 using the map like a regular map (outside build methods).
- x3 while Floop is on 'listening' mode (when a Widget is building).
- x5 considering the whole preprocessing (start listening) and post processing (stop listening), which means preparing to listen and commiting all the reads that were detected during the build of a widget.

Generally the performance hit increases slightly with the amount of data read, for example it's about x4.8 for 10^4 values and x5.5 for 10^5 values read.

### Writing performance
Writing to a [DynMap] has a performance hit of x1.6 in all circumstances, disregarding the extra time that takes Flutter to run [Element.markNeedsBuild] in case there are widgets subscribed to the key that changed it's value.

## Collaborate
Write code, report bugs, give advice or ideas to improve the library.
