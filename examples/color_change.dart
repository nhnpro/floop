import 'dart:math';

import 'package:floop/floop.dart';
import 'package:flutter/material.dart';

void main() {
  // baseWidgets = createColorBoxes();
  runApp(MaterialApp(title: 'Color change', home: ColoredGridDemo()));
}

// class ColoredGrid extends FloopWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: GridView.count(
//         crossAxisCount: 5,
//         children: floop['widgets']
//             .cast<Widget>(), //<Widget>[ColorBox(0), ColorBox(1)],
//       ),
//       floatingActionButton: FloatingActionButton(
//         child: Icon(Icons.reorder),
//         onPressed: createRandomColorBoxList,
//       ),
//     );
//   }
// }

// class ColorBox extends DynamicWidget {
//   final int id;
//   ColorBox(this.id);

//   static int lastClickedId;

//   static final _clicks = UniqueKey();
//   int get clicks => dyn[_clicks];
//   set clicks(int n) => dyn[_clicks] = n;

//   static final _color = UniqueKey();
//   Color get color => dyn[_color];
//   set color(Color c) => dyn[_color] = c;

//   static final _textColor = UniqueKey();
//   Color get textColor => dyn[_textColor];
//   set textColor(Color c) => dyn[_textColor] = c;

//   initDyn() {
//     newColor();
//     clicks = 0;
//   }

//   newColor() {
//     final c = randomColor();
//     color = c;
//     textColor = contrastColor(c);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return RaisedButton(
//       child: Opacity(
//         opacity: lastClickedId == id ? 1 - transition(3000) : 0,
//         child: Text(
//           '${clicks}',
//           style: TextStyle(
//             color: textColor, //contrastColor(dyn['color']), //
//             fontSize: 26,
//           ),
//         ),
//       ),
//       color: color,
//       onPressed: () {
//         lastClickedId = id;
//         clicks++;
//         newColor();
//         Transitions.restart(context: context);
//         floop['widgets'] = (floop['widgets'] as List).toList()..shuffle();
//         // createRandomColorBoxList();
//       },
//     );
//   }
// }

class Dyn {
  static int get selectedBoxId => floop['selectedBoxId'];
  static set selectedBoxId(int id) => floop['selectedBoxId'] = id;

  static List<Widget> get widgets => floop['widgets'].cast<Widget>();
  static set widgets(List<Widget> w) => floop['widgets'] = w;
}

class ColoredGridDemo extends FloopWidget {
  @override
  void initContext(BuildContext context) {
    createRandomColorBoxList();
  }

  createRandomColorBoxList() {
    Dyn.selectedBoxId = null;
    final baseWidgets = List.generate(4, (i) => ColorBoxDemo(i)..forceInit());
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

class ColorBoxDemo extends DynamicWidget {
  final int id;
  ColorBoxDemo(this.id);

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
        // note that widgets need to be converted to list before shuffling,
        // because List type instances are copied in immutable versions when
        // stored in an ObservedMap.
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
  // print(
  //     'red: ${color.red}, green: ${color.green}, blue: ${color.blue}, sum: $sum');
  return sum > pow(0.5, gamma) ? Colors.black : Colors.white;
}

Color randomColor() {
  const blend = 0xFA000000;
  return Color(Random().nextInt(1 << 32) | blend);
}

const baseWidgetsCount = 8;
const totalWidgetsCount = 40;

// List<Widget> baseWidgets = createColorBoxes();

// List<Widget> createColorBoxes() {
//   final res = List.generate(baseWidgetsCount, (i) => ColorBox(i)..forceInit());
//   createRandomColorBoxList(res);
//   return res;
// }

// createRandomColorBoxList([List<Widget> widgets]) {
//   widgets ??= baseWidgets;
//   Random random = Random();
//   floop['widgets'] =
//       List.generate(50, (_) => widgets[random.nextInt(baseWidgetsCount)]);
// }
