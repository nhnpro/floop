import 'dart:math';

import 'package:flutter/material.dart';
import 'package:floop/floop.dart';
import 'package:floop/internals.dart';

const speed = 4;

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

class Clicker extends StatelessWidget with Floop {
  const Clicker();

  @override
  Widget buildWithFloop(BuildContext context) {
    return Scaffold(
      body: BouncingNumber(),
      backgroundColor: Color.lerp(
        Colors.grey[900],
        Colors.blue[900],
        transition(100 * speed),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          floop['clicks']++;
          clearTransitions();
        },
      ),
    );
  }
}

class BouncingNumber extends StatelessWidget with Floop {
  BouncingNumber({Key key});

  @override
  Widget buildWithFloop(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment(2 * min(0.5, transition(800 * speed)) - 1,
              2 * max(0.5, transition(800 * speed)) - 2),
          child: Container(
            height: 150,
            width: 180,
            color: Color.lerp(Colors.yellow, Colors.red,
                transition(200 * speed, delayMillis: 1000 * speed)),
          ),
        ),
        Align(
          alignment: Alignment(
              transitionNumber(-1, 0, 1000 * speed),
              (1 - transition(800 * speed)) *
                  0.5 *
                  sin(transition(800 * speed) * 20 * pi)),
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
