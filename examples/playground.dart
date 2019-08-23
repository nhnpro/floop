import 'dart:math';

import 'package:flutter/material.dart';
import 'package:floop/floop.dart';
import 'package:floop/internals.dart';

void main() {
  floop['clicks'] = 0;
  floop['left'] = 0.0;
  floop['top'] = 0.0;
  runApp(MaterialApp(
      title: 'Clicker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const Clicker()));
}

class PositionedFloop extends StatelessWidget with Floop {
  const PositionedFloop({Key key});

  @override
  Widget buildWithFloop(BuildContext context) {
    // var x = transitionNumber(-1, 0, 6000);
    // var y = transitionNumber(-1, 0, 3000);
    // print('Alignments: $x, $y');
    return Align(
      alignment: Alignment(transitionNumber(-1, 0, 10000),
          (1 - transition(8000)) * 0.5 * sin(transition(8000) * 20 * pi)),
      child: Text(
        floop['clicks'].toString(),
        style: TextStyle(
          color: Colors.red,
          fontSize: 100,
        ),
      ),
    );
    // ]);
  }
}

class Clicker extends StatelessWidget with Floop {
  const Clicker();

  @override
  Widget buildWithFloop(BuildContext context) {
    // return LayoutBuilder(
    //     builder: (BuildContext context, BoxConstraints constraints) {
    bool reset = floop['clicks'] % 2 == 0;
    return Scaffold(
        body: reset ? Container() : const PositionedFloop(),
        // : Align(
        //     alignment: Alignment(transitionNumber(-1, 0, 6000),
        //         transitionNumber(-1, 0, 3000)),
        //     child: Text(
        //       floop['clicks'].toString(),
        //       style: TextStyle(
        //         color: Colors.red,
        //         fontSize: 100,
        //       ),
        //     ),
        //   ),
        backgroundColor: reset
            ? Colors.white
            : Color.fromRGBO(
                transitionNumber(100, 50, 2000).toInt(),
                transitionNumber(0, 100, 2000).toInt(),
                transitionNumber(20, 255, 2000).toInt(),
                0.3 + 0.2 * transition(4000)),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () {
            floop['clicks']++;
            resetTransitions(context);
            // transition(3000, callback: (double fraction) {
            //   floop['left'] = constraints.maxWidth * fraction / 2;
            // });
            // transition(3000, callback: (double fraction) {
            //   floop['top'] = constraints.maxWidth * fraction / 2;
            // });
          },
        ));
    // });
  }
}

// The following are alternative implementations of the same Widget

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
