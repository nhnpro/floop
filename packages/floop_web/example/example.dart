import 'package:flutter_web/material.dart';
import 'package:floop_web/floop_web.dart';

/// This example exists solely to satisfy dart publishing requirements.
/// The real examples folder lies at the root of the project on Github.
/// https://github.com/icatalud/floop

void main() {
  floop['clicks'] = 0;
  runApp(MaterialApp(
      title: 'Clicker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Clicker()));
}

class Clicker extends StatelessWidget with Floop {
  @override
  Widget buildWithFloop(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          floop['clicks'].toString(),
          style: TextStyle(
            color: Colors.red,
            fontSize: 100,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add), onPressed: () => floop['clicks']++),
    );
  }
}

// The following are alternative implementations.

class ClickerStateful extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => ClickerState();
}

class ClickerState extends State<ClickerStateful> with FloopStateMixin {
  @override
  Widget buildWithFloop(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Text(floop['clicks'].toString(),
              style: TextStyle(
                color: Colors.red,
                fontSize: 100,
              ))),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add), onPressed: () => floop['clicks']++),
    );
  }
}

// Simplest example.

class SimpleClicker extends StatelessWidget with Floop {
  @override
  Widget buildWithFloop(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(floop['clicks'].toString())),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add), onPressed: () => floop['clicks']++),
    );
  }
}
