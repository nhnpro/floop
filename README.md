# Floop

A super easy state management for flutter (forget about state management). Inspired by [react-recollect](https://github.com/davidgilbertson/react-recollect).

Floop uses an observed 'global store' state management paradigm. Widgets will always display the current value in the store. With Floop it's possible to build a whole interactive app using purely stateless widgets.

### Example

```diff
-class Clicker extends StatelessWidget {
+// class Clicker extends StatefulWidget with FloopState {
+class Clicker extends StatelessWidget with Floop {

  @override
-Widget build(BuildContext context)
+Widget buildWithFloop(BuildContext context) {
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

That's all you need to know to use Floop, you can keep reading to learn more details, but it's not necessary. 

Any kind of values can be kept in the global store `floop`.
## Why use Floop

- It's an intuitive way of building UI. It's a matter of taste, but many people expect that if they add a component `Text(floop['myText'])`, the UI would always display the value that is on `floop['myText']`. If not expected, it's at least desired.
- There is no learning curve. Anyone can use it and understand it immediately, the example above is all there is.
- Build animations completely decoupling the component from the animation itself. You may create oscillating values with a certain periodicity once and then use those values many times in the widgets you want to animate. [Example](url).



## Install

Add floop dependency to your project's `pubspec.yaml`

```yaml
depedencies:
  floop: any
```

Run `flutter pub get` in the root folder of your project.

## Details

[Map] and [Iterable] values will not be stored by reference, but rather they'll get deep copied (automatically), so be careful not to store structs where values have themselves values that point to their parent struct.



## Performance

