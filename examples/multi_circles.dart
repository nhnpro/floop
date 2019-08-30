import 'dart:math';

import 'package:floop/internals.dart';
import 'package:flutter/material.dart';
import 'package:floop/floop.dart';

const timeFactor = 4;

Map<String, Offset> startingPositions = {
  'box1': Offset(200, 200),
  'box2': Offset(240, 200),
  'box3': Offset(200, 240),
  'box4': Offset(240, 240),
};

// List<NumberGesture> boxes = List.from(['box1', 'box2', 'box3', 'box4']);
List<NumberGesture> boxes = List();

int _boxes = 0;

placeLast(String name) {
  int i = boxes.indexWhere((widget) => widget.name == name);
  boxes.removeAt(i);
  boxes.add(NumberGesture(name));
}

addBox(String name) {
  floop[name + 'count'] = 0;
  floop[name + 'pos'] = Offset(200, 200);
  floop[name + 'color'] = randomColor();
  floop[name + 'prevColor'] = Colors.white;
  boxes.add(NumberGesture(name));
  floop['boxes'] = boxes;
}

Color randomColor() {
  const blend = 0xFA000000;
  return Color(Random().nextInt(1 << 32) | blend);
}

void main() {
  floop['inputText'] = 'Type text here';
  floop['text'] = 'Click me';
  for (var box in startingPositions.keys) {
    floop[box + 'pos'] = startingPositions[box];
    floop[box + 'count'] = 0;
  }
  runApp(MaterialApp(
      title: 'Clicker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: NumbersMove()));
}

class NumbersMove extends StatelessWidget with Floop {
  @override
  Widget buildWithFloop(BuildContext context) {
    int ms = 700;
    int i = 0;
    floop['boxes'];
    return Scaffold(
      appBar: AppBar(
        title: Text('Replay Text'),
      ),
      body: GestureDetector(
        child: Stack(
          children: boxes.map(
            (box) {
              Offset pos = floop[box.name + 'pos'];
              return Positioned(
                  key: Key(box.name),
                  left: pos.dx,
                  top: pos.dy,
                  child: Opacity(
                      opacity: transition(
                        ms,
                      ), //delayMillis: ms * i++),
                      child: box //NumberGesture(box),
                      ));
            },
          ).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () {
            Transitions.resumeOrPause();
            // addBox('box${_boxes++}');
          }),
    );
  }
}

const diameter = 60.0;

class NumberGesture extends FloopStatelessWidget {
  final String name;
  NumberGesture(this.name, {Key key}) : super(key: key) {
    if (floop[name + 'count'] == null) {
      // floop.setValue(name+'pos', Offset.zero, false);
      floop.setValue(name + 'count', 0, false);
    }
    // floop[box + 'count'] = 0;
  }

  @override
  Widget buildWithFloop(BuildContext context) {
    int ms = min(5000, 500 * floop[name + 'count']);
    var x = transition(ms, key: name, refreshRateMillis: 100);
    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        // return GestureDetector(
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(5),
          height: diameter,
          width: diameter,
          decoration: BoxDecoration(
            color:
                Color.lerp(floop[name + 'prevColor'], floop[name + 'color'], x),
            shape: BoxShape.circle,
          ),
          child: Text(
            floop[name + 'count'].toString(), // (x * ).toInt().toString(),
            style: TextStyle(
              fontSize: 30,
              color: Colors.white,
            ),
          ),
        ),
        onTap: () {
          placeLast(name);
          floop[name + 'count'] = (floop[name + 'count'] + 1) % 100;
          floop[name + 'prevColor'] = floop[name + 'color'];
          floop[name + 'color'] = randomColor();
          Transitions.clear(key: name);
          Transitions.resumeOrPause(key: name + 'back');
        },
        onPanStart: (_) {
          placeLast(name);
          Transitions.pause(key: name + 'back');
        },
        // onPanCancel: () => Transitions.resume(key: name + 'back'),
        onPanUpdate: (drag) {
          // Transitions.pause(key: name + 'back');
          floop[name + 'pos'] += drag.delta;
        },
        onPanEnd: (_) => transitionBack(name),
        onLongPress: () => floop[name + 'count'] = 0,
      );
    });
  }
}

transitionBack(String name) {
  Transitions.clear(key: name + 'back');
  Offset pos = floop[name + 'pos'];
  transitionEval(2000, (ratio) {
    floop[name + 'pos'] = Offset.lerp(pos, startingPositions[name], ratio);
  }, key: name + 'back');
}
