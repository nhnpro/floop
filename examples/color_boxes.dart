import 'dart:math';

import 'package:floop/floop.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(title: 'Color change', home: ColoredGrid()));
}

class Dyn {
  static final _dyn = ObservedMap();

  static int get selectedBoxId => _dyn['selectedBoxId'];
  static set selectedBoxId(int id) => _dyn['selectedBoxId'] = id;

  static List<Widget> get widgets => _dyn['widgets'].cast<Widget>();
  static set widgets(List<Widget> w) => _dyn['widgets'] = w;
}

class ColoredGrid extends FloopWidget {
  @override
  void initContext(BuildContext context) {
    createRandomColorBoxList();
  }

  createRandomColorBoxList() {
    Dyn.selectedBoxId = null;
    final baseWidgets = List.generate(4, (i) => ColorBox(i)..forceInit());
    Dyn.widgets = List.generate(50, (i) => baseWidgets[i % 4])..shuffle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridView.count(
        crossAxisCount: 5,
        children: Dyn.widgets,
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.replay),
        onPressed: createRandomColorBoxList,
      ),
    );
  }
}

class ColorBox extends DynamicWidget {
  final int id;
  ColorBox(this.id);

  static final _color = UniqueKey();
  Color get color => dyn[_color];
  set color(Color c) => dyn[_color] = c;

  static final _textColor = UniqueKey();
  Color get textColor => dyn[_textColor];
  set textColor(Color c) => dyn[_textColor] = c;

  static final _clicks = UniqueKey();
  int get clicks => dyn[_clicks];
  set clicks(int n) => dyn[_clicks] = n;

  initDyn() {
    color = randomColor();
    textColor = contrastColor(color);
    clicks = 0;
  }

  @override
  Widget build(BuildContext context) {
    return RaisedButton(
      child: Dyn.selectedBoxId == id
          ? Text(
              '$clicks',
              style: TextStyle(
                color: textColor,
                fontSize: 26,
              ),
            )
          : null,
      color: color,
      onPressed: () {
        Dyn.selectedBoxId = id;
        clicks++;
        // note that widgets need to be converted to a list before shuffling.
        // This is because when List type instances are stored in an
        // ObservedMap, they are copied and stored as unmodifiable lists.
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
