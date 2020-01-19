import 'dart:math';

import 'package:floop/floop.dart';
import 'package:floop/transition.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(title: 'Color boxes', home: ColoredGrid()));
}

class Dyn {
  static final _dyn = DynMap();

  static int get selectedBoxId => _dyn[#selectedBoxId];
  static set selectedBoxId(int id) => _dyn[#selectedBoxId] = id;

  static List<Widget> get widgets => _dyn[#widgets].cast<Widget>();
  static set widgets(List<Widget> newWidgets) => _dyn[#widgets] = newWidgets;

  static int get totalClicks => _dyn[#totalClicks];
  static set totalClicks(int n) => _dyn[#totalClicks] = n;

  static bool get useRepeatingWidgets => _dyn[#useRepeatingWidgets];
  static set useRepeatingWidgets(bool value) =>
      _dyn[#useRepeatingWidgets] = value;
}

class ColoredGrid extends FloopWidget {
  @override
  void initContext(BuildContext context) {
    Dyn.totalClicks ??= 0;
    Dyn.useRepeatingWidgets = true;
    createRandomColorBoxList();
  }

  createRandomColorBoxList() {
    Dyn.selectedBoxId = null;
    final baseWidgets = List.generate(4, (i) => ColorBox(i)..forceInit());
    Dyn.widgets = List.generate(50, (i) => baseWidgets[i % 4])..shuffle();
  }

  @override
  Widget build(BuildContext context) {
    final clicks = Dyn.totalClicks;
    return Scaffold(
      appBar: AppBar(
        title: Text('Total clicks: $clicks'),
      ),
      body: Dyn.useRepeatingWidgets
          ? GridView.count(crossAxisCount: 5, children: Dyn.widgets)
          : GridView.count(
              crossAxisCount: 4,
              children: List.generate(
                20,
                (i) => ColorBox(clicks - i, key: ValueKey(clicks - i)),
              ),
            ),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.replay),
          onPressed: () {
            createRandomColorBoxList();
            Dyn.useRepeatingWidgets =
                !Dyn.useRepeatingWidgets || clicks % 2 == 0;
          }),
    );
  }
}

class ColorBox extends DynamicWidget {
  final int id;
  ColorBox(this.id, {Key key}) : super(key: key);

  Color get color => dyn[#color];
  set color(Color c) => dyn[#color] = c;

  Color get textColor => dyn[#textColor];
  set textColor(Color c) => dyn[#textColor] = c;

  int get clicks => dyn[#clicks];
  set clicks(int n) => dyn[#clicks] = n;

  initDyn() {
    color = randomColor();
    textColor = contrastColor(color);
    clicks = 0;
  }

  @override
  Widget build(BuildContext context) {
    return RaisedButton(
      child: Dyn.selectedBoxId == id
          ? Opacity(
              opacity: 1 - transition(2000, key: id),
              child: Text(
                '$clicks',
                style: TextStyle(
                  color: textColor,
                  fontSize: 26,
                ),
              ))
          : null,
      color: color,
      onPressed: () {
        clicks++;
        final switchMode = clicks % 4 == 0;
        Dyn.useRepeatingWidgets ^= switchMode;
        Dyn.selectedBoxId = switchMode ? null : id;
        Dyn.totalClicks++;
        TransitionGroup(key: id).restart();
        // Note that [Dyn.widgets] is copied into a new list prior to
        // shuffling. This is because when [List] instances are stored in an
        // [DynMap], they are copied and stored as unmodifiable lists.
        Dyn.widgets = Dyn.widgets.toList()..shuffle();
      },
    );
  }
}

Color contrastColor(Color color) {
  const gamma = 2.2;
  final sum = 0.2126 * pow(color.red / 255, gamma) +
      0.7152 * pow(color.green / 255, gamma) +
      0.0722 * pow(color.blue / 255, gamma);
  return sum > pow(0.5, gamma) ? Colors.black : Colors.white;
}

Color randomColor() {
  const blend = 0xFA000000;
  return Color(Random().nextInt(1 << 32) | blend);
}

/// The same ColorBox widget implemented using StatefulWidget.
class ColorBoxStateful extends StatefulWidget with FloopStateful {
  final int id;
  ColorBoxStateful(this.id, {Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ColorBoxState<ColorBoxStateful>(id);
}

class ColorBoxState<ColorBoxStateful> extends State {
  final int id;
  ColorBoxState(this.id, {Key key});

  Color color;
  Color textColor;
  int clicks = 0;

  @override
  void initState() {
    clicks = 0;
    color = randomColor();
    textColor = contrastColor(color);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return RaisedButton(
      child: Dyn.selectedBoxId == id
          ? Opacity(
              opacity: 1 - transition(2000, key: id),
              child: Text(
                '$clicks',
                style: TextStyle(
                  color: textColor,
                  fontSize: 26,
                ),
              ))
          : null,
      color: color,
      onPressed: () {
        setState(() => clicks++);
        TransitionGroup(key: id).restart();
        Dyn.selectedBoxId = id;
        Dyn.totalClicks++;
        Dyn.widgets = Dyn.widgets.toList()..shuffle();
      },
    );
  }
}
