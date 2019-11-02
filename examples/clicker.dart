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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Opacity(
          opacity: transition(2000),
          child: Text(
            floop['clicks'].toString(),
            style: TextStyle(
              color: Colors.red,
              fontSize: 100,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () {
            floop['clicks']++;
            Transitions.restart(context: context);
          }),
    );
  }
}

// The following are alternative implementations of the same Widget

class ClickerStateful extends StatefulWidget with FloopStateful {
  @override
  State<ClickerStateful> createState() => ClickerState();
}

class ClickerState extends State<ClickerStateful> {
  @override
  Widget build(BuildContext context) {
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
  runApp(MaterialApp(title: 'Clicker', home: SimpleClicker()));
}

class SimpleClicker extends StatelessWidget with Floop {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(floop['clicks'].toString())),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add), onPressed: () => floop['clicks']++),
    );
  }
}
