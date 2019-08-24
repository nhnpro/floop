import 'package:floop/internals.dart';
import 'package:flutter/material.dart';
import 'package:floop/floop.dart';

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

// The following are alternative implementations of the same Widget

class ClickerStateful extends FloopStatefulWidget {
  @override
  FloopState<ClickerStateful> createState() => ClickerState();
}

class ClickerState extends FloopState<ClickerStateful> {
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

void mainSimple() {
  floop['clicks'] = 0;
  runApp(MaterialApp(
      title: 'Clicker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SimpleClicker()));
}

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
