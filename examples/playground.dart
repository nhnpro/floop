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

class BouncingNumber extends StatelessWidget with Floop {
  BouncingNumber({Key key});

  @override
  Widget buildWithFloop(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment(2 * min(0.5, transition(8000)) - 1,
              2 * max(0.5, transition(8000)) - 2),
          child: Container(
            height: 150,
            width: 180,
            color: Colors.yellow,
          ),
        ),
        Align(
          alignment: Alignment(transitionNumber(-1, 0, 10000),
              (1 - transition(8000)) * 0.5 * sin(transition(8000) * 20 * pi)),
          child: Text(
            floop['clicks'].toString(),
            style: TextStyle(
              color: Colors.red,
              fontSize: 100,
            ),
          ),
        ),
      ],
    );
  }
}

class Clicker extends StatelessWidget with Floop {
  const Clicker();

  @override
  Widget buildWithFloop(BuildContext context) {
    return Scaffold(
        body: BouncingNumber(),
        // body: Stack(
        //   children: [
        //     Align(
        //       alignment: Alignment(2 * min(0.5, transition(8000)) - 1,
        //           2 * max(0.5, transition(8000)) - 2),
        //       child: Container(
        //         height: 150,
        //         width: 180,
        //         color: Colors.yellow,
        //       ),
        //     ),
        //     BouncingNumber(),
        //   ],
        // ),
        backgroundColor: Color.fromRGBO(
            transitionNumber(100, 50, 500).toInt(),
            transitionNumber(0, 100, 500).toInt(),
            transitionNumber(20, 255, 1000).toInt(),
            0.3 + 0.2 * transition(1000)),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () {
            floop['clicks']++;
            resetContextTransitions(context);
            if (floop['clicks'] % 5 == 0) {
              clearAllTransitions();
            }
          },
        ));
  }
}

// The following are alternative implementations of the same Widget

class ClickerStateful extends FloopStatefulWidget {
  @override
  FloopState<FloopStatefulWidget> createState() => ClickerState();
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
