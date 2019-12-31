import 'dart:math';

import 'package:flutter/material.dart';
import 'package:floop/floop.dart';

const speed = 7;

void main() {
  floop['clicks'] = 0;
  floop['left'] = 0.0;
  floop['top'] = 0.0;
  floop['rotate'] = Matrix4.identity();
  floop['offset'] = Offset.zero;
  runApp(MaterialApp(
      title: 'Bouncing Number',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PerspectiveLayout()));
}

class PerspectiveLayout extends StatelessWidget with Floop {
  const PerspectiveLayout();

  @override
  Widget build(BuildContext context) {
    return Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateX(0.01 * floop['offset'].dy) // changed
          ..rotateY(-0.01 * floop['offset'].dx), // changed,
        alignment: FractionalOffset.center,
        child: GestureDetector(
          onPanStart: (_) => TransitionGroup(key: Key('resetOffset')).cancel(),
          onPanUpdate: (details) => floop['offset'] += details.delta,
          onDoubleTap: () {
            var oldOffset = floop['offset'];
            transitionEval(
              3000,
              (ratio) {
                floop['offset'] = Offset.lerp(oldOffset, Offset.zero, ratio);
                return ratio;
              },
              key: Key('resetOffset'),
            );
          },
          child: _scaffoldBase(context),
        ));
  }

  Widget _scaffoldBase(BuildContext context) {
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
          TransitionGroup().cancel();
          transitionEval(
            3000,
            (x) {
              floop['rotate'] = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(x * 2 * pi)
                ..rotateY(x * 2 * pi);
              return x;
            },
            key: Key('rotate'),
          );
        },
      ),
    );
  }
}

class BouncingNumber extends StatelessWidget with Floop {
  const BouncingNumber({Key key});

  @override
  Widget build(BuildContext context) {
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
              transition(1000 * speed) - 1, // from left to the middle [-1, 0]
              (1 - transition(800 * speed)) * // amortizes the amplitude
                  0.5 * // scales the amplitude
                  sin(transition(800 * speed) * 20 * pi)), // oscillates
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
