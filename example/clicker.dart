import 'package:flutter/material.dart';
import 'package:floop/floop.dart';

void main() {
  floop['clicks'] = 0;
  runApp(
    MaterialApp(
      title: 'Task Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Clicker()
    )
  );
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
          ))
        ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => floop['clicks']++
      ),
    );
  }
}


// The following are alternative implementations of the same

class ClickerStateful extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => ClickerState();
}

class ClickerState extends State<ClickerStateful> with FloopStateMixin {
  @override
  Widget buildWithFloop(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          floop['clicks'].toString(),
          style: TextStyle(
            color: Colors.red,
            fontSize: 100,
          ))
        ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => floop['clicks']++
      ),
    );
  }
}


void mainSimple() {
  floop['clicks'] = 0;
  runApp(
    MaterialApp(
      title: 'Task Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SimpleClicker()
    )
  );
}

class SimpleClicker extends StatelessWidget with Floop {

  @override
  Widget buildWithFloop(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Text(floop['clicks'].toString())
        ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => floop['clicks']++
      ),
    );
  }
}
