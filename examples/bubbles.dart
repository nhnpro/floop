import 'dart:math';
import 'package:flutter/material.dart';
import 'package:floop/floop.dart';

const timeFactor = 2;
const diameter = 60.0;

List<InteractiveCircle> circleWidgets = List();

void main() {
  floop['circleWidgets'] = circleWidgets;
  runApp(MaterialApp(
      title: 'Bubbles',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Bubbles()));
}

class Bubbles extends StatelessWidget with Floop {
  @override
  Widget build(BuildContext context) {
    // int ms = 500 * timeFactor;
    List<Widget> widgets = floop['circleWidgets'].cast<Widget>();
    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Bubbles - Long press to spawn a bubble'),
        ),
        body: GestureDetector(
          child: Container(
            color: Colors.white,
            child: Stack(
              children: widgets,
            ),
          ),
          onLongPressStart: (details) {
            spawnCircle(details.localPosition, constraints.biggest);
          },
        ),
        floatingActionButton: FloatingActionButton(
            child: Icon(Icons.repeat),
            onPressed: () {
              TransitionGroup().resumeOrPause();
            }),
      );
    });
  }
}

class InteractiveCircle extends FloopWidget {
  final String name;
  final CircleProperties circle;
  InteractiveCircle(this.circle, {Key key})
      : name = circle.name,
        super(key: key);

  disposeContext(BuildContext context) {
    circle.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // print('building circle $name');
    int ms = min(5000, 500 * circle.count);
    var x = transition(ms, key: name, refreshPeriodicityMillis: 100);
    var pos = circle.position; // reads floop map
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: Opacity(
        opacity: transition(200 * timeFactor),
        child: GestureDetector(
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(5),
              height: diameter,
              width: diameter,
              decoration: BoxDecoration(
                color: Color.lerp(circle.baseColor, circle.color, x),
                shape: BoxShape.circle,
              ),
              child: Text(
                // the transition uses a key to prevent new transitions from
                // triggering when `ms` changes
                (circle.count * transition(ms, key: name + 'counter'))
                    .toInt()
                    .toString(),
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                ),
              ),
            ),
            onTap: () {
              placeCircleLast(name);
              circle.count = (circle.count + 1).clamp(0, 99);
              circle.baseColor = circle.color;
              circle.color = randomColor();
              TransitionGroup(key: name).cancel();
              TransitionGroup(key: circle.backKey).resumeOrPause();
            },
            onDoubleTap: () {
              TransitionGroup(context: context).cancel();
            },
            onPanStart: (_) {
              // TransitionGroup(context: context).clear();
              TransitionGroup(key: circle.backKey).cancel();
              circle.targetPosition = circle.position;
              placeCircleLast(name);
              // TransitionGroup(key: goBackKey).pause();
            },
            onPanUpdate: (drag) {
              // TransitionGroup(key: name + 'back').pause();
              circle.position += drag.delta;
            },
            onPanEnd: (_) => transitionBack(circle),
            onLongPress: () {
              removeCircle(name);
              TransitionGroup(context: context).cancel();
              TransitionGroup(key: circle.backKey).cancel();
            }),
      ),
    );
  }
}

class CircleProperties {
  static int _ids = 0;
  final int id;
  final int delay = 300 * timeFactor;
  final String name;
  final String backKey;
  final double _diameter;

  // floop map keys
  final String _count;
  final String _pos;
  final String _color;

  Color baseColor;
  Offset basePosition;
  Offset targetPosition;

  CircleProperties([double diameter = diameter])
      : name = 'circle$_ids',
        backKey = 'circle${_ids}back0',
        _count = 'circle${_ids}count',
        _pos = 'circle${_ids}pos',
        _color = 'circle${_ids}color',
        _diameter = diameter,
        id = _ids++ {
    count = 0;
    color = Colors.white;
  }

  double get radius => _diameter / 2;

  int get count => floop[_count];
  set count(int val) => floop[_count] = val;

  Offset get position => floop[_pos];
  set position(Offset newPos) => floop[_pos] = newPos;

  Color get color => floop[_color];
  set color(Color newColor) => floop[_color] = newColor;

  dispose() {
    floop.remove(_count);
    floop.remove(_pos);
    floop.remove(_color);
  }
}

spawnCircle(Offset offset, Size maxSpace) {
  var circle = CircleProperties();
  // fields read from floop map
  circle.count = 0;
  circle.position = offset - Offset(circle.radius, circle.radius);
  circle.color = randomColor();

  // other fields
  circle.basePosition = circle.position;
  circle.targetPosition = randomPosition(maxSpace.width, maxSpace.height);
  circle.baseColor = Colors.white;

  floop['circleWidgets'] = circleWidgets
    ..add(InteractiveCircle(
      circle,
      key: ValueKey(circle.id),
    ));
  transitionBack(circle, true);
}

transitionBack(CircleProperties circle, [bool delayed = false]) {
  TransitionGroup(key: circle.backKey).cancel();
  int delay = delayed ? circle.delay : 0;
  circle.basePosition = circle.position;
  transitionEval(1000 * timeFactor, (ratio) {
    circle.position =
        Offset.lerp(circle.basePosition, circle.targetPosition, ratio);
    if (ratio == 1) {
      // print('transition back ${circle.name}');
      circle.targetPosition = circle.basePosition;
      transitionBack(circle);
    }
    return ratio;
  }, key: circle.backKey, delayMillis: delay);
}

placeCircleLast(String name) {
  int i = circleWidgets.indexWhere((widget) => widget.circle.name == name);
  if (i < 0) {
    print('Widget $name not found: ${circleWidgets.map((w) => w.circle.name)}');
  } else {
    final circle = circleWidgets.removeAt(i);
    circleWidgets.add(circle);
  }
}

removeAll() {
  floop['circleWidgets'] = circleWidgets..clear();
}

removeCircle(String name) {
  circleWidgets.removeWhere((widget) => widget.circle.name == name);
  floop['circleWidgets'] = circleWidgets;
}

Offset randomPosition(double x, double y) {
  var r = Random();
  return Offset(x * r.nextDouble(), y * r.nextDouble());
}

Color randomColor() {
  const blend = 0xFA000000;
  return Color(Random().nextInt(1 << 32) | blend);
}
